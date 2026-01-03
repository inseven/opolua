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

-- Constants

local KTbWidth_s5 = 70
local KTbWidth_revo = 52
local KTbBtTop_s5 = 24
local KTbBtTop_revo = 20
local KTbBtTop_s7 = 48
local KTbBtH_s5 = 37
local KTbBtH_revo = 35
local KTbBtH_s7 = 48
local KTbClockSize = 70
local KTbNumComps = 6

local KTbFlgLatchable = 0x2
local KTbFlgLatchStart = 0x12
local KTbFlgLatchMiddle = 0x22
local KTbFlgLatchEnd = 0x32
local KTbFlgLatched = 0x04

local KTbFont = KFontSquashed
local KTbTitleFont = KFontArialNormal11
local KTbTitleFont_revo = KFontSquashed
local KTbClockPosX = 4
local KTbClockHeight = 64

-- Global vars
local TbVis, TbMenuSym, TbBtFlags, TbWinId

-- Actual state
local tbWidth
local tbWinId
local KTitleButtonId = 0
local KClockButtonId = 1000 -- Not an index into buttons
local title
local buttons = {}
local pressedButtonId
local toolbarHeight
local buttonHeight
local appTitleHeight
local fgColour = { 0, 0, 0 } -- black
local bgColour = { 0xFF, 0xFF, 0xFF } -- white
local defaultIcon
local titleFont

function TBarLink(appLink)
    TbVis = runtime:declareGlobal("TbVis%")
    TbVis(0)
    TbMenuSym = runtime:declareGlobal("TbMenuSym%")
    TbMenuSym(KMenuCheckBox)
    local deviceName = runtime:getDeviceName()
    local maxButtons
    if deviceName == "psion-series-7" then
        tbWidth = KTbWidth_s5
        appTitleHeight = KTbBtTop_s7
        buttonHeight = KTbBtH_s7
        maxButtons = 7 -- By inspection it looks like 7 would fit, dunno what the actual limit was
        titleFont = KTbTitleFont
    elseif deviceName == "psion-revo" then
        tbWidth = KTbWidth_revo
        appTitleHeight = KTbBtTop_revo
        buttonHeight = KTbBtH_revo
        maxButtons = 3        
        titleFont = KTbTitleFont_revo
    else
        tbWidth = KTbWidth_s5
        appTitleHeight = KTbBtTop_s5
        buttonHeight = KTbBtH_s5
        maxButtons = 4
        titleFont = KTbTitleFont
    end
    TbBtFlags = runtime:declareGlobal("TbBtFlags%", maxButtons)
    TbWinId = runtime:declareGlobal("TbWinId%")
    local tbWidthVar = runtime:declareGlobal("TbWidth%")
    tbWidthVar(tbWidth)
    runtime:callProc(appLink:upper())
end

local function drawButton(pos)
    local button = buttons[pos]
    local state = button.state
    if pos == pressedButtonId and button.isPushedDown then
        state = state + 1
    end
    if button.flags() & KTbFlgLatched > 0 then
        state = state + 1
    end
    gUSE(tbWinId)
    gFONT(KTbFont)
    gAT(0, appTitleHeight + (pos - 1) * buttonHeight)
    gBUTTON(button.text, 2, tbWidth, buttonHeight + 1, state, button.bmp, button.mask)
end

