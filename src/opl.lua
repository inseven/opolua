--[[

The idea of this file is to define a Lua equivalent of some of the OPL APIs,
using normal Lua function arguments and return values. Where it makes sense to
do so, implementations of individual opcodes pull values from the OPL stack and
convert them to call these functions.

The reason for doing it like this is so that Lua implementations of modules and
OPXes have an equivalent-level API to use, rather than having to do
everything in terms of calls to runtime and iohandler, which would be both
verbose and brittle (since the iohandler API in particular is always subject to
change).

All of the APIs in this file are available via runtime member fns, eg
runtime:gCREATE(20, 20). As a convenience, modules and OPX code (ie the files
in the modules and opx directories) can call them directly as gCREATE(20, 20).

Boolean parameters should be actual bools - ie pass true or false, not -1 or 0.
]]


_ENV = module()

local mbm = require("mbm")

local runtime = nil

function _setRuntime(r)
    runtime = r
end

local function darkGrey()
    gCOLOR(0x55, 0x55, 0x55)
end

local function lightGrey()
    gCOLOR(0xAA, 0xAA, 0xAA)
end

local function black()
    gCOLOR(0, 0, 0)
end

local function white()
    gCOLOR(0xFF, 0xFF, 0xFF)
end

-- Graphics APIs

function gCLOSE(id)
    runtime:closeGraphicsContext(id)
end

function gUSE(id)
    runtime:setGraphicsContext(id)
end

function gVISIBLE(show)
    local context = runtime:getGraphicsContext()
    assert(context.isWindow, KOplErrInvalidWindow)
    runtime:iohandler().graphicsop("show", context.id, show)
end

function gFONT(id)
    local font = FontIds[id]
    if not font then
        printf("No font found for 0x%08X\n", id)
        error(KOplErrFontNotLoaded)
    end
    runtime:getGraphicsContext().font = font
end

function gGMODE(mode)
    runtime:getGraphicsContext().mode = mode
end

function gTMODE(tmode)
    runtime:getGraphicsContext().tmode = tmode
end

function gSTYLE(style)
    runtime:getGraphicsContext().style = style
end

function gORDER(id, pos)
    local graphics = runtime:getGraphics()
    assert(graphics[id] and graphics[id].isWindow, KOplErrInvalidWindow)
    runtime:iohandler().graphicsop("order", id, pos)
end

function gCLS()
    local context = runtime:getGraphicsContext()
    context.pos = { x = 0, y = 0 }
    runtime:drawCmd("fill", { width = context.width, height = context.height, mode = 1 })
end

function gAT(x, y)
    local contextPos = runtime:getGraphicsContext().pos
    contextPos.x = x
    contextPos.y = y
end

function gMOVE(x, y)
    local contextPos = runtime:getGraphicsContext().pos
    contextPos.x = contextPos.x + x
    contextPos.y = contextPos.y + y
end

-- Only support a single arg since we can't express the difference between comma and semicolon separators
function gPRINT(val)
    local str = tostring(val)
    runtime:drawCmd("text", { string = str })
    local context = runtime:getGraphicsContext()
    local w, h = runtime:iohandler().graphicsop("textsize", str, context.font)
    context.pos.x = context.pos.x + w
end

