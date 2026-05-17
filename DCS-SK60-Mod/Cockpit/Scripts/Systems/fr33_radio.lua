dofile(LockOn_Options.script_path.."devices.lua")
dofile(LockOn_Options.script_path.."command_defs.lua")

local dev = GetSelf()
make_default_activity(0.05)

local FR33_MIN_FREQ_HZ = 118E6
local FR33_MAX_FREQ_HZ = 135.975E6
local FR33_DEFAULT_FREQ_HZ = 124.8E6
local FR33_STEP_HZ = 25E3

local fr33_power = get_param_handle("FR33_POWER")
local fr33_freq_hz = get_param_handle("FR33_FREQ_HZ")
local fr33_active_freq = get_param_handle("FR33_ACTIVE_FREQ")
local power_knob = get_param_handle("PTN_720")

local roll_params = {
    get_param_handle("FR33_ROLL_100MHZ"),
    get_param_handle("FR33_ROLL_10MHZ"),
    get_param_handle("FR33_ROLL_1MHZ"),
    get_param_handle("FR33_ROLL_100KHZ"),
    get_param_handle("FR33_ROLL_10KHZ"),
    get_param_handle("FR33_ROLL_1KHZ"),
}

local current_freq_hz = FR33_DEFAULT_FREQ_HZ
local powered = false

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

local function quantize_frequency(freq_hz)
    return math.floor((freq_hz / FR33_STEP_HZ) + 0.5) * FR33_STEP_HZ
end

local function wrap_frequency(freq_hz)
    local span_steps = math.floor(((FR33_MAX_FREQ_HZ - FR33_MIN_FREQ_HZ) / FR33_STEP_HZ) + 0.5) + 1
    local offset_steps = math.floor(((quantize_frequency(freq_hz) - FR33_MIN_FREQ_HZ) / FR33_STEP_HZ) + 0.5)
    offset_steps = offset_steps % span_steps
    return FR33_MIN_FREQ_HZ + (offset_steps * FR33_STEP_HZ)
end

local function roll_arg_from_digit(digit)
    -- The FR33 mechanical rolls use one full cockpit-argument revolution from
    -- -1.0 through +1.0. Digit 0 is the start position; digit 9 is the last
    -- visible detent before the roll returns to 0.
    return -1.0 + (digit * 0.2)
end

local function set_roll_digits(freq_hz)
    local freq_khz = math.floor((freq_hz / 1E3) + 0.5)
    local digits = {
        math.floor(freq_khz / 100000) % 10,
        math.floor(freq_khz / 10000) % 10,
        math.floor(freq_khz / 1000) % 10,
        math.floor(freq_khz / 100) % 10,
        math.floor(freq_khz / 10) % 10,
        freq_khz % 10,
    }

    for index,digit in ipairs(digits) do
        roll_params[index]:set(roll_arg_from_digit(digit))
    end
end

local function set_frequency(freq_hz)
    current_freq_hz = wrap_frequency(freq_hz)
    fr33_freq_hz:set(current_freq_hz)
    fr33_active_freq:set(current_freq_hz / 1E6)
    set_roll_digits(current_freq_hz)
end

local function set_power(value)
    powered = value > 0.05
    fr33_power:set(powered and 1 or 0)
    power_knob:set(value)
end

local function tune_by(step_hz, clicks)
    if clicks == 0 then
        return
    end

    set_frequency(current_freq_hz + (step_hz * clicks))
end

dev:listen_command(Keys.FR33_Power)
dev:listen_command(Keys.FR33_100kHz)
dev:listen_command(Keys.FR33_25kHz)

function post_initialize()
    set_frequency(FR33_DEFAULT_FREQ_HZ)
    set_power(power_knob:get())
end

function SetCommand(command, value)
    if command == Keys.FR33_Power then
        set_power(value or 0)
    elseif command == Keys.FR33_100kHz then
        tune_by(100E3, command_value_to_clicks(value))
    elseif command == Keys.FR33_25kHz then
        tune_by(25E3, command_value_to_clicks(value))
    end
end

function update()
    fr33_active_freq:set(current_freq_hz / 1E6)
    fr33_freq_hz:set(current_freq_hz)
    fr33_power:set(powered and 1 or 0)
end

need_to_be_closed = false
