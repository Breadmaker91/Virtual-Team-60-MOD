local nav_system = GetSelf()
dofile(LockOn_Options.script_path .. "command_defs.lua")

local update_time_step = 0.02
make_default_activity(update_time_step)
local RAD_TO_DEGREE  = 57.29577951308233
local DEG_TO_RADIAN  = 0.0174532925199433

dofile(LockOn_Options.script_path .. "NavDataPlugin/Nav.lua")

local sensor_data = get_base_data()
local rnav_power_knob_arg = 735
local dme_power_knob_arg = 718
local rmi_needle_arg = 345
local adf_needle_arg = 346
local hsi_course_needle_arg = 752
local hsi_cdi_arg = 742
local hsi_tacan_handle = get_param_handle("HSI_TACAN")
local hsi_adf_handle = get_param_handle("HSI_ADF")
local hsi_course_needle_handle = get_param_handle("HSI_COURSE_NEEDLE")
local hsi_cdi_handle = get_param_handle("HSI_CDI")
local ehsi_course_roll = get_param_handle("COURSE_ROLL")
local ehsi_course_heading = get_param_handle("EHSI_COURSE")
local rnav_display_enable = get_param_handle("RNAV_DISPLAY_ENABLE")
local rnav_display_frq = get_param_handle("RNAV_DISPLAY_FRQ")
local rnav_display_rad = get_param_handle("RNAV_DISPLAY_RAD")
local rnav_display_dst = get_param_handle("RNAV_DISPLAY_DST")
local rnav_display_wpt = get_param_handle("RNAV_DISPLAY_WPT")
local rnav_power_knob_anim = get_param_handle("PTN_735")
local rnav_sel_frq = get_param_handle("RNAV_SEL_FRQ")
local rnav_sel_rad = get_param_handle("RNAV_SEL_RAD")
local rnav_sel_dst = get_param_handle("RNAV_SEL_DST")
local rnav_sel_blink = get_param_handle("RNAV_SEL_BLINK")
local rnav_ils_mode = get_param_handle("RNAV_ILS_MODE")
local ils_bars_visible = get_param_handle("ILS_BARS_VISIBLE")
local ils_loc_dev = get_param_handle("ILS_LOC_DEV")
local ils_gs_dev = get_param_handle("ILS_GS_DEV")
local rnav_display_power = 0
local adf_display_enable = get_param_handle("ADF_DISPLAY_ENABLE")
local adf_display_freq = get_param_handle("ADF_DISPLAY_FREQ")
local adf_display_power = 0
local dme_display_enable = get_param_handle("DME_DISPLAY_ENABLE")
local dme_display_dist = get_param_handle("DME_DISPLAY_DIST")
local dme_display_gs = get_param_handle("DME_DISPLAY_GS")
local dme_display_time = get_param_handle("DME_DISPLAY_TIME")
local dme_data_valid = get_param_handle("DME_DATA_VALID")
local dme_power_knob_anim = get_param_handle("PTN_718")
local nav_main_power_switch = get_param_handle("PTN_401")
local nav_converter_switch = get_param_handle("PTN_402")
local dme_display_power = 0
local selected_vor_course_deg = 0
local selected_offset_radial_deg = 0
local selected_offset_distance_nm = 0
local EDIT_SEGMENT_FRQ = 1
local EDIT_SEGMENT_RAD = 2
local EDIT_SEGMENT_DST = 3
local active_rnav_edit_segment = EDIT_SEGMENT_FRQ
local current_waypoint_index = 0
local waypoint_slot_count = 10
local waypoint_slots = {}

-- Initial VOR station tuning (MHz). We will replace this with cockpit controls later.
local tuned_vor_frequency_mhz = 113.00
local vor_min_frequency_mhz = 108.00
local vor_max_frequency_mhz = 117.95
local vor_small_step_mhz = 0.05
local vor_large_step_mhz = 1.00
local tuned_ndb_frequency_khz = 350
local ndb_min_frequency_khz = 200
local ndb_max_frequency_khz = 1799
local ndb_small_step_khz = 1
local ndb_large_step_khz = 100
local ndb_large_min_khz = 200
local ndb_large_max_khz = 1700

local last_message_time = 0
local message_interval_seconds = 2.0
local ils_message_interval_seconds = 0.5
local last_ils_message_time = -10
local current_rmi_value = 0
local target_rmi_value = 0
local current_adf_value = 0
local target_adf_value = 0
local rmi_slew_rate_arg_per_second = 1.2
local current_ils_loc_value = 0
local target_ils_loc_value = 0
local current_ils_gs_value = 0
local target_ils_gs_value = 0
local ils_bar_slew_per_second = 0.7
local nav_debug_popup_enabled = false
local last_announced_ils_frequency_hz = nil

