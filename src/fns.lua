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

local fmt = string.format

local sibosyscalls

codes_er5 = {
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

codes_sibo = setmetatable({
    [0x02] = "Call",
    [0x1D] = "Usr",
    [0x35] = "Os",
    [0xD9] = "IllegalFuncOpCode",
    [0xDA] = "IllegalFuncOpCode",
    [0xDB] = "IllegalFuncOpCode",
    [0xDC] = "IllegalFuncOpCode",
}, { __index = codes_er5 })

local function numParams_dump(runtime)
    local numParams = runtime:IP8()
    return fmt(" numParams=%d", numParams)
end

function Addr(stack, runtime) -- 0x00
    local var = stack:pop()
    stack:push(var:addressOf())
end

function IllegalFuncOpCode(stack, runtime)
    printf("Illegal func opcode at:\n%s\n", runtime:getOpoStacktrace())
    error(KErrIllegal)
end

function Asc(stack, runtime) -- 0x01
    local str = stack:pop()
    if #str == 0 then
        stack:push(0)
    else
        stack:push(string.byte(str))
    end
end

function Call(stack, runtime) -- 0x02 (SIBO only)
    local numParams = runtime:IP8()
    local s, bx, cx, dx, si, di
    assert(numParams >= 1 and numParams <= 6, "Unexpected numParams in call!")
    if numParams == 6 then
        di = stack:pop()
    end
    if numParams >= 5 then
        si = stack:pop()
    end
    if numParams >= 4 then
        dx = stack:pop()
    end
    if numParams >= 3 then
        cx = stack:pop()
    end
    if numParams >= 2 then
        bx = stack:pop()
    end
    s = stack:pop()

    -- printf("CALL(0x%04X, %s, %s, %s, %s, %s)\n", s, bx, cx, dx, si, di)
    if sibosyscalls == nil then
        sibosyscalls = require("sibosyscalls")
    end
    local fn = s & 0x00FF
    local ax = s & 0xFF00
    local params = {
        ax = ax,
        bx = bx or 0,
        cx = cx or 0,
        dx = dx or 0,
        si = si or 0,
        di = di or 0,
    }
    sibosyscalls.syscall(runtime, fn, params, params)
    -- printf("Call result = %x\n", params.ax)
    stack:push(params.ax)
end

Call_dump = numParams_dump

function Count(stack, runtime) -- 0x03
    local db = runtime:getDb()
    stack:push(db:getCount())
end

function Day(stack, runtime) -- 0x04
    stack:push(os.date("*t").day)
end

function Dow(stack, runtime) -- 0x05
    local year = stack:pop()
    local month = stack:pop()
    local day = stack:pop()
    local t = runtime:iohandler().utctime({year = year, month = month, day = day})
    -- Lua (and C) use 1 to mean Sunday, OPL 1 is Monday...
    local result = os.date("!*t", t).wday - 1
    if result == 0 then
        result = 7
    end
    stack:push(result)
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
    stack:push(runtime:EXIST(path))
end

function Find(stack, runtime) -- 0x09
    local text = stack:pop()
    local db = runtime:getDb()
    stack:push(db:findField(text, 1, nil, KFindForwards))
end

function Get(stack, runtime) -- 0x0A
    stack:push(runtime:GET())
end

function Ioa(stack, runtime) -- 0x0B
    local b = runtime:addrFromInt(stack:pop())
    local a = runtime:addrFromInt(stack:pop())
    local stat = runtime:addrAsVariable(stack:pop(), DataTypes.EWord)
    local fn = stack:pop()
    local h = stack:pop()
    local err = runtime:IOA(h, fn, stat, a, b)
    stack:push(err)
end

function Iow(stack, runtime) -- 0x0C
    unimplemented("fns.Iow")
end

function IoOpen(stack, runtime) -- 0x0D
    local mode = stack:pop()
    local name = stack:pop()
    local handleVar = runtime:addrAsVariable(stack:pop(), DataTypes.EWord)

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
    local addr = runtime:addrFromInt(stack:pop())
    local h = stack:pop()
    local data = addr:read(len)
    local err = runtime:IOWRITE(h, data)
    stack:push(err)
end

function IoRead(stack, runtime) -- 0x0F
    local maxLen = stack:pop()
    local addr = runtime:addrFromInt(stack:pop())
    local h = stack:pop()
    -- printf("IoRead maxLen=%d\n", maxLen)
    local data, err = runtime:IOREAD(h, maxLen)

    if data then
        -- printf("IoRead got %d bytes\n", #data)
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
    local addr = runtime:addrFromInt(stack:pop())
    local data = addr:read(1)
    stack:push(string.unpack("B", data))
end

function PeekW(stack, runtime) -- 0x19
    local addr = runtime:addrFromInt(stack:pop())
    local data = addr:read(2)
    stack:push(string.unpack("<i2", data))
end

function Pos(stack, runtime) -- 0x1A
    local db = runtime:getDb()
    stack:push(db:getPos())
end

function Second(stack, runtime) -- 0x1C
    stack:push(os.date("*t").sec)
end

function Usr(stack, runtime) -- 0x1D
    unimplemented("fns.Usr")
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
    local dd, mm, yy = stack:pop(3)
    local t = os.time({ day = dd, month = mm, year = yy })
    -- %V matches LCSTARTOFWEEK which always returns Monday
    local week = assert(tonumber(os.date("%V", t)))
    stack:push(week)
end

function IoSeek(stack, runtime) -- 0x21
    local offsetVar = runtime:addrAsVariable(stack:pop(), runtime:addressType())
    local mode = stack:pop()
    local handle = stack:pop()
    local err, result = runtime:IOSEEK(handle, mode, offsetVar())
    if result then
        offsetVar(result)
    end
    stack:push(err)
end

function Kmod(stack, runtime) -- 0x22
    local modifiers = runtime:getResource("kmod") or 0
    stack:push(modifiers)
end

function KeyA(stack, runtime) -- 0x23
    local keyArrayAddr = runtime:addrFromInt(stack:pop())
    local stat = stack:pop():asVariable(DataTypes.EWord)
    runtime:KEYA(stat, keyArrayAddr)
    stack:push(KErrNone)
end

function KeyC(stack, runtime) -- 0x24
    -- As with GetEventC, this includes the waitForRequest
    local stat = stack:pop():asVariable(DataTypes.EWord)
    runtime:iohandler().cancelRequest(stat)
    runtime:waitForRequest(stat)
    stack:push(KErrNone)
end

function IoOpenUnique(stack, runtime) -- 0x25
    local mode = stack:pop()
    local nameVar = runtime:addrAsVariable(stack:pop(), DataTypes.EString)
    local handleVar = runtime:addrAsVariable(stack:pop(), DataTypes.EWord)

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
    stack:push(KColorgCreate2GrayMode)
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

gCreateBit_dump = numParams_dump

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
    unimplemented("fns.gLoadFont")
end

function gRank(stack, runtime) -- 0x2A
    local result = runtime:gRANK()
    stack:push(result)
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
    stack:push(runtime:gORIGINX())
end

function gOriginY(stack, runtime) -- 0x31
    stack:push(runtime:gORIGINY())
end

function gTWidth(stack, runtime) -- 0x32
    local width = runtime:gTWIDTH(stack:pop())
    stack:push(width)
end

function gPrintClip(stack, runtime) -- 0x33
    local width = stack:pop()
    local text = stack:pop()
    local numChars = runtime:gPRINTCLIP(text, width)
    stack:push(numChars)
end

function TestEvent(stack, runtime) -- 0x34
    stack:push(runtime:TESTEVENT())
end

local syscallPackFmt = "<I2I2I2I2I2I2"

function Os(stack, runtime) -- 0x35 (SIBO only)
    local numParams = runtime:IP8()
    local addr2
    if numParams == 3 then
        addr2 = runtime:addrFromInt(stack:pop())
    end
    local addr1 = runtime:addrFromInt(stack:pop())
    if not addr2 then
        addr2 = addr1
    end
    local fn = stack:pop()
    if sibosyscalls == nil then
        sibosyscalls = require("sibosyscalls")
    end
    local params = {}
    params.ax, params.bx, params.cx, params.dx, params.si, params.di = string.unpack(syscallPackFmt, addr1:read(12))
    local results = {}
    results.ax, results.bx, results.cx, results.dx, results.si, results.di = string.unpack(syscallPackFmt, addr2:read(12))
    local flags = sibosyscalls.syscall(runtime, fn, params, results)
    addr2:write(string.pack(syscallPackFmt, results.ax, results.bx, results.cx, results.dx, results.si, results.di))
    stack:push(flags)
end

Os_dump = numParams_dump

function Menu(stack, runtime) -- 0x36
    local menu = runtime:getMenu()
    runtime:setMenu(nil)
    local result
    if runtime:iohandler().menu then
        result = runtime:iohandler().menu(menu)
    else
        result = runtime:MENU(menu)
    end
    stack:push(result)
end

function Dialog(stack, runtime) -- 0x37
    local dialog = runtime:getDialog()
    runtime:setDialog(nil)
    dialog.frame = nil -- Simplifies dumping dialog structure
    local result = runtime:DIALOG(dialog)
    -- Be bug compatible with Psion 5 and return 0 if a negative-keycode or escape button was pressed
    if result < 0 or result == 27 then
        result = 0
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

    local dlg = {
        title = "Information",
        flags = 0,
        xpos = 0,
        ypos = 0,
        items = {
            {
            type = dItemTypes.dTEXT,
            align = "center",
            value = line1,
            },
            {
            type = dItemTypes.dTEXT,
            align = "center",
            value = line2 or "",
            }
        },
        buttons = {
            { key = KKeyEsc, text = but1 or "Continue" },
        },
    }

    if but2 then
        table.insert(dlg.buttons, { key = KKeyEnter, text = but2 })
    end
    if but3 then
        table.insert(dlg.buttons, 2, { key = KKeySpace, text = but3 })
    end
    local key = runtime:DIALOG(dlg)
    local returnValues = {
        [KKeyEsc] = 1,
        [KKeyEnter] = 2,
        [KKeySpace] = 3,
    }
    local choice = assert(returnValues[key])
    stack:push(choice)
end

Alert_dump = numParams_dump

function gCreateEnhanced(stack, runtime) -- 0x39
    local flags = stack:pop()
    local visible = stack:pop()
    local x, y, w, h = stack:popRect()
    -- printf("gCreate x=%d y=%d w=%d h=%d flags=%d", x, y, w, h, flags)

    if runtime:getDeviceName() == "psion-series-7" then
        -- See https://github.com/inseven/opolua/issues/414 for why we do this
        flags = (flags & ~0xF) | KColorgCreateRGBColorMode
    end
    
    local id = runtime:gCREATE(x, y, w, h, visible ~= 0, flags)
    -- printf(" -> %d\n", id)
    stack:push(id)
end

function MenuWithMemory(stack, runtime) -- 0x3A
    local var = runtime:addrAsVariable(stack:pop(), DataTypes.EWord)
    local menu = runtime:getMenu()
    runtime:setMenu(nil)
    menu.highlight = var()
    local selected, highlighted
    if runtime:iohandler().menu then
        selected, highlighted = runtime:iohandler().menu(menu)
    else
        selected, highlighted = runtime:MENU(menu)
    end
    if highlighted then
        var(highlighted) -- Update this
    end
    stack:push(selected)
end

function Days(stack, runtime) -- 0x37
    local year = stack:pop()
    local month = stack:pop()
    local day = stack:pop()
    local t = runtime:DAYS(day, month, year)
    stack:push(t)
end

function IAbs(stack, runtime) -- 0x41
    stack:push(math.abs(stack:pop()))
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
    local addr = runtime:addrFromInt(stack:pop())
    local data = addr:read(4)
    stack:push(string.unpack("<i4", data))
end

function Space(stack, runtime) -- 0x44
    unimplemented("fns.Space")
end

function DateToSecs(stack, runtime) -- 0x45
    local seconds = stack:pop()
    local minutes = stack:pop()
    local hours = stack:pop()
    local day = stack:pop()
    local month = stack:pop()
    local year = stack:pop()
    local t, err = runtime:iohandler().utctime({
        year = year,
        month = month,
        day = day,
        hour = hours,
        min = minutes,
        sec = seconds
    })
    -- printf("DATETOSECS(year=%d, month=%d, day=%d, h=%d, m=%d, s=%d) = %s\n", year, month, day, hours, minutes, seconds, t)
    assert(t, err)
    stack:push(toint32(t))
end

function Alloc(stack, runtime) -- 0x4B
    local sz = stack:pop()
    assert(sz > 0, "Allocation size must be positive")
    local result = runtime:realloc(0, sz)
    stack:push(result)
end

function ReAlloc(stack, runtime) -- 0x4C
    local sz = stack:pop()
    local addr = runtime:addrFromInt(stack:pop())
    local result = runtime:realloc(addr:intValue(), sz)
    stack:push(result)
end

function AdjustAlloc(stack, runtime) -- 0x4D
    -- This API is a weird combo of realloc and memcpy
    local addr, offset, sz = stack:pop(3)
    local result = runtime:adjustAlloc(addr, offset, sz)
    stack:push(result)
end

function LenAlloc(stack, runtime) -- 0x4E
    local ptr = stack:pop()
    local result = runtime:allocLen(ptr)
    stack:push(result)
end

function Ioc(stack, runtime) -- 0x4F
    local numParams = runtime:IP8()
    local a, b
    if numParams >= 5 then
        b = runtime:addrFromInt(stack:pop())
    end
    if numParams >= 4 then
        a = runtime:addrFromInt(stack:pop())
    end
    local stat = runtime:addrAsVariable(stack:pop(), DataTypes.EWord)
    local fn = stack:pop()
    local h = stack:pop()
    runtime:IOC(h, fn, stat, a, b)
    stack:push(0)
end

Ioc_dump = numParams_dump

function Uadd(stack, runtime) -- 0x50
    local right = stack:pop()
    local left = stack:pop()

    if type(left) == "table" or type(right) == "table" then
        -- Assume one is an AddrSlice and just run with it (it shouln't be,
        -- unless SETFLAGS(1) is in effect, but there are programs which use
        -- UADD on addresses regardless of that setting...)
        stack:push(left + right)
    else
        local result = touint16(left) + touint16(right)
        stack:push(string.unpack("<i2", string.pack("<I2", result)))
    end
end

function Usub(stack, runtime) -- 0x51
    local right = touint16(stack:pop())
    local left = touint16(stack:pop())
    stack:push(string.unpack("<i2", string.pack("<I2", left - right)))
end

function IoCancel(stack, runtime) -- 0x52
    stack:push(runtime:IOCANCEL(stack:pop()))
end

function FindField(stack, runtime) -- 0x54
    local flags = stack:pop()
    local num = stack:pop()
    local start = stack:pop()
    local text = stack:pop()

    local db = runtime:getDb()
    stack:push(db:findField(text, start, num, flags))
end

function Bookmark(stack, runtime) -- 0x55
    -- Since we have a very simple model for databases, the bookmark identifier can just be the same as the position
    local db = runtime:getDb()
    stack:push(db:getPos())
end

function GetEventC(stack, runtime) -- 0x56
    local stat = stack:pop():asVariable(DataTypes.EWord)
    runtime:iohandler().cancelRequest(stat)
    -- Unlike IoCancel, GetEventC should do its own waitForRequest.
    runtime:waitForRequest(stat)
    stack:push(0) -- why these return something, who knows
end

function InTrans(stack, runtime) -- 0x57
    local db = runtime:getDb()
    stack:push(db:inTransaction())
end

function mPopup(stack, runtime) -- 0x58
    local numParams = runtime:IP8()
    local items = {}
    while numParams > 3 do
        local key = stack:pop()
        local text = stack:pop()
        table.insert(items, 1, { key = key, text = text })
        numParams = numParams - 2
    end
    local pos = stack:pop()
    local x, y = stack:popXY()
    local result = runtime:mPOPUP(x, y, pos, items)
    stack:push(result)
end

mPopup_dump = numParams_dump

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
    local addr = stack:pop()
    local data = addr:read(8)
    stack:push(string.unpack("<d", data))
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
    local str = stack:pop()
    -- printf("Val('%s')\n", hexEscape(str))
    local result = tonumber(str)
    if not result then
        printf("Bad Val('%s')\n", hexEscape(str))
        error(KErrInvalidArgs)
    end
    stack:push(result)
end

local function valList(stack, runtime)
    local numParams = runtime:IP8()
    local vals = {}
    if numParams == 0 then
        -- It's an array, represented as ArrayDirectLeftSideFloat(1)
        -- so we can safely turn back to an array variable
        local numVals = stack:pop()
        local var = stack:pop()
        local array = var:addressOf():asVariable(var:type() | 0x80)
        for i = 1, numVals do
            vals[i] = array[i]()
        end
    else
        while numParams > 0 do
            table.insert(vals, stack:pop())
            numParams = numParams - 1
        end
    end
    return vals
end

function Max(stack, runtime) -- 0x93
    stack:push(math.max(table.unpack(valList(stack, runtime))))
end

Max_dump = numParams_dump

function Mean(stack, runtime) -- 0x94
    local vals = valList(stack, runtime)
    local sum = 0
    for _, val in ipairs(vals) do
        sum = sum + val
    end
    stack:push(sum / #vals)
end

Mean_dump = numParams_dump

function Min(stack, runtime) -- 0x95
    stack:push(math.min(table.unpack(valList(stack, runtime))))
end

Min_dump = numParams_dump

function Std(stack, runtime) -- 0x96
    unimplemented("fns.Std")
end

function Sum(stack, runtime) -- 0x97
    local vals = valList(stack, runtime)
    local sum = 0
    for _, val in ipairs(vals) do
        sum = sum + val
    end
    stack:push(sum)
end

Sum_dump = numParams_dump

function Var(stack, runtime) -- 0x98
    unimplemented("fns.Var")
end

function Eval(stack, runtime) -- 0x99
    local str = stack:pop()
    -- We will treat this as an anonymous proc, which is the simplest way to resolve potential variable and proc
    -- calls in the expression.
    local proc = string.format([[
        PROC evaluateExpression:
            RETURN %s
        ENDP
        ]], str)
    local ok, prog = pcall(require("compiler").compile, "evaluateExpression", nil, proc, {})
    if not ok then
        error(-87) -- "Syntax error", not sure what the actual constant name should be since it isn't in const.oph...
    end
    local proc = assert(require("opofile").parseOpo(prog)[1])
    runtime:pushNewFrame(stack, proc, 0)
end

function ChrStr(stack) -- 0xC0
    -- Some apps try passing raw keycodes like 4104 (cursor key) to this fn,
    -- hence masking them with 0xFF which seems to do the expected thing...
    return stack:push(string.char(stack:pop() & 0xFF))
end

function DatimStr(stack, runtime) -- 0xC1
    -- system time -> Fri 16 Oct 1992 16:25:30
    stack:push(os.date("%a %d %b %Y %T"))
end

function DayNameStr(stack, runtime) -- 0xC2
    -- 1st Jan 1970 was a Thursday, and dayname=1 means Monday, so
    stack:push(os.date("!%a", 86400 * (3 + stack:pop())))
end

function DirStr(stack, runtime) -- 0xC3
    local path = stack:pop()
    -- dir requires state to be tracked, so push it into runtime
    local result = runtime:dir(path)
    -- printf('DIR$("%s") -> %s\n', path, result)
    stack:push(result)
end

function ErrStr(stack, runtime) -- 0xC4
    local err = stack:pop()
    stack:push(Errors[err] or fmt("Unknown error %d", err))
end

function FixStr(stack, runtime) -- 0xC5
    local width = stack:pop()
    local decimals = stack:pop()
    local val = stack:pop()
    local result = string.format("%0."..decimals.."f", val)
    if width < 0 then
        width = -width
        result = string.rep(" ", width - #result)..result
    end
    if #result > width then
        result = string.rep("*", width)
    end
    stack:push(result)
end

function GenStr(stack, runtime) -- 0xC6
    local width = stack:pop()
    local val = stack:pop()
    local result = fmt("%g", val)
    if width < 0 then
        width = -width
        result = string.rep(" ", width - #result)..result
    end
    if #result > width then
        result = string.rep("*", width)
    end
    stack:push(result)
end

function GetStr(stack, runtime) -- 0xC7
    stack:push(runtime:GETSTR())
end

function HexStr(stack, runtime) -- 0xC8
    stack:push(fmt("%X", stack:pop() & 0xFFFFFFFF))
end

function KeyStr(stack, runtime) -- 0xC9
    stack:push(runtime:KEYSTR())
end

function LeftStr(stack, runtime) -- 0xCA
    local numChars = stack:pop()
    assert(numChars >= 0, KErrInvalidArgs)
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
    assert(offset >= 1, KErrInvalidArgs)
    assert(len >= 0, KErrInvalidArgs)
    local result = str:sub(offset, offset + len - 1)
    -- printf("MID$('%s', %d, %d)='%s'\n", str, offset, len, result)
    stack:push(result)
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
    stack:push(assert(months[stack:pop()], KErrInvalidArgs))
end

function NumStr(stack, runtime) -- 0xCE
    local width = stack:pop()
    local val = stack:pop()
    local intVal = roundToNearest(val)
    -- printf("NumStr(%s, %d) intval=%d", val, width, intVal)
    local result
    if width < 0 then
        width = -width
        result = fmt("%"..tostring(width).."d", intVal)
    else
        result = tostring(intVal)
    end
    if #result > width then
        result = string.rep("*", width)
    end
    -- printf(" -> '%s'\n", result)
    stack:push(result)
end

function PeekStr(stack, runtime) -- 0xCF
    local addr = runtime:addrFromInt(stack:pop())
    local var = addr:asVariable(DataTypes.EString)
    stack:push(var())
end

function ReptStr(stack, runtime) -- 0xD0
    local reps = stack:pop()
    local str = stack:pop()
    stack:push(string.rep(str, reps))
end

function RightStr(stack, runtime) -- 0xD1
    local numChars = stack:pop()
    assert(numChars >= 0, KErrInvalidArgs)
    local str = stack:pop()
    if numChars == 0 then
        stack:push("")
    else
        stack:push(string.sub(str, -numChars))
    end
end

function SciStr(stack, runtime) -- 0xD2
    unimplemented("fns.SciStr")
end

function UpperStr(stack, runtime) -- 0xD3
    stack:push(stack:pop():upper())
end

function WCmd(stack, runtime) -- 0xD5
    local result = runtime:getResource("GETCMD")
    runtime:setResource("GETCMD", nil)
    stack:push(result or "")
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
        error("unhandled CMD$ param "..tostring(x))
    end
end

function ParseStr(stack, runtime) -- 0xD7
    local offsetsArrayAddr = stack:pop()
    local rel = stack:pop()
    local f = stack:pop()
    -- Wow this is a fun API
    -- printf("Parse(%s, %s)\n", f, rel)

    rel = oplpath.abs(rel, runtime:getCwd())
    local _, fext = oplpath.splitext(f)
    local _, relext = oplpath.splitext(rel)
    f = oplpath.abs(f, rel)
    if #fext == 0 and #relext > 0 then
        -- f is expected to inherit rel's extension
        f = f .. relext
    end

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
    unimplemented("fns.gPixel")
end

function LocWithCase(stack, runtime) -- 0xDB
    unimplemented("fns.LocWithCase")
end

function Size(stack, runtime) -- 0xDA
    unimplemented("fns.Size")
end

function GetDocStr(stack, runtime) -- 0xD9
    unimplemented("fns.GetDocStr")
end

return _ENV
