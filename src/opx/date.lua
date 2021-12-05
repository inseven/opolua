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
    [31] = "DTFileTime",
    [32] = "DTSetFileTime",
    [33] = "DTIsLeapYear",
}

handles = {}

function DTNewDateTime(stack, runtime) -- 1
    error("Unimplemented date.opx function DTNewDateTime!")
end

function DTDeleteDateTime(stack, runtime) -- 2
    handles[stack:pop()] = nil
end

function DTYear(stack, runtime) -- 3
    error("Unimplemented date.opx function DTYear!")
end

function DTMonth(stack, runtime) -- 4
    error("Unimplemented date.opx function DTMonth!")
end

function DTDay(stack, runtime) -- 5
    error("Unimplemented date.opx function DTDay!")
end

function DTHour(stack, runtime) -- 6
    error("Unimplemented date.opx function DTHour!")
end

function DTMinute(stack, runtime) -- 7
    error("Unimplemented date.opx function DTMinute!")
end

function DTSecond(stack, runtime) -- 8
    error("Unimplemented date.opx function DTSecond!")
end

function DTMicro(stack, runtime) -- 9
    error("Unimplemented date.opx function DTMicro!")
end

function DTSetYear(stack, runtime) -- 10
    error("Unimplemented date.opx function DTSetYear!")
end

function DTSetMonth(stack, runtime) -- 11
    error("Unimplemented date.opx function DTSetMonth!")
end

function DTSetDay(stack, runtime) -- 12
    error("Unimplemented date.opx function DTSetDay!")
end

function DTSetHour(stack, runtime) -- 13
    error("Unimplemented date.opx function DTSetHour!")
end

function DTSetMinute(stack, runtime) -- 14
    error("Unimplemented date.opx function DTSetMinute!")
end

function DTSetSecond(stack, runtime) -- 15
    error("Unimplemented date.opx function DTSetSecond!")
end

function DTSetMicro(stack, runtime) -- 16
    error("Unimplemented date.opx function DTSetMicro!")
end

function DTNow(stack, runtime) -- 17
    local h = #handles + 1
    local t = runtime:iohandler().getTime()
    handles[h] = t
    stack:push(h)
end

function DTDateTimeDiff(stack, runtime) -- 18
    error("Unimplemented date.opx function DTDateTimeDiff!")
end

function DTYearsDiff(stack, runtime) -- 19
    error("Unimplemented date.opx function DTYearsDiff!")
end

function DTMonthsDiff(stack, runtime) -- 20
    error("Unimplemented date.opx function DTMonthsDiff!")
end

function DTDaysDiff(stack, runtime) -- 21
    error("Unimplemented date.opx function DTDaysDiff!")
end

function DTHoursDiff(stack, runtime) -- 22
    error("Unimplemented date.opx function DTHoursDiff!")
end

function DTMinutesDiff(stack, runtime) -- 23
    error("Unimplemented date.opx function DTMinutesDiff!")
end

function DTSecsDiff(stack, runtime) -- 24
    error("Unimplemented date.opx function DTSecsDiff!")
end

function DTMicrosDiff(stack, runtime) -- 25
    local endh = stack:pop()
    local starth = stack:pop()
    local diff = handles[endh] - handles[starth]
    stack:push(math.floor(diff * 1000000))
end

function DTWeekNoInYear(stack, runtime) -- 26
    error("Unimplemented date.opx function DTWeekNoInYear!")
end

function DTDayNoInYear(stack, runtime) -- 27
    error("Unimplemented date.opx function DTDayNoInYear!")
end

function DTDayNoInWeek(stack, runtime) -- 28
    error("Unimplemented date.opx function DTDayNoInWeek!")
end

function DTDaysInMonth(stack, runtime) -- 29
    error("Unimplemented date.opx function DTDaysInMonth!")
end

function DTSetHomeTime(stack, runtime) -- 30
    error("Unimplemented date.opx function DTSetHomeTime!")
end

function DTFileTime(stack, runtime) -- 31
    error("Unimplemented date.opx function DTFileTime!")
end

function DTSetFileTime(stack, runtime) -- 32
    error("Unimplemented date.opx function DTSetFileTime!")
end

function DTIsLeapYear(stack, runtime) -- 33
    error("Unimplemented date.opx function DTIsLeapYear!")
end

return _ENV