local function nav_debug_popup(message)
    if nav_debug_popup_enabled then
        print_message_to_user(message)
    end
end

local function set_rnav_display_power(is_on)
    rnav_display_power = is_on and 1 or 0
    rnav_display_enable:set(rnav_display_power)
    rnav_power_knob_anim:set(rnav_display_power)
    set_aircraft_draw_argument_value(rnav_power_knob_arg, rnav_display_power)
    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(rnav_power_knob_arg, rnav_display_power)
    end
end

local function set_adf_display_power(is_on)
    adf_display_power = is_on and 1 or 0
    adf_display_enable:set(adf_display_power)
end

local function set_dme_display_power(is_on)
    dme_display_power = is_on and 1 or 0
    dme_display_enable:set(dme_display_power)
    dme_power_knob_anim:set(dme_display_power)
    set_aircraft_draw_argument_value(dme_power_knob_arg, dme_display_power)
    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(dme_power_knob_arg, dme_display_power)
    end
end

local function is_nav_units_power_available()
    return nav_main_power_switch:get() > 0.5 and nav_converter_switch:get() > 0.5
end

local function enforce_nav_units_power_dependency()
    if is_nav_units_power_available() then
        return
    end

    if rnav_display_power ~= 0 then
        set_rnav_display_power(false)
    end
    if adf_display_power ~= 0 then
        set_adf_display_power(false)
    end
    if dme_display_power ~= 0 then
        set_dme_display_power(false)
    end
end

local function normalize_bearing(bearing_deg)
    local bearing = bearing_deg % 360
    if bearing < 0 then
        bearing = bearing + 360
    end
    return bearing
end

local function shortest_angle_delta(from_deg, to_deg)
    local delta = (to_deg - from_deg + 180) % 360 - 180
    return delta
end

local function get_magnetic_variation_deg()
    if type(sensor_data.getHeading) ~= "function" or type(sensor_data.getMagneticHeading) ~= "function" then
        return nil
    end

    local true_heading_rad = sensor_data.getHeading()
    local magnetic_heading_rad = sensor_data.getMagneticHeading()
    if type(true_heading_rad) ~= "number" or type(magnetic_heading_rad) ~= "number" then
        return nil
    end

    -- In DCS sensor API, true heading uses opposite turn sign versus magnetic heading.
    -- Convert true heading convention first, then compute (true - magnetic).
    local true_converted_rad = (2 * math.pi) - true_heading_rad
    local variation = (true_converted_rad - magnetic_heading_rad) * RAD_TO_DEGREE
    if variation > 180 then
        variation = variation - 360
    elseif variation < -180 then
        variation = variation + 360
    end
    return variation
end

local function true_to_magnetic(true_bearing_deg)
    local variation_deg = get_magnetic_variation_deg()
    if variation_deg == nil then
        return normalize_bearing(true_bearing_deg)
    end

    return normalize_bearing(true_bearing_deg - variation_deg)
end

local function magnetic_to_true(magnetic_bearing_deg)
    local variation_deg = get_magnetic_variation_deg()
    if variation_deg == nil then
        return normalize_bearing(magnetic_bearing_deg)
    end

    return normalize_bearing(magnetic_bearing_deg + variation_deg)
end

local function destination_point_geo(lat_deg, lon_deg, bearing_deg, distance_nm)
    local angular_distance = (distance_nm or 0) / 3440.065
    local bearing_rad = normalize_bearing(bearing_deg) * DEG_TO_RADIAN
    local lat1 = lat_deg * DEG_TO_RADIAN
    local lon1 = lon_deg * DEG_TO_RADIAN

    local sin_lat1 = math.sin(lat1)
    local cos_lat1 = math.cos(lat1)
    local sin_ad = math.sin(angular_distance)
    local cos_ad = math.cos(angular_distance)

    local lat2 = math.asin((sin_lat1 * cos_ad) + (cos_lat1 * sin_ad * math.cos(bearing_rad)))
    local lon2 = lon1 + math.atan2(
        math.sin(bearing_rad) * sin_ad * cos_lat1,
        cos_ad - (sin_lat1 * math.sin(lat2))
    )

    return {
        lat = lat2 * RAD_TO_DEGREE,
        lon = lon2 * RAD_TO_DEGREE,
    }
end

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
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

local function normalize_radial(radial_deg)
    return normalize_bearing(radial_deg)
end

local function set_offset_radial(radial_deg)
    selected_offset_radial_deg = normalize_radial(radial_deg)