local function drawTitle()
    gUSE(tbWinId)
    gSTYLE(1) -- bold everything
    gAT(0, 0)
    gFILL(tbWidth, appTitleHeight, KgModeClear)
    gBOX(tbWidth, toolbarHeight)

    gFONT(titleFont)
    local _, _, ascent = gTWIDTH("")
    local y = ((appTitleHeight - ascent) // 2) + ascent
    gAT(1, y)
    local align = KgPrintBCentredAligned
    if gTWIDTH(title) > tbWidth - 2 then
        align = KgPrintBLeftAligned
    end
    gPRINTB(title, tbWidth - 2, align, 6, 6)
end    

local function drawTitleAndClock()
    gUSE(tbWinId)
    gAT(0, 0)
    gFILL(tbWidth, toolbarHeight, KgModeClear)
    gBOX(tbWidth, toolbarHeight)
    drawTitle()
    -- Not sure how the Revo clock should be drawn, for now just omit it.
    if runtime:getDeviceName() ~= "psion-revo" then
        gAT(KTbClockPosX, toolbarHeight - KTbClockHeight)
        gCLOCK(KgClockS5System)
    end
end

function TBarInit(title, screenWidth, screenHeight)
    local displayMode = runtime:getGraphicsContext().displayMode
    TBarInitC(title, screenWidth, screenHeight, displayMode)
end

function TBarInitC(aTitle, screenWidth, screenHeight, winMode)
    local prevId = gIDENTITY()
    local w = tbWidth
    toolbarHeight = screenHeight
    gUPDATE(false)
    if runtime:getDeviceName() == "psion-series-7" then
        -- See https://github.com/inseven/opolua/issues/414 for why we do this
        winMode = KgCreateRGBColorMode
    end
    tbWinId = gCREATE(screenWidth - w, 0, w, toolbarHeight, false, winMode)
    TbWinId(tbWinId)
    gCOLOR(table.unpack(fgColour))
    gCOLORBACKGROUND(table.unpack(bgColour))
    title = aTitle
    drawTitleAndClock()
    runtime:iohandler().system("setAppTitle", title)
    gUSE(prevId)
end

function TBarSetTitle(name)
    title = name
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    drawTitle()
    runtime:iohandler().system("setAppTitle", title)
    gUSE(prevId)
end

function TBarButt(shortcut, pos, text, state, bmp, mask, flags)
    local prevId = gIDENTITY()
    if bmp == 0 then
        if defaultIcon == nil and runtime:getDeviceName() ~= "psion-revo" then
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
        flags = TbBtFlags[pos]
    }
    buttons[pos].flags(flags)
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
        butId = 1 + ((ptrY - appTitleHeight) // buttonHeight)
    end

    if winId ~= tbWinId or ptrY < 0 or ptrX < 0 or ptrX >= tbWidth then
        butId = nil
    elseif butId < 0 or (butId > 0 and butId ~= KClockButtonId and not buttons[butId]) then
        butId = nil
    end

    if ptrX == 0 and ptrY == 0 then
        -- Conquete has a habit of making a spurious call with coords (0,0), so let's consider that a dead pixel.
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
                local latched = button.flags() & KTbFlgLatched ~= 0
                local latchable = button.flags() & KTbFlgLatchable ~= 0
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
    if button.flags() & KTbFlgLatched > 0 then
        button.flags(button.flags() & ~KTbFlgLatched)
        drawButton(button.id)
    end
end

function TBarLatch(butId)
    local button = buttons[butId]
    -- Apparently there's nothing to say you can't latch a button that doesn't have KTbFlgLatchable set...
    assert(button, "No button found!")
    -- Unlatch everything above that's in the same latch group
    local buttonLatchGroup = button.flags() & 0x30
    for id = butId - 1, 1, -1 do
        local blg = buttons[id].flags() & 0x30
        if blg == 0 or blg > buttonLatchGroup then
            break
        end
        unlatch(buttons[id])
    end
    -- And everything below
    for id = butId + 1, #buttons do
        local blg = buttons[id].flags() & 0x30
        if blg == 0 or blg < buttonLatchGroup then
            break
        end
        unlatch(buttons[id])
    end

    if button.flags() & KTbFlgLatched == 0 then
        button.flags(button.flags() | KTbFlgLatched)
        drawButton(button.id)
    end
end

function TBarShow()
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gORDER(gIDENTITY(), 1)
    gVISIBLE(true)
    TbVis(-1)
    TbMenuSym(KMenuCheckBox | KMenuSymbolOn)
    gUSE(prevId)
end

function TBarHide()
    local prevId = gIDENTITY()
    gUSE(tbWinId)
    gVISIBLE(false)
    TbVis(0)
    TbMenuSym(KMenuCheckBox)
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
