--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

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

FileTypeAliases = {
    FILE = FileType.File,
    FF = FileType.File,
    FILETEXT = FileType.FileText,
    FT = FileType.FileText,
    FILERUN = FileType.FileRun,
    FR = FileType.FileRun,
    FILENULL = FileType.FileNull,
    FN = FileType.FileNull,
    FILEMIME = FileType.FileMime,
    FM = FileType.FileMime,
}

FileTextDetails = enum {
    continue = 0,
    skip = 1,
    abort = 2,
    exit = 3,
}

FileTextAliases = {
    TEXTCONTINUE = FileTextDetails.continue,
    TC = FileTextDetails.continue,
    TEXTSKIP = FileTextDetails.skip,
    TS = FileTextDetails.skip,
    TEXTABORT = FileTextDetails.abort,
    TA = FileTextDetails.abort,
    TEXTEXIT = FileTextDetails.exit,
    TE = FileTextDetails.exit,
}

FileRunDetails = enum {
    RunInstall = 0,
    RunRemove = 1,
    RunBoth = 2,
    RunSendEnd = 256,
    RunWait = 512,
}

FileRunAliases = {
    RUNINSTALL = FileRunDetails.RunInstall,
    RI = FileRunDetails.RunInstall,
    RUNREMOVE = FileRunDetails.RunRemove,
    RR = FileRunDetails.RunRemove,
    RUNBOTH = FileRunDetails.RunBoth,
    RB = FileRunDetails.RunBoth,
    RUNSENDEND = FileRunDetails.RunSendEnd,
    RE = FileRunDetails.RunSendEnd,
    RW = FileRunDetails.RunWait,
    RUNWAITEND = FileRunDetails.RunWait,
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

LangShortCodes = enum {
    [0x0001] = "EN", -- UK English
    [0x0002] = "FR", -- French
    [0x0003] = "GE", -- German
    [0x0004] = "SP", -- Spanish
    [0x0005] = "IT", -- Italian
    [0x0006] = "SW", -- Swedish
    [0x0007] = "DA", -- Danish
    [0x0008] = "NO", -- Norwegian
    [0x0009] = "FI", -- Finnish
    [0x000A] = "AM", -- American English
    [0x000B] = "SF", -- Swiss French
    [0x000C] = "SG", -- Swiss German
    [0x000D] = "PO", -- Portuguese
    [0x000E] = "TU", -- Turkish
    [0x000F] = "IC", -- Icelandic
    [0x0010] = "RU", -- Russian
    [0x0011] = "HU", -- Hungarian
    [0x0012] = "DU", -- Dutch
    [0x0013] = "BL", -- Belgian Flemish
    [0x0014] = "AU", -- Australian English
    [0x0015] = "BF", -- Belgian French
    [0x0016] = "AS", -- Austrian German
    [0x0017] = "NZ", -- New Zealand English
    [0x0018] = "IF", -- International French
    [0x0019] = "CS", -- Czech
    [0x001A] = "SK", -- Slovak
    [0x001B] = "PL", -- Polish
    [0x001C] = "SL", -- Slovenian
    [0x001D] = "TC", -- Taiwan Chinese
    [0x001E] = "HK", -- Hong Kong Chinese
    [0x001F] = "ZH", -- PRC Chinese
    [0x0020] = "JA", -- Japanese
    [0x0021] = "TH", -- Thai
    [0x0022] = "AF", -- Afrikaans
    [0x0023] = "SQ", -- Albanian
    [0x0024] = "AH", -- Amharic
    [0x0025] = "AR", -- Arabic
    [0x0026] = "HY", -- Armenian
    [0x0027] = "TL", -- Tagalog
    [0x0028] = "BE", -- Belarussian
    [0x0029] = "BN", -- Bengali
    [0x002A] = "BG", -- Bulgarian
    [0x002B] = "MY", -- Burmese
    [0x002C] = "CA", -- Catalan
    [0x002D] = "HR", -- Croatian
    [0x002E] = "CE", -- Canadian English
    [0x002F] = "IE", -- International English
    [0x0030] = "SF", -- South African English
    [0x0031] = "ET", -- Estonian
    [0x0032] = "FA", -- Farsi
    [0x0033] = "CF", -- Canadian French
    [0x0034] = "GD", -- Scots Gaelic
    [0x0035] = "KA", -- Georgian
    [0x0036] = "EL", -- Greek
    [0x0037] = "CG", -- Cyprus Greek
    [0x0038] = "GU", -- Gujarati
    [0x0039] = "HE", -- Hebrew
    [0x003A] = "HI", -- Hindi
    [0x003B] = "IN", -- Indonesian
    [0x003C] = "GA", -- Irish
    [0x003D] = "SZ", -- Swiss Italian
    [0x003E] = "KN", -- Kannada
    [0x003F] = "KK", -- Kazakh
    [0x0040] = "KM", -- Khmer
    [0x0041] = "KO", -- Korean
    [0x0042] = "LO", -- Laothian
    [0x0043] = "LV", -- Latvian
    [0x0044] = "LT", -- Lithuanian
    [0x0045] = "MK", -- Macedonian
    [0x0046] = "MS", -- Malay
    [0x0047] = "ML", -- Malayalam
    [0x0048] = "MR", -- Marathi
    [0x0049] = "MO", -- Moldavian
    [0x004A] = "MN", -- Mongolian
    [0x004B] = "NN", -- Norwegian-Nynorsk
    [0x004C] = "BP", -- Brazilian Portuguese
    [0x004D] = "PA", -- Punjabi
    [0x004E] = "RO", -- Romanian
    [0x004F] = "SR", -- Serbian
    [0x0050] = "SI", -- Sinhalese
    [0x0051] = "SO", -- Somali
    [0x0052] = "OS", -- International Spanish
    [0x0053] = "LS", -- Latin American Spanish
    [0x0054] = "SH", -- Swahili
    [0x0055] = "FS", -- Finland Swedish
    [0x0057] = "TA", -- Tamil
    [0x0058] = "TE", -- Telugu
    [0x0059] = "BO", -- Tibetan
    [0x005A] = "TI", -- Tigrinya
    [0x005B] = "CT", -- Cyprus Turkish
    [0x005C] = "TK", -- Turkmen
    [0x005D] = "UK", -- Ukrainian
    [0x005E] = "UR", -- Urdu
    [0x0060] = "VI", -- Vietnamese
    [0x0061] = "CY", -- Welsh
    [0x0062] = "ZU", -- Zulu
}

function parseSisFile(data, verbose)
    local uid1, uid2, uid3, uid4, checksum, nLangs, nFiles, pos = string.unpack("<I4I4I4I4I2I2I2", data)
    if verbose then
        printf("uid1=0x%08X uid2=0x%08X uid3=0x%08X uid4=0x%08X nLangs=%d nFiles=%d\n", uid1, uid2, uid3, uid4, nLangs, nFiles)
    end

    assert(uid2 == KUidAppDllDoc8 or uid2 == KUidSisFileEr6, "Bad uid2 in SIS file!")
    assert(uid3 == KUidInstallApp, "Bad uid3 in SIS file!")

    local nReq, lang, instFiles, instDrv, nCaps, instVer, pos = string.unpack("<I2I2I2I2I2I4", data, pos)
    if verbose then
        printf("nReq=%d lang=%d instFiles=%d instDrv=%d nCaps=%d instVer=0x%08X\n",
            nReq, lang, instFiles, instDrv, nCaps, instVer)
    end

    assert(instVer == 0x64, "Only ER5 SIS files are supported")

    local options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr, certPtr, namePtr, pos =
        string.unpack("<I2I2I2I2I4I4I4I4I4I4", data, pos)
    if verbose then
        printf("options=%d type=%d verMaj=%d verMin=%d variant=%d langPtr=0x%08X filesPtr=0x%08X reqPtr=0x%08X certPtr=0x%08X namePtr=0x%08X \n",
            options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr, certPtr, namePtr)
    end

    assert(options & Options.IsUnicode == 0, "ER5U not supported!")

    local endOfStrings = 0

    local result = {
        name = {},
        langs = {},
        installedFiles = instFiles,
        files = {},
        version = { verMaj, verMin },
        uid = uid1,
    }

    pos = 1 + langPtr
    for i = 1, nLangs do
        local code
        code, pos = string.unpack("<I2", data, pos)
        result.langs[i] = code
    end

    pos = 1 + filesPtr
    for i = 1, nFiles do
        local recordType, file, maxStringOffset
        recordType, pos = string.unpack("<I4", data, pos)
        if recordType == FileRecordType.SimpleFileRecord then
            file, pos, maxStringOffset = parseSimpleFileRecord(data, pos, 1, verbose)
        elseif recordType == FileRecordType.MultiLangRecord then
            file, pos, maxStringOffset = parseSimpleFileRecord(data, pos, nLangs, verbose)
        else
            error("Unknown record type "..tostring(recordType))
        end
        if file.type ~= FileType.FileNull and file.data == nil and file.langData == nil then
            result.isTruncated = true
        end
        result.files[i] = file
        endOfStrings = math.max(endOfStrings, maxStringOffset)
    end

    pos = 1 + namePtr
    local nameLens = {}
    for i = 1, nLangs do
        nameLens[i], pos = string.unpack("<I4", data, pos)
    end
    for i = 1, nLangs do
        local ptr
        ptr, pos = string.unpack("<I4", data, pos)
        endOfStrings = math.max(endOfStrings, ptr + nameLens[i])
        result.name[i] = data:sub(1 + ptr, ptr + nameLens[i])
        if verbose then
            printf("Name[%d] ptr=0x%08X %s\n", i, ptr, result.name[i])
        end
    end

    if instDrv ~= 0 then
        local ch = string.char(instDrv)
        if ch:match("[A-Za-z]") then
            result.installedDrive = ch:upper()
        end
    end

    if lang ~= 0 then
        result.language = lang
    end

    result.stubSize = endOfStrings
    result.isStub = #data == result.stubSize

    if verbose then
        printf("stubSize=%d\n", result.stubSize)
    end
    return result
end

function getBestLangIdx(langs, preferred)
    if preferred then
        for i, lang in ipairs(langs) do
            if lang == preferred then
                return i
            end
        end
    end

    -- Otherwise, just pick the first english-ish thing
    for i, lang in ipairs(langs) do
        local locale = Locales[lang]
        if locale and locale:lower():match("^en") then
            return i
        end
    end
    -- And if all else fails, go with the first one
    return 1
end

function parseSimpleFileRecord(data, pos, numLangs, verbose)
    local function vprintf(...)
        if verbose then
            printf(...)
        end
    end

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

    vprintf("type=%d details=%d srcNameLen=%d srcNamePtr=0x%08X destNameLen=%d destNamePtr=0x%08X\n",
        type, details, srcNameLen, srcNamePtr, destNameLen, destNamePtr)

    local srcName = data:sub(1 + srcNamePtr, srcNamePtr + srcNameLen)
    local destName = data:sub(1 + destNamePtr, destNamePtr + destNameLen)
    local maxStringOffset = math.max(srcNamePtr + srcNameLen, destNamePtr + destNameLen)

    if type == FileType.SisComponent and destName:match("[\x00-\x1F]") then
        -- SIS files created with Neuon's nSISUtil appear to put corrupt garbage data into the dest name for
        -- embedded SIS files.
        destName = ""
    end

    local file = {
        type = type,
        src = srcName,
        dest = destName,
    }

    if type == FileType.FileNull then
        vprintf("    %s[FileNull] ptr=0x%08X len=%d\n", destName, contents[1].ptr, contents[1].len)
    else
        local langData = {}
        for i, lang in ipairs(contents) do
            local filePtr = contents[i].ptr
            local fileLen = contents[i].len
            vprintf("    %s[%d] ptr=0x%08X len=%d", destName, i, filePtr, fileLen)
            if filePtr + fileLen > #data then
                vprintf(" TRUNCATED")
            else
                langData[i] = data:sub(1 + filePtr, filePtr + fileLen)
            end
            vprintf("\n")
        end
        if numLangs > 1 then
            file.langData = langData
        else
            file.data = langData[1]
        end
    end
    if type == FileType.FileText or type == FileType.FileRun or type == FileType.SisComponent then
        file.details = details
    end

    return file, pos, maxStringOffset
end

function makeManifest(sisfile, singleLanguage, includeFiles)
    local langIdx
    if singleLanguage then
        langIdx = getBestLangIdx(sisfile.langs, singleLanguage)
    end
    local includeLangs = singleLanguage == nil

    local function langListToLocaleMap(langs, list)
        local result = {}
        for i = 1, math.min(#langs, #list) do
            local langName = Locales[langs[i]]
            if langName then
                result[langName] = list[i]
            else
                -- io.stderr:write(string.format("Warning: Language 0x%x not recognized!\n", langs[i]))
            end
        end
        return result
    end

    local result = {
        type = "sis",
        name = includeLangs and json.Dict(langListToLocaleMap(sisfile.langs, sisfile.name)) or sisfile.name[langIdx],
        version = { major = sisfile.version[1], minor = sisfile.version[2] },
        uid = sisfile.uid,
        languages = {},
        drive = sisfile.installedDrive, -- will be nil for non-stubs
        language = sisfile.language and Locales[sisfile.language], -- likewise
        installedFiles = sisfile.installedFiles, -- always zero for non-stubs
        path = sisfile.path,
    }
    for _, lang in ipairs(sisfile.langs) do
        table.insert(result.languages, Locales[lang])
    end

    if not includeFiles then
        return result
    end

    result.files = {}

    for i, file in ipairs(sisfile.files) do
        local f = {
            type = FileType[file.type],
            dest = file.dest,
        }
        if file.type ~= FileType.FileNull then
            f.src = file.src
            if includeLangs then
                f.len = {}
                if file.langData then
                    for i = 1, #sisfile.langs do
                        if file.langData[i] then
                            f.len[Locales[sisfile.langs[i]]] = #file.langData[i]
                        end
                    end
                else
                    for i = 1, #sisfile.langs do
                        if file.data then
                            f.len[Locales[sisfile.langs[i]]] = #file.data
                        end
                    end
                end
            else
                local data = file.data or (file.langData and file.langData[langIdx])
                f.len = data and #data
            end
        end

        if file.type == FileType.SisComponent and file.data then
            local componentSis = parseSisFile(file.data)
            f.sis = makeManifest(componentSis, singleLanguage, includeFiles)
        end

        result.files[i] = f
    end

    return result
end

function installSis(filename, data, iohandler, includeStub, verbose, stubs)
    if data == nil then
        -- Assume filename is a psion path
        data = assert(iohandler.fsop("read", filename))
    end

    local sisfile = parseSisFile(data, verbose)
    -- This is compatible with struct SisFile in Swift (plus some other stuff that doesn't matter)
    local callbackContext = makeManifest(sisfile)

    local drive = "C"
    local function getPath(file)
        return (file.dest:gsub("^!", drive):gsub("^(.)", function(ch) return ch:upper() end))
    end

    local writeStub

    local function failInstallWithError(fileIdx, err)
        printf("Install of %s failed: %s %s %s\n", filename, err.type, err.code or "", err.context or "")
        local failedFile = fileIdx and sisfile.files[fileIdx]
        local shouldRollback = fileIdx ~= nil -- by default
        local isAbort = failedFile and failedFile.type == FileType.FileText
            and failedFile.details == FileTextDetails.abort
        if err.type == "usercancel" and isAbort then
            shouldRollback = false
        end

        local didRollback = false
        if shouldRollback and iohandler.sisInstallRollback(callbackContext) then
            for i = fileIdx + 1, #sisfile.files do
                local file = sisfile.files[i]
                if file.type == FileType.File then
                    local err = iohandler.fsop("delete", getPath(file))
                    if err ~= KErrNone then
                        print("Rollback failed", err)
                        break
                    end
                elseif file.type == FileType.SisComponent then
                    -- Should we try to roll back completed embedded SIS installs?
                end
            end
            didRollback = true
        end

        if fileIdx and not didRollback and includeStub then
            -- Have to write a stub with the partial count
            writeStub(#sisfile.files - fileIdx)
            -- ignore errors from within rollback?
        end

        iohandler.sisInstallComplete(callbackContext)
        return err
    end
    local function failInstall(fileIdx, reason, code, context)
        return failInstallWithError(fileIdx, { type = reason, code = code, context = context })
    end

    if sisfile.isStub then
        return failInstall(nil, "stub")
    elseif sisfile.isTruncated then
        return failInstall(nil, "epocerr", KErrEof)
    end

    local hasDriveChoice = false
    for _, file in ipairs(sisfile.files) do
        if file.dest:match("^!") then
            hasDriveChoice = true
            break
        end
    end
    local isRootInstall = (stubs == nil)
    if stubs == nil then
        local err
        stubs, err = getStubs(iohandler)
        if stubs == nil then
            return failInstall(nil, "epocerr", err)
        end
    end
    local existing = stubs[sisfile.uid]
    local beginInfo = {
        driveRequired = hasDriveChoice,
        replacing = existing and makeManifest(existing, existing.language),
        isRoot = isRootInstall,
    }
    local ret = iohandler.sisInstallBegin(callbackContext, beginInfo)

    if ret.type == "skip" then
        return nil -- No error
    elseif ret.type == "usercancel" then
        return failInstall(nil, "usercancel")
    elseif ret.type == "epocerr" then
        return failInstall(nil, "epocerr", ret.code)
    else
        assert(ret.type == "install", "Unexpected return type from sisInstallBegin")
    end

    if hasDriveChoice then
        drive = ret.drive:upper()
        assert(drive:match("^[A-Z]$"), "Bad drive returned!")
    end

    local preferredLang = assert(Locales[ret.lang], "Bad lang returned from sisInstallBegin")
    local langIdx = getBestLangIdx(sisfile.langs, preferredLang)

    if existing then
        -- We need to uninstall existing. Note this will not uninstall embedded SIS files at this point. That happens
        -- as part of the installSis() call in the FileType.SisComponent clause below.
        uninstallSis(stubs, existing.uid, iohandler, true)
    end

    writeStub = function(instFiles)
        local stub = makeStub(data, sisfile.langs[langIdx], drive, instFiles)
        local stubDrive = ret.stubDrive or "C"
        local dir = stubDrive .. [[:\System\install\]]
        if iohandler.fsop("exists", dir) ~= KErrNone then
            local err = iohandler.fsop("mkdir", dir)
            if err ~= KErrNone then
                return failInstall(0, "epocerr", err, dir)
            end
        end
        local stubPath = oplpath.join(dir, oplpath.basename(filename))
        local err = iohandler.fsop("write", stubPath, stub)
        if err ~= KErrNone then
            return failInstall(0, "epocerr", err, stubPath)
        end
        return nil -- meaning success
    end


    local skipNext = false
    -- You're supposed to iterate the files list backwards when installing
    for i = #sisfile.files, 1, -1 do
        local file = sisfile.files[i]
        if skipNext then
            printf("Skipping file %s\n", file.dest)
            skipNext = false
        elseif file.type == FileType.File or file.type == FileType.FileRun then
            local path = getPath(file)
            local dir = oplpath.dirname(path)
            if not dir:match("^.:\\$") and iohandler.fsop("exists", dir) ~= KErrNone then
                local err = iohandler.fsop("mkdir", dir)
                if err ~= KErrNone then
                    return failInstall(i, "epocerr", err, dir)
                end
            end
            local data = file.data
            if not data then
                data = file.langData[langIdx]
            end
            local err = iohandler.fsop("write", path, data)
            if err ~= KErrNone then
                return failInstall(i, "epocerr", err, path)
            end
            if file.type == FileType.FileRun and (file.details & FileRunDetails.RunRemove) == 0 then
                iohandler.sisInstallRun(callbackContext, path, file.details)
            end
        elseif file.type == FileType.SisComponent then
            local err = installSis(file.src, file.data, iohandler, includeStub, verbose, stubs)
            if err then
                return failInstallWithError(i, err)
            end
        elseif file.type == FileType.FileText then
            local data = file.data or file.langData[langIdx]
            local queryType = FileTextDetails[file.details]
            assert(queryType, "Unknown FileText details")
            local shouldContinue = iohandler.sisInstallQuery(callbackContext, data, queryType)
            if not shouldContinue then
                if queryType == "skip" then
                    skipNext = true
                else
                    return failInstall(i, "usercancel")
                end
            end
        end
    end

    if includeStub then
        local err = writeStub()
        if err then
            return err
        end
    end

    iohandler.sisInstallComplete(callbackContext)
    return nil -- ie no error
end

function makeStub(sisData, installedLang, drive, instFiles)
    local sisfile = parseSisFile(sisData)

    -- The stub updates lang, instFiles and instDrv. instFiles should be the same as nFiles, not the number of files
    -- actually written (nFiles includes embedded SIS files, FileNull and FileText files), because it's used as a
    -- progress indicator to indicate a partial or completed install.
    --
    -- In ER6 we'd have to also update the Installed Space field.

    if instFiles == nil then
        instFiles = #sisfile.files
    end

    local newData = string.pack("<I2I2I2", installedLang, instFiles, string.byte(drive:lower()))
    local dataOffset = 0x18 -- position of lang

    local result = sisData:sub(1, dataOffset)..newData..sisData:sub(1 + dataOffset + #newData, sisfile.stubSize)
    return result
end


function uninstallSis(stubMap, uid, iohandler, upgrading)
    if not stubMap then
        stubMap = getStubs(iohandler)
    end
    local sisfile = assert(stubMap[uid], "Can't find installer in stubs!")
    printf("uninstalling %s\n", sisfile.path)
    local callbackContext = makeManifest(sisfile)

    local drive = sisfile.installedDrive --or "C"
    local function getPath(file)
        return (file.dest:gsub("^!", drive):gsub("^(.)", function(ch) return ch:upper() end))
    end
    local function delete(path)
        local err = iohandler.fsop("delete", path)
        if err ~= KErrNone and err ~= KErrNotExists then
            printf("Uninstall failed to delete %s, err=%d\n", path, err)
        end
    end

    for i = 1, #sisfile.files do
        local file = sisfile.files[i]
        if file.type == FileType.File or (file.type == FileType.FileNull and not upgrading) then
            -- print("DELETE", getPath(file))
            local path = getPath(file)
            delete(path)
        elseif file.type == FileType.SisComponent and not upgrading then
            -- See if anyone else is using it. If we're upgrading, then the nested install will take care of uninstalling.
            local inUserBySomethingElse = false
            local name = oplpath.basename(file.src):lower()
            local foundStubUid
            for uid, stub in pairs(stubMap) do
                if oplpath.basename(stub.path):lower() == name then
                    printf("Found stub for %s - %s\n", name, stub.path)
                    foundStubUid = stub.uid
                end

                for _, file in ipairs(stub.files) do
                    if file.type == FileType.SisComponent and oplpath.basename(file.src):lower() == name then
                        printf("%s in use by %s\n", name, stub.path)
                        if stub.path ~= sisfile.path then
                            inUserBySomethingElse = true
                        end
                    end
                end
            end

            if not inUserBySomethingElse then
                uninstallSis(stubMap, foundStubUid, iohandler, false)
            end
        elseif file.type == FileType.FileRun then
            local path = getPath(file)
            if file.details & (FileRunDetails.RunRemove | FileRunDetails.RunBoth) ~= 0 then
                iohandler.sisInstallRun(callbackContext, path, file.details)
            end
            delete(path)
        end
    end

    delete(sisfile.path) -- the stub
end

function getStubs(iohandler)
    local result, err = iohandler.sisGetStubs()
    if result == "notimplemented" then
        result = {}
        local disks = assert(iohandler.fsop("disks"))
        for _, disk in ipairs(disks) do
            local installDir = disk .. [[:\System\install\]]
            local stubNames = iohandler.fsop("dir", installDir) or {}
            for _, path in ipairs(stubNames) do
                if path:lower():match("%.sis$") then
                    local contents = assert(iohandler.fsop("read", path))
                    table.insert(result, { path = path, contents = contents })
                end
            end
        end
    elseif result == nil then
        return nil, err
    end
    return stubArrayToUidMap(result)
end

function stubArrayToUidMap(stubs)
    local result = {}
    for _, stub in ipairs(stubs) do
        local sisfile = parseSisFile(stub.contents)
        sisfile.path = stub.path
        result[sisfile.uid] = sisfile
    end
    return result
end

local shortFileTextDetails = enum {
    TC = FileTextDetails.continue,
    TS = FileTextDetails.skip,
    TA = FileTextDetails.abort,
    TE = FileTextDetails.exit,
}

local shortFileRunDetails = enum {
    RI = FileRunDetails.RunInstall,
    RR = FileRunDetails.RunRemove,
    RB = FileRunDetails.RunBoth,
    RE = FileRunDetails.RunSendEnd,
    RW = FileRunDetails.RunWait,
}

function describeSis(sisfile, indent)
    local cp1252 = require("cp1252")
    for _, name in ipairs(sisfile.name) do
        printf("%sName: %s\n", indent, cp1252.toUtf8(name))
    end

    printf("%sVersion: %d.%d\n", indent, sisfile.version[1], sisfile.version[2])
    
    printf("%sUid: 0x%08X\n", indent, sisfile.uid)

    for _, lang in ipairs(sisfile.langs) do
        printf("%sLanguage: 0x%04X (%s)\n", indent, lang, Locales[lang])
    end

    printf("%sInstalled files: %d of %d\n", indent, sisfile.installedFiles, #sisfile.files)

    -- local langIdx = getBestLangIdx(sisfile.langs)
    for _, file in ipairs(sisfile.files) do
        local src = cp1252.toUtf8(file.src)
        local dest = cp1252.toUtf8(file.dest)
        printf("%s%s: %s -> %s", indent, FileType[file.type], src, dest)
        if file.langData then
            local lens = {}
            for i, data in ipairs(file.langData) do
                lens[i] = tostring(#data)
            end
            printf(" len=%s", table.concat(lens, ","))
        elseif file.data then
            printf(" len=%d", #file.data)
        end
        if file.type == FileType.FileText then
            printf(" [%s]", shortFileTextDetails[file.details])
        elseif file.type == FileType.FileRun then
            printf(" [%s]", shortFileRunDetails[file.details])
        end
        printf("\n")

        if file.type == FileType.SisComponent and file.data then
            local componentSis = parseSisFile(file.data)
            describeSis(componentSis, "    "..indent)
        end
    end
end

function pkgToManifest(pkgData)
    local manifest = { files = {} }

    for line in pkgData:gmatch("[^\r\n]*") do
        local pos = 1
        local function parseQuotedString()
            local str, newPos = line:match('^ *"([^"]*)" *()', pos)
            assert(str, "Expected quoted string")
            pos = newPos
            return str
        end
        local function handleFileRecord(file)
            -- pos should be pointing to the dash before the dest
            local dash, nextPos = line:match("^ *(%-)()", pos)
            assert(dash, "Expected '-'")
            pos = nextPos
            file.dest = parseQuotedString()
            file.type = "File"
            local fileTypeStr, pos = line:match("^ *, *([A-Za-z]+)()", pos)
            if fileTypeStr then
                file.type = FileType[assert(FileTypeAliases[fileTypeStr:upper()], "Bad file type "..fileTypeStr)]
                local detailsStr, pos = line:match(" *, *([A-Za-z]+)()", pos)
                if detailsStr then
                    if file.type == "FileRun" then
                        file.details = assert(FileRunAliases[detailsStr:upper()], "Bad FileRun details "..detailsStr)
                    elseif file.type == "FileText" then
                        file.details = assert(FileTextAliases[detailsStr:upper()], "Bad FileText details "..detailsStr)
                    else
                        error("Unexpected details for file type "..file.type)
                    end
                end
            end
            table.insert(manifest.files, file)
        end

        if line == "" or line:match("^;") then
            -- ignore
        elseif line:match("^&") then
            -- Languages
            manifest.languages = {}
            for langCode in line:gmatch("[^,]+", 2) do
                local langId = LangShortCodes[langCode]
                assert(langId, "Unrecognized language "..langCode)
                table.insert(manifest.languages, Locales[langId])
            end
        elseif line:match("^#{") then
            -- Header
            pos = 3
            if manifest.languages == nil then
                manifest.languages = { "en_GB" }
            end
            local names = {}
            while true do
                table.insert(names, parseQuotedString())
                local nextToken, nextPos = line:match('^ *([,}])()', pos)
                pos = nextPos
                assert(nextToken, "Expected , or }")
                if nextToken == "}" then
                    break
                end
            end
            assert(#names == #manifest.languages, "Bad localised string count in package name")
            manifest.name = {}
            for i, name in ipairs(names) do
                manifest.name[manifest.languages[i]] = name
            end
            local uidStr, majStr, minStr, variantStr, pos = line:match(", *%(([0-9A-Fa-fxX]+)%),([0-9]+),([0-9]+),([0-9]+)()", pos)
            manifest.uid = assert(tonumber(uidStr), "Bad uid "..uidStr)
            manifest.version = {
                major = assert(tonumber(majStr), "Bad major version "..majStr),
                minor = assert(tonumber(minStr), "Bad minor version "..minStr)
            }
            local variant = assert(tonumber(variantStr), "Bad variant "..variantStr)
            assert(variant == 0, "Non-zero variant not supported!")
            
            local optionsStr = line:match(" *,(.*)", pos)
            if optionsStr == "ID" then
                manifest.options = 2
            else
                manifest.options = tonumber(optionsStr) or 0
            end

        elseif line:match('^%"') then
            -- Simple file record
            local file = {
                src = { parseQuotedString() }
            }
            handleFileRecord(file)
        elseif line:match('^{"') then
            -- Multi-language record
            local src = {}
            pos = 2
            while true do
                table.insert(src, parseQuotedString())
                local nextToken, nextPos = line:match('^ *(["}])()', pos)
                assert(nextToken, 'Expected " or }')
                if nextToken == '"' then
                    pos = nextPos - 1 -- unconsume the opening quote
                else
                    pos = nextPos
                    break
                end
            end
            assert(#src == #manifest.languages, "Bad number of sources in MultiLangRecord")
            handleFileRecord({ src = src })
        elseif line:match('^@"') then
            -- Embedded (not-per-language) SIS file
            pos = 2
            local src = parseQuotedString()
            local uid = assert(tonumber(line:match("^, *%(([0-9A-Fa-fxX]+)%)", pos)))
            local file = {
                src = { src },
                dest = "",
                type = "SisComponent",
                details = uid,
            }
            table.insert(manifest.files, file)
        elseif line:match('^{@') then
            -- Embedded per-language SIS file
            error("TODO")
        else
            printf("Warning: unhandled line %s\n", line)
        end
    end

    return manifest
end

local singleFileRecordSize = 28 -- not including file length(s) and pointer(s)

--[[
Implementation detail of how the average sis file is laid out:

Header - 68 bytes

Languages - 2n bytes

Files - SimpleFileRecord 36 bytes, MultiLangFileRecord 28 + 8n bytes

Requisites - if empty, reqPtr points to same as namePtr

Name table - not the actual strings

File src/dest strings

Name strings

-- End of stub sis --

File data

]]
function makeSis(manifest)
    local parts = { sz = 0 }
    local function appendData(str)
        parts.sz = parts.sz + #str
        table.insert(parts, str)
    end        
    local function appendf(fmt, ...)
        local part = string.pack("<" .. fmt, ...)
        appendData(part)
    end
    local function updateIndex(index)
        assert(#parts[index] == 4, "Cannot update index that isn't pointer-sized")
        parts[index] = string.pack("<I4", parts.sz)
    end
    -- local uid1, uid2, uid3, uid4, checksum, nLangs, nFiles, pos = string.unpack("<I4I4I4I4I2I2I2", data)

    local uid1, uid2, uid3 = manifest.uid, KUidAppDllDoc8, KUidInstallApp
    local crc = require("crc")
    local uid4 = crc.getUidsChecksum(uid1, uid2, uid3)
    appendf("I4I4I4I4",
        uid1,
        uid2,
        uid3,
        uid4
    )
    appendf("I2", 0) -- checksum
    appendf("I2I2 I2I2I2I2I2I4 I2I2I2I2I4",
        #manifest.languages,
        #manifest.files,

        0, -- numRequisites
        0, -- instLang
        0, -- instFiles
        0, -- instDrv
        0, -- nCaps
        0x64, -- instVer

        manifest.options,
        0, -- type
        manifest.version.major,
        manifest.version.minor,
        0) -- variant

    appendf("I4", 0)
    local langPtrIdx = #parts
    appendf("I4", 0)
    local filesPtrIdx = #parts
    appendf("I4", 0)
    local reqPtrIdx = #parts
    
    appendf("I4", 0)
    -- certPtr is always zero

    appendf("I4", 0)
    local namePtrIdx = #parts

    -- Header done, languages next
    updateIndex(langPtrIdx)
    for _, lang in ipairs(manifest.languages) do
        appendf("I2", Locales[lang])
    end

    -- Files section
    updateIndex(filesPtrIdx)
    local nameTableSize = 8 * #manifest.languages
    local filesEnd = parts.sz
    for _, file in ipairs(manifest.files) do
        filesEnd = filesEnd + singleFileRecordSize + (file.data == nil and 1 or #file.data) * 8
    end
    local stringPtr = filesEnd + nameTableSize
    local fileDataPtrIndexes = {}
    for i, file in ipairs(manifest.files) do
        local recordType = (file.data == nil or #file.data == 1) and FileRecordType.SimpleFileRecord or FileRecordType.MultiLangRecord
        local srcNamePtr = stringPtr
        stringPtr = stringPtr + #file.src[1]
        local destNamePtr = stringPtr
        stringPtr = stringPtr + #file.dest
        appendf("I4I4I4I4I4I4I4",
            recordType,
            FileType[file.type],
            file.details or 0,
            #file.src[1],
            srcNamePtr,
            #file.dest,
            destNamePtr
        )
        fileDataPtrIndexes[i] = {}
        if file.data then
            for j = 1, #file.data do
                appendf("I4", #file.data[j])
            end
            for j = 1, #file.data do
                appendf("I4", 0)
                fileDataPtrIndexes[i][j] = #parts
            end
        else
            appendf("I4", 0) -- len
            appendf("I4", 0) -- ptr
            fileDataPtrIndexes[i][1] = #parts
        end
    end

    assert(parts.sz == filesEnd, "filesEnd calculation mismatch!")
    updateIndex(reqPtrIdx)

    -- package name(s)
    updateIndex(namePtrIdx)
    for _, lang in ipairs(manifest.languages) do
        appendf("I4", #manifest.name[lang])
    end
    for _, lang in ipairs(manifest.languages) do
        appendf("I4", stringPtr)
        stringPtr = stringPtr + #manifest.name[lang]
    end

    -- Now file strings
    for i, file in ipairs(manifest.files) do
        appendData(file.src[1])
        appendData(file.dest)
    end
    -- Name strings
    for _, lang in ipairs(manifest.languages) do
        appendData(manifest.name[lang])
    end

    assert(parts.sz == stringPtr, "stringPtr calculation mismatch!")

    -- Finally, file data
    for i, file in ipairs(manifest.files) do
        for j, idx in ipairs(fileDataPtrIndexes[i]) do
            updateIndex(idx)
            if file.data then
                appendData(file.data[j])
            end
        end
    end

    -- Last thing is to calculate the checksum
    local checksum = crc.crc16(parts[1])
    -- parts[2] is checksum placeholder
    for i = 3, #parts do
        checksum = crc.crc16(parts[i], checksum)
    end
    parts[2] = string.pack("<I2", checksum)

    return table.concat(parts)
end

return _ENV
