_ENV = module()

local fmt = string.format

codes = {
    [0x00] = "Addr",
    [0x01] = "Asc",
    [0x02] = "IllegalFuncOpCode",
    [0x03] = "Count",
    [0x04] = "Day",
    [0x05] = "Dow",
    [0x06] = "Eof",
    [0x07] = "Err",
    [0x08] = "Exist",
    [0x09] = "Find",
    [0x0A] = "Get",
    [0x0B] = "Ioa",
    [0x0C] = "Iow",
    [0x0D] = "IoOpen",
    [0x0E] = "IoWrite",
    [0x0F] = "IoRead",
    [0x10] = "IoClose",
    [0x11] = "IoWait",
    [0x12] = "Hour",
    [0x13] = "Key",
    [0x14] = "Len",
    [0x15] = "Loc",
    [0x16] = "Minute",
    [0x17] = "Month",
    [0x18] = "PeekB",
    [0x19] = "PeekW",
    [0x1A] = "Pos",
    [0x1B] = "IllegalFuncOpCode",
    [0x1C] = "Second",
    [0x1D] = "IllegalFuncOpCode",
    [0x1E] = "Year",
    [0x1F] = "SAddr",
    [0x20] = "Week",
    [0x21] = "IoSeek",
    [0x22] = "Kmod",
    [0x23] = "KeyA",
    [0x24] = "KeyC",
    [0x25] = "IoOpenUnique",
    [0x26] = "gCreate",
    [0x27] = "gCreateBit",
    [0x28] = "gLoadBit",
    [0x29] = "gLoadFont",
    [0x2A] = "gRank",
    [0x2B] = "gIdentity",
    [0x2C] = "gX",
    [0x2D] = "gY",
    [0x2E] = "gWidth",
    [0x2F] = "gHeight",
    [0x30] = "gOriginX",
    [0x31] = "gOriginY",
    [0x32] = "gTWidth",
    [0x33] = "gPrintClip",
    [0x34] = "TestEvent",
    [0x35] = "IllegalFuncOpCode",
    [0x36] = "Menu",
    [0x37] = "Dialog",
    [0x38] = "Alert",
    [0x39] = "gCreateEnhanced",
    [0x3A] = "MenuWithMemory",
    [0x3B] = "IllegalFuncOpCode",
    [0x3C] = "IllegalFuncOpCode",
    [0x3D] = "IllegalFuncOpCode",
    [0x3E] = "IllegalFuncOpCode",
    [0x3F] = "IllegalFuncOpCode",
    [0x40] = "Days",
    [0x41] = "IAbs",
    [0x42] = "IntLong",
    [0x43] = "PeekL",
    [0x44] = "Space",
    [0x45] = "DateToSecs",
    [0x46] = "IllegalFuncOpCode",
    [0x47] = "IllegalFuncOpCode",
    [0x48] = "IllegalFuncOpCode",
    [0x49] = "IllegalFuncOpCode",
    [0x4A] = "IllegalFuncOpCode",
    [0x4B] = "Alloc",
    [0x4C] = "ReAlloc",
    [0x4D] = "AdjustAlloc",
    [0x4E] = "LenAlloc",
    [0x4F] = "Ioc",
    [0x50] = "Uadd",
    [0x51] = "Usub",
    [0x52] = "IoCancel",
    [0x53] = "IllegalFuncOpCode",
    [0x54] = "FindField",
    [0x55] = "Bookmark",
    [0x56] = "GetEventC",
    [0x57] = "InTrans",
    [0x58] = "mPopup",
    [0x59] = "IllegalFuncOpCode",
    [0x5A] = "IllegalFuncOpCode",
    [0x5B] = "IllegalFuncOpCode",
    [0x5C] = "IllegalFuncOpCode",
    [0x5D] = "IllegalFuncOpCode",
    [0x5E] = "IllegalFuncOpCode",
    [0x5F] = "IllegalFuncOpCode",
    [0x60] = "IllegalFuncOpCode",
    [0x61] = "IllegalFuncOpCode",
    [0x62] = "IllegalFuncOpCode",
    [0x63] = "IllegalFuncOpCode",
    [0x64] = "IllegalFuncOpCode",
    [0x65] = "IllegalFuncOpCode",
    [0x66] = "IllegalFuncOpCode",
    [0x67] = "IllegalFuncOpCode",
    [0x68] = "IllegalFuncOpCode",
    [0x69] = "IllegalFuncOpCode",
    [0x6A] = "IllegalFuncOpCode",
    [0x6B] = "IllegalFuncOpCode",
    [0x6C] = "IllegalFuncOpCode",
    [0x6D] = "IllegalFuncOpCode",
    [0x6E] = "IllegalFuncOpCode",
    [0x6F] = "IllegalFuncOpCode",
    [0x70] = "IllegalFuncOpCode",
    [0x71] = "IllegalFuncOpCode",
    [0x72] = "IllegalFuncOpCode",
    [0x73] = "IllegalFuncOpCode",
    [0x74] = "IllegalFuncOpCode",
    [0x75] = "IllegalFuncOpCode",
    [0x76] = "IllegalFuncOpCode",
    [0x77] = "IllegalFuncOpCode",
    [0x78] = "IllegalFuncOpCode",
    [0x79] = "IllegalFuncOpCode",
    [0x7A] = "IllegalFuncOpCode",
    [0x7B] = "IllegalFuncOpCode",
    [0x7C] = "IllegalFuncOpCode",
    [0x7D] = "IllegalFuncOpCode",
    [0x7E] = "IllegalFuncOpCode",
    [0x7F] = "IllegalFuncOpCode",
    [0x80] = "Abs",
    [0x81] = "ACos",
    [0x82] = "ASin",
    [0x83] = "ATan",
    [0x84] = "Cos",
    [0x85] = "Deg",
    [0x86] = "Exp",
    [0x87] = "Flt",
    [0x88] = "Intf",
    [0x89] = "Ln",
    [0x8A] = "Log",
    [0x8B] = "PeekF",
    [0x8C] = "Pi",
    [0x8D] = "Rad",
    [0x8E] = "Rnd",
    [0x8F] = "Sin",
    [0x90] = "Sqr",
    [0x91] = "Tan",
    [0x92] = "Val",
    [0x93] = "Max",
    [0x94] = "Mean",
    [0x95] = "Min",
    [0x96] = "Std",
    [0x97] = "Sum",
    [0x98] = "Var",
    [0x99] = "Eval",
    [0x9A] = "IllegalFuncOpCode",
    [0x9B] = "IllegalFuncOpCode",
    [0x9C] = "IllegalFuncOpCode",
    [0x9D] = "IllegalFuncOpCode",
    [0x9E] = "IllegalFuncOpCode",
    [0x9F] = "IllegalFuncOpCode",
    [0xA0] = "IllegalFuncOpCode",
    [0xA1] = "IllegalFuncOpCode",
    [0xA2] = "IllegalFuncOpCode",
    [0xA3] = "IllegalFuncOpCode",
    [0xA4] = "IllegalFuncOpCode",
    [0xA5] = "IllegalFuncOpCode",
    [0xA6] = "IllegalFuncOpCode",
    [0xA7] = "IllegalFuncOpCode",
    [0xA8] = "IllegalFuncOpCode",
    [0xA9] = "IllegalFuncOpCode",
    [0xAA] = "IllegalFuncOpCode",
    [0xAB] = "IllegalFuncOpCode",
    [0xAC] = "IllegalFuncOpCode",
    [0xAD] = "IllegalFuncOpCode",
    [0xAE] = "IllegalFuncOpCode",
    [0xAF] = "IllegalFuncOpCode",
    [0xB0] = "IllegalFuncOpCode",
    [0xB1] = "IllegalFuncOpCode",
    [0xB2] = "IllegalFuncOpCode",
    [0xB3] = "IllegalFuncOpCode",
    [0xB4] = "IllegalFuncOpCode",
    [0xB5] = "IllegalFuncOpCode",
    [0xB6] = "IllegalFuncOpCode",
    [0xB7] = "IllegalFuncOpCode",
    [0xB8] = "IllegalFuncOpCode",
    [0xB9] = "IllegalFuncOpCode",
    [0xBA] = "IllegalFuncOpCode",
    [0xBB] = "IllegalFuncOpCode",
    [0xBC] = "IllegalFuncOpCode",
    [0xBD] = "IllegalFuncOpCode",
    [0xBE] = "IllegalFuncOpCode",
    [0xBF] = "IllegalFuncOpCode",
    [0xC0] = "ChrStr",
    [0xC1] = "DatimStr",
    [0xC2] = "DayNameStr",
    [0xC3] = "DirStr",
    [0xC4] = "ErrStr",
    [0xC5] = "FixStr",
    [0xC6] = "GenStr",
    [0xC7] = "GetStr",
    [0xC8] = "HexStr",
    [0xC9] = "KeyStr",
    [0xCA] = "LeftStr",
    [0xCB] = "LowerStr",
    [0xCC] = "MidStr",
    [0xCD] = "MonthStr",
    [0xCE] = "NumStr",
    [0xCF] = "PeekStr",
    [0xD0] = "ReptStr",
    [0xD1] = "RightStr",
    [0xD2] = "SciStr",
    [0xD3] = "UpperStr",
    [0xD4] = "IllegalFuncOpCode",
    [0xD5] = "WCmd",
    [0xD6] = "CmdStr",
    [0xD7] = "ParseStr",
    [0xD8] = "ErrxStr",
    [0xD9] = "GetDocStr",
    [0xDA] = "Size",
    [0xDB] = "LocWithCase",
    [0xDC] = "gPixel",
    [0xDD] = "IllegalFuncOpCode",
    [0xDE] = "IllegalFuncOpCode",
    [0xDF] = "IllegalFuncOpCode",
}

