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

local function numParams_dump(runtime)
    local numParams = runtime:IP8()
    return fmt(" numParams=%d", numParams)
end

function IP8_dump(runtime)
    local val = runtime:IP8()
    return fmt("%d (0x%02X)", val, val)
end

function Addr(stack, runtime) -- 0x00
    local var = stack:pop()
    stack:push(var:addressOf())
end

function IllegalFuncOpCode(stack, runtime)
    error(KOplErrIllegal)
end

function Asc(stack, runtime) -- 0x01
    stack:push(string.byte(stack:pop()))
end

function Count(stack, runtime) -- 0x03
    local db = runtime:getDb()
    stack:push(db:getCount())
end

function Day(stack, runtime) -- 0x04
    stack:push(os.date("*t").day)
end

function Dow(stack, runtime) -- 0x05
    error("Unimplemented function Dow!")
end

function Eof(stack, runtime) -- 0x06
    local db = runtime:getDb()
    stack:push(db:eof())
end

function Err(stack, runtime) -- 0x07
    stack:push(runtime:getLastError())
end

function Exist(stack, runtime) -- 0x08
    local path = stack:pop()
    local ret = runtime:iohandler().fsop("exists", path)
    stack:push(ret == KOplErrExists)
end

function Find(stack, runtime) -- 0x09
    error("Unimplemented function Find!")
end

function Get(stack, runtime) -- 0x0A
    stack:push(runtime:GET())
end

function Ioa(stack, runtime) -- 0x0B
    error("Unimplemented function Ioa!")
end

function Iow(stack, runtime) -- 0x0C
    error("Unimplemented function Iow!")
end

function IoOpen(stack, runtime) -- 0x0D
    local mode = stack:pop()
    local name = stack:pop()
    local handleVar = stack:pop():dereference()

    local handle, err = runtime:IOOPEN(name, mode)
    if handle then
        handleVar(handle)
        stack:push(0)
    else
        handleVar(-1) -- Just in case
        stack:push(err)
    end
end

function IoWrite(stack, runtime) -- 0x0E
    local len = stack:pop()
    local addr = stack:pop()
    local h = stack:pop()
    local data = addr:read(len)
    local err = runtime:IOWRITE(h, data)
    stack:push(err)
end

