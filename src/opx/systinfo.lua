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

fns = {
    [1] = "SISystemVisible",
    [2] = "SIHiddenVisible",
    [3] = "SICurrencyFormat",
    [4] = "SIDateFormat",
    [5] = "SITimeFormat",
    [6] = "SIUTCOffset",
    [7] = "SIWorkday",
    [8] = "SIDaylightSaving",
    [9] = "SIHomeCountry",
    [10] = "SIUnits",
    [11] = "SIIsDirectory",
    [12] = "SIVolumeName",
    [13] = "SIUniqueFilename",
    [14] = "SIBookmark",
    [15] = "SIStandardFolder",
    [16] = "SIDisplayContrast",
    [17] = "SIOwner",
    [18] = "SIBatteryVolts",
    [19] = "SIBatteryCurrent",
    [20] = "SIMemory",
    [21] = "SIKeyClickEnabled",
    [22] = "SIKeyClickLoud",
    [23] = "SIKeyClickOverridden",
    [24] = "SIPointerClickEnabled",
    [25] = "SIPointerClickLoud",
    [26] = "SIBeepEnabled",
    [27] = "SIBeepLoud",
    [28] = "SISoundDriverEnabled",
    [29] = "SISoundDriverLoud",
    [30] = "SISoundEnabled",
    [31] = "SIAutoSwitchOffBehaviour",
    [32] = "SIAutoSwitchOffTime",
    [33] = "SIBacklightBehaviour",
    [34] = "SIBacklightOnTime",
    [35] = "SIDisplaySize",
    [36] = "SIKeyboardIndex",
    [37] = "SILanguageIndex",
    [38] = "SIXYInputPresent",
    [39] = "SIKeyboardPresent",
    [40] = "SIMaximumColors",
    [41] = "SIProcessorClock",
    [42] = "SISpeedFactor",
    [43] = "SIMachine",
    [44] = "SIRemoteLinkStatus",
    [45] = "SIRemoteLinkDisable",
    [46] = "SIIsPathVisible",
    [47] = "SIRemoteLinkEnable",
    [48] = "SIPWIsEnabled",
    [49] = "SIPWSetEnabled",
    [50] = "SIPWIsValid",
    [51] = "SIPWSet",
    [52] = "SILedSet",
    [53] = "SIRemoteLinkEnableWithOptions",
    [54] = "SIRemoteLinkConfig",
}

KDateFormatAmerican = 0
KDateFormatEuropean = 1
KDateFormatJapanese = 2

KTimeFormat12Hour = 0
KTimeFormat24Hour = 1

KDaylightSavingZoneHome = 0
KDaylightSavingZoneEuropean = 1
KDaylightSavingZoneNorthern = 2
KDaylightSavingZoneSouthern = 4

KUnitsImperial = 0
KUnitsMetric = 1

KSwitchOffDisabled = 0
KSwitchOffEnabledOnBatteries = 1
KSwitchOffEnabledAlways = 2

KBacklightBehaviorTimed = 0
KBacklightBehaviorUntimed = 1

KRemoteLinkDisabled = 0
KRemoteLinkDisconnected = 1 
KRemoteLinkConnected = 2

KLinkTypeUnknown = 0
KLinkTypeCable = 1
KLinkTypeIrDA = 2

KLinkBpsUnknown = 0
KLinkBps9600 = 1
KLinkBps19200 = 2
KLinkBps38400 = 3
KLinkBps57600 = 4
KLinkBps115200 = 5

function SISystemVisible(stack, runtime) -- 1
    unimplemented("opx.systinfo.SISystemVisible")
end

function SIHiddenVisible(stack, runtime) -- 2
    unimplemented("opx.systinfo.SIHiddenVisible")
end

function SICurrencyFormat(stack, runtime) -- 3
    unimplemented("opx.systinfo.SICurrencyFormat")
end