function Addr(stack, runtime) -- 0x00
    -- We only support Addr followed immediately by MenuWithMemory call (because
    -- supporting general-purpose Addr is a pita)
    if stack then
        local nextOp = runtime:IP8()
        local nextFn = runtime:IP8()
        assert(nextOp == 0x57 and codes[nextFn] == "MenuWithMemory",
            "Addr fncalls are not supported except as part of MENU()")
        AddrPlusMenuWithMemory(stack, runtime)
    end
end

function Day(stack, runtime) -- 0x04
    if stack then
        stack:push(os.date("*t").day)
    end
end

function Err(stack, runtime) -- 0x07
    if stack then
        stack:push(runtime:getLastError())
    end
end

function Get(stack, runtime) -- 0x0A
    if stack then
        stack:push(runtime:iohandler().getch())
    end
end

function Hour(stack, runtime) -- 0x12
    if stack then
        stack:push(os.date("*t").hour)
    end
end

function Minute(stack, runtime) -- 0x16
    if stack then
        stack:push(os.date("*t").min)
    end
end

function Month(stack, runtime) -- 0x17
    if stack then
        stack:push(os.date("*t").month)
    end
end

function Second(stack, runtime) -- 0x1C
    if stack then
        stack:push(os.date("*t").sec)
    end
