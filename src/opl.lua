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
    -- TODO implement properly
    runtime:iohandler().print(text .. "\n")
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

function gBORDER(flags, w, h)
    runtime:drawCmd("border", { width = w, height = h, btype = flags })
end

function gXBORDER(type, flags, w, h)
    if not w then
        w = gWIDTH()
        h = gHEIGHT()
    end

    if flags == 0 then
        -- Nothing...
    elseif flags == 1 then
        gBOX(w, h)
    else
        runtime:drawCmd("border", { width = w, height = h, btype = (type << 16) | flags })
    end
end

function gBUTTON(text, type, width, height, state, bmpId, maskId, layout)
    -- TODO utterly terrible
    local id = gIDENTITY()
    local prevX, prevY = gX(), gY()

    -- The Series 5 appears to ignore type and treat 1 as 2 the same
    printf("TODO BUTTON %s type=%d state=%d\n", text, type, state)

    if state == 0 then
        gXBORDER(2, 0x84, width, height)
    elseif state == 1 then
        gXBORDER(2, 0x42, width, height)
    elseif state == 2 then
        gXBORDER(2, 0x54, width, height)
    end

    gMOVE(2, 2)
    if bmpId and bmpId > 0 then
        gUSE(bmpId)
        local bmpWidth = gWIDTH()
        local bmpHeight = gHEIGHT()
        gUSE(id)
        local bmpOffset = (height - bmpHeight) // 2
        gMOVE(0, bmpOffset)
        gCOPY(bmpId, 0, 0, bmpWidth, bmpHeight, 3)
        gMOVE(bmpWidth + 2, -bmpOffset)
    end

    gMOVE(0, height - 2)
    gPRINT(text)
    -- gAT(prevX, prevY)
    -- gBOX(width, height)
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
    if flag == nil then
        -- gUPDATE
        runtime:flushGraphicsOps()
    else
        -- gUPDATE ON/OFF
        runtime:setGraphicsAutoFlush(flag)
    end
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