function SIDateFormat(stack, runtime) -- 4
    local dateSep3 = stack:pop():asVariable(DataTypes.EWord)
    local dateSep2 = stack:pop():asVariable(DataTypes.EWord)
    local dateSep1 = stack:pop():asVariable(DataTypes.EWord)
    local dateSep0 = stack:pop():asVariable(DataTypes.EWord)
    local dateFormat = stack:pop():asVariable(DataTypes.ELong)

    dateFormat(KDateFormatEuropean)
    dateSep0(0)
    dateSep1(string.byte('/'))
    dateSep2(string.byte('/'))
    dateSep3(0)
    stack:push(0)
end

function SITimeFormat(stack, runtime) -- 5
    local ampmPos = stack:pop():asVariable(DataTypes.ELong)
    local ampmSpace = stack:pop():asVariable(DataTypes.ELong)
    local timeSep3 = stack:pop():asVariable(DataTypes.EWord)
    local timeSep2 = stack:pop():asVariable(DataTypes.EWord)
    local timeSep1 = stack:pop():asVariable(DataTypes.EWord)
    local timeSep0 = stack:pop():asVariable(DataTypes.EWord)
    local timeFmt = stack:pop():asVariable(DataTypes.ELong)

    timeFmt(runtime:LCClockFormat())
    timeSep0(0)
    timeSep1(string.byte(':'))
    timeSep2(string.byte(':'))
    timeSep3(0)
    ampmSpace(0)
    ampmPos(1)

    stack:push(0)
end

function SIUTCOffset(stack, runtime) -- 6
    unimplemented("opx.systinfo.SIUTCOffset")
end

function SIWorkday(stack, runtime) -- 7
    unimplemented("opx.systinfo.SIWorkday")
end

function SIDaylightSaving(stack, runtime) -- 8
    local zone = stack:pop()
    local result
    if zone == KDaylightSavingZoneHome then
        result = os.date("*t").isdst
    end
    if result == nil then
        result = false
    end
    stack:push(result)
end

function SIHomeCountry(stack, runtime) -- 9
    unimplemented("opx.systinfo.SIHomeCountry")
end

function SIUnits(stack, runtime) -- 10
    unimplemented("opx.systinfo.SIUnits")
end

function SIIsDirectory(stack, runtime) -- 11
    unimplemented("opx.systinfo.SIIsDirectory")
end

function SIVolumeName(stack, runtime) -- 12
    unimplemented("opx.systinfo.SIVolumeName")
end

function SIUniqueFilename(stack, runtime) -- 13
    unimplemented("opx.systinfo.SIUniqueFilename")
end

function SIBookmark(stack, runtime) -- 14
    unimplemented("opx.systinfo.SIBookmark")
end

function SIStandardFolder(stack, runtime) -- 15
    unimplemented("opx.systinfo.SIStandardFolder")
end

function SIDisplayContrast(stack, runtime) -- 16
    unimplemented("opx.systinfo.SIDisplayContrast")
end

function SIOwner(stack, runtime) -- 17
    unimplemented("opx.systinfo.SIOwner")
end

function SIBatteryVolts(stack, runtime) -- 18
    local backupMax = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local backupCur = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local mainMax = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local mainCur = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)

    mainCur(3300)
    mainMax(3300)
    backupCur(3100)
    backupMax(3100)
    stack:push(0)
end

function SIBatteryCurrent(stack, runtime) -- 19
    unimplemented("opx.systinfo.SIBatteryCurrent")
end

function SIMemory(stack, runtime) -- 20
    unimplemented("opx.systinfo.SIMemory")
end

function SIKeyClickEnabled(stack, runtime) -- 21
    stack:push(false)
end

function SIKeyClickLoud(stack, runtime) -- 22
    stack:push(false)
end

function SIKeyClickOverridden(stack, runtime) -- 23
    unimplemented("opx.systinfo.SIKeyClickOverridden")
end

function SIPointerClickEnabled(stack, runtime) -- 24
    stack:push(false)
end

function SIPointerClickLoud(stack, runtime) -- 25
    stack:push(false)
end

