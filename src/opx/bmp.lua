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
    [1] = "BitmapLoad",
    [2] = "BitmapUnload",
    [3] = "BitmapDisplayMode",
    [4] = "SpriteCreate",
    [5] = "SpriteAppend",
    [6] = "SpriteChange",
    [7] = "SpriteDraw",
    [8] = "SpritePos",
    [9] = "SpriteDelete",
    [10] = "SpriteUse",
}

function BitmapLoad(stack, runtime)
    local idx = stack:pop()
    local path = stack:pop()
    local cur = runtime:gIDENTITY()
    local id = runtime:gLOADBIT(path, false, idx)
    runtime:getGraphicsContext().bmpRefCount = 1
    runtime:gUSE(cur)
    stack:push(id)
end

local function incRefcount(runtime, bitmapId)
    if bitmapId == 0 then
        -- SIBO allows initially invalid bitmap IDs (updated by a subsequent SPRITECHANGE)
        return
    end
    local bitmap = runtime:getGraphicsContext(bitmapId)
    assert(bitmap, "incRefcount on invalid bitmapId!")
    bitmap.bmpRefCount = (bitmap.bmpRefCount or 1) + 1
end

local function decRefcount(runtime, bitmapId)
    if bitmapId == 0 then
        -- SIBO allows initially invalid bitmap IDs (updated by a subsequent SPRITECHANGE)
        return
    end
    local bitmap = runtime:getGraphicsContext(bitmapId)
    assert(bitmap, "decRefcount on invalid bitmapId!")
    bitmap.bmpRefCount = bitmap.bmpRefCount - 1
    if bitmap.bmpRefCount == 0 then
        runtime:gCLOSE(bitmapId)
    end
end

function BitmapUnload(stack, runtime)
    decRefcount(runtime, stack:pop())
    stack:push(0)
end

function BitmapDisplayMode(stack, runtime)
    local context = runtime:getGraphicsContext(stack:pop())
    stack:push(context.displayMode)
end

function SpriteCreate(stack, runtime)
    local flags = stack:pop()
    local x, y = stack:popXY()
    local winId = stack:pop()
    if winId == 0 then
        winId = 1 -- apparently...
    end
    local spriteId = SPRITECREATE(runtime, winId, x, y, flags)
    stack:push(spriteId)
end

function SPRITECREATE(runtime, winId, x, y, flags)
    local graphics = runtime:getGraphics()
    assert(graphics[winId] and graphics[winId].isWindow, "id is not a window")
    local spriteId = #graphics.sprites + 1
    local sprite = {
        origin = { x = x, y = y },
        win = winId,
        id = spriteId,
        frames = {},
    }
    graphics.sprites[spriteId] = sprite
    graphics.currentSprite = sprite
    return spriteId
end

function SpriteAppend(stack, runtime)
    local dx, dy = stack:popXY()
    local invertMask = stack:pop() ~= 0
    local maskBitmap = stack:pop()
    local bitmap = stack:pop()
    local time = stack:pop() / 1000000
    SPRITEAPPEND(runtime, time, bitmap, maskBitmap, invertMask, dx, dy)
    stack:push(0)
end

function SPRITEAPPEND(runtime, time, bitmap, maskBitmap, invertMask, dx, dy)
    local graphics = runtime:getGraphics()
    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")

    incRefcount(runtime, bitmap)
    incRefcount(runtime, maskBitmap)
    local frame = {
        offset = { x = dx, y = dy },
        bitmap = bitmap,
        mask = maskBitmap,
        time = time,
        invertMask = invertMask,
    }
    table.insert(sprite.frames, frame)
end

function SpriteChange(stack, runtime)
    -- printf("SpriteChange\n")
    local graphics = runtime:getGraphics()
    local dx, dy = stack:popXY()
    local invertMask = stack:pop() == 1
    local maskBitmap = stack:pop()
    local bitmap = stack:pop()
    local time = stack:pop() / 1000000
    local frameId = stack:pop() + 1

    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")
    SPRITECHANGE(runtime, sprite.id, frameId, time, bitmap, maskBitmap, invertMask, dx, dy)
    stack:push(0)
end

function SPRITECHANGE(runtime, spriteId, frameId, time, bitmap, maskBitmap, invertMask, dx, dy)
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[spriteId]
    assert(sprite, "Bad sprite id to SPRITECHANGE")

    local oldFrame = sprite.frames[frameId]
    assert(oldFrame, "No frame for id!")

    incRefcount(runtime, bitmap)
    incRefcount(runtime, maskBitmap)
    decRefcount(runtime, oldFrame.bitmap)
    decRefcount(runtime, oldFrame.mask)

    local frame = {
        offset = { x = dx, y = dy },
        bitmap = bitmap,
        mask = maskBitmap,
        time = time,
        invert = invertMask,
    }
    sprite.frames[frameId] = frame
    runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, sprite)
end

function getCurrentSprite(runtime)
    local graphics = runtime:getGraphics()
    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")
    return sprite
end

function SpriteDraw(stack, runtime)
    SPRITEDRAW(runtime)
    stack:push(0)
end

function SPRITEDRAW(runtime)
    -- printf("SpriteDraw\n")
    local sprite = getCurrentSprite(runtime)
    sprite.drawn = true
    runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, sprite)
end

function SpritePos(stack, runtime)
    -- printf("SpritePos\n")
    local sprite = getCurrentSprite(runtime)
    local x, y = stack:popXY()
    SPRITEPOS(runtime, sprite.id, x, y)
    stack:push(0)
end

function SPRITEPOS(runtime, spriteId, x, y)
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[spriteId]
    assert(sprite, "Bad sprite id to SPRITEPOS")
    sprite.origin = { x = x, y = y }
    if sprite.drawn then
        runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, sprite)
    end
end

function SpriteDelete(stack, runtime)
    -- printf("SpriteDelete\n")
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[stack:pop()]
    assert(sprite, "Bad sprite ID!")
    for _, frame in ipairs(sprite.frames) do
        decRefcount(runtime, frame.bitmap)
        decRefcount(runtime, frame.mask)
    end
    graphics.sprites[sprite.id] = nil
    runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, nil)
    stack:push(0)
end

function SpriteUse(stack, runtime)
    local graphics = runtime:getGraphics()
    local spriteId = stack:pop()
    local sprite = graphics.sprites[spriteId]
    assert(sprite, "Bad id to SpriteUse")
    graphics.currentSprite = sprite
    stack:push(0)
end

return _ENV
