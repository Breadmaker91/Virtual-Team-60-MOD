local nav_system = GetSelf()
dofile(LockOn_Options.script_path .. "command_defs.lua")

local update_time_step = 0.02
make_default_activity(update_time_step)

dofile(LockOn_Options.script_path .. "NavDataPlugin/Nav.lua")

local sensor_data = get_base_data()
local rmi_needle_arg = 345
local hsi_tacan_handle = get_param_handle("HSI_TACAN")
local rnav_display_enable = get_param_handle("RNAV_DISPLAY_ENABLE")
local rnav_display_frq = get_param_handle("RNAV_DISPLAY_FRQ")
local rnav_display_rad = get_param_handle("RNAV_DISPLAY_RAD")
local rnav_display_dst = get_param_handle("RNAV_DISPLAY_DST")
local rnav_display_power = 0

-- Initial VOR station tuning (MHz). We will replace this with cockpit controls later.
local tuned_vor_frequency_mhz = 113.00
local vor_min_frequency_mhz = 108.00
local vor_max_frequency_mhz = 117.95
local vor_small_step_mhz = 0.05
local vor_large_step_mhz = 1.00

local last_message_time = 0
local message_interval_seconds = 2.0
local current_rmi_value = 0
local target_rmi_value = 0
local rmi_slew_rate_arg_per_second = 1.2
local nav_debug_popup_enabled = false

local function nav_debug_popup(message)
    if nav_debug_popup_enabled then
        print_message_to_user(message)
    end
end

local function set_rnav_display_power(is_on)
    rnav_display_power = is_on and 1 or 0
    rnav_display_enable:set(rnav_display_power)
end

local function normalize_bearing(bearing_deg)
    local bearing = bearing_deg % 360
    if bearing < 0 then
        bearing = bearing + 360
    end
    return bearing
end

local function normalize_vor_frequency(freq_mhz)
    local snapped = math.floor((freq_mhz / vor_small_step_mhz) + 0.5) * vor_small_step_mhz

    while snapped > vor_max_frequency_mhz do
        snapped = snapped - (vor_max_frequency_mhz - vor_min_frequency_mhz + vor_small_step_mhz)
    end

    while snapped < vor_min_frequency_mhz do
        snapped = snapped + (vor_max_frequency_mhz - vor_min_frequency_mhz + vor_small_step_mhz)
    end

    return snapped
end

local function tune_vor_frequency(delta_mhz)
    local new_frequency = normalize_vor_frequency(tuned_vor_frequency_mhz + delta_mhz)
    if math.abs(new_frequency - tuned_vor_frequency_mhz) > 0.0001 then
        tuned_vor_frequency_mhz = new_frequency
        nav_debug_popup(string.format("VOR Tune: %.2f MHz", tuned_vor_frequency_mhz))
    end
end

local function command_value_to_clicks(value)
    if value == nil or math.abs(value) < 0.0001 then
        return 0
    end

    local clicks = math.max(1, math.floor((math.abs(value) / 0.09) + 0.5))
    if value < 0 then
        clicks = -clicks
    end
    return clicks
end

local function bearing_to_rmi_argument(bearing_deg)
    local normalized = normalize_bearing(bearing_deg)
    local signed = normalized
    if signed > 180 then
        signed = signed - 360
    end

    return signed / 180
end

local function set_rmi_needle(value)
    current_rmi_value = value
    hsi_tacan_handle:set(value)
    set_aircraft_draw_argument_value(rmi_needle_arg, value)

    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(rmi_needle_arg, value)
    end
end

local function normalize_rmi_value(value)
    local wrapped = value
    while wrapped > 1 do
        wrapped = wrapped - 2
    end
    while wrapped < -1 do
        wrapped = wrapped + 2
    end
    return wrapped
end

--[[local function update_rmi_slew()
    local delta = target_rmi_value - current_rmi_value
    if delta > 1 then
        delta = delta - 2
    elseif delta < -1 then
        delta = delta + 2
    end

    local max_step = rmi_slew_rate_arg_per_second * update_time_step
    if math.abs(delta) <= max_step then
        set_rmi_needle(normalize_rmi_value(target_rmi_value))
    else
        local step = max_step
        if delta < 0 then
            step = -max_step
        end
        set_rmi_needle(normalize_rmi_value(current_rmi_value + step))
    end
end]]--

local function update_rmi_slew()

    local current_deg = current_rmi_value * 180
    local target_deg  = target_rmi_value  * 180

    -- Shortest path
    local delta = target_deg - current_deg
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end

    local turn_rate = 60 -- deg/sec
    local max_step = turn_rate * update_time_step

    -- 🔴 KEY: clamp step so we NEVER overshoot
    local step = math.max(-max_step, math.min(max_step, delta))

    current_deg = current_deg + step

    -- 🔴 KEY: normalize angle AFTER movement, not via your normalize function
    if current_deg > 180 then
        current_deg = current_deg - 360
    elseif current_deg < -180 then
        current_deg = current_deg + 360
    end

    local new_value = current_deg / 180

    set_rmi_needle(new_value)
