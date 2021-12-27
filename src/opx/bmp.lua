--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

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
    stack:push(id)
end

function BitmapUnload(stack, runtime)
    runtime:gCLOSE(stack:pop())
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
    local graphics = runtime:getGraphics()
    assert(graphics[winId] and graphics[winId].isWindow, "id is not a window")
    local spriteId = #graphics.sprites + 1
    local sprite = {
        x = x,
        y = y,
        win = winId,
        id = spriteId,
        frames = {},
    }
    graphics.sprites[spriteId] = sprite
    graphics.currentSprite = sprite
    stack:push(spriteId)
end

function SpriteAppend(stack, runtime)
    local graphics = runtime:getGraphics()
    local dx, dy = stack:popXY()
    local invertMask = stack:pop() == 1
    local maskBitmap = stack:pop()
    local bitmap = stack:pop()
    local time = stack:pop()

    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")

    local frame = {
        dx = dx,
        dy = dy,
        bitmap = bitmap,
        mask = maskBitmap,
        time = time,
        invert = invertMask,
    }
    table.insert(sprite.frames, frame)
    stack:push(0)
end

function SpriteChange(stack, runtime)
    local graphics = runtime:getGraphics()
    local dx, dy = stack:popXY()
    local invertMask = stack:pop() == 1
    local maskBitmap = stack:pop()
    local bitmap = stack:pop()
    local time = stack:pop()
    local frameId = stack:pop() + 1

    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")
    assert(sprite.frames[frameId], "No frame for id!")

    local frame = {
        dx = dx,
        dy = dy,
        bitmap = bitmap,
        mask = maskBitmap,
        time = time,
        invert = invertMask,
    }
    sprite.frames[frameId] = frame
    runtime:iohandler().graphicsop("sprite", sprite.id, sprite)
    stack:push(0)
end

function getCurrentSprite(runtime)
    local graphics = runtime:getGraphics()
    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")
    return sprite
end

function SpriteDraw(stack, runtime)
    local sprite = getCurrentSprite(runtime)
    runtime:iohandler().graphicsop("sprite", sprite.id, sprite)
    stack:push(0)
end

function SpritePos(stack, runtime)
    local sprite = getCurrentSprite(runtime)
    local x, y = stack:popXY()
    sprite.x = x
    sprite.y = y
    runtime:iohandler().graphicsop("sprite", sprite.id, sprite)
    stack:push(0)
end

function SpriteDelete(stack, runtime)
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[stack:pop()]
    assert(sprite, "Bad sprite ID!")
    graphics.sprites[sprite.id] = nil
    runtime:iohandler().graphicsop("sprite", sprite.id, nil)
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