end

local function set_offset_distance(distance_nm)
    selected_offset_distance_nm = clamp(distance_nm, 0, 999.9)
end

local function create_default_waypoint_slot()
    return {
        vor_frequency_mhz = 113.00,
        offset_radial_deg = 0,
        offset_distance_nm = 0,
    }
end

local function waypoint_slot_to_array_index(waypoint_index)
    return (waypoint_index % waypoint_slot_count) + 1
end

local function save_current_waypoint_slot()
    local slot = waypoint_slots[waypoint_slot_to_array_index(current_waypoint_index)]
    if slot == nil then
        return
    end

    slot.vor_frequency_mhz = tuned_vor_frequency_mhz
    slot.offset_radial_deg = selected_offset_radial_deg
    slot.offset_distance_nm = selected_offset_distance_nm
end

local function load_waypoint_slot(waypoint_index)
    local slot = waypoint_slots[waypoint_slot_to_array_index(waypoint_index)]
    if slot == nil then
        return
    end

    current_waypoint_index = waypoint_index % waypoint_slot_count
    tuned_vor_frequency_mhz = normalize_vor_frequency(slot.vor_frequency_mhz or tuned_vor_frequency_mhz)
    set_offset_radial(slot.offset_radial_deg or selected_offset_radial_deg)
    set_offset_distance(slot.offset_distance_nm or selected_offset_distance_nm)
end

local function cycle_waypoint_slot(delta_slots)
    if delta_slots == 0 then
        return
    end

    save_current_waypoint_slot()
    load_waypoint_slot(current_waypoint_index + delta_slots)
end

local function cycle_rnav_edit_segment()
    active_rnav_edit_segment = active_rnav_edit_segment + 1
    if active_rnav_edit_segment > EDIT_SEGMENT_DST then
        active_rnav_edit_segment = EDIT_SEGMENT_FRQ
    end

    if active_rnav_edit_segment == EDIT_SEGMENT_FRQ then
        print_message_to_user("RNAV edit segment: FRQ")
    elseif active_rnav_edit_segment == EDIT_SEGMENT_RAD then
        print_message_to_user("RNAV edit segment: RAD")
    else
        print_message_to_user("RNAV edit segment: DST")
    end
end

local function update_rnav_selection_indicator()
    rnav_sel_frq:set(active_rnav_edit_segment == EDIT_SEGMENT_FRQ and 1 or 0)
    rnav_sel_rad:set(active_rnav_edit_segment == EDIT_SEGMENT_RAD and 1 or 0)
    rnav_sel_dst:set(active_rnav_edit_segment == EDIT_SEGMENT_DST and 1 or 0)

    local now = get_absolute_model_time()
    local blink_on = (math.floor(now * 2) % 2) == 0
    rnav_sel_blink:set(blink_on and 1 or 0)
end

local function tune_vor_frequency(delta_mhz)
    local new_frequency = normalize_vor_frequency(tuned_vor_frequency_mhz + delta_mhz)
    if math.abs(new_frequency - tuned_vor_frequency_mhz) > 0.0001 then
        tuned_vor_frequency_mhz = new_frequency
        nav_debug_popup(string.format("VOR Tune: %.2f MHz", tuned_vor_frequency_mhz))
    end
end

local function tune_ndb_frequency_small(delta_khz)
    local large = math.floor(tuned_ndb_frequency_khz / 100) * 100
    local small = tuned_ndb_frequency_khz % 100
    local new_small = (small + delta_khz) % 100
    if new_small < 0 then
        new_small = new_small + 100
    end

    local new_frequency = large + new_small
    if math.abs(new_frequency - tuned_ndb_frequency_khz) > 0.0001 then
        tuned_ndb_frequency_khz = new_frequency
        nav_debug_popup(string.format("ADF Tune: %04.0f kHz", tuned_ndb_frequency_khz))
    end
end

local function tune_ndb_frequency_large(delta_khz)
    local large = math.floor(tuned_ndb_frequency_khz / 100) * 100
    local small = tuned_ndb_frequency_khz % 100
    local steps = math.floor(delta_khz / ndb_large_step_khz)
    if steps == 0 then
        return
    end

    local range_steps = math.floor((ndb_large_max_khz - ndb_large_min_khz) / ndb_large_step_khz) + 1
    local large_index = math.floor((large - ndb_large_min_khz) / ndb_large_step_khz)
    large_index = (large_index + steps) % range_steps
    if large_index < 0 then
        large_index = large_index + range_steps
    end

    local new_large = ndb_large_min_khz + (large_index * ndb_large_step_khz)
    local new_frequency = new_large + small
    if new_frequency < ndb_min_frequency_khz then
        new_frequency = ndb_min_frequency_khz
    elseif new_frequency > ndb_max_frequency_khz then
        new_frequency = ndb_max_frequency_khz
    end

    if math.abs(new_frequency - tuned_ndb_frequency_khz) > 0.0001 then
        tuned_ndb_frequency_khz = new_frequency
        nav_debug_popup(string.format("ADF Tune: %04.0f kHz", tuned_ndb_frequency_khz))
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

