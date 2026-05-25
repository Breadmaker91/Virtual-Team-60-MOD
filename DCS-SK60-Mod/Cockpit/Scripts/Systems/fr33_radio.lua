dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."command_defs.lua")

local dev = GetSelf()
make_default_activity(0.05)

local main_power = get_param_handle("PTN_401")
local radio_power = get_param_handle("RADIO_POWER")
local fr33_freq_mhz = get_param_handle("FR33_ACTIVE_FREQ")
local fr33_freq_hz = get_param_handle("FR33_FREQ_HZ")

local DEFAULT_FREQ_HZ = 124.800E6
local FREQ_STEP_HZ = 25E3
local current_freq_hz = DEFAULT_FREQ_HZ

local function is_valid_fr33_frequency(freq_hz)
    if freq_hz == nil then
        return false
    end

    if freq_hz < 118.000E6 or freq_hz > 151.975E6 then
        return false
    end

    return math.floor((freq_hz / FREQ_STEP_HZ) + 0.5) * FREQ_STEP_HZ == freq_hz
end

local function apply_frequency(freq_hz)
    if not is_valid_fr33_frequency(freq_hz) then
        return
    end

    current_freq_hz = freq_hz
    fr33_freq_hz:set(freq_hz)
    fr33_freq_mhz:set(freq_hz / 1E6)

    local vhf_radio = GetDevice(devices.VHF_RADIO)
    if vhf_radio ~= nil then
        vhf_radio:set_frequency(freq_hz)
        vhf_radio:set_modulation(MODULATION_AM)
    end
end

local function load_initial_frequency()
    if get_aircraft_mission_data == nil then
        return
    end

    local mission_radio_data = get_aircraft_mission_data("Radio")
    if mission_radio_data == nil or mission_radio_data[2] == nil or mission_radio_data[2].channels == nil then
        return
    end

    local channels = mission_radio_data[2].channels
    local has_zero_based_channels = channels[0] ~= nil
    local channel_index = has_zero_based_channels and 0 or 1
    local mission_freq = tonumber(channels[channel_index])

    if mission_freq == nil then
        return
    end

    if mission_freq < 1E6 then
        mission_freq = mission_freq * 1E6
    end

    if is_valid_fr33_frequency(mission_freq) then
        current_freq_hz = mission_freq
    end
end

function post_initialize()
    load_initial_frequency()
    apply_frequency(current_freq_hz)
end

function SetCommand(command, value)
end

function update()
    -- Keep shared radio-power param asserted for SRS compatibility.
    radio_power:set(1.0)

    if main_power:get() > 0.5 then
        apply_frequency(current_freq_hz)
    end
end

need_to_be_closed = false
