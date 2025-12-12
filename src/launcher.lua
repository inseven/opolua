-- Copyright (c) 2025 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

local ch = string.byte

local langNames = {
    en_GB = "UK English",
    fr_FR = "French",
    de_DE = "German",
    es_ES = "Spanish",
    it_IT = "Italian",
    sv_SE = "Swedish",
    da_DK = "Danish",
    no_NO = "Norwegian",
    fi_FI = "Finnish",
    en_US = "American English",
    fr_CH = "Swiss French",
    de_CH = "Swiss German",
    pt_PT = "Portuguese",
    tr_TR = "Turkish",
    is_IS = "Icelandic",
    ru_RU = "Russian",
    hu_HU = "Hungarian",
    nl_NL = "Dutch",
    nl_BE = "Belgian Flemish",
    en_AU = "Australian English",
    fr_BE = "Belgian French",
    de_AT = "Austrian German",
    en_NZ = "New Zealand English",
    fr = "International French",
    cs_CZ = "Czech",
    sk_SK = "Slovak",
    pl_PL = "Polish",
    sl_SI = "Slovenian",
    zh_Hant_TW = "Taiwan Chinese",
    zh_Hant_HK = "Hong Kong Chinese",
    zh_Hant_CN = "PRC Chinese",
    ja_JP = "Japanese",
    th_TH = "Thai",
    af_ZA = "Afrikaans",
    sq_AL = "Albanian",
    am_ET = "Amharic",
    ar = "Arabic",
    hy_AM = "Armenian",
    fil_PH = "Tagalog",
    be_BY = "Belarussian",
    bn = "Bengali",
    bg_BG = "Bulgarian",
    my_MM = "Burmese",
    ca_ES = "Catalan",
    hr_HR = "Croatian",
    en_CA = "Canadian English",
    en_001 = "International English",
    en_ZA = "South African English",
    et_EE = "Estonian",
    fa_IR = "Farsi",
    fr_CA = "Canadian French",
    gd_GB = "Scots Gaelic",
    ka_GE = "Georgian",
    el_GR = "Greek",
    el_CY = "Cyprus Greek",
    gu_IN = "Gujarati",
    he_IL = "Hebrew",
    hi_IN = "Hindi",
    id_ID = "Indonesian",
    ga_IE = "Irish",
    it_CH = "Swiss Italian",
    kn_IN = "Kannada",
    kk_KZ = "Kazakh",
    km_KH = "Khmer",
    ko_KR = "Korean",
    lo_LA = "Laothian",
    lv_LV = "Latvian",
    lt_LT = "Lithuanian",
    mk_MK = "Macedonian",
    ms_MY = "Malay",
    ml_IN = "Malayalam",
    mr_IN = "Marathi",
    ro_MD = "Moldavian",
    mn_MN = "Mongolian",
    nn_NO = "Norwegian-Nynorsk",
    pt_BR = "Brazilian Portuguese",
    pa = "Punjabi",
    ro_RO = "Romanian",
    sr = "Serbian",
    si_LK = "Sinhalese",
    so_SO = "Somali",
    es = "International Spanish",
    es_419 = "Latin American Spanish",
    sw = "Swahili",
    sv_FI = "Finland Swedish",
    ta_LK = "Tamil",
    te_IN = "Telugu",
    bo = "Tibetan",
    ti = "Tigrinya",
    tr_CY = "Cyprus Turkish",
    tk_TM = "Turkmen",
    uk_UA = "Ukrainian",
    ur = "Urdu",
    vi_VN = "Vietnamese",
    cy_GB = "Welsh",
    zu_ZA = "Zulu",
}