local function course_knob_value_to_degrees(value)
    if value == nil or math.abs(value) < 0.0001 then
        return 0
    end

    -- PTN_750 reports very small relative deltas compared to the VOR frequency knobs.
    -- Use a dedicated conversion so every valid scroll input creates at least 1° change.
    local degrees = math.max(1, math.floor((math.abs(value) * 20) + 0.5))
    if value < 0 then
        degrees = -degrees
    end
    return degrees
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

local function set_adf_needle(value)
    current_adf_value = value
    hsi_adf_handle:set(value)
    set_aircraft_draw_argument_value(adf_needle_arg, value)

    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(adf_needle_arg, value)
    end
end

local function course_deg_to_hsi_argument(course_deg)
    local normalized = normalize_bearing(course_deg)
    if normalized > 180 then
        normalized = normalized - 360
    end
    return normalized / 180
end

local function set_course_needle(course_deg)
    local arg_value = course_deg_to_hsi_argument(course_deg)
    hsi_course_needle_handle:set(arg_value)
    set_aircraft_draw_argument_value(hsi_course_needle_arg, arg_value)

    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(hsi_course_needle_arg, arg_value)
    end
end

local function set_hsi_cdi(value)
    local clamped = clamp(value, -1, 1)
    hsi_cdi_handle:set(clamped)
    set_aircraft_draw_argument_value(hsi_cdi_arg, clamped)

    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(hsi_cdi_arg, clamped)
    end
end

local function set_selected_vor_course(course_deg)
    selected_vor_course_deg = normalize_bearing(course_deg)
    ehsi_course_roll:set(selected_vor_course_deg)
    ehsi_course_heading:set(selected_vor_course_deg)
    set_course_needle(selected_vor_course_deg)
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

local function update_adf_slew()
    local current_deg = current_adf_value * 180
    local target_deg  = target_adf_value  * 180

    local delta = target_deg - current_deg
    if delta > 180 then
        delta = delta - 360
    elseif delta < -180 then
        delta = delta + 360
    end

    local turn_rate = 60
    local max_step = turn_rate * update_time_step
    local step = math.max(-max_step, math.min(max_step, delta))

    current_deg = current_deg + step

    if current_deg > 180 then
        current_deg = current_deg - 360
    elseif current_deg < -180 then
        current_deg = current_deg + 360
    end

    set_adf_needle(current_deg / 180)
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

local function get_tuned_ils_beacon()
    local ils_beacons = Get_ILS_beacons()
    if type(ils_beacons) ~= "table" then
        return nil
    end

    local tuned_frequency_hz = math.floor((tuned_vor_frequency_mhz * 1000000) + 0.5)
    return ils_beacons[tuned_frequency_hz]
end

local function is_ils_frequency_selected(freq_mhz)
    return freq_mhz >= 108.10 and freq_mhz <= 111.95
end

local function get_beacon_display_name(beacon)
    if type(beacon) ~= "table" then
        return "UNKNOWN ILS"
    end

    if type(beacon.display_name) == "string" and beacon.display_name ~= "" then
        return beacon.display_name
    end

    if type(beacon.name) == "string" and beacon.name ~= "" then
        return beacon.name
    end

    if type(beacon.callsign) == "string" and beacon.callsign ~= "" then
        return beacon.callsign
    end

    return "UNKNOWN ILS"
end

local function get_ils_course_deg(beacon)
    if type(beacon) ~= "table" then
        return nil
    end

    local direction = beacon.direction or beacon.course or beacon.runway_course
    if type(direction) == "number" then
        return normalize_bearing(direction)
    end

    if type(beacon.position) == "table" and type(beacon.position.direction) == "number" then
        return normalize_bearing(beacon.position.direction)
    end

    return nil
end

local function get_beacon_altitude_m(beacon)
    if type(beacon) ~= "table" then
        return 0
    end

    if type(beacon.position) == "table" then
        local by = beacon.position.y or beacon.position.alt or beacon.position[2]
        if type(by) == "number" then
            return by
        end
    end

    if type(beacon.y) == "number" then
        return beacon.y
    end

    return 0
