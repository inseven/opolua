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

--

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

local string_byte = string.byte

local mbm = require("mbm")

function _setRuntime(r)
    _ENV.runtime = r
    -- Load everything that's defined elsewhere
    local separateModules = {
        "menu",
        "dialog",
    }
    for _, module in ipairs(separateModules) do
        for name, fn in pairs(runtime:require(module)) do
            if type(fn) == "function" then
                assert(_ENV[name] == nil, "Duplicate definition of "..name)
                _ENV[name] = fn
            end
        end
    end
end

function darkGrey()
    gCOLOR(0x55, 0x55, 0x55)
end

function lightGrey()
    gCOLOR(0xAA, 0xAA, 0xAA)
end

function black()
    gCOLOR(0, 0, 0)
end

function white()
    gCOLOR(0xFF, 0xFF, 0xFF)
end

-- Graphics APIs

function gCLOSE(id)
    runtime:closeGraphicsContext(id)
end

function gUSE(id)
    -- printf("gUSE(%d)\n", id)
    runtime:setGraphicsContext(id)
    runtime:setResource("ginfo", nil)
end

function gVISIBLE(show)
    local context = runtime:getGraphicsContext()
    assert(context.isWindow, KErrInvalidWindow)
    runtime:iohandler().graphicsop("show", context.id, show)
end

function gFONT(id)
    local font = runtime:getFont(id)
    if not font then
        printf("No font found for 0x%08X\n", id)
        error(KErrFontNotLoaded)
    end
    runtime:getGraphicsContext().fontUid = font.uid
    runtime:setResource("ginfo", nil)
end

function gGMODE(mode)
    runtime:getGraphicsContext().mode = mode
    runtime:setResource("ginfo", nil)
end

function gTMODE(tmode)
    runtime:getGraphicsContext().tmode = tmode
    runtime:setResource("ginfo", nil)
end

function gSTYLE(style)
    runtime:getGraphicsContext().style = style
    runtime:setResource("ginfo", nil)
end

function gORDER(id, pos)
    local graphics = runtime:getGraphics()
    assert(graphics[id] and graphics[id].isWindow, KErrInvalidWindow)
    runtime:iohandler().graphicsop("order", id, pos)
end

function gRANK(id)
    local ctx = runtime:getGraphicsContext()
    assert(ctx and ctx.isWindow, KErrInvalidWindow)
    local result = runtime:iohandler().graphicsop("rank", ctx.id)
    if result < 0 then
        error(result)
    end
    return result
end

function gCLS()
    -- printf("gCLS\n")
    local context = runtime:getGraphicsContext()
    context.pos = { x = 0, y = 0 }
    runtime:drawCmd("fill", { width = context.width, height = context.height, mode = 1 })
end

function gAT(x, y)
    local contextPos = runtime:getGraphicsContext().pos
    contextPos.x = assert(x)
    contextPos.y = assert(y)
end

function gMOVE(x, y)
    local contextPos = runtime:getGraphicsContext().pos
    contextPos.x = contextPos.x + x
    contextPos.y = contextPos.y + y
end

-- Only support a single arg since we can't express the difference between comma and semicolon separators
function gPRINT(val)
    local str = tostring(val)
    local context = runtime:getGraphicsContext()
    local w, h, ascent = gTWIDTH(str)
    -- gPRINT and friends have this nonsense about text coords being relative to
    -- the baseline rather than the top left or bottom left corners; all our
    -- native operations assume text coords are for the top-left of the text.
    -- Since we always have to ask about the text size anyway, fix it up here.
    runtime:drawText(str, context.pos.x, context.pos.y - ascent)
    context.pos.x = context.pos.x + w
end