local function sisInstallQuery(sisFile, text, queryType)
    text = text:gsub("\r\n", KLineBreakStr)
    local w, h = gTWIDTH("M", kDialogFont)
    local nonTextHeight = 23 + 9 + 1 + 3 -- kButtonDefaultHeight + kButtonYOffset + kDialogLineGap + DialogItemEditMulti:contentSize() space
    local ret = DIALOG {
        title = "",
        flags = KDlgNoTitle | KDlgFillScreen | KDlgDensePack,
        xpos = 0,
        ypos = 0,
        items = {
            {
            type = dItemTypes.dEDITMULTI,
            value = text,
            widthChars = (gWIDTH() // w),
            numLines = (gHEIGHT() - nonTextHeight) // (h + 4), -- See DialogItemEditMulti:lineHeight() for the 4
            readonly = true, -- extension, not part of standard dEDITMULTI
            },
        },
        buttons = {
            { key = KKeyEsc | KDButtonNoLabel, text = "No" },
            { key = KKeyEnter | KDButtonNoLabel, text = "Yes" },
        },
    }
    return ret == KKeyEnter
end

function installSis(hostPath, devicePath, hostDest)
    runtime:iohandler().system("setAppTitle", "Installer")

    local sis = require("sis")

    local seenApps = {}
    local drive

    local function sisInstallBegin(sisFile, info)
        if not info.isRoot then
            return {
                type = "install",
                drive = drive,
                -- stubDir = nil,
                lang = sisFile.languages[1]
            }
        end

        local sharedPath = runtime:iohandler().fsop("getNativePath", "D:\\")
        local showSharedToggle = false -- sharedPath ~= nil
        local useShared = false

        local textLine1
        if info.replacing then
            -- Always upgrade to same drive
            drive = info.replacing.path:sub(1, 1):upper()
            useShared = drive == "D"
            showSharedToggle = false

            textLine1 = string.format("Replace %s v%d.%02d in",
                oplpath.basename(hostPath), info.replacing.version.major, info.replacing.version.minor)
        else
            textLine1 = string.format("Install %s to", oplpath.basename(hostPath))
        end

        local langQuery
        if #sisFile.languages > 1 then
            langQuery = {
                type = dItemTypes.dCHOICE,
                prompt = "Language",
                choices = {},
                variable = runtime:makeTemporaryVar(DataTypes.EWord),
                index = 1,
            }
            for i, id in ipairs(sisFile.languages) do
                langQuery.choices[i] = langNames[id] or id
            end
        end

        local ret
        repeat
            local buttons = {
                { key = KKeyEsc | KDButtonNoLabel, text = "Cancel" },
                { key = KKeyEnter | KDButtonNoLabel, text = "OK" },
            }
            if showSharedToggle then
                if useShared then
                    table.insert(buttons, 1, { key = ch's' | KDButtonPlainKey, text = "Use Separate" })
                else
                    table.insert(buttons, 1, { key = ch's' | KDButtonPlainKey, text = "Use Shared" })
                end
            end

            ret = DIALOG {
                title = string.format("Install %s %d.%02d",
                    sisFile.name[sisFile.languages[1]], sisFile.version.major, sisFile.version.minor),
                flags = 0,
                xpos = 0,
                ypos = 0,
                items = {
                    {
                    type = dItemTypes.dTEXT,
                    align = "center",
                    value = textLine1,
                    },
                    {
                    type = dItemTypes.dTEXT,
                    align = "center",
                    value = string.format("'%s'?", useShared and sharedPath or hostDest),
                    },
                    langQuery
                },
                buttons = buttons,
            }
            if ret == ch's' then
                useShared = not useShared
            end
        until ret ~= ch's'
        drive = useShared and "D" or "C"
        local lang = sisFile.languages[langQuery and langQuery.variable() or 1]

        if ret == KKeyEnter then
            ESCAPE(false) -- Don't allow polite interruptions from here on
            return {
                type = "install",
                drive = drive,
                -- stubDir = nil,
                lang = lang,
            }
        else
            return { type = "usercancel" }
        end
    end

    local iohandler = {
        fsop = function(cmd, path, ...)
            if cmd == "write" then
                if path:lower():match([[^.:\system\apps\[^\]+\.+%.app]]) then -- TODO check for an AIF instead
                    table.insert(seenApps, path)
                end
            end
            return runtime:iohandler().fsop(cmd, path, ...)
        end,
        sisInstallBegin = sisInstallBegin,
        sisGetStubs = function() return "notimplemented" end,
        sisInstallQuery = sisInstallQuery,
        sisInstallRollback = function()
            print("TODO sisInstallRollback")
        end,
        sisInstallRun = function(sisInfo, path, flags)
            printf("sisInstallRun %s\n", path)
        end,
        sisInstallComplete = function() end,
    }

    local result = sis.installSis(devicePath, nil, iohandler, true)

    if result == nil then
        local items = {}
        local buttons = {
            { key = KKeyEsc | KDButtonNoLabel, text = "Quit" },
        }
        local appNames = {}
        for i, path in ipairs(seenApps) do
            local appNamePos = path:lower():match([[.:\system\apps\[^\]+\().+%.app]]) 
            appNames[i] = path:sub(appNamePos, -5)
        end
        if #seenApps == 1 then
            table.insert(items, {
                type = dItemTypes.dTEXT,
                align = "center",
                value = string.format("Launch app '%s'?", appNames[1]),
            })
            table.insert(buttons, { key = KKeyEnter | KDButtonNoLabel, text = "Launch" })
        end

        local ret = DIALOG {
            title = "Installation complete",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = items,
            buttons = buttons,
        }

        if ret == KKeyEnter then
            return { launch = seenApps[1] }
        else
            return {} -- Success, but no launch
        end
    else
        local errText
        if result.type == "usercancel" then
            errText = "User cancelled."
        elseif result.type == "stub" then
            errText = "Cannot install a stub SIS file."
        else
            errText = string.format("Error %d.", result.code)
        end
        DIALOG {
            title = "Installation failed",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = {
                {
                type = dItemTypes.dTEXT,
                align = "center",
                value = errText,
                }
            },
            buttons = {
                { key = -KKeyEnter, text = "Quit" },
            },
        }
        return nil
    end
end

function launcher(osName)
    runtime:iohandler().system("setAppTitle", "Launcher")
    SCREEN(70, 20, 10, 1)
    local isMac = osName == "osx" or osName == "macos" -- Qt5 and Qt6 names respectively
    local mod = isMac and "Cmd" or "Ctrl-Alt"
    local function print(str)
        PRINT(str..KLineBreakStr)
    end
    print("Welcome to OpoLua")
    print("")
    print("Install a SIS by:")
    print(string.format("  * selecting File->Install SIS (%s-I)", mod))
    print("  * double-clicking the SIS file, or")
    print("  * dragging it into this window.")
    print("")
    print("Install multiple SIS files on the same virtual disk by dragging a SIS onto the window of a running app.")

    local icon = gLOADBIT("C:\\icons_color.mbm", false, 0)
    local w, h = gWIDTH(), gHEIGHT()
    gUSE(1)
    -- gAT((gWIDTH() - w) // 2, (gHEIGHT() - h) // 2)
    gAT(10, 15)
    gCOPY(icon, 0, 0, w, h, KtModeReplace)
    gCLOSE(icon)
end

function selectApp()
    runtime:iohandler().system("setAppTitle", "App selector")

    local aif = require("aif")
    local choices = {}
    local choicePaths = {}
    local dirs = runtime:ls([[C:\System\Apps]])
    for _, dir in ipairs(dirs) do
        local aifPath = runtime:dir(oplpath.join(dir, "*.aif"))
        if #aifPath > 0 then
            local aifData = runtime:iohandler().fsop("read", aifPath)
            local captions = aifData and aif.parseAif(aifData).captions
            local caption = captions[runtime:iohandler().getConfig("locale")]
                or captions["en_GB"] or captions[next(captions)]

            if caption then
                table.insert(choices, caption)
                table.insert(choicePaths, aifPath:sub(1, #aifPath - 4)..".app")
            end
        else
            -- Look for raw .apps in case it's an app that doesn't install an AIF file or only configures it on first
            -- run rather than in an install step (PsiBall, looking at you)
            local appPath = runtime:dir(oplpath.join(dir, "*.app"))
            if #appPath > 0 then
                table.insert(choices, oplpath.basename(appPath))
                table.insert(choicePaths, appPath)
            end
        end
    end

    if #choices == 0 then
        DIALOG {
            title = "No apps found",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = {
                {
                type = dItemTypes.dTEXT,
                align = "center",
                value = "No apps were found in this location.",
                }
            },
            buttons = {
                { key = -(KKeyEnter | KDButtonNoLabel), text = "OK" },
            },
        }
        return
    end

    local choiceVar = runtime:makeTemporaryVar(DataTypes.EWord)
    local ret = DIALOG {
        title = "Select app to launch",
        flags = 0,
        xpos = 0,
        ypos = 0,
        items = {
            {
            type = dItemTypes.dCHOICE,
            prompt = "App",
            choices = choices,
            index = 1,
            variable = choiceVar,
            },
        },
        buttons = {
            { key = KKeyEsc | KDButtonNoLabel, text = "Cancel" },
            { key = KKeyEnter | KDButtonNoLabel, text = "Launch" },
        },
    }

    if ret == KKeyEnter then
        return choicePaths[choiceVar()]
    else
        return nil
    end
end

return _ENV
