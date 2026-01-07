--[[

Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe

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
    [1] = "AlmSetClockAlarm",
    [2] = "AlmAlarmState",
    [3] = "AlmAlarmEnable",
    [4] = "AlmAlarmDelete",
    [5] = "AlmQuietPeriodCancel",
    [6] = "AlmQuietPeriodUntil",
    [7] = "AlmQuietPeriodSet",
    [8] = "AlmSetAlarmSound",
    [9] = "AlmAlarmSoundState",
    [10] = "WldFindCity",
    [11] = "WldSunlight",
    [12] = "WldHome",
    [13] = "WldPreviousCity",
    [14] = "WldPreviousCountry",
    [15] = "WldNextCity",
    [16] = "WldNextCountry",
    [17] = "WldAddCity",
    [18] = "WldAddCountry",
    [19] = "WldEditCity",
    [20] = "WldEditCountry",
    [21] = "WldDeleteCity",
    [22] = "WldDeleteCountry",
    [23] = "WldNumberOfCities",
    [24] = "WldNumberOfCountries",
    [25] = "WldDataFileSave",
    [26] = "WldDataFileRevert",
}

local KAlarmNotSet = 0
local KAlarmSet = 1
local KAlarmDisabled = 2

function AlmSetClockAlarm(stack, runtime) -- 1
    unimplemented("opx.alarm.AlmSetClockAlarm")
end

function AlmAlarmState(stack, runtime) -- 2
    local alarmNumber = stack:pop()
    stack:push(KAlarmNotSet)
end

function AlmAlarmEnable(stack, runtime) -- 3
    unimplemented("opx.alarm.AlmAlarmEnable")
end

function AlmAlarmDelete(stack, runtime) -- 4
    unimplemented("opx.alarm.AlmAlarmDelete")
end

function AlmQuietPeriodCancel(stack, runtime) -- 5
    unimplemented("opx.alarm.AlmQuietPeriodCancel")
end

function AlmQuietPeriodUntil(stack, runtime) -- 6
    unimplemented("opx.alarm.AlmQuietPeriodUntil")
end

function AlmQuietPeriodSet(stack, runtime) -- 7
    unimplemented("opx.alarm.AlmQuietPeriodSet")
end

function AlmSetAlarmSound(stack, runtime) -- 8
    unimplemented("opx.alarm.AlmSetAlarmSound")
end

function AlmAlarmSoundState(stack, runtime) -- 9
    unimplemented("opx.alarm.AlmAlarmSoundState")
end

function WldFindCity(stack, runtime) -- 10
    unimplemented("opx.alarm.WldFindCity")
end

function WldSunlight(stack, runtime) -- 11
    unimplemented("opx.alarm.WldSunlight")
end

function WldHome(stack, runtime) -- 12
    unimplemented("opx.alarm.WldHome")
end

function WldPreviousCity(stack, runtime) -- 13
    unimplemented("opx.alarm.WldPreviousCity")
end

function WldPreviousCountry(stack, runtime) -- 14
    unimplemented("opx.alarm.WldPreviousCountry")
end

function WldNextCity(stack, runtime) -- 15
    unimplemented("opx.alarm.WldNextCity")
end

function WldNextCountry(stack, runtime) -- 16
    unimplemented("opx.alarm.WldNextCountry")
end

function WldAddCity(stack, runtime) -- 17
    unimplemented("opx.alarm.WldAddCity")
end

function WldAddCountry(stack, runtime) -- 18
    unimplemented("opx.alarm.WldAddCountry")
end

function WldEditCity(stack, runtime) -- 19
    unimplemented("opx.alarm.WldEditCity")
end

function WldEditCountry(stack, runtime) -- 20
    unimplemented("opx.alarm.WldEditCountry")
end

function WldDeleteCity(stack, runtime) -- 21
    unimplemented("opx.alarm.WldDeleteCity")
end

function WldDeleteCountry(stack, runtime) -- 22
    unimplemented("opx.alarm.WldDeleteCountry")
end

function WldNumberOfCities(stack, runtime) -- 23
    unimplemented("opx.alarm.WldNumberOfCities")
end

function WldNumberOfCountries(stack, runtime) -- 24
    unimplemented("opx.alarm.WldNumberOfCountries")
end

function WldDataFileSave(stack, runtime) -- 25
    unimplemented("opx.alarm.WldDataFileSave")
end

function WldDataFileRevert(stack, runtime) -- 26
    unimplemented("opx.alarm.WldDataFileRevert")
end

return _ENV