function gPRINTB(text, width, align, top, bottom, margin)
    if not align then align = Align.Left end
    if not top then top = 0 end
    if not bottom then bottom = 0 end
    if not margin then margin = 0 end
    local context = runtime:getGraphicsContext()
    local textw, texth, fontAscent = runtime:iohandler().graphicsop("textsize", text, context.font)

    runtime:drawCmd("fill", {
        x = context.pos.x,
        y = context.pos.y - fontAscent - top,
        width = width,
        height = top + texth + bottom,
        mode = GraphicsMode.Clear
    })

    local textX
    if align == Align.Right then
        textX = context.pos.x + width - margin - textw
    elseif align == Align.Center then
        -- Ugh how does margin work for center, docs aren't clear to me right now...
        textX = context.pos.x + (width // 2) - (textw // 2)
    else
        textX = context.pos.x + margin
    end

    runtime:drawCmd("text", { string = text, x = textX, y = context.pos.y - fontAscent + texth })
end

function gTWIDTH(text)
    local width = runtime:iohandler().graphicsop("textsize", text, runtime:getGraphicsContext().font)
    return width
end

function gIPRINT(text, corner)
    runtime:iohandler().graphicsop("giprint", text, corner)
end

function gLINEBY(dx, dy)
    local context = runtime:getGraphicsContext()
    local x = context.pos.x + dx
    local y = context.pos.y + dy
    runtime:drawCmd("line", { x2 = x, y2 = y })
    context.pos.x = x
    context.pos.y = y
end

function gBOX(width, height)
    runtime:drawCmd("box", { width = width, height = height })
end

function gCIRCLE(radius, fill)
    runtime:drawCmd("circle", { r = radius, fill = fill })
end

function gELLIPSE(hRadius, vRadius, fill)
    runtime:drawCmd("ellipse", { hradius = hRadius, vradius = vRadius, fill = fill })
end

-- TODO gPOLY

function gFILL(width, height, mode)
    runtime:drawCmd("fill", { width = width, height = height, mode = mode })
end

-- TODO gPATT

local KExtraPixelInset = 0x100
local KExtraRoundedCorners = 0x200
local KLoseSinglePixel = 0x400 -- I have no idea wtf this is supposed to do

function gBORDER(flags, w, h)
    if flags & KExtraPixelInset > 0 then
        flags = flags & ~KExtraPixelInset
        local pos = runtime:getGraphicsContext().pos
        -- No I don't understand the reason for this flag either
        runtime:drawCmd("border", { x = pos.x + 1, y = pos.y + 1, width = w - 2, height = h - 2, btype = flags })
    else
        runtime:drawCmd("border", { width = w, height = h, btype = flags })
    end
end

function gXBORDER(type, flags, w, h)
    if not w then
        w = gWIDTH()
        h = gHEIGHT()
    end

    if flags == 0 then
        -- Nothing...
    elseif type == 2 and flags == 1 then
        gBOX(w, h)
    else
        if type == 1 and flags & KExtraPixelInset > 0 then
            flags = flags & ~KExtraPixelInset -- KExtraPixelInset has no effect on type 1
        end
        if type == 2 and flags & KExtraRoundedCorners > 0 then
            flags = flags & ~KExtraRoundedCorners -- rounded corners is ignored on type 2 borders
        end
        if flags & KLoseSinglePixel > 0 then
            flags = flags & ~KLoseSinglePixel
        end
        runtime:drawCmd("border", { width = w, height = h, btype = (type << 16) | flags })
    end
end

function gBUTTON(text, type, width, height, state, bmpId, maskId, layout)
    local s = runtime:saveGraphicsState()
    gUPDATE(false)

    -- The Series 5 appears to ignore type and treat 1 as 2 the same
    -- printf("gBUTTON %s type=%d state=%d\n", text, type, state)

    local textw, texth = runtime:iohandler().graphicsop("textsize", text, s.font)

    lightGrey()
    if state == 0 then
        gXBORDER(2, 0x84, width, height)
        gMOVE(3, 3)
        gFILL(width - 6, height - 6)
    elseif state == 1 then
        gXBORDER(2, 0x42, width, height)
        gMOVE(2, 2)
        gFILL(width - 4, height - 4, GraphicsMode.Clear)
    elseif state == 2 then
        gXBORDER(2, 0x54, width, height)
        gMOVE(3, 3)
        gFILL(width - 5, height - 5)
    end

    -- state 1 should offset the button contents by 1 pixel, and state 2 by 2, so just add the state to the coords
    local textX = s.pos.x + 4 + state
    if bmpId and bmpId > 0 then
        gUSE(bmpId)
        local bmpWidth = gWIDTH()
        local bmpHeight = gHEIGHT()
        gUSE(s.id)
        local bmpOffset = (height - bmpHeight) // 2
        gAT(textX, s.pos.y + bmpOffset + state)
        if maskId and maskId > 0 then
            gUSE(maskId)
            assert(gWIDTH() == bmpWidth and gHEIGHT() == bmpHeight, "Bitmap and mask have different dimensions!")
            gUSE(s.id)
            runtime:drawCmd("copy", {
                srcid = bmpId,
                mask = maskId,
                srcx = 0,
                srcy = 0,
                width = bmpWidth,
                height = bmpHeight,
                mode = 3,
            })
        else
            gCOPY(bmpId, 0, 0, bmpWidth, bmpHeight, 3)
        end
        textX = textX + bmpWidth + 1
    end

    gAT(textX, s.pos.y + ((height + texth) // 2) + state)
    black()
    gPRINT(text)

    runtime:restoreGraphicsState(s) -- also restores gUPDATE state
end

function gCOPY(id, x, y, w, h, mode)
    runtime:drawCmd("copy", {
        srcid = id,
        srcx = x,
        srcy = y,
        width = w,
        height = h,
        mode = mode
    })
end

function gSCROLL(dx, dy, x, y, w, h)
    local rect
    if x then
        rect = { x = x, y = y, w = w, h = h }
    else
        local ctx = runtime:getGraphics().current
        rect = { x = 0, y = 0, w = ctx.width, h = ctx.h }
    end
    runtime:drawCmd("scroll", { dx = dx, dy = dy, rect = rect })
end

function gUPDATE(flag)
    local prevState = runtime:getGraphicsAutoFlush()
    if flag == nil then
        -- gUPDATE
        runtime:flushGraphicsOps()
    else
        -- gUPDATE ON/OFF
        runtime:setGraphicsAutoFlush(flag)
    end
    return prevState
end

function gLINETO(x, y)
    local context = runtime:getGraphicsContext()
    runtime:drawCmd("line", { x2 = x, y2 = y })
    context.pos.x = x
    context.pos.y = y
end

function gGREY(mode)
    local val = mode == 1 and 0xAA or 0
    runtime:getGraphicsContext().color = val
end

function gCOLOR(red, green, blue)
    -- Not gonna bother too much about exact luminosity right now
    local val = (red + green + blue) // 3
    runtime:getGraphicsContext().color = val
end

function gCREATE(x, y, w, h, visible, flags)
    -- printf("gCreate w=%d h=%d flags=%X\n", w, h, flags or 0)
    local id = runtime:iohandler().createWindow(x, y, w, h, flags or 0)
    assert(id, "Failed to createWindow!")
    runtime:newGraphicsContext(id, w, h, true)
    if visible then
        runtime:iohandler().graphicsop("show", id, true)
    end
    return id
end

function gCREATEBIT(w, h, mode)
    -- We ignore mode - bitmaps are always (atm) 8bpp greyscale internally
    local id = runtime:iohandler().createBitmap(w, h)
    assert(id, "Failed to createBitmap!") -- Shouldn't ever fail...
    runtime:newGraphicsContext(id, w, h, false)
    return id
end

function gLOADBIT(path, writable, index)
    -- We implement this in 3 phases:
    -- (1) Get the mbm data and decode it
    -- (2) Tell iohandler to create an empty bitmap
    -- (3) Tell iohandler to blit the decoded MBM data into it

    -- (1)
    local iohandler = runtime:iohandler()
    local data, err = iohandler.fsop("read", path)
    assert(data, err)
    local bitmaps = mbm.parseMbmHeader(data)
    assert(bitmaps, KOplErrGenFail)
    local bitmap = bitmaps[1 + index]
    assert(bitmap, KOplErrNotExists)
    -- (2)
    local id = gCREATEBIT(bitmap.width, bitmap.height)
    -- (3)
    runtime:drawCmd("bitblt", {
        bmpWidth = bitmap.width,
        bmpHeight = bitmap.height,
        bmpBpp = bitmap.bpp,
        bmpStride = bitmap.stride,
        bmpData = mbm.decodeBitmap(bitmap, data)
    })
    return id
end

function gSAVEBIT(path, w, h)
    printf("TODO: gSAVEBIT(%s)\n", path)
end

function gIDENTITY()
    return runtime:getGraphicsContext().id
end

function gX()
    return runtime:getGraphicsContext().pos.x
end

function gY()
    return runtime:getGraphicsContext().pos.y
end

function gWIDTH()
    return runtime:getGraphicsContext().width
end

function gHEIGHT()
    return runtime:getGraphicsContext().height
end

function gPOLY(array)
    local flush = runtime:getGraphicsAutoFlush()
    runtime:setGraphicsAutoFlush(false)
    local prevX, prevY = gX(), gY()
    gAT(array[1], array[2])
    local n = array[3]
    for i = 0, n-1 do
        local dx, dy = array[4 + i*2], array[4 + i*2 + 1]
        if dx & 1 > 0 then
            printf("gmove %d %d\n", (dx - 1) // 2, dy)
            gMOVE((dx - 1)// 2, dy)
        else
            printf("glineby %d %d\n", (dx // 2), dy)
            gLINEBY(dx // 2, dy)
        end
    end
    runtime:setGraphicsAutoFlush(flush)
end

-- Screen APIs

function SCREEN(w, h, x, y)
    -- Since we don't draw text into the main window this command doesn't
    -- currently have any effect, but we will update the info returned by
    -- SCREENINFO just to be polite.
    local screen = runtime:getGraphics().screen
    screen.w = w
    screen.h = h
    if not x then
        local scrw, scrh = runtime:iohandler().getScreenSize()
        x = (scrw - w) // 2
        y = (scrh - h) // 2
    end
    screen.x = x
    screen.y = y
end
-- Menu APIs

function mINIT()
    runtime:setMenu({
        cascades = {},
    })
end

-- File APIs

function MKDIR(path)
    local err = runtime:iohandler().fsop("mkdir", path)
    if err ~= KErrNone then
        error(err)
    end
end

return _ENV