end

local function calculate_ils_deviation(beacon)
    local beacon_x, beacon_z = get_beacon_position(beacon)
    if beacon_x == nil or beacon_z == nil then
        return 0, 0, 0, 0
    end

    local own_x, own_y, own_z = sensor_data.getSelfCoordinates()
    if own_x == nil or own_z == nil then
        return 0, 0, 0, 0
    end

    local own_geo = lo_to_geo_coords(own_x, own_z)
    local beacon_geo = lo_to_geo_coords(beacon_x, beacon_z)
    if own_geo == nil or beacon_geo == nil then
        return 0, 0, 0, 0
    end

    local ils_course = get_ils_course_deg(beacon)
    if ils_course == nil then
        return 0, 0, 0, 0
    end

    -- Localizer full scale deflection ≈ 2.5 deg.
    local bearing_to_station = normalize_bearing(getBearing(own_geo.lat, own_geo.lon, beacon_geo.lat, beacon_geo.lon))
    local loc_delta_deg = shortest_angle_delta(bearing_to_station, ils_course)

    local loc_norm = clamp(loc_delta_deg / 2.5, -1, 1)

    -- Glideslope full scale deflection ≈ 1.4 deg around 3 deg nominal.
    local horizontal_distance_m = math.sqrt((beacon_x - own_x)^2 + (beacon_z - own_z)^2)
    local beacon_alt_m = get_beacon_altitude_m(beacon)
    local own_alt_m = own_y or beacon_alt_m
    local vertical_delta_m = own_alt_m - beacon_alt_m
    local current_slope_deg = math.deg(math.atan2(vertical_delta_m, math.max(horizontal_distance_m, 1)))
    local gs_error_deg = current_slope_deg - 3.0
    local gs_norm = clamp((-gs_error_deg) / 1.4, -1, 1)

    return loc_norm, gs_norm, loc_delta_deg, gs_error_deg
end

local function update_ils_bar_slew()
    local max_step = ils_bar_slew_per_second * update_time_step

    local delta_loc = target_ils_loc_value - current_ils_loc_value
    if math.abs(delta_loc) <= max_step then
        current_ils_loc_value = target_ils_loc_value
    else
        current_ils_loc_value = current_ils_loc_value + (delta_loc > 0 and max_step or -max_step)
    end

    local delta_gs = target_ils_gs_value - current_ils_gs_value
    if math.abs(delta_gs) <= max_step then
        current_ils_gs_value = target_ils_gs_value
    else
        current_ils_gs_value = current_ils_gs_value + (delta_gs > 0 and max_step or -max_step)
    end

    ils_loc_dev:set(current_ils_loc_value)
    ils_gs_dev:set(current_ils_gs_value)
end

local function get_tuned_ndb_beacon()
    local ndb_beacons = Get_NDB_beacons()
    if type(ndb_beacons) ~= "table" then
        return nil
    end

    local tuned_frequency_hz = math.floor((tuned_ndb_frequency_khz * 1000) + 0.5)
    return ndb_beacons[tuned_frequency_hz]
end

local function calculate_vor_data(beacon, target_geo_override)
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

    local target_geo = target_geo_override or beacon_geo
    local distance_nm = haversine(own_geo.lat, own_geo.lon, target_geo.lat, target_geo.lon)
    local bearing_true = normalize_bearing(getBearing(own_geo.lat, own_geo.lon, target_geo.lat, target_geo.lon))
    local bearing_magnetic = true_to_magnetic(bearing_true)
    return {
        distance_nm = distance_nm,
        bearing_true = bearing_true,
        bearing_magnetic = bearing_magnetic,
        target_geo = target_geo,
        beacon_geo = beacon_geo,
    }
end

local function calculate_closing_speed_to_target(target_geo)
    local own_x, _, own_z = sensor_data.getSelfCoordinates()
    local vel_x, _, vel_z = sensor_data.getSelfVelocity()
    if own_x == nil or own_z == nil or vel_x == nil or vel_z == nil or target_geo == nil then
        return nil
    end

    local own_geo = lo_to_geo_coords(own_x, own_z)
    if own_geo == nil then
        return nil
    end

    local gs_mps = math.sqrt((vel_x * vel_x) + (vel_z * vel_z))
    if gs_mps < 0.1 then
        return 0
    end

    local track_true = normalize_bearing(math.deg(math.atan2(vel_x, vel_z)))
    local bearing_true = normalize_bearing(getBearing(own_geo.lat, own_geo.lon, target_geo.lat, target_geo.lon))
    local closure_mps = gs_mps * math.cos(shortest_angle_delta(track_true, bearing_true) * DEG_TO_RADIAN)
    if closure_mps < 0 then
        return 0
    end

    return closure_mps * 1.9438444924406 -- m/s -> knots
