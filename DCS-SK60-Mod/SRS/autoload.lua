function exportRadioSK60(_data, SR)
    _data.capabilities = { dcsPtt = false, dcsIFF = false, dcsRadioSwitch = false, intercomHotMic = false, desc = "" }
    _data.iff = {status=0,mode1=0,mode2=-1,mode3=0,mode4=0,control=1,expansion=false,mic=-1}

    -- INTERCOM
    _data.radios[1].name = "Intercom"
    _data.radios[1].freq = 100.0
    _data.radios[1].modulation = 2
    _data.radios[1].volume = 1.0
    _data.radios[1].model = SR.RadioModels.Intercom

    -- COMM1 / FR31. Native UHF radio device ID is fixed at 6.
    _data.radios[2].name = "FR31"
    _data.radios[2].freq = SR.getRadioFrequency(6)
    _data.radios[2].modulation = 0
    _data.radios[2].secFreq = 121.5 * 1000000
    _data.radios[2].volume = 1.0
    _data.radios[2].freqMin = 104 * 1000000
    _data.radios[2].freqMax = 407.975 * 1000000

    -- COMM2 / FR33. Native VHF radio device ID is fixed at 24.
    _data.radios[3].name = "FR33"
    _data.radios[3].freq = 121.5 * 1000000
    _data.radios[3].modulation = 0
    _data.radios[3].secFreq = 121.5 * 1000000
    _data.radios[3].volume = 1.0
    _data.radios[3].freqMin = 118 * 1000000
    _data.radios[3].freqMax = 135.975 * 1000000

    return _data;
end


local result = { }

function result.register(SR)
    SR.exporters["SK-60B"] = exportRadioSK60
end

return result