end

local function get_beacon_position(beacon)
    if type(beacon) ~= "table" then
        return nil, nil
    end

    if type(beacon.position) == "table" then
        local bx = beacon.position.x or beacon.position[1]
        local bz = beacon.position.z or beacon.position.y or beacon.position[3] or beacon.position[2]
        if bx ~= nil and bz ~= nil then
            return bx, bz
        end
    end

    if beacon.x ~= nil and (beacon.z ~= nil or beacon.y ~= nil) then
        return beacon.x, (beacon.z or beacon.y)
    end

    return nil, nil
end

local function get_tuned_vor_beacon()
    local vor_beacons = Get_VOR_beacons()
    if type(vor_beacons) ~= "table" then
        return nil
    end

    local tuned_frequency_hz = math.floor((tuned_vor_frequency_mhz * 1000000) + 0.5)
    return vor_beacons[tuned_frequency_hz]
end

local function calculate_vor_data(beacon)
    local own_x, _, own_z = sensor_data.getSelfCoordinates()
    if own_x == nil or own_z == nil then
        return nil
    end

    local beacon_x, beacon_z = get_beacon_position(beacon)
    if beacon_x == nil or beacon_z == nil then
        return nil
    end

    local own_geo = lo_to_geo_coords(own_x, own_z)
    local beacon_geo = lo_to_geo_coords(beacon_x, beacon_z)
    if own_geo == nil or beacon_geo == nil then
        return nil
    end

    local distance_nm = haversine(own_geo.lat, own_geo.lon, beacon_geo.lat, beacon_geo.lon)
    local bearing_true = normalize_bearing(getBearing(own_geo.lat, own_geo.lon, beacon_geo.lat, beacon_geo.lon))
    return {
        distance_nm = distance_nm,
        bearing_true = bearing_true,
    }
end

function post_initialize()
    nav_system:listen_command(Keys.Nav_VOR_MHz)
    nav_system:listen_command(Keys.Nav_VOR_005)
    nav_system:listen_command(Keys.Nav_RNAV_PWR)
    set_rnav_display_power(false)
    rnav_display_frq:set(tuned_vor_frequency_mhz)
    rnav_display_rad:set(0)
    rnav_display_dst:set(0)
    set_rmi_needle(0)
    nav_debug_popup(string.format("NAV INIT: Tuned VOR %.2f MHz", tuned_vor_frequency_mhz))
end

function SetCommand(command, value)
    if command == Keys.Nav_VOR_MHz then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            tune_vor_frequency(vor_large_step_mhz * clicks)
        end
    elseif command == Keys.Nav_VOR_005 then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            tune_vor_frequency(vor_small_step_mhz * clicks)
        end
    elseif command == Keys.Nav_RNAV_PWR then
        local clicks = command_value_to_clicks(value)
        if clicks > 0 then
            set_rnav_display_power(true)
        elseif clicks < 0 then
            set_rnav_display_power(false)
        end
    end
end

function update()
    rnav_display_enable:set(rnav_display_power)
    rnav_display_frq:set(tuned_vor_frequency_mhz)

    local tuned_beacon = get_tuned_vor_beacon()
    if tuned_beacon == nil then
        rnav_display_rad:set(0)
        rnav_display_dst:set(0)
        target_rmi_value = current_rmi_value
        update_rmi_slew()
        local now = get_absolute_model_time()
        if now - last_message_time >= message_interval_seconds then
            last_message_time = now
            nav_debug_popup(string.format("VOR %.2f MHz: station not found", tuned_vor_frequency_mhz))
        end
        return
    end

    local vor_data = calculate_vor_data(tuned_beacon)
    if vor_data == nil then
        rnav_display_rad:set(0)
        rnav_display_dst:set(0)
        target_rmi_value = current_rmi_value
        update_rmi_slew()
        local now = get_absolute_model_time()
        if now - last_message_time >= message_interval_seconds then
            last_message_time = now
            nav_debug_popup(string.format("VOR %.2f MHz: station data incomplete", tuned_vor_frequency_mhz))
        end
        return
    end

    -- The RMI needle is parented to the rotating compass card (arg 341),
    -- so it must receive absolute bearing-to-station, not relative bearing.
    target_rmi_value = bearing_to_rmi_argument(vor_data.bearing_true)
    update_rmi_slew()
    rnav_display_rad:set(vor_data.bearing_true)
    rnav_display_dst:set(vor_data.distance_nm)

    local now = get_absolute_model_time()
    if now - last_message_time < message_interval_seconds then
        return
    end
    last_message_time = now

    nav_debug_popup(string.format(
        "VOR %.2f | BRG %03.0f° | DME %.1f NM",
        tuned_vor_frequency_mhz,
        vor_data.bearing_true,
        vor_data.distance_nm
    ))
end

need_to_be_closed = false
