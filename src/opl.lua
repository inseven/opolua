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
    -- printf("gUSE(%d)\n", id)
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
    -- printf("gCLS\n")
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

    runtime:drawCmd("text", {
        x = textX,
        y = context.pos.y - fontAscent + texth,
        mode = GraphicsMode.Set,
        string = text,
    })
end

function gPRINTCLIP(text, width)
    while #text > 0 and gTWIDTH(text) > width do
        text = text:sub(1, -2)
    end
    gPRINT(text)
    return #text
end

function gTWIDTH(text)
    local width = runtime:iohandler().graphicsop("textsize", text, runtime:getGraphicsContext().font)
    return width
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
        rect = { x = 0, y = 0, w = ctx.width, h = ctx.h }
    end
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

function gGREY(mode)
    local val = mode == 1 and 0xAA or 0
    runtime:getGraphicsContext().color = { val, val, val }
end

function gCOLOR(red, green, blue)
    runtime:getGraphicsContext().color = { red, green, blue }
end

function gCOLORBACKGROUND(red, green, blue)
    runtime:getGraphicsContext().bgcolor = { red, green, blue }
end

function gSETWIN(x, y, w, h)
    -- printf("gSETWIN id=%d %d,%d %sx%s\n", gIDENTITY(), x, y, w, h)
    runtime:flushGraphicsOps()
    local ctx = runtime:getGraphicsContext()
    runtime:iohandler().graphicsop("setwin", ctx.id, x, y, w, h)
    if w then
        ctx.width = w
        ctx.height = h
    end
end

function gCREATE(x, y, w, h, visible, flags)
    -- printf("gCREATE w=%d h=%d flags=%X", w, h, flags or 0)
    local id = runtime:iohandler().createWindow(x, y, w, h, flags or 0)
    assert(id, "Failed to createWindow!")
    -- printf(" id=%d\n", id)
    runtime:newGraphicsContext(id, w, h, true, (flags or 0) & 0xF)
    if visible then
        runtime:iohandler().graphicsop("show", id, true)
    end
    return id
end

function gCREATEBIT(w, h, mode)
    -- printf("gCREATEBIT w=%d h=%d mode=%X", w, h, mode or 0)
    local id = runtime:iohandler().createBitmap(w, h, mode)
    assert(id, "Failed to createBitmap!") -- Shouldn't ever fail...
    -- printf(" id=%d\n", id)
    runtime:newGraphicsContext(id, w, h, false, mode)
    return id
end

function gLOADBIT(path, writable, index)
    -- We implement this in 3 phases:
    -- (1) Get the mbm data and decode it
    -- (2) Tell iohandler to create an empty bitmap
    -- (3) Tell iohandler to blit the decoded MBM data into it

    -- (1)
    -- printf("gLOADBIT %s mbmid=%d", path, 1+index)
    local iohandler = runtime:iohandler()
    local data, err = iohandler.fsop("read", runtime:abs(path))
    assert(data, err)
    local bitmaps = mbm.parseMbmHeader(data)
    assert(bitmaps, KOplErrGenFail)
    local bitmap = bitmaps[1 + index]
    assert(bitmap, KOplErrNotExists)
    -- (2)
    local id = gCREATEBIT(bitmap.width, bitmap.height, bitmap.mode)
    -- printf(" %dx%d drawableid=%d\n", bitmap.width, bitmap.height, id)
    -- (3)
    runtime:drawCmd("bitblt", {
        bmpWidth = bitmap.width,
        bmpHeight = bitmap.height,
        bmpMode = bitmap.mode,
        bmpStride = bitmap.stride,
        bmpData = mbm.decodeBitmap(bitmap, data)
    })
    runtime:flushGraphicsOps()
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
    runtime:getGraphicsContext().penwidth = width
end

-- Screen APIs

local function drawInfoPrint(drawable, text, corner)
    gUPDATE(false)
    gUSE(1)
    local screenWidth = gWIDTH()
    local screenHeight = gHEIGHT()
    local winHeight = 23
    gUSE(drawable)

    local cornerInset = 5
    local inset = 6
    local textWidth = gTWIDTH(text)
    local w = math.min(screenWidth - 2 * cornerInset, textWidth + inset * 2)
    local actualTextWidth = w - 2 * inset

    local x, y
    if corner == 0 then
        -- Top left
        x = cornerInset
        y = cornerInset
    elseif corner == 1 then
        -- Bottom left
        x = cornerInset
        y = screenHeight - winHeight - cornerInset
    elseif corner == 2 then
        -- Top right
        x = screenWidth - w - cornerInset
        y = cornerInset
    elseif corner == 3 then
        -- Bottom right
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
    gAT(inset, 20)
    gPRINTCLIP(text, w - 2 * inset)
    return { x = inset, y = inset, w = actualTextWidth, h = 15 }
end

