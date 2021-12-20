--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

_ENV = module()

Options = enum {
    IsUnicode = 0x1
}

FileRecordType = enum {
    SimpleFileRecord = 0,
    MultiLangRecord = 1,
    OptionsRecord = 2,
    IfRecord = 3,
    ElseIfRecord = 4,
    ElseRecord = 5,
    EndIfRecord = 6,
}

FileType = enum {
    File = 0,
    FileText = 1,
    SisComponent = 2,
    FileRun = 3,
    FileNull = 4,
    FileMime = 5,
}

Langs = enum {
    Test = 0x0000,
    EN = 0x0001, -- UK English
    FR = 0x0002, -- French
    GE = 0x0003, -- German
    SP = 0x0004, -- Spanish
    IT = 0x0005, -- Italian
    SW = 0x0006, -- Swedish
    DA = 0x0007, -- Danish
    NO = 0x0008, -- Norwegian
    FI = 0x0009, -- Finnish
    AM = 0x000A, -- American English
    SF = 0x000B, -- Swiss French
    SG = 0x000C, -- Swiss German
    PO = 0x000D, -- Portuguese
    TU = 0x000E, -- Turkish
    IC = 0x000F, -- Icelandic
    RU = 0x0010, -- Russian
    HU = 0x0011, -- Hungarian
    DU = 0x0012, -- Dutch
    BL = 0x0013, -- Belgian Flemish
    AU = 0x0014, -- Australian English
    BG = 0x0015, -- Belgian French
    AS = 0x0016, -- Austrian German
    NZ = 0x0017, -- New Zealand English
    IF = 0x0018, -- International French
    CS = 0x0019, -- Czech
    SK = 0x001A, -- Slovak
    PL = 0x001B, -- Polish
    SL = 0x001C, -- Slovenian
    TC = 0x001D, -- Taiwan Chinese
    HK = 0x001E, -- Hong Kong Chinese
    ZH = 0x001F, -- PRC Chinese
    JA = 0x0020, -- Japanese
    TH = 0x0021, -- Thai
    AF = 0x0022, -- Afrikaans
    SQ = 0x0023, -- Albanian
    AH = 0x0024, -- Amharic
    AR = 0x0025, -- Arabic
    HY = 0x0026, -- Armenian
    TL = 0x0027, -- Tagalog
    BE = 0x0028, -- Belarussian
    BN = 0x0029, -- Bengali
    BG = 0x002A, -- Bulgarian
    MY = 0x002B, -- Burmese
    CA = 0x002C, -- Catalan
    HR = 0x002D, -- Croatian
    CE = 0x002E, -- Canadian English
    IE = 0x002F, -- International English
    SF = 0x0030, -- South African English
    ET = 0x0031, -- Estonian
    FA = 0x0032, -- Farsi
    CF = 0x0033, -- Canadian French
    GD = 0x0034, -- Scots Gaelic
    KA = 0x0035, -- Georgian
    EL = 0x0036, -- Greek
    CG = 0x0037, -- Cyprus Greek
    GU = 0x0038, -- Gujarati
    HE = 0x0039, -- Hebrew
    HI = 0x003A, -- Hindi
    IN = 0x003B, -- Indonesian
    GA = 0x003C, -- Irish
    SZ = 0x003D, -- Swiss Italian
    KN = 0x003E, -- Kannada
    KK = 0x003F, -- Kazakh
    KM = 0x0040, -- Khmer
    KO = 0x0041, -- Korean
    LO = 0x0042, -- Laothian
    LV = 0x0043, -- Latvian
    LT = 0x0044, -- Lithuanian
    MK = 0x0045, -- Macedonian
    MS = 0x0046, -- Malay
    ML = 0x0047, -- Malayalam
    MR = 0x0048, -- Marathi
    MO = 0x0049, -- Moldavian
    MN = 0x004A, -- Mongolian
    NN = 0x004B, -- Norwegian-Nynorsk
    BP = 0x004C, -- Brazilian Portuguese
    PA = 0x004D, -- Punjabi
    RO = 0x004E, -- Romanian
    SR = 0x004F, -- Serbian
    SI = 0x0050, -- Sinhalese
    SO = 0x0051, -- Somali
    OS = 0x0052, -- International Spanish
    LS = 0x0053, -- Latin American Spanish
    SH = 0x0054, -- Swahili
    FS = 0x0055, -- Finland Swedish
    TA = 0x0057, -- Tamil
    TE = 0x0058, -- Telugu
    BO = 0x0059, -- Tibetan
    TI = 0x005A, -- Tigrinya
    CT = 0x005B, -- Cyprus Turkish
    TK = 0x005C, -- Turkmen
    UK = 0x005D, -- Ukrainian
    UR = 0x005E, -- Urdu
    VI = 0x0060, -- Vietnamese
    CY = 0x0061, -- Welsh
    ZU = 0x0062, -- Zulu
}

