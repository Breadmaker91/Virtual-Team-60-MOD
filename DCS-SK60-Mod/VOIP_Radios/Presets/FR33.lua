preset =
{
    Channels =
    {
        [1] = 243.000,
        [2] = 261.000,
        [3] = 251.000,
        [4] = 250.000,
        [5] = 261.500,
        [6] = 273.000,
        [7] = 130.000,
        [8] = 131.000,
        [9] = 132.000,
        [10] = 133.000,
    }, -- end of Channels
    Squelch = true,
    Step = 25000,
    OutputSD = 5,
    RegulationTime = 0.25,
    Ranges =
    {
        [1] =
        {
            minFreq = 118000000,
            maxFreq = 151975000,
            modulation = 0,
        }, -- end of [1]
    }, -- end of Ranges
    Power =
    {
        [1] =
        {
            value = 10,
        }, -- end of [1]
    }, -- end of Power
    InputSD = 50,
    Encryption =
    {
        enable = false,
        key = 1,
        present = false,
    }, -- end of Encryption
    MaxSearchTime = 0,
    FrequencyAccuracy = 1,
    MinSearchTime = 0,
    Guards =
    {
        [1] =
        {
            modulation = 0,
            freq = 121500000,
        }, -- end of [1]
    }, -- end of Guards
    Name = "FR33",
    ID = "FR33",
    InputSLZ = 10,
    InnerNoise = 1.1561e-06,
    BandWidth = 1,
} -- end of preset
