-- For better examples see any function like:
--   function SR.exportRadio...(_data)
-- in file DCS-SimpleRadioStandalone.lua

local SR_API = nil
local FR31_DEVICE_ID = 6
local FR31_DEFAULT_FREQ = 124.8 * 1000000
local FR31_GUARD_FREQ = 121.5 * 1000000
local FR31_MIN_FREQ = 104 * 1000000
local FR31_MAX_FREQ = 407.975 * 1000000
local FR31_GAP_MIN_FREQ = 161.975 * 1000000
local FR31_GAP_MAX_FREQ = 223 * 1000000
local FR31_FREQ_STEP = 25 * 1000

local function getSR()
    return SR_API or SR
end

local function callSR(function_name, ...)
    local sr = getSR()
    if sr and sr[function_name] then
        local ok, result = pcall(sr[function_name], ...)
        if ok then
            return result
        end
    end

    return nil
end

local function readParamValue(param_name)
    if get_param_handle == nil then
        return nil
    end

    local ok, handle = pcall(get_param_handle, param_name)
    if not ok or handle == nil or handle.get == nil then
        return nil
    end

    local read_ok, value = pcall(function()
        return handle:get()
    end)

    if read_ok then
        return value
    end

    return nil
end

local function isFR31Frequency(freq)
    if freq == nil or freq < FR31_MIN_FREQ or freq > FR31_MAX_FREQ then
        return false
    end

    -- The FR31 covers VHF/AM, VHF/FM, and UHF bands, but not the 162-222.975 MHz gap.
    if freq > FR31_GAP_MIN_FREQ and freq < FR31_GAP_MAX_FREQ then
        return false
    end

    return math.floor((freq / FR31_FREQ_STEP) + 0.5) * FR31_FREQ_STEP == freq
end

local function getFR31Frequency()
    -- Prefer the FR31 controller's own exported parameter. The new FR31 is an
    -- avLuaDevice layered over the legacy DCS UHF device, so SRS should read the
    -- FR31 state directly instead of depending on the backing device always
    -- reporting the latest cockpit-entered frequency.
    local freq = readParamValue("FR31_FREQ_HZ")
    if isFR31Frequency(freq) then
        return freq
    end

    freq = callSR("getRadioFrequency", FR31_DEVICE_ID)
    if isFR31Frequency(freq) then
        return freq
    end

    return FR31_DEFAULT_FREQ
end

local function getFR31Modulation()
    local modulation = readParamValue("FR31_MODULATION")
    if modulation ~= nil then
        return modulation > 0.5 and 1 or 0
    end

    local mode_position = readParamValue("PTN_717")
    if mode_position ~= nil then
        return mode_position > 0.5 and 1 or 0
    end

    mode_position = callSR("getButtonPosition", 717)
    if mode_position then
        return mode_position > 0.5 and 1 or 0
    end

    return 0
end

local function setFR31RadioData(radio)
    local fr31Frequency = getFR31Frequency()
    radio.name = "FR31"
    radio.freq = fr31Frequency
    radio.frequency = fr31Frequency
    radio.modulation = getFR31Modulation()
    radio.secFreq = FR31_GUARD_FREQ
    radio.secondaryFrequency = FR31_GUARD_FREQ
    radio.volume = 1.0
    radio.freqMin = FR31_MIN_FREQ
    radio.freqMax = FR31_MAX_FREQ
    radio.volMode = 1
    radio.freqMode = 1
    radio.expansion = true
end

function exportRadioSK60(_data)
    _data.capabilities = { dcsPtt = false, dcsIFF = false, dcsRadioSwitch = true, intercomHotMic = false, desc = "" }
    _data.iff = {status=0,mode1=0,mode2=-1,mode3=0,mode4=0,control=1,expansion=false,mic=-1}

    -- Keep radio slot 1 available for intercom/default SRS handling and expose
    -- the FR31 on slot 2, matching the common SRS custom-aircraft convention.
    local radio_index = _data.radios[2] ~= nil and 2 or 1
    setFR31RadioData(_data.radios[radio_index])

    _data.selected = radio_index - 1
    _data.control = 1
    _data.radioType = 1

    return _data;
end

local result = { }

function result.register(SR)
    SR_API = SR
    SR.exporters["SK-60"] = exportRadioSK60
    SR.exporters["SK60"] = exportRadioSK60
    SR.exporters["SK-60B"] = exportRadioSK60
    SR.exporters["SK60B"] = exportRadioSK60
    SR.exporters["SAAB_SK60"] = exportRadioSK60
end

return result
-- For better examples see any function like:
--   function SR.exportRadio...(_data)
-- in file DCS-SimpleRadioStandalone.lua

local SR_API = nil
local FR31_DEVICE_ID = 6
local FR31_DEFAULT_FREQ = 124.8 * 1000000
local FR31_GUARD_FREQ = 121.5 * 1000000
local FR31_MIN_FREQ = 104 * 1000000
local FR31_MAX_FREQ = 407.975 * 1000000

local function getSR()
    return SR_API or SR
end

local function callSR(function_name, ...)
    local sr = getSR()
    if sr and sr[function_name] then
        local ok, result = pcall(sr[function_name], ...)
        if ok then
            return result
        end
    end

    return nil
end

local function getFR31Frequency()
    local freq = callSR("getRadioFrequency", FR31_DEVICE_ID)
    if freq and freq >= FR31_MIN_FREQ and freq <= FR31_MAX_FREQ then
        return freq
    end

    return FR31_DEFAULT_FREQ
end

local function getFR31Modulation()
    local mode_position = callSR("getButtonPosition", 717)
    if mode_position then
        return mode_position > 0.5 and 1 or 0
    end

    return 0
end

local function setFR31RadioData(radio)
    local fr31Frequency = getFR31Frequency()
    radio.name = "FR31"
    radio.freq = fr31Frequency
    radio.frequency = fr31Frequency
    radio.modulation = getFR31Modulation()
    radio.secFreq = FR31_GUARD_FREQ
    radio.secondaryFrequency = FR31_GUARD_FREQ
    radio.volume = 1.0
    radio.freqMin = FR31_MIN_FREQ
    radio.freqMax = FR31_MAX_FREQ
    radio.volMode = 1
    radio.freqMode = 1
    radio.expansion = true
end

function exportRadioSK60(_data)
    _data.capabilities = { dcsPtt = false, dcsIFF = false, dcsRadioSwitch = true, intercomHotMic = false, desc = "" }
    _data.iff = {status=0,mode1=0,mode2=-1,mode3=0,mode4=0,control=1,expansion=false,mic=-1}

    -- Keep radio slot 1 available for intercom/default SRS handling and expose
    -- the FR31 on slot 2, matching the common SRS custom-aircraft convention.
    local radio_index = _data.radios[2] ~= nil and 2 or 1
    setFR31RadioData(_data.radios[radio_index])

    _data.selected = radio_index - 1
    _data.control = 1
    _data.radioType = 1

    return _data;
end

local result = { }

function result.register(SR)
    SR_API = SR
    SR.exporters["SK-60"] = exportRadioSK60
    SR.exporters["SK60"] = exportRadioSK60
    SR.exporters["SK-60B"] = exportRadioSK60
    SR.exporters["SK60B"] = exportRadioSK60
    SR.exporters["SAAB_SK60"] = exportRadioSK60
end

return result
