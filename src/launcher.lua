-- Copyright (c) 2025 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

local function sisInstallBegin(sisFile, info, hostPath, hostDest)
    if not info.isRoot then
        return { type = "install", drive = "C", lang = sisFile.languages[1] }
    end

    local textLine1
    if info.replacing then
        textLine1 = string.format("Replace %s v%d.%02d in",
            oplpath.basename(hostPath), info.replacing.version.major, info.replacing.version.minor)
    else
        textLine1 = string.format("Install %s to", oplpath.basename(hostPath))
    end
    local dlg = {
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
            value = string.format("'%s'?", hostDest),
            }
        },
        buttons = {
            { key = KKeyEnter, text = "OK" },
            { key = -KKeyEsc, text = "Cancel" },
        },
    }
    local ret = DIALOG(dlg)
    if ret == KKeyEnter then
        return { type = "install", drive = "C", lang = sisFile.languages[1] }
    else
        return { type = "usercancel" }
    end
end

local function sisInstallQuery(sisFile, text, queryType)
    text = text:gsub("\r\n", KLineBreakStr)
    local w, h = gTWIDTH("M", kDialogFont)
    local dlg = {
        title = string.format("Install %s %d.%02d",
            sisFile.name[sisFile.languages[1]], sisFile.version.major, sisFile.version.minor),
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
            { key = KKeyEnter, text = "Yes" },
            { key = -KKeyEsc, text = "No" },
        },
    }
    return DIALOG(dlg) == KKeyEnter
end


function installSis(hostPath, devicePath, hostDest)
    -- device dest is assumed to always be "C"

    runtime:iohandler().setAppTitle("Installer")

    local sis = require("sis")

    local iohandler = {
        fsop = runtime:iohandler().fsop,
        sisInstallBegin = function(sisFile, info)
            return sisInstallBegin(sisFile, info, hostPath, hostDest)
        end,
        sisGetStubs = function() return "notimplemented" end,
        sisInstallQuery = sisInstallQuery,
        sisInstallRollback = function()
            print("TODO sisInstallRollback")
        end,
        sisInstallComplete = function() end,
    }

    local result = sis.installSis(devicePath, nil, iohandler, true)
    if result == nil then
        local dlg = {
            title = "Installation complete",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = {
            },
            buttons = {
                { key = KKeyEnter | KDButtonNoLabel, text = "OK" },
            },
        }
        DIALOG(dlg)
    else
    end
end

return _ENV
