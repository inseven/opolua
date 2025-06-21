-- Copyright (c) 2025 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

local ch = string.byte

local function sisInstallQuery(sisFile, text, queryType)
    text = text:gsub("\r\n", KLineBreakStr)
    local w, h = gTWIDTH("M", kDialogFont)
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
            numLines = (gHEIGHT() // h) - 7,
            readonly = true, -- extension, not part of standard dEDITMULTI
            },
        },
        buttons = {
            { key = KKeyEsc | KDButtonNoLabel, text = "No" },
            { key = KKeyEnter| KDButtonNoLabel, text = "Yes" },
        },
    }
    return ret == KKeyEnter
end

function installSis(hostPath, devicePath, hostDest)
    runtime:iohandler().setAppTitle("Installer")

    local sis = require("sis")

    local seenApps = {}
    local drive

    local function sisInstallBegin(sisFile, info)
        if not info.isRoot then
            return { type = "install", drive = drive, stubDrive = drive, lang = sisFile.languages[1] }
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
        local ret
        repeat
            local buttons = {
                { key = KKeyEsc, text = "Cancel" },
                { key = KKeyEnter, text = "OK" },
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
                    }
                },
                buttons = buttons,
            }
            if ret == ch's' then
                useShared = not useShared
            end
        until ret ~= ch's'
        drive = useShared and "D" or "C"

        if ret == KKeyEnter then
            return { type = "install", drive = drive, stubDrive = drive, lang = sisFile.languages[1] }
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
        end

    else
        DIALOG {
            title = "Installation failed",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = {
                {
                type = dItemTypes.dTEXT,
                align = "center",
                value = string.format("Error %s %s", result.type, result.code),
                }
            },
            buttons = {
                { key = -KKeyEnter, text = "Quit" },
            },
        }
    end
end

function launcher(osName)
    runtime:iohandler().setAppTitle("Launcher")
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

    local icon = gLOADBIT("C:\\icons_color.mbm", false, 0)
    local w, h = gWIDTH(), gHEIGHT()
    gUSE(1)
    gAT((gWIDTH() - w) // 2, (gHEIGHT() - h) // 2)
    gCOPY(icon, 0, 0, w, h, KtModeReplace)
    gCLOSE(icon)

end

return _ENV