function gPRINTB(text, width, align, top, bottom, margin)
    if not align then align = KgPrintBLeftAligned end
    if not top then top = 0 end
    if not bottom then bottom = 0 end
    if not margin then margin = 0 end
    local context = runtime:getGraphicsContext()
    local textw, texth, fontAscent = gTWIDTH(text)

    runtime:drawCmd("fill", {
        x = context.pos.x,
        y = context.pos.y - fontAscent - top,
        width = width,
        height = top + texth + bottom,
        mode = KgModeClear
    })

    local textX
    if align == KgPrintBRightAligned then
        textX = context.pos.x + width - margin - textw
    elseif align == KgPrintBCentredAligned then
        -- Ugh how does margin work for center, docs aren't clear to me right now...
        textX = context.pos.x + (width // 2) - (textw // 2)
    else
        textX = context.pos.x + margin
    end

    runtime:drawText(text, textX, context.pos.y - fontAscent, KgModeSet)
end

function gPRINTCLIP(text, width)
    while #text > 0 and gTWIDTH(text) > width do
        text = text:sub(1, -2)
    end
    gPRINT(text)
    return #text
end

function gXPRINT(text, flags)
    local context = runtime:getGraphicsContext()
    local ascent = runtime:getFont().ascent
    -- gXPRINT always behaves like mode is replace
    runtime:drawText(text, context.pos.x, context.pos.y - ascent, KtModeReplace, flags)
    -- Note, doesn't increment context.pos.x
end

function gTWIDTH(text, fontId, style)
    local context = runtime:getGraphicsContext()
    -- fontId and style param are an opolua extension
    local font
    if fontId then
        font = assert(runtime:getFont(fontId), "Bad font id!")
        if style == nil then
            style = 0
        end
    else
        font = runtime:getFont()
        style = context.style
    end
    local bold = (style & KgStyleBold) ~= 0
    local width = 0
    for i = 1, #text do
        local chw = font.widths[1 + string_byte(text, i)]
        width = width + chw
        if bold and chw > 0 then
            width = width + 1
        end
    end
    return width, font.height, font.ascent, font.descent
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

function gFILL(width, height, mode)
    -- printf("gFILL %d,%d %dx%d\n", gX(), gY(), width, height)
    runtime:drawCmd("fill", { width = width, height = height, mode = mode })
end

function gBORDER(flags, w, h)
    -- gBORDER(...) is equivalent to gXBORDER(0, ...)
    gXBORDER(0, flags, w, h)
end

function gXBORDER(type, flags, w, h)
    local context = runtime:getGraphicsContext()
    local x = context.pos.x
    local y = context.pos.y
    if not w then
        x = 0
        y = 0
        w = context.width
        h = context.height
    end
    printf("gXBorder type=%d flags=%x %dx%d\n", type, flags, w, h)

    -- KBordLosePixel has no effect on ANY border type, that I can see. The docs suggest it's supposed to make a less
    -- rounded corner (contrasting with KBordRoundCorners) on series 3 style buttons (type=0 or type=1), but it does
    -- not appear to be implemented - at least on my Series 5.
    flags = flags & ~KBordLosePixel

    if type == 0 then
        if flags & KBordGapAllRound > 0 then
            -- This flag is a straighforward "inset everything by one pixel" so doesn't require distinguishing native-side
            flags = flags & ~KBordGapAllRound
            x = x + 1
            y = y + 1
            w = w - 2
            h = h - 2
        end
        runtime:drawCmd("border", { x = x, y = y, width = w, height = h, btype = flags })
    elseif type == 1 then
        flags = flags & ~(KBordGapAllRound) -- The only flag that has an effect on type 1 is KBordRoundCorners
        runtime:drawCmd("border", { x = x, y = y, width = w, height = h, btype = (type << 16) | flags })
    elseif type == 2 then
        if flags == 0 then
            return -- It's a no-op
        end
        if flags & KBordRoundCorners > 0 and flags ~= 0x294 then
            -- It doesn't make any sense logically for the round corners variants to be the same as the "gap all round"
            -- variant. I think it's likely to be a drop-through in a switch statement in the original implementation,
            -- or something like that. It makes even LESS sense that "deep raised with outline" (0x94) is only border
            -- type where 194 and 294 are completely different.
            flags = (flags & ~KBordRoundCorners) | KBordGapAllRound
        end
        runtime:drawCmd("border", { x = x, y = y, width = w, height = h, btype = (type << 16) | flags })
    end
end

function gBUTTON(text, type, width, height, state, bmpId, maskId, layout)
    local s = runtime:saveGraphicsState()
    gUPDATE(false)

    -- The Series 5 appears to ignore type and treat 1 as 2 the same
    -- printf("gBUTTON %s type=%d state=%d\n", text, type, state)

    local textw = 0
    local texth = 0
    local _, descent, lineh
    for line in text:gmatch("[^\n]*") do
        local w, h, _, d = gTWIDTH(line)
        textw = math.max(textw, w)
        texth = texth + h
        descent = d
        lineh = h
    end

    local _, _, displayMode = runtime:getScreenInfo()
    local isColor = displayMode >= KColorgCreate256ColorMode
    if isColor then
        gCOLOR(0x99, 0x99, 0xCC)
    else
        lightGrey()
    end
    gCOLORBACKGROUND(0xFF, 0xFF, 0xFF)

    if state == 0 then
        gXBORDER(2, 0x84, width, height)
        gMOVE(3, 3)
        gFILL(width - 6, height - 6)
    elseif state == 1 then
        gXBORDER(2, 0x42, width, height)
        gMOVE(2, 2)
        if isColor then
            gCOLOR(0x88, 0x88, 0x88)
        else
            white()
        end
        gFILL(width - 4, height - 4)
    elseif state == 2 then
        if isColor then
            gCOLOR(0x66, 0x66, 0x99)
        end
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
            -- Yes, examples where the mask is smaller than the bitmap exist...
            if gWIDTH() > bmpWidth or gHEIGHT() > bmpHeight then
                printf("%dx%d != %dx%d\n", gWIDTH(), gHEIGHT(), bmpWidth, bmpHeight)
                error("bitmap mask cannot be larger than the bitmap!")
            end
            gUSE(s.id)
            runtime:drawCmd("copy", {
                srcid = bmpId,
                mask = maskId,
                srcx = 0,
                srcy = 0,
                width = bmpWidth,
                height = bmpHeight,
                mode = KtModeReplace,
            })
        else
            gCOPY(bmpId, 0, 0, bmpWidth, bmpHeight, KtModeReplace)
        end
        textX = textX + bmpWidth + 1
    end

    if bmpId == nil then
        layout = KButtTextTop
    end

    local pos = (layout or 0) & 0xF
    if pos == KButtTextTop or pos == KButtTextBottom then
        -- We need to center the text (note, we don't actually support layout when there actually is an image, yet)
        textX = s.pos.x + state + (width - textw) // 2
    end
    local textY = s.pos.y + ((height - texth + descent) // 2) + state
    black()
    for line in text:gmatch("[^\n]*") do
        runtime:drawText(line, textX, textY, KgModeSet)
        textY = textY + lineh
    end

    runtime:restoreGraphicsState(s) -- also restores gUPDATE state
end

function gCOPY(id, x, y, w, h, mode)
    -- printf("gCOPY from %d(%d,%d %dx%d) to %d(%d,%d %dx%d)\n",
    --     id, x, y, w, h, gIDENTITY(), gX(), gY(), w, h)
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
        rect = { x = 0, y = 0, w = ctx.width, h = ctx.height }
    end
    -- printf("gSCROLL(dx=%d dy=%d x=%d y=%d w=%d h=%d)\n", dx, dy, rect.x, rect.y, rect.w, rect.h)
    runtime:drawCmd("scroll", { dx = dx, dy = dy, rect = rect })
end

function gPATT(id, width, height, mode)
    runtime:drawCmd("patt", {
        srcid = id,
        width = width,
        height = height,
        mode = mode
    })
end

function gUPDATE(flag)
    -- printf("gUPDATE %s\n", flag)
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

function gCOLOR(red, green, blue)
    -- printf("gCOLOR(id=%d, r=%x, g=%x, b=%x)\n", gIDENTITY(), red, green, blue) 
    runtime:getGraphicsContext().color = { r = red, g = green, b = blue }
    runtime:setResource("ginfo", nil)
end

function gCOLORBACKGROUND(red, green, blue)
    runtime:getGraphicsContext().bgcolor = { r = red, g = green, b = blue }
    runtime:setResource("ginfo", nil)
end

function gSETWIN(x, y, w, h)
    -- printf("gSETWIN id=%d %d,%d %sx%s\n", gIDENTITY(), x, y, w, h)
    -- runtime:flushGraphicsOps()
    local ctx = runtime:getGraphicsContext()
    ctx.winX = x
    ctx.winY = y
    if w then
        ctx.width = w
        ctx.height = h
    end
    if w == 0 then w = 1 end
    if h == 0 then h = 1 end
    runtime:iohandler().graphicsop("setwin", ctx.id, x, y, w, h)
end

function gCREATE(x, y, w, h, visible, flags)
    -- printf("gCREATE w=%d h=%d flags=%X", w, h, flags or 0)
    local ctx = runtime:newGraphicsContext(w, h, true, (flags or 0) & 0xF)
    local id = ctx.id
    -- Since neither backend (Swift/CoreGraphics or Qt) likes zero-sized bitmaps or windows, we're going to fudge it
    -- here.
    if w == 0 then w = 1 end
    if h == 0 then h = 1 end

    local err = runtime:iohandler().createWindow(id, x, y, w, h, flags or KColorgCreate2GrayMode) or KErrNone
    if err ~= KErrNone then
        runtime:closeGraphicsContext(id)
        error(err)
    end
    -- printf(" id=%d\n", id)
    ctx.winX = x
    ctx.winY = y
    if visible then
        runtime:iohandler().graphicsop("show", id, true)
    end
    gUSE(id) -- Creating new window sets it as current
    return id
end

function gCREATEBIT(w, h, mode)
    -- printf("gCREATEBIT w=%d h=%d mode=%X", w, h, mode or 0)
    -- Mask mode here because some apps incorrectly include shadow flags as per gCREATE
    mode = (mode or 0) & 0xF
    local ctx = runtime:newGraphicsContext(w, h, false, mode)
    local id = ctx.id
    -- See comment in gCREATE
    if w == 0 then w = 1 end
    if h == 0 then h = 1 end

    local err = runtime:iohandler().createBitmap(id, w, h, mode) or KErrNone
    if err ~= KErrNone then
        runtime:closeGraphicsContext(id)
        error(err)
    end
    -- printf(" id=%d\n", id)
    gUSE(id) -- Creating new bitmap sets it as current
    return id
end

function gLOADBIT(path, writable, index)
    -- We implement this in 3 phases:
    -- (1) Get the mbm data and decode it
    -- (2) Tell iohandler to create an empty bitmap
    -- (3) Tell iohandler to blit the decoded MBM data into it

    -- (1)
    -- printf("gLOADBIT %s mbmid=%d", path, 1 + index)
    local iohandler = runtime:iohandler()
    local absPath = runtime:abs(path)
    if not EXIST(absPath) then
        -- It's allowed to omit the .pic
        absPath = absPath .. ".PIC"
    end
    local data, err = iohandler.fsop("read", absPath)
    assert(data, err)
    local bitmaps = mbm.parseMbmHeader(data)
    assert(bitmaps, KErrGenFail)
    local bitmap = bitmaps[1 + index]
    assert(bitmap, KErrNotExists)
    -- (2)
    local id = gCREATEBIT(bitmap.width, bitmap.height, bitmap.mode)
    -- printf(" %dx%d drawableid=%d\n", bitmap.width, bitmap.height, id)
    -- (3)
    bitmap.imgData = bitmap:getImageData()
    runtime:drawCmd("bitblt", { bitmap = bitmap, mode = KtModeReplace })
    -- runtime:flushGraphicsOps()
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

function gORIGINX()
    local context = runtime:getGraphicsContext()
    assert(context.isWindow, KErrInvalidWindow)
    return context.winX
end

function gORIGINY()
    local context = runtime:getGraphicsContext()
    assert(context.isWindow, KErrInvalidWindow)
    return context.winY
end

function gPOLY(array)
    local flush = runtime:getGraphicsAutoFlush()
    runtime:setGraphicsAutoFlush(false)
    local prevX, prevY = gX(), gY()
    gAT(array[KgPolyAStartX], array[KgPolyAStartY])
    local n = array[KgPolyANumPairs]
    for i = 0, n-1 do
        local dx, dy = array[KgPolyANumDx1 + i*2], array[KgPolyANumDy1 + i*2]
        if dx & 1 > 0 then
            -- printf("gmove %d %d\n", (dx - 1) // 2, dy)
            gMOVE((dx - 1)// 2, dy)
        else
            -- printf("glineby %d %d\n", (dx // 2), dy)
            gLINEBY(dx // 2, dy)
        end
    end
    runtime:setGraphicsAutoFlush(flush)
end

function gINVERT(w, h)
    runtime:drawCmd("invert", { width = w, height = h })
end

function gSETPENWIDTH(width)
    -- printf("gSETPENWIDTH %d\n", width)
    runtime:getGraphicsContext().penwidth = width
end

function gCLOCK(mode)
    local context = runtime:getGraphicsContext()
    assert(context.isWindow, KErrInvalidWindow)
    local x, y
    if mode then
        x, y = context.pos.x, context.pos.y
    end
    runtime:iohandler().graphicsop("clock", context.id, { mode = mode, position = { x = x, y = y }})
end

-- Screen APIs

local function drawInfoPrint(drawable, text, corner)
    gUPDATE(false)
    local screenWidth, screenHeight = runtime:getScreenInfo()
    local winHeight = 23 -- 15 plus 4 pixels top and bottom
    gUSE(drawable)
    gFONT(KFontArialNormal15)

    local cornerInset = 5
    local inset = 6
    local textWidth, textHeight, ascent = gTWIDTH(text)
    local w = math.min(screenWidth - 2 * cornerInset, textWidth + inset * 2)
    local actualTextWidth = w - 2 * inset

    local x, y
    if corner == KBusyTopLeft then
        x = cornerInset
        y = cornerInset
    elseif corner == KBusyBottomLeft then
        x = cornerInset
        y = screenHeight - winHeight - cornerInset
    elseif corner == KBusyTopRight then
        x = screenWidth - w - cornerInset
        y = cornerInset
    elseif corner == KBusyBottomRight then
        x = screenWidth - w - cornerInset
        y = screenHeight - winHeight - cornerInset
    else
        error("Bad corner")
    end
    gSETWIN(x, y, w, winHeight)
    gCOLOR(0, 0, 0)
    gAT(0, 0)
    gFILL(w, winHeight)
    gXBORDER(2, 0x94)
    gCOLOR(255, 255, 255)
    gAT(inset, 4 + ascent)
    gPRINTCLIP(text, w - 2 * inset)
    return { x = inset, y = gY() - ascent, w = actualTextWidth, h = textHeight }
end

function gIPRINT(text, corner)
    if text == "" then
        runtime:iohandler().graphicsop("giprint", 0)
        return
    end
    local state = runtime:saveGraphicsState()
    local infoWinId = runtime:getResource("infowin")
    if not infoWinId then
        infoWinId = gCREATE(0, 0, 1, 1, false, KColorgCreate4GrayMode)
        runtime:setResource("infowin", infoWinId)
    end
    drawInfoPrint(infoWinId, text, corner or KBusyBottomRight)
    runtime:flushGraphicsOps()
    runtime:iohandler().graphicsop("giprint", infoWinId)
    runtime:restoreGraphicsState(state)
end

function BUSY(text, corner, delay)
    local busyWinId = runtime:getResource("busy")
    if busyWinId then
        runtime:iohandler().graphicsop("busy", 0)
        runtime:setResource("busy", nil)
        gCLOSE(busyWinId)
    end
    if not text then
        return
    end

    local state = runtime:saveGraphicsState()
    busyWinId = gCREATE(0, 0, 1, 1, false, KColorgCreate4GrayMode)
    runtime:setResource("busy", busyWinId)
    local textRect = drawInfoPrint(busyWinId, text, corner or KBusyBottomLeft)

    local bmp = require("opx.bmp")
    local sprite = bmp.SPRITECREATE(runtime, busyWinId, textRect.x, textRect.y, 0)
    local blackBmp = gCREATEBIT(textRect.w, textRect.h, KColorgCreate2GrayMode)
    gCOLOR(0, 0, 0)
    gFILL(gWIDTH(), gHEIGHT())
    gUSE(busyWinId)
    runtime:flushGraphicsOps()
    bmp.SPRITEAPPEND(runtime, 0.5, blackBmp, blackBmp, true, 0, 0)
    bmp.SPRITEAPPEND(runtime, 0.5, blackBmp, blackBmp, false, 0, 0)
    bmp.SPRITEDRAW(runtime)

    if delay and delay > 0 then
        runtime:iohandler().graphicsop("busy", busyWinId, delay)
    else
        -- Jusy show it now
        gVISIBLE(true)
    end
    runtime:restoreGraphicsState(state)
end

function INPUT(var, initVal)
    local trapped = runtime:getTrap()
    local isint = var:type() == DataTypes.EWord
    local islong = var:type() == DataTypes.ELong
    local isfloat = var:type() == DataTypes.EReal
    local maxChars
    if isint then
        maxChars = 6
    elseif islong then
        maxChars = 11
    elseif isfloat then
        maxChars = 23 -- Or something like that
    else
        maxChars = var:stringMaxLen()
    end

    -- Special case for defaultiohandler
    local iohandlerInput = runtime:iohandler().input
    if iohandlerInput then
        while true do
            local result = iohandlerInput(initVal)
            if result == nil and trapped then
                error(KErrEsc)
            elseif isint or islong or isfloat then
                local n = tonumber(result)
                if n then
                    var(n)
                    break
                elseif trapped then
                    error(KErrGenFail)
                end
            elseif result then
                var(result)
                break
            else
                printf("? ")
            end
        end
        runtime:setTrap(false)
        return
    end

    local screen = runtime:getGraphics().screen
    local origx, origy = runtime:getTextCursorXY()
    local editor = require("editor").Editor()
    local lastLen = 0
    local function onEditorChanged()
        CURSOR(nil)
        AT(origx, origy)
        if #editor.value < lastLen then
            PRINT(string.rep(" ", lastLen))
            AT(origx, origy)
        end
        -- Easiest way to figure out where the cursor should be is to print up to the cursor, then check where we are,
        -- then print the rest (this handles the printed text wrapping onto a new line).
        PRINT(editor.value:sub(1, editor.cursorPos - 1))
        local cursorx, cursory = runtime:getTextCursorXY()
        PRINT(editor.value:sub(editor.cursorPos))
        local finalx, finaly = runtime:getTextCursorXY()
        -- Well, nearly anyway
        if cursorx == screen.w + 1 then
            cursorx = 1
            cursory = math.min(cursory + 1, screen.h)
        end
        AT(cursorx, cursory)
        CURSOR(true)
        AT(finalx, finaly)
        lastLen = #editor.value
    end
    editor.view = {
        canUpdate = function(_, newVal)
            return #newVal <= maxChars
        end,
        onEditorChanged = onEditorChanged,
    }
    CURSOR(true)
    if initVal then
        editor:setValue(initVal)
    end
    while true do
        local k = GET()
        if k == KKeyEnter then
            CURSOR(nil)
            PRINT(KLineBreakStr)
            if isint or islong then
                local n = tonumber(editor.value, 10)
                if n and ((islong and n >= KMinLong and n <= KMaxLong) or (isint and n >= KMinInt and n <= KMaxInt)) then
                    break
                end
            elseif isfloat then
                if tonumber(editor.value) then
                    break
                end
            else
                break
            end
            -- Only reach here if input was not valid
            if trapped then
                error(KErrGenFail)
            else
                PRINT("?")
                origx, origy = runtime:getTextCursorXY()
                editor:setValue("")
            end
        elseif k == KKeyEsc then
            if editor.value == "" and trapped then
                CURSOR(nil)
                error(KErrEsc)
            else
                editor:setValue("")
            end
        else
            editor:handleKeyPress(k, 0)
        end
    end

    if isint or islong then
        var(tonumber(editor.value, 10))
    elseif isfloat then
        var(tonumber(editor.value))
    else
        var(editor.value)
    end
    runtime:setTrap(false)
end

-- Unlike the OPL CURSOR command, the x and y coordinates are explicit and indicate the top left of the cursor.
-- Therefore, no ascent parameter is necessary.
function CURSOR(id, x, y, w, h, t)
    -- printf("CURSOR id=%s, x=%s, y=%s, w=%s, h=%s, t=%s\n", id, x, y, w, h, t)
    runtime:flushGraphicsOps()
    runtime:setResource("ginfo", nil)

    local isTextCursor = false
    if id == true then
        -- CURSOR(true) means text cursor, in the default window, at the current text cursor position
        local screen = runtime:getGraphics().screen
        id = KDefaultWin
        x = screen.x + (screen.cursorx * screen.charw)
        y = screen.y + (screen.cursory * screen.charh)
        w = screen.charw
        h = screen.charh
        isTextCursor = true
    end

    local cursor = runtime:getResource("cursor")
    if not id then
        runtime:iohandler().graphicsop("cursor", nil)
        runtime:setResource("cursor", nil)
    else
        local win = assert(runtime:getGraphicsContext(id), "Bad id for CURSOR")
        assert(win.isWindow, "Cannot call CURSOR on a bitmap")

        if t == nil then
            t = 0
        end

        t = t & ~1 -- Explicitly ignore obloid cursor flag

        if cursor and id == cursor.id
            and x == cursor.rect.x and y == cursor.rect.y
            and w == cursor.rect.w and h == cursor.rect.h and t == cursor.flags then
            -- Cursor has not moved or changed, don't interrupt the timing
            return
        end

        if not cursor then
            cursor = {}
            runtime:setResource("cursor", cursor)
        end
        cursor.id = id
        cursor.rect = {
            x = x,
            y = y,
            w = w,
            h = h,
        }
        cursor.flags = t
        cursor.isText = isTextCursor
        runtime:iohandler().graphicsop("cursor", cursor)
    end
end

function FONT(id, style)
    -- printf("FONT(0x%08X, %d)\n", id, style)
    local screen = runtime:getGraphics().screen
    local defaultWin = runtime:getGraphicsContext(KDefaultWin)
    local font = runtime:getFont(id)
    assert(font, KErrFontNotLoaded)

    -- Font keyword always resets text window size, position and text pos
    local charw = font.widths[1 + string.byte("0")]
    local charh = font.height
    local numcharsx = defaultWin.width // charw
    local numcharsy = defaultWin.height // charh
    runtime:getGraphics().screen = {
        x = (defaultWin.width - numcharsx * charw) // 2,
        y = (defaultWin.height - numcharsy * charh) // 2,
        w = numcharsx,
        h = numcharsy,
        cursorx = 0,
        cursory = 0,
        charh = charh,
        charw = charw,
        fontUid = font.uid,
        style = 0,
    }
    STYLE(style)
end

function STYLE(style)
    -- Only underline or inverse are supported (but not both)
    style = style & (KgStyleUnder|KgStyleInverse)
    if style == (KgStyleUnder|KgStyleInverse) then
        style = KgStyleInverse
    end
    runtime:getGraphics().screen.style = style
end

function SCREEN(widthInChars, heightInChars, xInChars, yInChars)
    -- printf("SCREEN %d %d %s %s\n", widthInChars, heightInChars, xInChars, yInChars)

    -- (x,y) being (0,0) means centre the screen, whereas 1,1 means put it in top left (well, the top left char pos
    -- if the screen were full width)
    
    local screen = runtime:getGraphics().screen
    local defaultWin = runtime:getGraphicsContext(KDefaultWin)

    -- Both of these are in chars too
    local maxScreenWidth = defaultWin.width // screen.charw
    local maxScreenHeight = defaultWin.height // screen.charh

    if xInChars == 0 and yInChars == 0 then
        xInChars = ((maxScreenWidth - widthInChars) // 2) + 1
        yInChars = ((maxScreenHeight - heightInChars) // 2) + 1
    end

    if xInChars < 1 or yInChars < 1 or widthInChars < 1 or heightInChars < 1
        or xInChars - 1 + widthInChars > maxScreenWidth
        or yInChars - 1 + heightInChars > maxScreenHeight then
        error(KErrInvalidArgs)
    end
    screen.w = widthInChars
    screen.h = heightInChars

    local marginx = (defaultWin.width % screen.charw) // 2
    local marginy = (defaultWin.height % screen.charh) // 2
    screen.x = marginx + (xInChars - 1) * screen.charw
    screen.y = marginy + (yInChars - 1) * screen.charh

    -- Note, calling SCREEN does not modify cursor position (other than to cap it if necessary...)
    screen.cursorx = math.min(screen.cursorx, screen.w - 1)
    screen.cursory = math.min(screen.cursory, screen.h - 1)
end

function AT(x, y)
    local screen = runtime:getGraphics().screen
    assert(x > 0 and y > 0, KErrInvalidArgs)
    screen.cursorx = x - 1
    screen.cursory = y - 1
    -- TODO cursor
end

function CLS()
    local prev = gIDENTITY()
    gUSE(KDefaultWin)
    local state = runtime:saveGraphicsState()
    local screen = runtime:getGraphics().screen
    gAT(screen.x, screen.y)
    gFILL(screen.w * screen.charw, screen.h * screen.charh, KgModeClear)
    screen.cursorx = 0
    screen.cursory = 0
    runtime:restoreGraphicsState(state)
    gUSE(prev)
    runtime:flushGraphicsOps()
end

function PRINT(str)
    local handlerPrint = runtime:iohandler().iohPrint
    if handlerPrint then
        handlerPrint(str)
        return
    end

    local prevId = gIDENTITY()
    gUSE(KDefaultWin)
    local state = runtime:saveGraphicsState()
    gUPDATE(false)
    local screen = runtime:getGraphics().screen
    gCOLOR(0, 0, 0)
    gFONT(screen.fontUid)
    gSTYLE(screen.style)
    gTMODE(KtModeReplace)
    local strPos = 1
    local strLen = #str
    local charX = screen.cursorx
    local charY = screen.cursory
    local maxX = screen.w
    local maxY = screen.h
    while strPos <= strLen do
        local lineEnd = str:find(KLineBreakStr, strPos, true)
        local endPos = lineEnd
        if not endPos then
            endPos = #str + 1
        end
        local remaining = endPos - strPos
        local lineSpace = maxX - charX
        if lineSpace ~= 0 and lineSpace < remaining then
            remaining = lineSpace
        end
        local frag = str:sub(strPos, strPos + remaining - 1)
        strPos = strPos + #frag
        if #frag > 0 then
            if charX == maxX then
                -- Wrap to next line
                charX = 0
                charY = charY + 1
            end
            while charY >= maxY do
                gSCROLL(0, -screen.charh, screen.x, screen.y, screen.w * screen.charw, screen.h * screen.charh)
                charY = charY - 1
            end
            drawText(frag, screen.x + charX * screen.charw, screen.y + charY * screen.charh, KtModeReplace)
            charX = charX + #frag
        end
        if lineEnd and strPos == lineEnd then
            -- newline
            charX = 0
            charY = charY + 1
            strPos = strPos + 1
        end
    end
    screen.cursorx = charX
    screen.cursory = charY
    -- Restore drawable 1's state
    runtime:restoreGraphicsState(state)
    -- and switch back to prev
    gUSE(prevId)
end

function drawText(str, x, y, mode, xflags)
    local s = runtime:saveGraphicsState()
    gUPDATE(false)
    local ctx = runtime:getGraphicsContext()
    local font = runtime:getFont(ctx.fontUid)
    if x == nil then
        x = ctx.pos.x
    end
    if y == nil then
        y = ctx.pos.y
    end
    if mode == nil then
        mode = ctx.tmode
    end
    local bold = (ctx.style & KgStyleBold) ~= 0
    local underlined = (ctx.style & KgStyleUnder) ~= 0
    local italic = (ctx.style & KgStyleItalic) ~= 0
    local inverse = (ctx.style & KgStyleInverse) ~= 0 -- Note, different to KtModeInvert
    local xflagsInverse = xflags and xflags >= KgXPrintInverse and xflags <= KgXPrintThinInverseRound
    local thin = xflags == KgXPrintThinInverse or xflags == KgXPrintThinInverseRound or xflags == KgXPrintThinUnderlined

    if xflagsInverse then
        -- Yes, if both gSTYLE inverse and gXPRINT inverse are set, they cancel each other out
        inverse = not inverse
    end

    if xflags == KgXPrintThinUnderlined then
        -- This smells like a bug, but gSTYLE inverse doesn't apply on KgXPrintThinUnderlined, despite the fact that it
        -- does with KgXPrintUnderlined and normal...
        inverse = false
    end

    local fgcol, bgcol = ctx.color, ctx.bgcolor
    if inverse then
        -- The inverse style appears to completely override the mode.
        mode = KtModeReplace
        fgcol, bgcol = bgcol, fgcol
    end

    gCOLOR(fgcol.r, fgcol.g, fgcol.b)
    gCOLORBACKGROUND(bgcol.r, bgcol.g, bgcol.b)

    -- In order to support drawing in something other than black we cannot just do a plain KgModeSet or KtModeReplace
    -- gCOPY here. We have to exploit KgModeClear which fills with the background colour only the pixels that were
    -- black in the src image. And fix up the actual background if necessary. KtModeInvert is just baffling in behaviour
    -- so we're going to ignore that for now.

    if mode == KtModeReplace then
        local function drawRoundedRect(w, h)
            gMOVE(1, 0)
            gLINEBY(w - 2, 0)
            gMOVE(0, 1)
            gLINEBY(0, h - 2)
            gMOVE(-1, 0)
            gLINEBY(-(w - 2), 0)
            gMOVE(0, -1)
            gLINEBY(0, -(h - 2))
            gMOVE(0, -1)
        end

        local bx, by, bw, bh = x, y, gTWIDTH(str), font.height

        gGMODE(KgModeClear)
        -- Non-thin gXPRINT styles draw an extra pixel all round (except for underlined which for padding purposes also
        -- counts as thin...)
        if xflags == KgXPrintThinInverseRound then
            gAT(bx, by)
            drawRoundedRect(bw, bh)
            gAT(bx + 1, by + 1)
            gFILL(bw - 2, bh - 2, KgModeClear)
        elseif xflags == KgXPrintNormal or xflags == KgXPrintInverseRound then
            -- +1 pixel, with rounded corners
            gAT(bx - 1, by - 1)
            drawRoundedRect(bw + 2, bh + 2)
            gAT(bx, by)
            gFILL(bw, bh, KgModeClear)
        elseif xflags == KgXPrintInverse then
            -- +1 pixel, not rounded
            gAT(bx - 1, by - 1)
            gFILL(bw + 2, bh + 2, KgModeClear)
        elseif xflags == nil or xflags == KgXPrintUnderlined or xflags == KgXPrintThinUnderlined or xflags == KgXPrintThinInverse then
            gAT(bx, by)
            gFILL(bw, bh, KgModeClear)
        end
    end
    gGMODE(mode)

    local opcol = (mode == KgModeClear) and bgcol or fgcol
    local startx = x
    local h, maxwidth, widths = font.height, font.maxwidth, font.widths

    local op = {
        srcid = font.id,
        mode = mode == KgModeInvert and KgModeInvert or KgModeClear,
        bgcolor = opcol,
        x = x,
        y = y,
    }        

    local function opadd(srcx, srcy, w, h, x, y)
        local n = #op
        op[n + 1] = srcx
        op[n + 2] = srcy
        op[n + 3] = w
        op[n + 4] = h
        op[n + 5] = x
        op[n + 6] = y
        -- runtime:drawCmd("copy", {
        --     x = x,
        --     y = y,
        --     srcid = font.id,
        --     srcx = srcx,
        --     srcy = srcy,
        --     width = w,
        --     height = h,
        --     mode = op.mode,
        --     bgcolor = opcol,
        -- })
    end
    for i = 1, #str do
        local ch = string_byte(str, i)
        local bmpx = (ch % 32) * maxwidth
        local bmpy = (ch // 32) * h
        local chw = font.widths[1 + ch]
        if chw > 0 then
            opadd(bmpx, bmpy, chw, h, x, y)
            if bold then
                opadd(bmpx, bmpy, chw, h, x + 1, y)
                x = x + 1
            end
            x = x + chw
        end
    end
    runtime:drawCmd("mcopy", op)

    if underlined then
        gAT(startx, y + font.ascent + 1)
        gLINEBY(x - startx, 0)
    end

    -- Yes these stack with gSTYLE underlined, and are drawn in a slightly different y offset
    if xflags == KgXPrintUnderlined then
        gAT(startx, y + font.height)
        gLINEBY(x - startx, 0)
    elseif xflags == KgXPrintThinUnderlined then
        -- local uy = y + font.height - 1
        gAT(startx, y + font.height - 1)
        gLINEBY(x - startx, 0)
    end
    runtime:restoreGraphicsState(s)
end

function gINFO()
    local context = runtime:getGraphicsContext()
    local font = runtime:getFont()
    local cursor = runtime:getResource("cursor")

    local ginfo = {
        fontHeight = font.height,
        fontDescent = font.descent,
        fontAscent = font.ascent,
        fontZeroWidth = font.widths[1 + string.byte("0")],
        fontMaxWidth = font.maxwidth,
        fontUid = font.uid,
        gmode = context.mode,
        tmode = context.tmode,
        style = context.style,
        cursorVibible = cursor ~= nil,
        cursorWidth = cursor and cursor.rect.w,
        cursorHeight = cursor and cursor.rect.h,
        cursorAscent = cursor and cursor.rect.h, -- We will say the ascent is always the height
        cursorWindow = cursor and (cursor.isText and -1 or cursor.id),
        cursorX = cursor and cursor.rect.x,
        cursorY = cursor and (cursor.rect.y + cursor.rect.h),
        isWindow = context.isWindow,
        cursorFlags = cursor and cursor.flags,
        displayMode = context.displayMode,
    }
    return ginfo
end

function TESTEVENT()
    return runtime:iohandler().testEvent()
end

function KEY()
    -- It's annoying that calling TESTEVENT() then GET() doesn't _quite_ have the right semantics (because that will
    -- still block if there's say a keydown event and no keypress events in the queue)

    local eventsWaiting = TESTEVENT()
    if not eventsWaiting then
        return 0
    end

    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()
    while eventsWaiting do
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        if ev[KEvAType]() & KEvNotKeyMask == 0 then
            runtime:setResource("kmod", ev[KEvAKMod]())
            return keycodeToCharacterCode(ev[KEvAType]())
        end
        eventsWaiting = TESTEVENT()
    end
    return 0
end

function KEYA(stat, keyArrayAddr)
    -- This is similar to GETEVENTA32 except for the actual async call

    local existingEvent = runtime:getResource("getevent")
    if existingEvent then
        -- printf("Outstanding getevent request, cancelling\n")
        runtime:iohandler().cancelRequest(existingEvent.var)
        runtime:waitForRequest(existingEvent.var)
        assert(runtime:getResource("getevent") == nil, "cancelRequest did not release getevent resource!")
    end

    stat(KErrFilePending)
    local function completion()
        runtime:setResource("getevent", nil)
    end
    local requestTable = {
        var = stat,
        ev = keyArrayAddr,
        completion = completion,
    }
    runtime:setResource("getevent", requestTable)
    runtime:iohandler().asyncRequest("keya", requestTable)
end

function KEYSTR()
    -- Yep, this is what the Psion does, meaning for eg that the menu key
    -- (charcode 0x122) gets returned as 0x22 which is double-quote...
    local code = KEY() & 0xFF
    if code >= 32 then
        return string.char(code)
    else
        return ""
    end
end

function PAUSE(val)
    local period = val * 50 -- now in ms
    local sleepVar = runtime:makeTemporaryVar(DataTypes.EWord)
    sleepVar(KErrFilePending)
    runtime:iohandler().asyncRequest("after", { var = sleepVar, period = period })
    -- TODO also return if there's a key event...
    runtime:waitForRequest(sleepVar)
end

function GET()
    -- GET() is the synchronous version of KEYA(). KEY(), by comparison, is a non-blocking poll function
    -- which returns 0 if no key has been pressed since the last event fetch.

    -- Special case for defaultiohandler
    local getch = runtime:iohandler().getch
    if getch then
        return getch()
    end

    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local k = runtime:makeTemporaryVar(DataTypes.EWordArray, 2)
    KEYA(stat, k:addressOf())
    runtime:waitForRequest(stat)

    local modifiers = k[2]() & 0xFF
    runtime:setResource("kmod", modifiers)
    return k[1]()
end

function GETSTR()
    local code = GET() & 0xFF
    if code >= 32 then
        return string.char(code)
    else
        return ""
    end
end

function GETEVENTA32(stat, evAddr)
    -- It's important not to call checkCompletions here, because that could make
    -- it look like the program had correctly managed its GetEventA32 calls when
    -- it potentially hadn't, which we can only determine by whether or not the
    -- onAssignCallback has fired and unset the getevent resource.
    local existingEvent = runtime:getResource("getevent")
    if existingEvent then
        -- printf("Outstanding getevent request, cancelling\n")
        runtime:iohandler().cancelRequest(existingEvent.var)
        runtime:waitForRequest(existingEvent.var)
        assert(runtime:getResource("getevent") == nil, "cancelRequest did not release getevent resource!")
        -- printf("Cancel complete\n")
    end

    stat(KErrFilePending)
    local function completion()
        -- printf("GetEvent stat set to %s\n", stat())
        runtime:setResource("getevent", nil)
    end
    local requestTable = {
        var = stat,
        ev = evAddr,
        completion = completion,
    }
    runtime:setResource("getevent", requestTable)
    runtime:iohandler().asyncRequest("getevent", requestTable)
end

function ESCAPE(flag)
    runtime:iohandler().system("escape", flag)
end

-- Menu APIs

function mINIT()
    runtime:setMenu({
        cascades = {},
    })
end

-- File APIs

function EXIST(path)
    local ret = runtime:iohandler().fsop("exists", runtime:abs(path))
    return ret == KErrNone
end

function MKDIR(path)
    path = assertPathValid(runtime:abs(path))
    local err = runtime:iohandler().fsop("mkdir", path)
    if err ~= KErrNone then
        error(err)
    end
end

function RMDIR(path)
    path = assertPathValid(runtime:abs(path))
    local err = runtime:iohandler().fsop("rmdir", path)
    if err ~= KErrNone then
        error(err)
    end
end

function IOOPEN(path, mode)
    if path == "TIM:" then
        local f = runtime:newFileHandle()
        f.timer = true
        return f.h
    end

    path = runtime:abs(path)
    -- printf("IOOPEN %s mode=%d\n", path, mode)

    local openMode = mode & KIoOpenModeMask
    assert(openMode ~= KIoOpenModeAppend, "Don't support append yet!")
    assert(openMode ~= KIoOpenModeUnique, "Don't support unique yet!")

    local ok, err = checkPathValid(path)
    if not ok then
        return nil, err
    end

    local data

    if openMode == KIoOpenModeOpen then
        data, err = runtime:iohandler().fsop("read", path)
        if not data then
            return nil, err, nil
        end
    elseif openMode == KIoOpenModeCreate then
        if EXIST(path) then
            return nil, KErrExists
        end
        mode = mode | KIoOpenAccessUpdate -- Not sure about this...
    elseif openMode == KIoOpenModeReplace then
        mode = mode | KIoOpenAccessUpdate -- Not sure about this...
    end

    local f = runtime:newFileHandle()
    f.path = path
    f.pos = 1
    f.mode = mode
    f.data = data or ""
    return f.h
end

-- return `nil, err` in some errors, and `data, err` in the event of "valid but truncated..."
function IOREAD(h, maxLen)
    local f = runtime:getFile(h)
    if not f then
        return nil, KErrInvalidArgs
    end
    assert(f.pos, "Cannot IOREAD a non-file handle!")

    if f.pos > #f.data then
        return nil, KErrEof
    end

    if f.mode & KIoOpenFormatText > 0 then
        local startPos, endPos = f.data:find("\r?\n", f.pos)
        if startPos then
            local data = f.data:sub(f.pos, startPos - 1)
            f.pos = endPos + 1
            if #data > maxLen then
                -- Yes returning both data and an error is a weird way to do things, it's what the API requires...
                return data:sub(1, maxLen), KErrRecord
            end
            -- printf("text IOREAD len=%d data=%s\n", #data, hexEscape(data))
            return data
        else
            f.pos = #f.data + 1
            return ""
        end
    else
        local data = f.data:sub(f.pos, f.pos + maxLen - 1)
        -- printf("IOREAD pos=%d len=%d data=%s\n", f.pos, #data, hexEscape(data))
        if #data == 0 then
            f.pos = #f.data + 1 -- So we error next read
        else
            f.pos = f.pos + #data
        end
        return data
    end
end

function IOWRITE(h, data)
    local f = runtime:getFile(h)
    if not f then
        return KErrInvalidArgs
    end
    -- What's the right actual error code for this? KErrWrite? KOplErrReadOnly? KErrAccess?
    assert(f.mode & KIoOpenAccessUpdate > 0, "Cannot write to a readonly file handle!")
    assert(f.pos, "Cannot IOWRITE a non-file handle!")
    -- printf("IOWRITE h=%d pos=%d len=%d data='%s'\n", h, f.pos, #data, hexEscape(data))
    -- Not the most efficient operation, oh well
    f.data = f.data:sub(1, f.pos - 1)..data..f.data:sub(f.pos + #data)

    if f.mode & KIoOpenFormatText > 0 then
        f.data = f.data.."\r\n"
    end
    f.pos = #f.data + 1
    return KErrNone
end

function IOSEEK(h, mode, offset)
    local f = runtime:getFile(h)
    if not f then
        printf("Invalid handle to IOSEEK!\n")
        return KErrInvalidArgs
    end
    assert(f.mode & KIoOpenAccessRandom > 0, KErrInvalidArgs)
    assert(f.pos, "Cannot IOSEEK a non-file handle!")
    local newPos
    -- printf("IOSEEK(%d, %d, %d)\n", h, mode, offset)
    if mode == KIoSeekFromStart then
        newPos = 1 + offset
    elseif mode == KIoSeekFromEnd then
        newPos = 1 + #f.data + offset -- I think it's plus...?
    elseif mode == KIoSeekFromCurrent then
        newPos = self.pos + offset
    elseif mode == KIoSeekFirstRecord then
        newPos = 1
    else
        error("Unknown mode to IOSEEK!")
    end

    assert(newPos >= 1 and newPos <= #f.data + 1) -- Not sure what the right error here is
    f.pos = newPos
    return KErrNone, newPos
end

function IOCLOSE(h)
    if h == 0 then
        return KErrNone
    end
    local err = KErrNone
    local f = runtime:getFile(h)
    if f then
        if f.pos and f.mode & KIoOpenAccessUpdate > 0 then
            err = runtime:iohandler().fsop("write", f.path, f.data)
        end
        IOCANCEL(h)
        -- OPL doesn't worry about consuming any potential signal here, so we won't either
        runtime:closeFile(h)
    else
        err = KErrInvalidArgs
    end
    return err
end

local KFnTimerRelative = 1
local KFnTimerAbsolute = 2

function IOA(h, fn, stat, a, b)
    local f = runtime:getFile(h)
    if not f or not f.timer then
        return KErrInvalidArgs
    end
    
    if f.timer then
        assert(f.stat == nil or not f.stat:isPending(), "Cannot have 2 outstanding timer requests at once!")
        a = a:asVariable(DataTypes.ELong)
        if fn == KFnTimerRelative then
            -- relative timer period is 1/10 second, and period should be in ms
            local period = a() * 100
            stat(KErrFilePending)
            runtime:iohandler().asyncRequest("after", { var = stat, period = period })
            f.stat = stat
        elseif fn == KFnTimerAbsolute then
            -- a is time in seconds since epoch
            stat(KErrFilePending)
            runtime:iohandler().asyncRequest("at", { var = stat, time = a() })
        else
            error("Unknown IOA timer operation")
        end
    else
        error("Unknown IOA operation")
    end
    return 0
end

function IOC(h, fn, stat, a, b)
    local err = IOA(h, fn, stat, a, b)
    if err ~= 0 then
        stat(err)
    end
end

function IOCANCEL(h)
    local f = runtime:getFile(h)
    if not f or not f.timer then
        return KErrInvalidArgs
    end

    if f.timer and f.stat and f.stat:isPending() then
        runtime:iohandler().cancelRequest(f.stat)
    end
    return KErrNone
end

-- system OPX stuff

function DisplayTaskList()
    printf("system.DisplayTaskList()\n")
    runtime:iohandler().system("displayTaskList")
end

function SetForeground()
    printf("system.SetForeground()\n")
    runtime:iohandler().system("setForeground")
end

function SetBackground()
    printf("system.SetBackground()\n")
    runtime:iohandler().system("setBackground")
end

function LoadRsc(path)
    -- printf("LoadRsc(%s)\n", path)
    path = runtime:abs(path)
    local data, err = runtime:iohandler().fsop("read", path)
    assert(data, err)
    local resourceFile = require("rsc").parseRsc(data)
    local loadedResources = runtime:getResource("rsc")
    if not loadedResources then
        loadedResources = { nextHandle = 1 }
        runtime:setResource("rsc", loadedResources)
    end
    resourceFile.handle = loadedResources.nextHandle
    loadedResources.nextHandle = loadedResources.nextHandle + 1
    table.insert(loadedResources, resourceFile)
    return resourceFile.handle
end

function UnLoadRsc(handle)
    local loadedResources = runtime:getResource("rsc")
    local resourceFileIdx
    for i, r in ipairs(loadedResources or {}) do
        if r.handle == handle then
            resourceFileIdx = i
            break
        end
    end
    assert(resourceFileIdx, KErrNotExists)
    table.remove(loadedResources, resourceFileIdx)
end

function ReadRsc(id)
    local loadedResources = runtime:getResource("rsc")
    for i, resourceFile in ipairs(loadedResources) do
        local result
        if resourceFile.idOffset then
            result = resourceFile[id - resourceFile.idOffset + 1]
        end
        if not result then
            -- Some apps seem to ask for the id directly - are they series 3 era predating the idOffset stuff?
            result = resourceFile[id]
        end
        if result then
            return result
        end
    end

    printf("ReadRsc 0x%x not found\n", id)
    error(KErrNotExists)
end

-- date OPX

function LCClockFormat()
    local fmt = runtime:iohandler().getConfig("clockFormat")
    return fmt == "1" and 1 or 0
end

function LCSetClockFormat(fmt)
    runtime:iohandler().setConfig("clockFormat", tostring(fmt))
end

-- Sound

function PlaySoundA(var, path)
    local path = runtime:abs(path)

    local data, err = runtime:iohandler().fsop("read", path)
    if not data then
        var(err)
        runtime:requestSignal()
        return
    end

    local sndData, err = require("sound").parseWveFile(data)
    if not sndData then
        print("Failed to decode sound data, not playing anything!")
        var(err)
        runtime:requestSignal()
        return
    end
    PlaySoundPcm16(var, sndData)
end

function PlaySoundPcm16(var, data)
    assert(runtime:getResource("sound") == nil, KErrInUse)
    var:setPending()

    runtime:setResource("sound", var)
    local function completion()
        runtime:setResource("sound", nil)
    end
    runtime:iohandler().asyncRequest("playsound", { var = var, data = data, completion = completion })
end

function StopSound()
    local var = runtime:getResource("sound")
    local didStop = false
    if var then
        runtime:iohandler().cancelRequest(var)
        runtime:waitForRequest(var)
        assert(runtime:getResource("sound") == nil, "cancelRequest did not release sound resource!")
        didStop = true
    end
    return didStop
end

-- misc

function checkPathValid(path)
    local toCheck = path
    if oplpath.isabs(path) then
        toCheck = path:sub(3)
    end
    if toCheck:match('[:"*?/]') then
        return nil, KErrName
    end

    return path
end

function assertPathValid(path)
    return assert(checkPathValid(path))
end

local kSecsFrom1900to1970 = 2208988800 -- runtime:iohandler().utctime({ year = 1900, month = 1, day = 1 })

function DAYS(day, month, year)
    local t = runtime:iohandler().utctime({ year = year, month = month, day = day })
    -- Result needs to be days since 1900. Only the old sibo-era APIs use 1900, date.opx uses 1970. Ugh.
    t = (t + kSecsFrom1900to1970) // (24 * 60 * 60)
    return t
end

function DAYSTODATE(days)
    local t = (days * 24 * 60 * 60) - kSecsFrom1900to1970
    local result = os.date("!*t", t)
    return result.year, result.month, result.day
end

return _ENV
