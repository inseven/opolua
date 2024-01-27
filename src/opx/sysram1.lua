--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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

fns = {
    [1] = "DBFind",
    [2] = "DBFindField",
    [3] = "GetThreadIdFromCaption",
    [4] = "ExternalPower",
    [5] = "LCNearestLanguageFile",
    [6] = "LCLanguage",
    [7] = "OSVersionMajor",
    [8] = "OSVersionMinor",
    [9] = "OSVersionBuild",
    [10] = "ROMVersionMajor",
    [11] = "ROMVersionMinor",
    [12] = "ROMVersionBuild",
    [13] = "GetFileSize",
    [14] = "DTDayNameFull",
    [15] = "DTMonthNameFull",
    [16] = "DTIsLeapYear",
    [17] = "LCDateSeparator",
    [18] = "LCTimeSeparator",
    [19] = "LCAmPmSpaceBetween",
    [20] = "RunExeWithCmd",
    [21] = "SendSwitchFilesMessageToApp",
    [22] = "RunDocument",
    [23] = "GetOPXVersion",
}

function DBFind(stack, runtime) -- 1
    unimplemented("opx.sysram1.DBFind")
end

function DBFindField(stack, runtime) -- 2
    unimplemented("opx.sysram1.DBFindField")
end

function GetThreadIdFromCaption(stack, runtime) -- 3
    unimplemented("opx.sysram1.GetThreadIdFromCaption")
end

function ExternalPower(stack, runtime) -- 4
    stack:push(true)
end

function LCNearestLanguageFile(stack, runtime) -- 5
    unimplemented("opx.sysram1.LCNearestLanguageFile")
end

function LCLanguage(stack, runtime) -- 6
    stack:push(require("sis").Locales["en_GB"])
end

local osversion = { 1, 2, 166 } -- according to my Psion 5, this is a sane version
local romversion = { 1, 5, 254 } -- according to my Psion 5, this is a sane version

function OSVersionMajor(stack, runtime) -- 7
    stack:push(osversion[1])
end

function OSVersionMinor(stack, runtime) -- 8
    stack:push(osversion[2])
end

function OSVersionBuild(stack, runtime) -- 9
    stack:push(osversion[3])
end

function ROMVersionMajor(stack, runtime) -- 10
    stack:push(romversion[1])
end

function ROMVersionMinor(stack, runtime) -- 11
    stack:push(romversion[2])
end

function ROMVersionBuild(stack, runtime) -- 12
    stack:push(romversion[3])
end

function GetFileSize(stack, runtime) -- 13
    local path = stack:pop()
    local stat, err = runtime:iohandler().fsop("stat", path)
    if stat then
        stack:push(stat.size)
    else
        error(err)
    end
end

function DTDayNameFull(stack, runtime) -- 14
    -- See DayNameStr for explanation of logic
    stack:push(os.date("!%A", 86400 * (3 + stack:pop())))
end

function DTMonthNameFull(stack, runtime) -- 15
    stack:push(os.date("!%B", 86400 * 31 * (stack:pop() - 1)))
end

function DTIsLeapYear(stack, runtime) -- 16
    unimplemented("opx.sysram1.DTIsLeapYear")
end

function LCDateSeparator(stack, runtime) -- 17
    unimplemented("opx.sysram1.LCDateSeparator")
end

function LCTimeSeparator(stack, runtime) -- 18
    unimplemented("opx.sysram1.LCTimeSeparator")
end

function LCAmPmSpaceBetween(stack, runtime) -- 19
    unimplemented("opx.sysram1.LCAmPmSpaceBetween")
end

function RunExeWithCmd(stack, runtime) -- 20
    unimplemented("opx.sysram1.RunExeWithCmd")
end

function SendSwitchFilesMessageToApp(stack, runtime) -- 21
    unimplemented("opx.sysram1.SendSwitchFilesMessageToApp")
end

function RunDocument(stack, runtime) -- 22
    unimplemented("opx.sysram1.RunDocument")
end

function GetOPXVersion(stack, runtime) -- 23
    unimplemented("opx.sysram1.GetOPXVersion")
end

return _ENV
