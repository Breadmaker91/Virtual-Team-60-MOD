-- For better examples see any function like:
--   function SR.exportRadio...(_data)
-- in file DCS-SimpleRadioStandalone.lua

function exportRadioSK60(_data)
    _data.capabilities = { dcsPtt = false, dcsIFF = false, dcsRadioSwitch = true, intercomHotMic = false, desc = "" }
    _data.iff = {status=0,mode1=0,mode2=-1,mode3=0,mode4=0,control=1,expansion=false,mic=-1}

    -- COMM1 Radio
    _data.radios[1].name = "AN/ARC-186(V)"
    _data.radios[1].freq = 124.8 * 1000000
    _data.radios[1].modulation = 0
    _data.radios[1].secFreq = 121.5 * 1000000
    _data.radios[1].volume = 1.0
    _data.radios[1].freqMin = 116 * 1000000
    _data.radios[1].freqMax = 151.975 * 1000000
    _data.radios[1].volMode = 1
    _data.radios[1].freqMode = 1
    _data.radios[1].expansion = true

    return _data;
end


local result = { }

function result.register(SR)
	SR.exporters["SK-60"] = exportRadioSK60
	SR.exporters["SK60"] = exportRadioSK60
	SR.exporters["SK-60B"] = exportRadioSK60
end

return result
