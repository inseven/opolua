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

fns = {
    [1] = "DTNewDateTime",
    [2] = "DTDeleteDateTime",
    [3] = "DTYear",
    [4] = "DTMonth",
    [5] = "DTDay",
    [6] = "DTHour",
    [7] = "DTMinute",
    [8] = "DTSecond",
    [9] = "DTMicro",
    [10] = "DTSetYear",
    [11] = "DTSetMonth",
    [12] = "DTSetDay",
    [13] = "DTSetHour",
    [14] = "DTSetMinute",
    [15] = "DTSetSecond",
    [16] = "DTSetMicro",
    [17] = "DTNow",
    [18] = "DTDateTimeDiff",
    [19] = "DTYearsDiff",
    [20] = "DTMonthsDiff",
    [21] = "DTDaysDiff",
    [22] = "DTHoursDiff",
    [23] = "DTMinutesDiff",
    [24] = "DTSecsDiff",
    [25] = "DTMicrosDiff",
    [26] = "DTWeekNoInYear",
    [27] = "DTDayNoInYear",
    [28] = "DTDayNoInWeek",
    [29] = "DTDaysInMonth",
    [30] = "DTSetHomeTime",
    [31] = "LCCountryCode",
    [32] = "LCDecimalSeparator",
    [33] = "LCSetClockFormat",
    [34] = "LCClockFormat",
    [35] = "LCStartOfWeek",
    [36] = "LCThousandsSeparator",
}

handles = {}

local function popTimeFromStack(stack)
    local t = assert(handles[stack:pop()], "Bad date/time handle")
    return t
end

function setDate(handle, val)
    assert(handles[handle], "Bad date/time handle!")
    handles[handle] = val
end

function DTNewDateTime(stack, runtime) -- 1
    local micro = stack:pop()
    local sec = stack:pop()
    local min = stack:pop()
    local hour = stack:pop()
    local day = stack:pop()
    local month = stack:pop()
    local year = stack:pop()
    local tt = {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    }
    local t = os.time(tt) + (micro / 1000000)
    local h = #handles + 1
    handles[h] = t
    stack:push(h)
end

function DTDeleteDateTime(stack, runtime) -- 2
    handles[stack:pop()] = nil
    stack:push(0)
end

function DTYear(stack, runtime) -- 3
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).year)
end

function DTMonth(stack, runtime) -- 4
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).month)
end

function DTDay(stack, runtime) -- 5
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).day)
end

function DTHour(stack, runtime) -- 6
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).hour)
end

function DTMinute(stack, runtime) -- 7
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).min)
end

function DTSecond(stack, runtime) -- 8
    local t = popTimeFromStack(stack)
    stack:push(os.date("*t", math.floor(t)).sec)
end

function DTMicro(stack, runtime) -- 9
    local t = popTimeFromStack(stack)
    local _, micro = math.modf(t)
    micro = math.floor(micro * 1000000)
    stack:push(micro)
end

function DTSetYear(stack, runtime) -- 10
    unimplemented("opx.date.DTSetYear")
end

function DTSetMonth(stack, runtime) -- 11
    unimplemented("opx.date.DTSetMonth")
end

function DTSetDay(stack, runtime) -- 12
    unimplemented("opx.date.DTSetDay")
end

function DTSetHour(stack, runtime) -- 13
    unimplemented("opx.date.DTSetHour")
end

function DTSetMinute(stack, runtime) -- 14
    unimplemented("opx.date.DTSetMinute")
end

function DTSetSecond(stack, runtime) -- 15
    unimplemented("opx.date.DTSetSecond")
end

function DTSetMicro(stack, runtime) -- 16
    unimplemented("opx.date.DTSetMicro")
end

function DTNow(stack, runtime) -- 17
    local h = #handles + 1
    local t = runtime:iohandler().getTime()
    handles[h] = t
    stack:push(h)
end

function DTDateTimeDiff(stack, runtime) -- 18
    unimplemented("opx.date.DTDateTimeDiff")
end

function DTYearsDiff(stack, runtime) -- 19
    unimplemented("opx.date.DTYearsDiff")
end

function DTMonthsDiff(stack, runtime) -- 20
    unimplemented("opx.date.DTMonthsDiff")
end

function DTDaysDiff(stack, runtime) -- 21
    unimplemented("opx.date.DTDaysDiff")
end

function DTHoursDiff(stack, runtime) -- 22
    unimplemented("opx.date.DTHoursDiff")
end

function DTMinutesDiff(stack, runtime) -- 23
    unimplemented("opx.date.DTMinutesDiff")
end

function DTSecsDiff(stack, runtime) -- 24
    local endt = popTimeFromStack(stack)
    local startt = popTimeFromStack(stack)
    local diff = endt - startt
    stack:push(toint32(math.floor(diff)))
end

function DTMicrosDiff(stack, runtime) -- 25
    local endt = popTimeFromStack(stack)
    local startt = popTimeFromStack(stack)
    local diff = endt - startt
    stack:push(toint32(math.floor(diff * 1000000)))
end

function DTWeekNoInYear(stack, runtime) -- 26
    unimplemented("opx.date.DTWeekNoInYear")
end

function DTDayNoInYear(stack, runtime) -- 27
    unimplemented("opx.date.DTDayNoInYear")
end

function DTDayNoInWeek(stack, runtime) -- 28
    unimplemented("opx.date.DTDayNoInWeek")
end

function DTDaysInMonth(stack, runtime) -- 29
    unimplemented("opx.date.DTDaysInMonth")
end

function DTSetHomeTime(stack, runtime) -- 30
    unimplemented("opx.date.DTSetHomeTime")
end

function LCCountryCode(stack, runtime) -- 31
    stack:push(44) -- This is supposed to be the dialling prefix? So +44 for UK?
end

function LCDecimalSeparator(stack, runtime) -- 32
    stack:push(".")
end

function LCSetClockFormat(stack, runtime) -- 33
    local fmt = stack:pop()
    runtime:LCSetClockFormat(fmt)
    stack:push(0)
end

function LCClockFormat(stack, runtime) -- 34
    local fmt = runtime:LCClockFormat()
    stack:push(fmt)
end

function LCStartOfWeek(stack, runtime) -- 35
    unimplemented("opx.date.LCStartOfWeek")
end

function LCThousandsSeparator(stack, runtime) -- 36
    stack:push("")
end

return _ENV