function IoRead(stack, runtime) -- 0x0F
    local maxLen = stack:pop()
    local addr = stack:pop()
    local h = stack:pop()
    local data, err = runtime:IOREAD(h, maxLen)

    if data then
        addr:write(data)
    end

    if err then
        stack:push(err)
    else
        stack:push(#data)
    end
end

function IoClose(stack, runtime) -- 0x10
    stack:push(runtime:IOCLOSE(stack:pop()))
end

function IoWait(stack, runtime) -- 0x11
    runtime:waitForAnyRequest()
    stack:push(0)
end

function Hour(stack, runtime) -- 0x12
    stack:push(os.date("*t").hour)
end

function Key(stack, runtime) -- 0x13
    stack:push(runtime:KEY())
end

function Len(stack, runtime) -- 0x14
    stack:push(#stack:pop())
end

function Loc(stack, runtime) -- 0x15
    local searchString = stack:pop():lower()
    local str = stack:pop():lower()
    local result = string.find(str, searchString, 1, true) or 0
    stack:push(result)
end

function Minute(stack, runtime) -- 0x16
    stack:push(os.date("*t").min)
end

function Month(stack, runtime) -- 0x17
    stack:push(os.date("*t").month)
end

function PeekB(stack, runtime) -- 0x18
    local addr = stack:pop()
    local data = addr:read(1)
    stack:push(string.unpack("b", data))
end

function PeekW(stack, runtime) -- 0x19
    error("Unimplemented function PeekW!")
end

function Pos(stack, runtime) -- 0x1A
    local db = runtime:getDb()
    stack:push(db:getPos())
end

function Second(stack, runtime) -- 0x1C
    stack:push(os.date("*t").sec)
end

function Year(stack, runtime) -- 0x1E
    stack:push(os.date("*t").year)
end

function SAddr(stack, runtime) -- 0x1F
    local str = stack:pop()
    assert(str:type() == DataTypes.EString, "Bad variable type passed to SAddr")
    stack:push(str:addressOf())
end

function Week(stack, runtime) -- 0x20
    error("Unimplemented function Week!")
end

function IoSeek(stack, runtime) -- 0x21
    local offsetVar = stack:pop():dereference()
    local mode = stack:pop()
    local handle = stack:pop()
    local err, result = runtime:IOSEEK(handle, mode, offsetVar())
    if result then
        offsetVar(result)
    end
    stack:push(err)
end

function Kmod(stack, runtime) -- 0x22
    error("Unimplemented function Kmod!")
end

function KeyA(stack, runtime) -- 0x23
    error("Unimplemented function KeyA!")
end

function KeyC(stack, runtime) -- 0x24
    error("Unimplemented function KeyC!")
end

function IoOpenUnique(stack, runtime) -- 0x25
    local mode = stack:pop()
    local nameVar = stack:pop():dereference()
    local handleVar = stack:pop():dereference()

    local handle, err, name = runtime:IOOPEN(nameVar(), mode)
    if handle then
        handleVar(handle)
        if name then
            nameVar(name)
        end
        stack:push(0)
    else
        handleVar(-1) -- Just in case
        stack:push(err)
    end
end

function gCreate(stack, runtime) -- 0x26
    stack:push(0)
    gCreateEnhanced(stack, runtime)
end

function gCreateBit(stack, runtime) -- 0x27
    local mode = 0
    if runtime:IP8() == 3 then
        mode = stack:pop()
    end
    local w, h = stack:popXY()
    local id = runtime:gCREATEBIT(w, h, mode)
    stack:push(id)
end

gCreateBit_dump = IP8_dump

function gLoadBit(stack, runtime) -- 0x28
    local numParams = runtime:IP8()
    local write = 1
    local idx = 0
    if numParams > 2 then
        idx = stack:pop()
    end
    if numParams > 1 then
        write = stack:pop()
    end
    local path = stack:pop()
    local id = runtime:gLOADBIT(path, write ~= 0, idx)
    stack:push(id)
end

gLoadBit_dump = numParams_dump

function gLoadFont(stack, runtime) -- 0x29
    error("Unimplemented function gLoadFont!")
end

function gRank(stack, runtime) -- 0x2A
    error("Unimplemented function gRank!")
end

function gIdentity(stack, runtime) -- 0x2B
    stack:push(runtime:gIDENTITY())
end

function gX(stack, runtime) -- 0x2C
    stack:push(runtime:gX())
end

function gY(stack, runtime) -- 0x2D
    stack:push(runtime:gY())
end

function gWidth(stack, runtime) -- 0x2E
    stack:push(runtime:gWIDTH())
end

function gHeight(stack, runtime) -- 0x2F
    stack:push(runtime:gHEIGHT())
end

function gOriginX(stack, runtime) -- 0x30
    error("Unimplemented function gOriginX!")
end

function gOriginY(stack, runtime) -- 0x31
    error("Unimplemented function gOriginY!")
end

function gTWidth(stack, runtime) -- 0x32
    local width = runtime:gTWIDTH(stack:pop())
    stack:push(width)
end

function gPrintClip(stack, runtime) -- 0x33
    error("Unimplemented function gPrintClip!")
end

function TestEvent(stack, runtime) -- 0x34
    error("Unimplemented function TestEvent!")
end

function Menu(stack, runtime) -- 0x36
    local menu = runtime:getMenu()
    runtime:setMenu(nil)
    local result = runtime:iohandler().menu(menu)
    stack:push(result)
end

function Dialog(stack, runtime) -- 0x37
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
    if result > 0 then
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

function Alert(stack, runtime) -- 0x38
    local nargs = runtime:IP8()
    local line1, line2, but1, but2, but3
    if nargs >= 5 then but3 = stack:pop() end
    if nargs >= 4 then but2 = stack:pop() end
    if nargs >= 3 then but1 = stack:pop() end
    if nargs >= 2 then line2 = stack:pop() end
    if nargs >= 1 then line1 = stack:pop() end

    local choice = runtime:iohandler().alert({line1, line2}, {but1, but2, but3})
    stack:push(choice)
end

Alert_dump = numParams_dump

function gCreateEnhanced(stack, runtime) -- 0x39
    local flags = stack:pop()
    local visible = stack:pop()
    local x, y, w, h = stack:popRect()
    local id = runtime:gCREATE(x, y, w, h, visible ~= 0, flags)
    stack:push(id)
end

function MenuWithMemory(stack, runtime) -- 0x3A
    local var = stack:pop():dereference()
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
    local year = stack:pop()
    local month = stack:pop()
    local day = stack:pop()
    local t = os.time({ year = year, month = month, day = day })
    -- Result needs to be days since 1900
    t = (t - getEpoch()) // (24 * 60 * 60)
    stack:push(t)
end

function IAbs(stack, runtime) -- 0x41
    error("Unimplemented function IAbs!")
end

function roundTowardsZero(val)
    if val > 0 then
        return math.floor(val)
    else
        return math.ceil(val)
    end
end

function roundToNearest(val)
    local int, frac = math.modf(val)
    if math.abs(frac) >= 0.5 then
        int = int + (int < 0 and -1 or 1)
    end
    return int
end

function IntLong(stack, runtime) -- 0x42
    local val = stack:pop()
    local result = roundTowardsZero(val)
    stack:push(result)
end

function PeekL(stack, runtime) -- 0x43
    error("Unimplemented function PeekL!")
end

function Space(stack, runtime) -- 0x44
    error("Unimplemented function Space!")
end

function DateToSecs(stack, runtime) -- 0x45
    error("Unimplemented function DateToSecs!")
end

function Alloc(stack, runtime) -- 0x4B
    error("Unimplemented function Alloc!")
end

function ReAlloc(stack, runtime) -- 0x4C
    error("Unimplemented function ReAlloc!")
end

function AdjustAlloc(stack, runtime) -- 0x4D
    error("Unimplemented function AdjustAlloc!")
end

function LenAlloc(stack, runtime) -- 0x4E
    error("Unimplemented function LenAlloc!")
end

function Ioc(stack, runtime) -- 0x4F
    error("Unimplemented function Ioc!")
end

function Uadd(stack, runtime) -- 0x50
    error("Unimplemented function Uadd!")
end

function Usub(stack, runtime) -- 0x51
    error("Unimplemented function Usub!")
end

function IoCancel(stack, runtime) -- 0x52
    error("Unimplemented function IoCancel!")
end

function FindField(stack, runtime) -- 0x54
    error("Unimplemented function FindField!")
end

function Bookmark(stack, runtime) -- 0x55
    error("Unimplemented function Bookmark!")
end

function GetEventC(stack, runtime) -- 0x56
    local stat = stack:pop():dereference()
    runtime:iohandler().cancelRequest(stat)
    -- Unlike IoCancel, GetEventC should do its own waitForRequest.
    runtime:waitForRequest(stat)
    stack:push(0) -- why these return something, who knows
end

function InTrans(stack, runtime) -- 0x57
    error("Unimplemented function InTrans!")
end

function mPopup(stack, runtime) -- 0x58
    error("Unimplemented function mPopup!")
end

function Abs(stack, runtime) -- 0x80
    stack:push(math.abs(stack:pop()))
end

function ACos(stack, runtime) -- 0x81
    stack:push(math.acos(stack:pop()))
end

function ASin(stack, runtime) -- 0x82
    stack:push(math.asin(stack:pop()))
end

function ATan(stack, runtime) -- 0x83
    stack:push(math.atan(stack:pop()))
end

function Cos(stack, runtime) -- 0x84
    stack:push(math.cos(stack:pop())) 
end

function Deg(stack, runtime) -- 0x85
    stack:push(math.deg(stack:pop()))
end

function Exp(stack, runtime) -- 0x86
    stack:push(math.exp(stack:pop()))
end

function Flt(stack, runtime) -- 0x87
    -- Nothing needed, numbers are numbers
end

function Intf(stack, runtime) -- 0x88
    return IntLong(stack, runtime) -- Same difference
end

function Ln(stack, runtime) -- 0x89
    stack:push(math.log(stack:pop()))
end

function Log(stack, runtime) -- 0x8A
    stack:push(math.log(stack:pop(), 10))
end

function PeekF(stack, runtime) -- 0x8B
    error("Unimplemented function PeekF!")
end

function Pi(stack, runtime) -- 0x8C
    stack:push(math.pi)
end

function Rad(stack, runtime) -- 0x8D
    stack:push(math.rad(stack:pop()))
end

function Rnd(stack, runtime) -- 0x8E
    stack:push(math.random())
end

function Sin(stack, runtime) -- 0x8F
    stack:push(math.sin(stack:pop())) 
end

function Sqr(stack, runtime) -- 0x90
    stack:push(math.sqrt(stack:pop()))
end

function Tan(stack, runtime) -- 0x91
    stack:push(math.tan(stack:pop())) 
end

function Val(stack, runtime) -- 0x92
    local result = tonumber(stack:pop())
    assert(result, KOplErrInvalidArgs)
    stack:push(result)
end

function Max(stack, runtime) -- 0x93
    error("Unimplemented function Max!")
end

function Mean(stack, runtime) -- 0x94
    error("Unimplemented function Mean!")
end

function Min(stack, runtime) -- 0x95
    error("Unimplemented function Min!")
end

function Std(stack, runtime) -- 0x96
    error("Unimplemented function Std!")
end

function Sum(stack, runtime) -- 0x97
    error("Unimplemented function Sum!")
end

function Var(stack, runtime) -- 0x98
    error("Unimplemented function Var!")
end

function Eval(stack, runtime) -- 0x99
    error("Unimplemented function Eval!")
end

function ChrStr(stack) -- 0xC0
    return stack:push(string.char(stack:pop()))
end

function DatimStr(stack, runtime) -- 0xC1
    error("Unimplemented function DatimStr!")
end

function DayNameStr(stack, runtime) -- 0xC2
    error("Unimplemented function DayNameStr!")
end

function DirStr(stack, runtime) -- 0xC3
    error("Unimplemented function DirStr!")
end

function ErrStr(stack, runtime) -- 0xC4
    local err = stack:pop()
    stack:push(Errors[err] or fmt("Unknown error %d", err))
end

function FixStr(stack, runtime) -- 0xC5
    error("Unimplemented function FixStr!")
end

function GenStr(stack, runtime) -- 0xC6
    local width = stack:pop()
    local val = fmt("%g", stack:pop())
    if #val > width then
        val = string.rep("*", width)
    end
    stack:push(val)
end

function GetStr(stack, runtime) -- 0xC7
    stack:push(runtime:GETSTR())
end

function HexStr(stack, runtime) -- 0xC8
    stack:push(fmt("%X", stack:pop()))
end

function KeyStr(stack, runtime) -- 0xC9
    stack:push(runtime:KEYSTR())
end

function LeftStr(stack, runtime) -- 0xCA
    local numChars = stack:pop()
    local str = stack:pop()
    stack:push(string.sub(str, 1, numChars))
end

function LowerStr(stack, runtime) -- 0xCB
    stack:push(stack:pop():lower())
end

function MidStr(stack, runtime) -- 0xCC
    local len = stack:pop()
    local offset = stack:pop()
    local str = stack:pop()
    assert(offset >= 1, KOplErrInvalidArgs)
    stack:push(str:sub(offset, offset + len - 1))
end

local months = {
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
}

function MonthStr(stack, runtime) -- 0xCD
    stack:push(assert(months[stack:pop()], KOplErrInvalidArgs))
end

function NumStr(stack, runtime) -- 0xCE
    local width = stack:pop()
    local intVal = roundToNearest(stack:pop())
    local result
    if width < 0 then
        result = fmt("%"..tostring(-width).."d", intVal)
    else
        result = tostring(intVal)
    end
    if #result > width then
        stack:push(string.rep("*", width))
    else
        stack:push(result)
    end
end

function PeekStr(stack, runtime) -- 0xCF
    error("Unimplemented function PeekStr!")
end

function ReptStr(stack, runtime) -- 0xD0
    local reps = stack:pop()
    local str = stack:pop()
    stack:push(string.rep(str, reps))
end

function RightStr(stack, runtime) -- 0xD1
    local numChars = stack:pop()
    local str = stack:pop()
    stack:push(string.sub(str, -numChars))
end

function SciStr(stack, runtime) -- 0xD2
    error("Unimplemented function SciStr!")
end

function UpperStr(stack, runtime) -- 0xD3
    stack:push(stack:pop():upper())
end

function WCmd(stack, runtime) -- 0xD5
    error("Unimplemented function WCmd!")
end

function CmdStr(stack, runtime) -- 0xD6
    local x = stack:pop()
    if x == 1 then
        stack:push(runtime:getPath())
    elseif x == 2 then
        local path = runtime:getPath()
        path = oplpath.join(oplpath.dirname(path), "SomeDoc.Wat")
        stack:push(path)
    elseif x == 3 then
        stack:push("R")
    else
        error("unhandle CMD$ param "..tostring(x))
    end
end

function ParseStr(stack, runtime) -- 0xD7
    local offsetsArrayAddr = stack:pop()
    local rel = stack:pop()
    local f = stack:pop()
    -- Wow this is a fun API

    rel = oplpath.abs(rel, runtime:getCwd())
    f = oplpath.abs(f, rel)

    -- Once f is complete, parse it to fill in offsetsArrayAddr
    local base, name = oplpath.split(f)
    local start, _ = oplpath.splitext(f)
    local nameNoExt, ext = oplpath.splitext(name)
    local nameHasWildcard = nameNoExt:match("%*") and 1 or 0
    local extHasWildcard = ext:match("%*") and 2 or 0
    local offsets = {
        1,
        1,
        3, -- Start of path will always be after the C:
        1 + #f - #name,
        1 + #start,
        nameHasWildcard | extHasWildcard,
    }
    offsetsArrayAddr:writeArray(offsets, DataTypes.EWord)
    stack:push(f)
end

function ErrxStr(stack, runtime) -- 0xD8
    local _, desc = runtime:getLastError()
    stack:push(desc)
end

function gPixel(stack, runtime) -- 0xDC
    error("Unimplemented function gPixel!")
end

function LocWithCase(stack, runtime) -- 0xDB
    error("Unimplemented function LocWithCase!")
end

function Size(stack, runtime) -- 0xDA
    error("Unimplemented function Size!")
end

function GetDocStr(stack, runtime) -- 0xD9
    error("Unimplemented function GetDocStr!")
end

return _ENV