end

function Year(stack, runtime) -- 0x1E
    if stack then
        stack:push(os.date("*t").year)
    end
end

function gIdentity(stack, runtime) -- 0x2B
    if stack then
        stack:push(runtime:getGraphics().current.id)
    end
end

function gX(stack, runtime) -- 0x2C
    if stack then
        stack:push(runtime:getGraphics().current.pos.x)
    end
end

function gY(stack, runtime) -- 0x2D
    if stack then
        stack:push(runtime:getGraphics().current.pos.y)
    end
end

function gWidth(stack, runtime) -- 0x2E
    if stack then
        stack:push(runtime:getGraphics().current.width)
    end
end

function gHeight(stack, runtime) -- 0x2F
    if stack then
        stack:push(runtime:getGraphics().current.height)
    end
end

function Menu(stack, runtime) -- 0x36
    local menu = runtime:getMenu()
    runtime:setMenu(nil)
    local result = runtime:iohandler().menu(menu)
    stack:push(result)
end

function Dialog(stack, runtime) -- 0x37
    if stack then
        local dialog = runtime:getDialog()
        runtime:setDialog(nil)
        local varMap = {} -- maps dialog item to variable
        for _, item in ipairs(dialog.items) do
            if item.variable ~= nil then
                varMap[item] = item.variable
                item.variable = nil -- Don't expose this to iohandler
            end
        end
        local result = runtime:iohandler().dialog(dialog)
        if result ~= 0 then
            -- Assign any variables eg `dCHOICE choice%`
            for item, var in pairs(varMap) do
                if item.value then
                    -- Have to reconstruct type because item.value will always be a string
                    -- (But the type of var() will still be correct)
                    local isnum = type(var()) == "number"
                    if isnum then
                        item.value = tonumber(item.value)
                    end
                    var(item.value)
                end
            end
        end
        stack:push(result)
    end
