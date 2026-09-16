-- Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

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

-- In the real bmp.opx, bitmap handles were CFbsBitmap pointers cast to TInt32.
-- To avoid having 2 different backends we just use drawable IDs and gLOADBIT
-- under the hood.
function BitmapLoad(stack, runtime)
    local idx = stack:pop()
    local path = stack:pop()
    local id = BITMAPLOAD(runtime, path, idx)
    stack:push(id)
end

function BITMAPLOAD(runtime, path, idx)
    local cur = runtime:gIDENTITY()
    local id = runtime:gLOADBIT(path, false, idx)
    runtime:getGraphicsContext().bmpRefCount = 1
    runtime:gUSE(cur)
    return id
end

local function incRefcount(runtime, bitmapId)
    local bitmap = runtime:getGraphicsContext(assert(bitmapId))
    assert(bitmap and bitmap.bmpRefCount, "incRefcount on invalid bitmapId!")
    bitmap.bmpRefCount = bitmap.bmpRefCount + 1
end

local function decRefcount(runtime, bitmapId)
    local bitmap = runtime:getGraphicsContext(bitmapId)
    assert(bitmap and bitmap.bmpRefCount, "decRefcount on invalid bitmapId!")
    bitmap.bmpRefCount = bitmap.bmpRefCount - 1
    if bitmap.bmpRefCount == 0 then
        bitmap.bmpRefCount = nil
        runtime:gCLOSE(bitmapId)
    end
end

function BitmapUnload(stack, runtime)
    BITMAPUNLOAD(runtime, stack:pop())
    stack:push(0)
end

function BITMAPUNLOAD(runtime, id)
    decRefcount(runtime, id)
end

function BitmapDisplayMode(stack, runtime)
    local context = runtime:getGraphicsContext(stack:pop())
    stack:push(context.displayMode)
end

function SpriteCreate(stack, runtime)
    local flags = stack:pop()
    local x, y = stack:popXY()
    local winId = stack:pop()
    local spriteId = SPRITECREATE(runtime, winId, x, y, flags)
    stack:push(spriteId)
end

function SPRITECREATE(runtime, winId, x, y, flags)
    local graphics = runtime:getGraphics()
    local context = runtime:getGraphicsContext(winId)
    -- winId zero means "the root window" which only really makes sense when combined with the ESpriteNoChildClip flag
    local isGlobal = winId == 0 and (flags & 1) ~= 0 -- TSpriteFlags::ESpriteNoChildClip in epoc32 terms
    -- printf("SPRITECREATE(winId=%d, x=%d, y=%d, flags=%X)", winId, x, y, flags)
    assert((context and context.isWindow) or isGlobal, "id is not a window")
    local spriteId = #graphics.sprites + 1
    local sprite = {
        origin = { x = x, y = y },
        win = winId,
        id = spriteId,
        frames = {},
        global = isGlobal,
    }
    graphics.sprites[spriteId] = sprite
    graphics.currentSprite = sprite
    -- printf(" = %d\n", spriteId)
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

-- The OPX API
function SPRITEAPPEND(runtime, time, bitmap, maskBitmap, invertMask, dx, dy)
    local graphics = runtime:getGraphics()
    local sprite = graphics.currentSprite
    assert(sprite, "No current sprite!")

    -- Note, refcounts not incremented until draw
    local frame = {
        offset = { x = dx, y = dy },
        bitmap = bitmap,
        mask = maskBitmap,
        time = time,
        invertMask = invertMask,
    }
    -- printf("SPRITEAPPEND(t=%s, bmp=%d, mask=%d, inv=%s, dx=%d, dy=%d)\n", time, bitmap, maskBitmap, invertMask, dx, dy)
    table.insert(sprite.frames, frame)
end

-- The SIBO API
function APPENDSPRITE(runtime, time, bitmaps, dx, dy)
    local sprite = runtime:getGraphics().currentSprite
    assert(sprite, "No currentSprite in APPEND/CREATESPRITE")

    local frame = {
        offset = { x = dx, y = dy },
        -- bitmap, mask and invertMask are all nil for S3a sprites
        time = time,
        blackSetMask = bitmaps[1],
        blackClearMask = bitmaps[2],
        blackInvertMask = bitmaps[3],
        greySetMask = bitmaps[4],
        greyClearMask = bitmaps[5],
        greyInvertMask = bitmaps[6],
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

-- The OPX API
function SPRITECHANGE(runtime, spriteId, frameId, time, bitmap, maskBitmap, invertMask, dx, dy)
    -- printf("SPRITECHANGE(id=%d, frame=%d, t=%s, bmp=%d, mask=%d, inv=%s, dx=%d, dy=%d\n", spriteId, frameId, time, bitmap, maskBitmap, invertMask, dx, dy)
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[spriteId]
    assert(sprite, "Bad sprite id to SPRITECHANGE")
    assert(sprite.drawn, KOplStructure)

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
        invertMask = invertMask,
    }
    sprite.frames[frameId] = frame
    runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, sprite)
end

-- The SIBO API
function CHANGESPRITE(runtime, spriteId, frameId, time, bitmaps, dx, dy)
    local sprite = runtime:getGraphics().sprites[spriteId]
    assert(sprite, "No currentSprite in CHANGESPRITE")
    assert(sprite.drawn, KOplStructure)

    local frame = {
        offset = { x = dx, y = dy },
        time = time,
        blackSetMask = bitmaps[1],
        blackClearMask = bitmaps[2],
        blackInvertMask = bitmaps[3],
        greySetMask = bitmaps[4],
        greyClearMask = bitmaps[5],
        greyInvertMask = bitmaps[6],
    }
    assert(frameId <= #sprite.frames, KErrInvalidArgs)
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
    if not sprite.isSibo then
        -- Apparently refcounts should not be incremented until draw
        for _, frame in ipairs(sprite.frames) do
            incRefcount(runtime, frame.bitmap)
            incRefcount(runtime, frame.mask)
        end
    end

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
    local id = stack:pop()
    SPRITEDELETE(runtime, id)
    stack:push(0)
end

function SPRITEDELETE(runtime, id)
    -- printf("SpriteDelete %d\n", id)
    local graphics = runtime:getGraphics()
    local sprite = graphics.sprites[id]

    if sprite == nil then
        -- It seems like this isn't an error on the Psion 5?
        printf("Bad sprite ID %d in SpriteDelete!\n", id)
        return
    end
    if not sprite.isSibo then
        for _, frame in ipairs(sprite.frames) do
            decRefcount(runtime, frame.bitmap)
            decRefcount(runtime, frame.mask)
        end
    end
    graphics.sprites[sprite.id] = nil
    if graphics.currentSprite == sprite then
        graphics.currentSprite = nil
    end
    runtime:iohandler().graphicsop("sprite", sprite.win, sprite.id, nil)
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
