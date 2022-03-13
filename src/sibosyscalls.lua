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
    [0x861E] = "IoPlaySoundW",
    [0x861F] = "IoPlaySoundA",
    [0x8620] = "IoPlaySoundCancel",
    [0x8B1B] = "GenGetLanguageCode",
    [0x8D0E] = "wInquireWindow",
    [0x8DF5] = "wSetSprite",
    [0x8DF6] = "wCreateSprite",
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

function syscall(runtime, fn, params, results)
    -- printf("syscall fn=%02X %s\n", fn, dumpRegisters(params))
    local fnSub = (fn << 8) | ((params.ax >> 8) & 0xFF)
    local fnName = fns[fnSub]
    if not fnName then
        -- See if there's one with no sub
        fnName = fns[fn << 8]
    end
    if fnName and _ENV[fnName] then
        return _ENV[fnName](runtime, params, results)
    else
        printf("Unimplemented fn=%02X Params %s results %s\n", fn, dumpRegisters(params), dumpRegisters(results))
        unimplemented(string.format("syscall.%04X", fnSub))
    end
end

function GenGetLanguageCode(runtime, params, results)
    results.ax = require("sis").Locales["en_GB"]
    return 0
end

local function getSpriteFrame(runtime, addr)
    local bmpBlackSet, bmpBlackClear, bmpBlackInvert, bmpGreySet, bmpGreyClear, bmpGreyInvert, relx, rely, delay =
        string.unpack("<I2I2I2I2I2I2I2I2I4", runtime:addrFromInt(addr):read(24))
    print("Sprite params", bmpBlackSet, bmpBlackClear, bmpBlackInvert, bmpGreySet, bmpGreyClear, bmpGreyInvert, relx, rely, delay)
    -- These are returned in the same order as accepted by SPRITECHANGE and SPRITEAPPEND
    return delay * 0.1, bmpBlackSet, bmpBlackSet, true, relx, rely
end

function wSetSprite(runtime, params, results)
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
    results.ax = 0
    return 0
end

function wCreateSprite(runtime, params, results)
    print("wCreateSprite", dumpRegisters(params))
    local winId = params.bx
    if winId == 0 then
        -- Apparently 0 can mean default win?
        winId = 1
    end
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

    results.ax = id
    return 0
end

function IoPlaySoundW(runtime, params, results)
    -- print("IoPlaySoundW", dumpRegisters(params))
    -- Fortunately PlaySound doesn't care (and will respect) what the type of
    -- var is, so even though system.lua expects an ELong, we are OK to use an
    -- EWord here.
    local var = runtime:makeTemporaryVar(DataTypes.EWord)
    params.di = var:addressOf()
    IoPlaySoundA(runtime, params, results)
    runtime:waitForRequest(var)
    results.ax = var() -- This will sign extend into AH which is ok
    -- printf("IoPlaySoundW returned %d\n", var())
    return 0
end

function IoPlaySoundA(runtime, params, results)
    local path = runtime:abs(string.unpack("z", runtime:addrFromInt(params.bx):read(255)))
    if not runtime:EXIST(path) then
        path = path .. ".WVE"
    end
    local duration = params.cx
    local volume = params.dx
    printf("IoPlaySoundA path=%s\n", path)
    local var = runtime:addrAsVariable(params.di, DataTypes.EWord)
    runtime:PlaySoundA(var, path)
    return 0, 0
end

function IoPlaySoundCancel(runtime, params, results)
    print("IoPlaySoundCancel")
    runtime:StopSound()
    results.ax = 0
    return 0
end

return _ENV
