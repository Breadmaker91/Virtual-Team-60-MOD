function exportRadioSK60(_data)
    _data.capabilities = { dcsPtt = false, dcsIFF = false, dcsRadioSwitch = true, intercomHotMic = false, desc = "" }
    _data.iff = {status=0,mode1=0,mode2=-1,mode3=0,mode4=0,control=1,expansion=false,mic=-1}

    _data.radios[1].name = "FR31 / AN-ARC164"
    _data.radios[1].modulation = _data.radios[1].modulation or 0
    _data.radios[1].secFreq = 121.5 * 1000000
    _data.radios[1].volume = _data.radios[1].volume or 1.0
    _data.radios[1].freqMin = 225 * 1000000
    _data.radios[1].freqMax = 399.975 * 1000000
    _data.radios[1].volMode = 1
    _data.radios[1].freqMode = 1
    _data.radios[1].expansion = true

    return _data
end

local result = {}
function result.register(SR)
    SR.exporters["SK-60"] = exportRadioSK60
    SR.exporters["SK60"] = exportRadioSK60
    SR.exporters["SK-60B"] = exportRadioSK60
end
return result
