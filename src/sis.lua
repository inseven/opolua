--[[

Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe

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

-- Codes from https://thoukydides.github.io/riscos-psifs/sis.html mapped into
-- ICU Locale identifiers based on some guesswork and
-- https://icu4c-demos.unicode.org/icu-bin/locexp?d_=en
Locales = enum {
    [0x0000] = "", -- Test
    [0x0001] = "en_GB", -- UK English (EN)
    [0x0002] = "fr_FR", -- French (FR)
    [0x0003] = "de_DE", -- German (GE)
    [0x0004] = "es_ES", -- Spanish (SP)
    [0x0005] = "it_IT", -- Italian (IT)
    [0x0006] = "sv_SE", -- Swedish (SW)
    [0x0007] = "da_DK", -- Danish (DA)
    [0x0008] = "no_NO", -- Norwegian (NO)
    [0x0009] = "fi_FI", -- Finnish (FI)
    [0x000A] = "en_US", -- American English (AM)
    [0x000B] = "fr_CH", -- Swiss French (SF)
    [0x000C] = "de_CH", -- Swiss German (SG)
    [0x000D] = "pt_PT", -- Portuguese (PO)
    [0x000E] = "tr_TR", -- Turkish (TU)
    [0x000F] = "is_IS", -- Icelandic (IC)
    [0x0010] = "ru_RU", -- Russian (RU)
    [0x0011] = "hu_HU", -- Hungarian (HU)
    [0x0012] = "nl_NL", -- Dutch (DU)
    [0x0013] = "nl_BE", -- Belgian Flemish (BL)
    [0x0014] = "en_AU", -- Australian English (AU)
    [0x0015] = "fr_BE", -- Belgian French (BF)
    [0x0016] = "de_AT", -- Austrian German (AS)
    [0x0017] = "en_NZ", -- New Zealand English (NZ)
    [0x0018] = "fr", -- International French (IF)
    [0x0019] = "cs_CZ", -- Czech (CS)
    [0x001A] = "sk_SK", -- Slovak (SK)
    [0x001B] = "pl_PL", -- Polish (PL)
    [0x001C] = "sl_SI", -- Slovenian (SL)
    [0x001D] = "zh_Hant_TW", -- Taiwan Chinese (TC)
    [0x001E] = "zh_Hant_HK", -- Hong Kong Chinese (HK)
    [0x001F] = "zh_Hant_CN", -- PRC Chinese (ZH)
    [0x0020] = "ja_JP", -- Japanese (JA)
    [0x0021] = "th_TH", -- Thai (TH)
    [0x0022] = "af_ZA", -- Afrikaans (AF)
    [0x0023] = "sq_AL", -- Albanian (SQ)
    [0x0024] = "am_ET", -- Amharic (AH)
    [0x0025] = "ar", -- Arabic (AR)
    [0x0026] = "hy_AM", -- Armenian (HY)
    [0x0027] = "fil_PH", -- Tagalog (TL)
    [0x0028] = "be_BY", -- Belarussian (BE)
    [0x0029] = "bn", -- Bengali (BN)
    [0x002A] = "bg_BG", -- Bulgarian (BG)
    [0x002B] = "my_MM", -- Burmese (MY)
    [0x002C] = "ca_ES", -- Catalan (CA)
    [0x002D] = "hr_HR", -- Croatian (HR)
    [0x002E] = "en_CA", -- Canadian English (CE)
    [0x002F] = "en_001", -- International English (IE)
    [0x0030] = "en_ZA", -- South African English (SF)
    [0x0031] = "et_EE", -- Estonian (ET)
    [0x0032] = "fa_IR", -- Farsi (FA)
    [0x0033] = "fr_CA", -- Canadian French (CF)
    [0x0034] = "gd_GB", -- Scots Gaelic (GD)
    [0x0035] = "ka_GE", -- Georgian (KA)
    [0x0036] = "el_GR", -- Greek (EL)
    [0x0037] = "el_CY", -- Cyprus Greek (CG)
    [0x0038] = "gu_IN", -- Gujarati (GU)
    [0x0039] = "he_IL", -- Hebrew (HE)
    [0x003A] = "hi_IN", -- Hindi (HI)
    [0x003B] = "id_ID", -- Indonesian (IN)
    [0x003C] = "ga_IE", -- Irish (GA)
    [0x003D] = "it_CH", -- Swiss Italian (SZ)
    [0x003E] = "kn_IN", -- Kannada (KN)
    [0x003F] = "kk_KZ", -- Kazakh (KK)
    [0x0040] = "km_KH", -- Khmer (KM)
    [0x0041] = "ko_KR", -- Korean (KO)
    [0x0042] = "lo_LA", -- Laothian (LO)
    [0x0043] = "lv_LV", -- Latvian (LV)
    [0x0044] = "lt_LT", -- Lithuanian (LT)
    [0x0045] = "mk_MK", -- Macedonian (MK)
    [0x0046] = "ms_MY", -- Malay (MS)
    [0x0047] = "ml_IN", -- Malayalam (ML)
    [0x0048] = "mr_IN", -- Marathi (MR)
    [0x0049] = "ro_MD", -- Moldavian (MO)
    [0x004A] = "mn_MN", -- Mongolian (MN)
    [0x004B] = "nn_NO", -- Norwegian-Nynorsk (NN)
    [0x004C] = "pt_BR", -- Brazilian Portuguese (BP)
    [0x004D] = "pa", -- Punjabi (PA)
    [0x004E] = "ro_RO", -- Romanian (RO)
    [0x004F] = "sr", -- Serbian (SR)
    [0x0050] = "si_LK", -- Sinhalese (SI)
    [0x0051] = "so_SO", -- Somali (SO)
    [0x0052] = "es", -- International Spanish (OS)
    [0x0053] = "es_419", -- Latin American Spanish (LS)
    [0x0054] = "sw", -- Swahili (SH)
    [0x0055] = "sv_FI", -- Finland Swedish (FS)
    [0x0057] = "ta_LK", -- Tamil (TA)
    [0x0058] = "te_IN", -- Telugu (TE)
    [0x0059] = "bo", -- Tibetan (BO)
    [0x005A] = "ti", -- Tigrinya (TI)
    [0x005B] = "tr_CY", -- Cyprus Turkish (CT)
    [0x005C] = "tk_TM", -- Turkmen (TK)
    [0x005D] = "uk_UA", -- Ukrainian (UK)
    [0x005E] = "ur", -- Urdu (UR)
    [0x0060] = "vi_VN", -- Vietnamese (VI)
    [0x0061] = "cy_GB", -- Welsh (CY)
    [0x0062] = "zu_ZA", -- Zulu (ZU)
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
    for i = 1, nLangs do
        local code
        code, pos = string.unpack("<I2", data, pos)
        result.langs[i] = code
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

function getBestLangIdx(langs)
    -- For now, just pick the first english-ish thing
    for i, lang in ipairs(langs) do
        local locale = Locales[lang]
        if locale and locale:lower():match("^en") then
            return i
        end
    end
    return 1
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