end

local function get_offset_waypoint_geo(beacon)
    local beacon_x, beacon_z = get_beacon_position(beacon)
    if beacon_x == nil or beacon_z == nil then
        return nil
    end

    local beacon_geo = lo_to_geo_coords(beacon_x, beacon_z)
    if beacon_geo == nil then
        return nil
    end

    local selected_radial_true = magnetic_to_true(selected_offset_radial_deg)
    return destination_point_geo(beacon_geo.lat, beacon_geo.lon, selected_radial_true, selected_offset_distance_nm)
end

function post_initialize()
    nav_system:listen_command(Keys.Nav_Course_Sel)
    nav_system:listen_command(Keys.Nav_Right_Knob_L)
    nav_system:listen_command(Keys.Nav_Right_Knob_S)
    nav_system:listen_command(Keys.Nav_RNAV_DAT_CYCLE)
    nav_system:listen_command(Keys.Nav_RNAV_WPT_CYCLE)
    nav_system:listen_command(Keys.Nav_VOR_MHz)
    nav_system:listen_command(Keys.Nav_VOR_005)
    nav_system:listen_command(Keys.Nav_ADF_100)
    nav_system:listen_command(Keys.Nav_ADF_1)
    nav_system:listen_command(Keys.Nav_ADF_PWR)
    nav_system:listen_command(Keys.Nav_DME_PWR)
    nav_system:listen_command(Keys.Nav_RNAV_PWR)
    set_rnav_display_power(false)
    rnav_ils_mode:set(0)
    ils_bars_visible:set(0)
    ils_loc_dev:set(0)
    ils_gs_dev:set(0)
    current_ils_loc_value = 0
    target_ils_loc_value = 0
    current_ils_gs_value = 0
    target_ils_gs_value = 0
    set_adf_display_power(false)
    set_dme_display_power(false)
    adf_display_freq:set(tuned_ndb_frequency_khz)
    dme_display_dist:set(0)
    dme_display_gs:set(0)
    dme_display_time:set(0)
    dme_data_valid:set(0)
    rnav_display_frq:set(tuned_vor_frequency_mhz)
    rnav_display_wpt:set(current_waypoint_index)
    set_offset_radial(0)
    set_offset_distance(0)
    for i = 1, waypoint_slot_count do
        waypoint_slots[i] = create_default_waypoint_slot()
    end
    save_current_waypoint_slot()
    active_rnav_edit_segment = EDIT_SEGMENT_FRQ
    rnav_display_rad:set(selected_offset_radial_deg)
    rnav_display_dst:set(selected_offset_distance_nm)
    rnav_sel_frq:set(1)
    rnav_sel_rad:set(0)
    rnav_sel_dst:set(0)
    rnav_sel_blink:set(1)
    set_selected_vor_course(0)
    set_hsi_cdi(0)
    set_rmi_needle(0)
    set_adf_needle(0)

    local birth = LockOn_Options.init_conditions.birth_place
    local is_hot_start = (birth == "GROUND_HOT" or birth == "AIR_HOT")
    if is_hot_start then
        set_rnav_display_power(true)
        set_adf_display_power(true)
        set_dme_display_power(true)
    end

    nav_debug_popup(string.format("NAV INIT: Tuned VOR %.2f MHz", tuned_vor_frequency_mhz))
end