function parseSisFile(data, verbose)
    local uid1, uid2, uid3, uid4, checksum, nLangs, nFiles, pos = string.unpack("<I4I4I4I4I2I2I2", data)
    if verbose then
        printf("nLangs=%d nFiles=%d\n", nLangs, nFiles)
    end

    local nReq, lang, instFiles, instDrv, nCaps, instVer, pos = string.unpack("<I2I2I2I2I2I4", data, pos)
    if verbose then
        printf("nReq=%d lang=%d instFiles=%d instDrv=%d nCaps=%d instVer=0x%08X\n",
            nReq, lang, instFiles, instDrv, nCaps, instVer)
    end

    assert(instVer == 0x64, "Only ER5 SIS files are supported")

    local options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr, pos =
        string.unpack("<I2I2I2I2I4I4I4I4", data, pos)
    if verbose then
        printf("options=%d type=%d verMaj=%d verMin=%d variant=%d langPtr=0x%08X filesPtr=0x%08X reqPtr=0x%08X\n",
            options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr)
    end

    assert(options & Options.IsUnicode == 0, "ER5U not supported!")

    local result = {
        langs = {},
        files = {},
    }

    pos = 1 + langPtr
    local langs = {}
    for i = 1, nLangs do
        local code
        code, pos = string.unpack("<I2", data, pos)
        result.langs[i] = Langs[code] or code
    end

    pos = 1 + filesPtr
    for i = 1, nFiles do
        local recordType, file
        recordType, pos = string.unpack("<I4", data, pos)
        if recordType == FileRecordType.SimpleFileRecord then
            file, pos = parseSimpleFileRecord(data, pos, 1, verbose)
        elseif recordType == FileRecordType.MultiLangRecord then
            file, pos = parseSimpleFileRecord(data, pos, nLangs, verbose)
        else
            error("Unknown record type "..tostring(recordType))
        end
        result.files[i] = file
    end
    return result
end

function parseSimpleFileRecord(data, pos, numLangs, verbose)
    local type, details, srcNameLen, srcNamePtr, destNameLen, destNamePtr, pos =
        string.unpack("<I4I4I4I4I4I4", data, pos)

    local contents = {}
    for i = 1, numLangs do
        local len
        len, pos = string.unpack("<I4", data, pos)
        contents[i] = { len = len }
    end
    for i = 1, numLangs do
        local ptr
        ptr, pos = string.unpack("<I4", data, pos)
        contents[i].ptr = ptr
    end

    if verbose then
        printf("type=%d details=%d srcNameLen=%d srcNamePtr=0x%08X destNameLen=%d destNamePtr=0x%08X\n",
            type, details, srcNameLen, srcNamePtr, destNameLen, destNamePtr)
    end
    local srcName = data:sub(1 + srcNamePtr, srcNamePtr + srcNameLen)
    local destName = data:sub(1 + destNamePtr, destNamePtr + destNameLen)
    local file = {
        type = type,
        src = srcName,
        dest = destName,
    }

    if type ~= FileRecordType.FileNull then
        local langData = {}
        for i, lang in ipairs(contents) do
            local filePtr = contents[i].ptr
            local fileLen = contents[i].len
            langData[i] = data:sub(1 + filePtr, filePtr + fileLen)
        end
        if numLangs > 1 then
            file.langData = langData
        else
            file.data = langData[1]
        end
    end
    if type == FileRecordType.FileText then
        file.details = details
    end

    return file, pos
end

return _ENV