function SIBeepEnabled(stack, runtime) -- 26
    unimplemented("opx.systinfo.SIBeepEnabled")
end

function SIBeepLoud(stack, runtime) -- 27
    unimplemented("opx.systinfo.SIBeepLoud")
end

function SISoundDriverEnabled(stack, runtime) -- 28
    stack:push(true)
end

function SISoundDriverLoud(stack, runtime) -- 29
    stack:push(true) -- or false? Who knows?
end

function SISoundEnabled(stack, runtime) -- 30
    stack:push(true) -- All Sound, All The Time!
end

function SIAutoSwitchOffBehaviour(stack, runtime) -- 31
    stack:push(KSwitchOffDisabled)
end

function SIAutoSwitchOffTime(stack, runtime) -- 32
    unimplemented("opx.systinfo.SIAutoSwitchOffTime")
end

function SIBacklightBehaviour(stack, runtime) -- 33
    unimplemented("opx.systinfo.SIBacklightBehaviour")
end

function SIBacklightOnTime(stack, runtime) -- 34
    unimplemented("opx.systinfo.SIBacklightOnTime")
end

function SIDisplaySize(stack, runtime) -- 35
    local physicalHeight = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local physicalWidth = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local digitizerHeight = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local digitizerWidth = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local displayHeight = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local displayWidth = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)

    local w, h = runtime:getScreenInfo()
    digitizerWidth(w)
    digitizerHeight(h)
    displayWidth(w)
    displayHeight(h)
    -- I have no idea about these...
    physicalWidth(w)
    physicalHeight(h)

    stack:push(0)
end

function SIKeyboardIndex(stack, runtime) -- 36
    unimplemented("opx.systinfo.SIKeyboardIndex")
end

function SILanguageIndex(stack, runtime) -- 37
    unimplemented("opx.systinfo.SILanguageIndex")
end

function SIXYInputPresent(stack, runtime) -- 38
    unimplemented("opx.systinfo.SIXYInputPresent")
end

function SIKeyboardPresent(stack, runtime) -- 39
    unimplemented("opx.systinfo.SIKeyboardPresent")
end

function SIMaximumColors(stack, runtime) -- 40
    unimplemented("opx.systinfo.SIMaximumColors")
end

function SIProcessorClock(stack, runtime) -- 41
    unimplemented("opx.systinfo.SIProcessorClock")
end

function SISpeedFactor(stack, runtime) -- 42
    unimplemented("opx.systinfo.SISpeedFactor")
end

function SIMachine(stack, runtime) -- 43
    unimplemented("opx.systinfo.SIMachine")
end

function SIRemoteLinkStatus(stack, runtime) -- 44
    unimplemented("opx.systinfo.SIRemoteLinkStatus")
end

function SIRemoteLinkDisable(stack, runtime) -- 45
    unimplemented("opx.systinfo.SIRemoteLinkDisable")
end

function SIIsPathVisible(stack, runtime) -- 46
    unimplemented("opx.systinfo.SIIsPathVisible")
end

function SIRemoteLinkEnable(stack, runtime) -- 47
    unimplemented("opx.systinfo.SIRemoteLinkEnable")
end

function SIPWIsEnabled(stack, runtime) -- 48
    stack:push(false)
end

function SIPWSetEnabled(stack, runtime) -- 49
    unimplemented("opx.systinfo.SIPWSetEnabled")
end

function SIPWIsValid(stack, runtime) -- 50
    unimplemented("opx.systinfo.SIPWIsValid")
end

function SIPWSet(stack, runtime) -- 51
    unimplemented("opx.systinfo.SIPWSet")
end

function SILedSet(stack, runtime) -- 52
    unimplemented("opx.systinfo.SILedSet")
end

function SIRemoteLinkEnableWithOptions(stack, runtime) -- 53
    unimplemented("opx.systinfo.SIRemoteLinkEnableWithOptions")
end

function SIRemoteLinkConfig(stack, runtime) -- 54
    unimplemented("opx.systinfo.SIRemoteLinkConfig")
end

return _ENV