end

function Alert(stack, runtime) -- 0x38
    local nargs = runtime:IP8()
    if stack then
        local line1, line2, but1, but2, but3
        if nargs >= 5 then but3 = stack:pop() end
        if nargs >= 4 then but2 = stack:pop() end
        if nargs >= 3 then but1 = stack:pop() end
        if nargs >= 2 then line2 = stack:pop() end
        if nargs >= 1 then line1 = stack:pop() end

        local choice = runtime:iohandler().alert({line1, line2}, {but1, but2, but3})
        stack:push(choice)
    else
        return fmt(" nargs=%d", nargs)
    end
end

function MenuWithMemory(stack, runtime) -- 0x3A
    if stack then
        -- This should've been picked up by Addr and translated into a AddrPlusMenuWithMemory call
        error("Unexpected MenuWithMemory fncall!")
    end
end

function AddrPlusMenuWithMemory(stack, runtime)
    local var = stack:pop() -- The highlighted item
    local menu = runtime:getMenu()
    runtime:setMenu(nil)
    menu.highlight = var()
    local selected, highlighted = runtime:iohandler().menu(menu)
    var(highlighted) -- Update this
    stack:push(selected)
end

local epoch
local function getEpoch()
    if not epoch then
        epoch = os.time({ year = 1900, month = 1, day = 1 })
    end
    return epoch
end

function Days(stack, runtime) -- 0x37
    if stack then
        local year = stack:pop()
        local month = stack:pop()
        local day = stack:pop()
        local t = os.time({ year = year, month = month, day = day })
        -- Result needs to be days since 1900
        t = (t - getEpoch()) // (24 * 60 * 60)
        stack:push(t)
    end
end

function IntLong(stack, runtime) -- 0x42
    -- Nothing needed
end

function Abs(stack, runtime) -- 0x80
    if stack then

    end
end

function ACos(stack, runtime) -- 0x81
    if stack then

    end
end

function ASin(stack, runtime) -- 0x82
    if stack then

    end
end

function ATan(stack, runtime) -- 0x83
    if stack then

    end
end

function Cos(stack, runtime) -- 0x84
    if stack then
        stack:push(math.cos(stack:pop())) 
    end
end

function Deg(stack, runtime) -- 0x85
    if stack then

    end
end

function Exp(stack, runtime) -- 0x86
    if stack then

    end
end

function Flt(stack, runtime) -- 0x87
    if stack then

    end
end

function Intf(stack, runtime) -- 0x88
    if stack then

    end
end

function Ln(stack, runtime) -- 0x89
    if stack then

    end
end

function Log(stack, runtime) -- 0x8A
    if stack then

    end
end

function PeekF(stack, runtime) -- 0x8B
    if stack then

    end
end

function Pi(stack, runtime) -- 0x8C
    if stack then
        stack:push(math.pi)
    end
end

function Rad(stack, runtime) -- 0x8D
    if stack then

    end
end

function Rnd(stack, runtime) -- 0x8E
    if stack then

    end
end

function Sin(stack, runtime) -- 0x8F
    if stack then
        stack:push(math.sin(stack:pop())) 
    end
end

function Sqr(stack, runtime) -- 0x90
    if stack then

    end
end

function Tan(stack, runtime) -- 0x91
    if stack then
        stack:push(math.tan(stack:pop())) 
    end
end

function ChrStr(stack) -- 0xC0
    if stack then
        return stack:push(string.char(stack:pop()))
    end
end

function ErrStr(stack, runtime) -- 0xC4
    if stack then
        local err = stack:pop()
        stack:push(Errors[err] or fmt("Unknown error %d", err))
    end
end

function ErrxStr(stack, runtime) -- 0xD8
    if stack then
        local _, desc = runtime:getLastError()
        stack:push(desc)
    end
end

return _ENV
