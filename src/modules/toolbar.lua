--[[

Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe

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

-- Constants

local KTbWidth = 70
local KTbBtTop = 24
local KTbBtH = 37
local KTbClockSize = 70
local KTbNumComps = 6

local KTbFlgLatchable = 0x2
local KTbFlgLatchStart = 0x12
local KTbFlgLatchMiddle = 0x22
local KTbFlgLatchEnd = 0x32
local KTbFlgLatched = 0x04

local KTbFont = KFontSquashed
local KTbTitleFont = KFontArialNormal11
local KTbClockPosX = 4
local KTbClockHeight = 64

-- Global vars
local visibleVar

-- Actual state
local tbWinId
local KTitleButtonId = 0
local KClockButtonId = 1000 -- Not an index into buttons
local title
local buttons = {}
local pressedButtonId
local toolbarHeight
local fgColour = { 0, 0, 0 } -- black
local bgColour = { 0xFF, 0xFF, 0xFF } -- white
local defaultIcon

function TBarLink(appLink)
    local tbWidthVar = runtime:declareGlobal("TbWidth%")
    tbWidthVar(KTbWidth)
    visibleVar = runtime:declareGlobal("TbVis%")
    visibleVar(0)
    runtime:callProc(appLink:upper())
end

local function drawButton(pos)
    local button = buttons[pos]
    local state = button.state
    if pos == pressedButtonId and button.isPushedDown then
        state = state + 1
    end
    if button.flags & KTbFlgLatched > 0 then
        state = state + 1
    end
    gUSE(tbWinId)
    gFONT(KTbFont)
    gAT(0, KTbBtTop + (pos - 1) * KTbBtH)
    gBUTTON(button.text, 2, KTbWidth, KTbBtH + 1, state, button.bmp, button.mask)
end

local function drawTitle()
    gUSE(tbWinId)
    gSTYLE(1) -- bold everything
    gAT(0, 0)
    gFILL(KTbWidth, KTbBtTop, KgModeClear)
    gBOX(KTbWidth, toolbarHeight)

    gAT(1, KTbBtTop - 8)
    gFONT(KTbTitleFont)
    local align = KgPrintBCentredAligned
    if gTWIDTH(title) > KTbWidth - 2 then
        align = KgPrintBLeftAligned
    end
    gPRINTB(title, KTbWidth - 2, align, 6, 6)
end    

local function drawTitleAndClock()
    gUSE(tbWinId)
    gAT(0, 0)
    gFILL(KTbWidth, toolbarHeight, KgModeClear)
    gBOX(KTbWidth, toolbarHeight)
    drawTitle()
    gAT(KTbClockPosX, toolbarHeight - KTbClockHeight)
    gCLOCK(KgClockS5System)
end

function TBarInit(title, screenWidth, screenHeight)
    local displayMode = runtime:getGraphicsContext().displayMode
    TBarInitC(title, screenWidth, screenHeight, displayMode)
end

function TBarInitC(aTitle, screenWidth, screenHeight, winMode)
    local prevId = gIDENTITY()
    local w = KTbWidth
    toolbarHeight = screenHeight
    gUPDATE(false)
    tbWinId = gCREATE(screenWidth - w, 0, w, toolbarHeight, false, winMode)
    gCOLOR(table.unpack(fgColour))
    gCOLORBACKGROUND(table.unpack(bgColour))
    title = aTitle
    drawTitleAndClock()
    runtime:iohandler().setAppTitle(name)
    gUSE(prevId)
end

function TBarSetTitle(name)
    title = name
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    drawTitle()
    runtime:iohandler().setAppTitle(name)
    gUSE(prevId)
end

function TBarButt(shortcut, pos, text, state, bmp, mask, flags)
    local prevId = gIDENTITY()
    if bmp == 0 then
        if defaultIcon == nil then
            defaultIcon = gCREATEBIT(24, 24, 0)
            gCLS()
            gBORDER(0)
        end
        bmp = defaultIcon
        mask = defaultIcon
    end
    buttons[pos] = {
        id = pos,
        text = text,
        shortcut = shortcut,
        state = state,
        bmp = bmp,
        mask = mask,
        flags = flags
    }
    drawButton(pos)
    gUSE(prevId)
end

local function TBarOffer(winId, ptrType, ptrX, ptrY)
    -- printf("TBarOffer id=%d ptrType=%d ptrX=%d ptrY=%d\n", winId, ptrType, ptrX, ptrY)
    if toolbarHeight == nil then
        -- We haven't even been TBarInit'd yet, people shouldn't be offering us events, but they do...
        return 0
    end

    local butId
    if ptrY >= toolbarHeight - KTbClockHeight then
        butId = KClockButtonId
    else
        butId = 1 + ((ptrY - KTbBtTop) // KTbBtH)
    end

    if winId ~= tbWinId or ptrY < 0 or ptrX < 0 or ptrX >= KTbWidth then
        butId = nil
    elseif butId < 0 or (butId > 0 and butId ~= KClockButtonId and not buttons[butId]) then
        butId = nil
    end

    if pressedButtonId then
        local gupdateState = gUPDATE(false)
        local prevId = gIDENTITY()
        local procToCall = nil
        if ptrType == KEvPtrPenUp then
            if buttons[pressedButtonId].isPushedDown then
                buttons[pressedButtonId].isPushedDown = false
                drawButton(pressedButtonId)
            end
            -- Note, already latched buttons don't get called (IF they actually are latchable)
            if butId == pressedButtonId then 
                local button = buttons[butId]
                local latched = button.flags & KTbFlgLatched ~= 0
                local latchable = button.flags & KTbFlgLatchable ~= 0
                if not latchable or not latched then
                    -- Call the shortcut
                    local shortcut = button.shortcut
                    local shifted = shortcut:match("^[A-Z]")
                    procToCall = string.upper("cmd" .. (shifted and "S" or "")..shortcut.."%")
                end
            end
            pressedButtonId = nil
        elseif ptrType == KEvPtrDrag then
            if butId ~= pressedButtonId and buttons[pressedButtonId].isPushedDown then
                buttons[pressedButtonId].isPushedDown = false
                drawButton(pressedButtonId)
            elseif butId == pressedButtonId and not buttons[pressedButtonId].isPushedDown then
                buttons[pressedButtonId].isPushedDown = true
                drawButton(pressedButtonId)
            end
        end
        gUPDATE(gupdateState)
        gUSE(prevId)
        if procToCall then
            runtime:callProc(procToCall)
        end
        return -1
    elseif butId and ptrType == KEvPtrPenDown then
        if butId == KTitleButtonId then
            runtime:DisplayTaskList()
        elseif butId == KClockButtonId then
            local fmt = runtime:LCClockFormat()
            LCSetClockFormat(fmt == 0 and 1 or 0)
        else
            pressedButtonId = butId
            buttons[butId].isPushedDown = true
            local prevId = gIDENTITY()
            drawButton(butId)
            gUSE(prevId)
        end
        return -1
    elseif butId or winId == tbWinId then
        -- Make sure we consume pen up events on the clock, for eg
        return -1
    else
        return 0
    end
end
_ENV["TBarOffer%"] = TBarOffer

local function unlatch(button)
    if button.flags & KTbFlgLatched > 0 then
        button.flags = button.flags & ~KTbFlgLatched
        drawButton(button.id)
    end
end

function TBarLatch(butId)
    local button = buttons[butId]
    -- Apparently there's nothing to say you can't latch a button that doesn't have KTbFlgLatchable set...
    assert(button, "No button found!")
    -- Unlatch everything above that's in the same latch group
    local buttonLatchGroup = button.flags & 0x30
    for id = butId - 1, 1, -1 do
        local blg = buttons[id].flags & 0x30
        if blg == 0 or blg > buttonLatchGroup then
            break
        end
        unlatch(buttons[id])
    end
    -- And everything below
    for id = butId + 1, #buttons do
        local blg = buttons[id].flags & 0x30
        if blg == 0 or blg < buttonLatchGroup then
            break
        end
        unlatch(buttons[id])
    end

    if button.flags & KTbFlgLatched == 0 then
        button.flags = button.flags | KTbFlgLatched
        drawButton(button.id)
    end
end

function TBarShow()
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gVISIBLE(true)
    visibleVar(-1)
    gUSE(prevId)
end

function TBarHide()
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gVISIBLE(false)
    visibleVar(0)
    gUSE(prevId)
end

function TBarColor(fgR, fgG, fgB, bgR, bgG, bgB)
    fgColour = { fgR, fgG, fgB }
    bgColour = { bgR, bgG, bgB }
    if tbWinId then
        local s = runtime:saveGraphicsState()
        gUPDATE(false)
        gUSE(tbWinId)
        gCOLOR(table.unpack(fgColour))
        gCOLORBACKGROUND(table.unpack(bgColour))
        drawTitleAndClock()
        for i in pairs(buttons) do
            drawButton(i)
        end
        runtime:restoreGraphicsState(s)
    end
end

return _ENV