function gIPRINT(text, corner)
    if text == "" then
        runtime:iohandler().graphicsop("giprint", 0)
        return
    end
    local state = runtime:saveGraphicsState()
    local infoWinId = runtime:getResource("infowin")
    if not infoWinId then
        infoWinId = gCREATE(0, 0, 1, 1, false)
        gFONT(KFontArialNormal15)
        runtime:setResource("infowin", infoWinId)
    end
    drawInfoPrint(infoWinId, text, corner or 3)
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
    busyWinId = gCREATE(0, 0, 1, 1, false)
    gFONT(KFontArialNormal15)
    runtime:setResource("busy", busyWinId)
    local textRect = drawInfoPrint(busyWinId, text, corner or 1)

    local bmp = require("opx.bmp")
    local sprite = bmp.SPRITECREATE(runtime, busyWinId, textRect.x, textRect.y, 0)
    local blackBmp = gCREATEBIT(textRect.w, textRect.h, 0)
    gCOLOR(0, 0, 0)
    gFILL(gWIDTH(), gHEIGHT())
    gUSE(busyWinId)
    runtime:flushGraphicsOps()
    bmp.SPRITEAPPEND(runtime, 1000000, blackBmp, blackBmp, true, 0, 0)
    bmp.SPRITEAPPEND(runtime, 1000000, blackBmp, blackBmp, false, 0, 0)
    bmp.SPRITEDRAW(runtime)

    if delay and delay > 0 then
        runtime:iohandler().graphicsop("busy", busyWinId, delay)
    else
        -- Jusy show it now
        gVISIBLE(true)
    end
    runtime:restoreGraphicsState(state)
end

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

function KEY()
    local charcode = runtime:iohandler().key()
    return charcode
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

function GET()
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    repeat
        stat(KOplErrFilePending)
        local requestTable = {
            var = stat,
            ev = ev:addressOf()
        }
        runtime:iohandler().asyncRequest("getevent", requestTable)
        runtime:waitForRequest(stat)
    until ev()[1]() & 0x400 == 0

    return keycodeToCharacterCode(ev()[1]())
end

function GETSTR()
    local code = GET() & 0xFF
    if code >= 32 then
        return string.char(code)
    else
        return ""
    end
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
    return ret == KOplErrExists
end

function MKDIR(path)
    local err = runtime:iohandler().fsop("mkdir", runtime:abs(path))
    if err ~= KErrNone then
        error(err)
    end
end

local Mode = {
    Open = 0,
    Create = 1,
    Replace = 2,
    Append = 3,
    Unique = 4,
    OpenModeMask = 0x3,

    TextFlag = 0x20,
    WriteFlag = 0x100,
    SeekableFlag = 0x200,
    ReadonlyShared = 0x400, -- We can safely ignore this one
}

function IOOPEN(path, mode)
    path = runtime:abs(path)
    local openMode = mode & Mode.OpenModeMask
    -- printf("IOOPEN %s mode=%d\n", path, mode)

    if openMode == Mode.Open then
        local f = runtime:newFileHandle()
        f.pos = 1
        f.mode = mode
        local data, err = runtime:iohandler().fsop("read", path)
        if data then
            f.data = data
            f.path = path
            return f.h
        else
            runtime:closeFile(f.h)
            return nil, err, nil
        end
    end

    -- Write support
    mode = mode | Mode.WriteFlag -- Apparently this _isn't_ mandatory...
    assert(openMode ~= Mode.Append, "Don't support append yet!")
    assert(openMode ~= Mode.Unique, "Don't support unique yet!")

    if openMode == Mode.Create then
        local err = runtime:iohandler().fsop("exists", path)
        if err ~= KOplErrNotExists then
            printf("IOOPEN(%s) failed: %d\n", path, err)
            return nil, err
        end
    end

    local f = runtime:newFileHandle()
    f.path = path
    f.pos = 1
    f.mode = mode
    f.data = ""
    return f.h
end

-- return `nil, err` in some errors, and `data, err` in the event of "valid but truncated..."
function IOREAD(h, maxLen)
    local f = runtime:getFile(h)
    if not f then
        return nil, KOplErrInvalidArgs
    end

    if f.mode & Mode.TextFlag > 0 then
        local startPos, endPos = f.data:find("\r?\n", f.pos)
        if startPos then
            local data = f.data:sub(f.pos, startPos - 1)
            f.pos = endPos + 1
            if #data > maxLen then
                -- Yes returning both data and an error is a weird way to do things, it's what the API requires...
                return data:sub(1, maxLen), KOplErrRecord
            end
            return data
        else
            f.pos = #f.data + 1
            return ""
        end
    else
        local data = f.data:sub(f.pos, f.pos + maxLen - 1)
        f.pos = f.pos + #data
        return data
    end
end

function IOWRITE(h, data)
    local f = runtime:getFile(h)
    if not f then
        return nil, KOplErrInvalidArgs
    end
    -- What's the right actual error code for this? KOplErrWrite? KOplErrReadOnly? KOplErrAccess?
    assert(f.mode & Mode.WriteFlag > 0, "Cannot write to a readonly file handle!")
    -- Not the most efficient operation, oh well
    f.data = f.data:sub(1, f.pos - 1)..data..f.data:sub(f.pos + #data)

    if f.mode & Mode.TextFlag > 0 then
        f.data = f.data.."\r\n"
    end
    f.pos = #f.data + 1
    return KErrNone
end

function IOSEEK(h, mode, offset)
    local f = runtime:getFile(h)
    if not f then
        printf("Invalid handle to IOSEEK!\n")
        return KOplErrInvalidArgs
    end
    local newPos
    if mode == 1 then
        newPos = 1 + offset
    elseif mode == 2 then
        newPos = 1 + #f.data + offset -- I think it's plus...?
    elseif mode == 3 then
        newPos = self.pos + offset
    elseif mode == 6 then
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
        if f.mode & Mode.WriteFlag > 0 then
            err = runtime:iohandler().fsop("write", f.path, f.data)
        end
        runtime:closeFile(h)
    else
        err = KOplErrInvalidArgs
    end
    return err
end

return _ENV