function SetCommand(command, value)
    if command == Keys.Nav_VOR_MHz then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            if active_rnav_edit_segment == EDIT_SEGMENT_FRQ then
                tune_vor_frequency(vor_large_step_mhz * clicks)
            elseif active_rnav_edit_segment == EDIT_SEGMENT_RAD then
                set_offset_radial(selected_offset_radial_deg + (clicks * 10))
            else
                set_offset_distance(selected_offset_distance_nm + (clicks * 1.0))
            end
            save_current_waypoint_slot()
        end
    elseif command == Keys.Nav_VOR_005 then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            if active_rnav_edit_segment == EDIT_SEGMENT_FRQ then
                tune_vor_frequency(vor_small_step_mhz * clicks)
            elseif active_rnav_edit_segment == EDIT_SEGMENT_RAD then
                set_offset_radial(selected_offset_radial_deg + clicks)
            else
                set_offset_distance(selected_offset_distance_nm + (clicks * 0.1))
            end
            save_current_waypoint_slot()
        end
    elseif command == Keys.Nav_Course_Sel then
        local delta_degrees = course_knob_value_to_degrees(value)
        if delta_degrees ~= 0 then
            set_selected_vor_course(selected_vor_course_deg + delta_degrees)
        end
    elseif command == Keys.Nav_Right_Knob_L then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            if active_rnav_edit_segment == EDIT_SEGMENT_FRQ then
                tune_vor_frequency(vor_large_step_mhz * clicks)
            elseif active_rnav_edit_segment == EDIT_SEGMENT_RAD then
                set_offset_radial(selected_offset_radial_deg + (clicks * 10))
            else
                set_offset_distance(selected_offset_distance_nm + (clicks * 1.0))
            end
            save_current_waypoint_slot()
        end
    elseif command == Keys.Nav_Right_Knob_S then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            if active_rnav_edit_segment == EDIT_SEGMENT_FRQ then
                tune_vor_frequency(vor_small_step_mhz * clicks)
            elseif active_rnav_edit_segment == EDIT_SEGMENT_RAD then
                set_offset_radial(selected_offset_radial_deg + clicks)
            else
                set_offset_distance(selected_offset_distance_nm + (clicks * 0.1))
            end
            save_current_waypoint_slot()
        end
    elseif command == Keys.Nav_RNAV_DAT_CYCLE then
        if value == nil or value > 0 then
            cycle_rnav_edit_segment()
        end
    elseif command == Keys.Nav_RNAV_WPT_CYCLE then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            cycle_waypoint_slot(clicks)
        end
    elseif command == Keys.Nav_ADF_100 then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            tune_ndb_frequency_large(ndb_large_step_khz * clicks)
        end
    elseif command == Keys.Nav_ADF_1 then
        local clicks = command_value_to_clicks(value)
        if clicks ~= 0 then
            tune_ndb_frequency_small(ndb_small_step_khz * clicks)
        end
    elseif command == Keys.Nav_ADF_PWR then
        local clicks = command_value_to_clicks(value)
        if clicks > 0 then
            if is_nav_units_power_available() then
                set_adf_display_power(true)
            else
                set_adf_display_power(false)
            end
        elseif clicks < 0 then
            set_adf_display_power(false)
        end
    elseif command == Keys.Nav_DME_PWR then
        -- PTN_718 is a 2-position tumbler and may report either relative clicks
        -- (-1/+1) or absolute position (0/1) depending on interaction path.
        if value ~= nil and value >= 0 and value <= 1 then
            if value > 0.5 and is_nav_units_power_available() then
                set_dme_display_power(true)
            else
                set_dme_display_power(false)
            end
        else
            local clicks = command_value_to_clicks(value)
            if clicks > 0 then
                if is_nav_units_power_available() then
                    set_dme_display_power(true)
                else
                    set_dme_display_power(false)
                end
            elseif clicks < 0 then
                set_dme_display_power(false)
            end
        end
    elseif command == Keys.Nav_RNAV_PWR then
        local clicks = command_value_to_clicks(value)
        if clicks > 0 then
            if is_nav_units_power_available() then
                set_rnav_display_power(true)
            else
                set_rnav_display_power(false)
            end
        elseif clicks < 0 then
            set_rnav_display_power(false)
        end
    end
end

