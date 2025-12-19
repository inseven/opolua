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
    [0x8000] = "SegFreeMemory",
    [0x861E] = "IoPlaySoundW",
    [0x861F] = "IoPlaySoundA",
    [0x8620] = "IoPlaySoundCancel",
    [0x8800] = "ProcId",
    [0x880C] = "ProcRename",
    [0x8B12] = "GenMarkActive",
    [0x8B13] = "GenMarkNonActive",
    [0x8B1B] = "GenGetLanguageCode",
    [0x8D0E] = "wInquireWindow",
    [0x8D11] = "wFree",
    [0x8D5F] = "gSetOpenAddress",
    [0x8D7E] = "wserv8D7E",
    [0x8DF5] = "wSetSprite",
    [0x8DF6] = "wCreateSprite",
    [0x8E28] = "HwGetScanCodes",
    [0xDB00] = "StringCapitalise",
}

function dumpRegisters(registers)
    local function fmt(reg)
        if ~reg then
            return string.format("0x%04X", reg)
        else
            return tostring(reg)
        end
    end
    return string.format("ax=%s, bx=%s, cx=%s, dx=%s, si=%s, di=%s",
        fmt(registers.ax), fmt(registers.bx), fmt(registers.cx), fmt(registers.dx), fmt(registers.si), fmt(registers.di))
end

function syscall(runtime, fn, params)
    -- printf("syscall fn=%02X %s\n", fn, dumpRegisters(params))
    local fnSub = (fn << 8) | ((params.ax >> 8) & 0xFF)
    local fnName = fns[fnSub]
    if fnName and _ENV[fnName] then
        local ax, bx, cx, dx, si, di, flags = _ENV[fnName](runtime, params)
        return ax or 0, bx or 0, cx or 0, dx or 0, si or 0, di or 0, flags or 0
    else
        printf("Unimplemented syscall fn=%02X Params %s\n", fn, dumpRegisters(params))
        unimplemented(string.format("syscall.%04X", fnSub))
    end
end

function SegFreeMemory(runtime, fn, params)
    return 60000 // 16
end

function IoPlaySoundW(runtime, params) -- 0x861E
    -- print("IoPlaySoundW", dumpRegisters(params))
    -- Fortunately PlaySound doesn't care (and will respect) what the type of
    -- var is, so even though system.lua expects an ELong, we are OK to use an
    -- EWord here.
    local var = runtime:makeTemporaryVar(DataTypes.EWord)
    params.di = var:addressOf()
    IoPlaySoundA(runtime, params)
    runtime:waitForRequest(var)
    -- printf("IoPlaySoundW returned %d\n", var())
    return var()
end

function IoPlaySoundA(runtime, params) -- 0x861F
    local path = runtime:abs(string.unpack("z", runtime:addrFromInt(params.bx):read(255)))
    if not runtime:EXIST(path) then
        path = path .. ".WVE"
    end
    local duration = params.cx
    local volume = params.dx
    printf("IoPlaySoundA path=%s\n", path)
    local var = runtime:addrAsVariable(params.di, DataTypes.EWord)
    runtime:PlaySoundA(var, path)
end

function IoPlaySoundCancel(runtime, params) -- 0x8620
    print("IoPlaySoundCancel")
    runtime:StopSound()
end

function ProcId(runtime, params) -- 0x8800
    return 1 -- We will say the procid is always 1
end

function ProcRename(runtime, params) -- 0x880C
    assert(params.bx == 1, "Bad process id to ProcRename") -- ie what we returned from ProcId
    local addr = runtime:addrFromInt(params.di)
    local str = string.unpack("z", addr:read(9))
    -- printf("ProcRename %s\n", str)
    runtime:iohandler().system("setAppTitle", str)
end

function GenMarkActive(runtime, params) -- 0x8B12
end

function GenMarkNonActive(runtime, params) -- 0x8B13
end

function GenGetLanguageCode(runtime, params) -- 0x8B1B
    return require("sis").Locales["en_GB"]
end

function wInquireWindow(runtime, params) -- 0x8D0E
    local winId = params.bx
    local ctx = runtime:getGraphicsContext(winId)
    assert(ctx and ctx.isWindow, KErrInvalidWindow)
    local resultAddr = runtime:addrFromInt(params.si)
    resultAddr:write(string.pack("<I2I2I2I2I2xxxx", 0, ctx.winX, ctx.winY, ctx.width, ctx.height))
end

function wFree(runtime, params) -- 0x8D11
    -- We're going to ignore this one for now because we don't have separate
    -- namespaces for all the types of identifier that wFree apparently
    -- accepts...
end