function update()
    enforce_nav_units_power_dependency()

    -- Keep cockpit argument animation synchronized with current power states.
    rnav_power_knob_anim:set(rnav_display_power)
    dme_power_knob_anim:set(dme_display_power)
    set_aircraft_draw_argument_value(rnav_power_knob_arg, rnav_display_power)
    set_aircraft_draw_argument_value(dme_power_knob_arg, dme_display_power)
    if type(set_cockpit_draw_argument_value) == "function" then
        set_cockpit_draw_argument_value(rnav_power_knob_arg, rnav_display_power)
        set_cockpit_draw_argument_value(dme_power_knob_arg, dme_display_power)
    end

    adf_display_enable:set(adf_display_power)
    adf_display_freq:set(tuned_ndb_frequency_khz)
    dme_display_enable:set(dme_display_power)

    local tuned_ndb = get_tuned_ndb_beacon()
    if tuned_ndb ~= nil then
        local ndb_data = calculate_vor_data(tuned_ndb)
        if ndb_data ~= nil then
            target_adf_value = bearing_to_rmi_argument(ndb_data.bearing_true)
        else
            target_adf_value = current_adf_value
        end
    else
        target_adf_value = current_adf_value
    end
    update_adf_slew()

    rnav_display_enable:set(rnav_display_power)
    rnav_display_frq:set(tuned_vor_frequency_mhz)
    rnav_display_rad:set(selected_offset_radial_deg)
    rnav_display_dst:set(selected_offset_distance_nm)
    rnav_display_wpt:set(current_waypoint_index)
    update_rnav_selection_indicator()
    set_selected_vor_course(selected_vor_course_deg)

    local tuned_ils = get_tuned_ils_beacon()
    if tuned_ils ~= nil and is_ils_frequency_selected(tuned_vor_frequency_mhz) then
        rnav_ils_mode:set(1)
        ils_bars_visible:set(1)
        local loc_norm, gs_norm, loc_delta_deg, gs_error_deg = calculate_ils_deviation(tuned_ils)

        if math.abs(loc_delta_deg) <= 30 then
            target_ils_loc_value = loc_norm
        else
            target_ils_loc_value = 0
        end

        if math.abs(gs_error_deg) <= 30 then
            target_ils_gs_value = gs_norm
        else
            target_ils_gs_value = 0
        end

        update_ils_bar_slew()
        local tuned_frequency_hz = math.floor((tuned_vor_frequency_mhz * 1000000) + 0.5)
        if last_announced_ils_frequency_hz ~= tuned_frequency_hz then
            last_announced_ils_frequency_hz = tuned_frequency_hz
            print_message_to_user(string.format(
                "ILS Tuned: %.2f MHz - %s",
                tuned_vor_frequency_mhz,
                get_beacon_display_name(tuned_ils)
            ))
        end

        local now = get_absolute_model_time()
        if now - last_ils_message_time >= ils_message_interval_seconds then
            last_ils_message_time = now
            print_message_to_user(string.format(
                "ILS DEV | LOC %+05.1f° | GS %+05.1f°",
                loc_delta_deg,
                gs_error_deg
            ))
        end
    else
        rnav_ils_mode:set(0)
        ils_bars_visible:set(0)
        target_ils_loc_value = 0
        target_ils_gs_value = 0
        update_ils_bar_slew()
        last_announced_ils_frequency_hz = nil
        last_ils_message_time = -10
    end

    local tuned_beacon = get_tuned_vor_beacon()
    if tuned_beacon == nil then
        dme_data_valid:set(0)
        target_rmi_value = current_rmi_value
        set_hsi_cdi(0)
        update_rmi_slew()
        local now = get_absolute_model_time()
        if now - last_message_time >= message_interval_seconds then
            last_message_time = now
            nav_debug_popup(string.format("VOR %.2f MHz: station not found", tuned_vor_frequency_mhz))
        end
        return
    end

    local offset_waypoint_geo = get_offset_waypoint_geo(tuned_beacon)
    local vor_data = calculate_vor_data(tuned_beacon, offset_waypoint_geo)
    if vor_data == nil then
        dme_data_valid:set(0)
        target_rmi_value = current_rmi_value
        set_hsi_cdi(0)
        update_rmi_slew()
        local now = get_absolute_model_time()
        if now - last_message_time >= message_interval_seconds then
            last_message_time = now
            nav_debug_popup(string.format("VOR %.2f MHz: station data incomplete", tuned_vor_frequency_mhz))
        end
        return
    end

    -- RMI should always point at the selected waypoint and must not be affected by HSI course selection.
    local vor_bearing_for_display = vor_data.bearing_magnetic or vor_data.bearing_true
    target_rmi_value = bearing_to_rmi_argument(vor_bearing_for_display)
    update_rmi_slew()
    local cdi_deviation_deg = shortest_angle_delta(selected_vor_course_deg, vor_bearing_for_display)
    local cdi_norm = clamp(cdi_deviation_deg / 10.0, -1, 1)
    set_hsi_cdi(cdi_norm)
    local closing_speed_kts = calculate_closing_speed_to_target(vor_data.target_geo)
    if closing_speed_kts == nil then
        closing_speed_kts = 0
    end

    local eta_min = 99
    if closing_speed_kts > 0.5 then
        eta_min = (vor_data.distance_nm / closing_speed_kts) * 60.0
    end

    dme_display_dist:set(clamp(vor_data.distance_nm, 0, 999.9))
    dme_display_gs:set(clamp(closing_speed_kts, 0, 999))
    dme_display_time:set(clamp(eta_min, 0, 99))
    dme_data_valid:set(1)

    local now = get_absolute_model_time()
    if now - last_message_time < message_interval_seconds then
        return
    end
    last_message_time = now

    nav_debug_popup(string.format(
        "VOR %.2f | BRG %03.0f° | DME %.1f NM",
        tuned_vor_frequency_mhz,
        vor_bearing_for_display,
        vor_data.distance_nm
    ))
end

need_to_be_closed = false