function gSetOpenAddress(runtime, params) -- 0x8D5F
    printf("gSetOpenAddress(bx=%d cx=%d dx=%d)\n", params.bx, params.cx, params.dx)
    -- This is a gnarly API...
    assert(params.bx == 0 or params.bx == 1, "gSetOpenAddress mode not supported: "..tostring(params.bx))
    local offset
    if params.bx == 0 then
        offset = nil
    else
        offset = (params.dx << 16) + params.cx
    end
    runtime:setResource("gSetOpenAddress", offset)
end

function wserv8D7E(runtime, params) -- 0x8D7E
    local al = params.ax & 0xFF
    if al == 2 then
        printf("wDisableKeyClick disable=%s\n", params.bx ~= 0)
    else
        unimplemented("syscall.8D.7E."..tostring(al))
    end
end

local function getSpriteFrame(runtime, addr)
    local bmpBlackSet, bmpBlackClear, bmpBlackInvert, bmpGreySet, bmpGreyClear, bmpGreyInvert, relx, rely, delay =
        string.unpack("<I2I2I2I2I2I2I2I2I4", runtime:addrFromInt(addr):read(24))
    -- print("Sprite params", bmpBlackSet, bmpBlackClear, bmpBlackInvert, bmpGreySet, bmpGreyClear, bmpGreyInvert, relx, rely, delay)
    -- These are returned in the same order as accepted by SPRITECHANGE and SPRITEAPPEND
    return delay * 0.1, bmpBlackSet, bmpBlackSet, true, relx, rely
end

function wSetSprite(runtime, params) -- 0x8DF5
    -- print("wSetSprite", dumpRegisters(params))
    local spriteId = params.bx
    local bmp = require("opx.bmp")
    if params.cx ~= 0 then
        local x = runtime:addrAsVariable(params.cx, DataTypes.EWord)()
        local y = runtime:addrAsVariable(params.cx + 2, DataTypes.EWord)()
        bmp.SPRITEPOS(runtime, spriteId, x, y)        
    end
    if params.di ~= 0 then
        local frameId = params.dx + 1 -- Or si...?
        bmp.SPRITECHANGE(runtime, spriteId, frameId, getSpriteFrame(runtime, params.di))
    end
end

function wCreateSprite(runtime, params) -- 0x8DF6
    print("wCreateSprite", dumpRegisters(params))
    local winId = params.bx
    -- if winId == 0 then
    --     -- Apparently 0 can mean default win?
    --     winId = 1
    -- end
    local x = runtime:addrAsVariable(params.cx, DataTypes.EWord)()
    local y = runtime:addrAsVariable(params.cx + 2, DataTypes.EWord)()

    local bmp = require("opx.bmp")
    local id = bmp.SPRITECREATE(runtime, winId, x, y, 0)

    local numSprites = params.di
    local spriteInfoAddr = params.si
    for i = 1, numSprites do
        bmp.SPRITEAPPEND(runtime, getSpriteFrame(runtime, spriteInfoAddr))
        spriteInfoAddr = spriteInfoAddr + 24
    end
    bmp.SPRITEDRAW(runtime)

    return id
end

local function byte(bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7)
    return
        (bit0 and 1 or 0) |
        (bit1 and 0x2 or 0) |
        (bit2 and 0x4 or 0) |
        (bit3 and 0x8 or 0) |
        (bit4 and 0x10 or 0) |
        (bit5 and 0x20 or 0) |
        (bit6 and 0x40 or 0) |
        (bit7 and 0x80 or 0)
end

-- TODO(tomsci): This needs updating
function HwGetScanCodes(runtime, params) -- 0x8E28
    -- print("HwGetScanCodes", dumpRegisters(params), dumpRegisters(results))
    local keys = runtime:iohandler().keysDown()
    local scanCodes = require("oplkeycode").series3aScanCodes
    local bytes = {}
    for i = 0, 19 do
        local base = 1 + (8 * i)
        bytes[i + 1] = byte(
            keys[scanCodes[base]],
            keys[scanCodes[base + 1]],
            keys[scanCodes[base + 2]],
            keys[scanCodes[base + 3]],
            keys[scanCodes[base + 4]],
            keys[scanCodes[base + 5]],
            keys[scanCodes[base + 6]],
            keys[scanCodes[base + 7]]
        )
    end
    local buf = string.pack("BBBBBBBBBBBBBBBBBBBB", table.unpack(bytes))
    runtime:addrFromInt(params.bx):write(buf)
end

function StringCapitalise(runtime, params) -- 0xDB00
    local ptr = runtime:addrFromInt(params.si)
    local len = 0
    local endPtr = ptr
    while endPtr:read(1) ~= '\0' and len < 256 do
        endPtr = endPtr + 1
        len = len + 1
    end
    printf("TODO StringCapitalise len=%d\n", len)
end

return _ENV
