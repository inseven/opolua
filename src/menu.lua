--[[

Copyright (c) 2022 Jason Morley, Tom Sutcliffe

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

local kMenuFont = KFontArialNormal15
local kShortcutFont = KFontArialNormal11

function mPOPUP(x, y, pos, values)
    local state = runtime:saveGraphicsState()
    
    -- Get required font metrics
    gFONT(kMenuFont)
    local _, textHeight, ascent = gTWIDTH("0")
    local textYPad = 4
    local lineHeight = textHeight + textYPad * 2
    gFONT(kShortcutFont)
    local _, _, shortcutAscent = gTWIDTH("0")
    local shortcutTextYOffset = ascent - shortcutAscent

    -- Work out content and window size
    local borderWidth = 5
    local textGap = 6
    local lineGap = 5 -- 2 pixels space each side of the horizontal line
    local numItems = #values
    local items = {}
    local itemY = borderWidth + 3
    local maxTextWidth = 20
    local maxShortcutTextWidth = 0
    local shortcuts = {}
    for i, value in ipairs(values) do
        assert(value.key and value.key ~= 0 and value.text, KErrInvalidArgs)
        local key = value.key
        local lineAfter = key < 0
        if lineAfter then
            key = -key
        end
        local shortcutText
        if key <= 32 then
            shortcutText = nil
        elseif key >= 0x41 and key <= 0x5A then
            shortcutText = string.format("Shift+Ctrl+%c", key)
        elseif key >= 0x61 and key <= 0x7A then
            shortcutText = string.format("Ctrl+%c", key - 0x20)
        end
        gFONT(kMenuFont)
        local w = gTWIDTH(value.text)
        if shortcutText then
            shortcuts[key & 0xFF] = i
            gFONT(kShortcutFont)
            local sw = gTWIDTH(shortcutText)
            maxShortcutTextWidth = math.max(maxShortcutTextWidth, textGap + sw)
        end
        if w > maxTextWidth then
            maxTextWidth = w
        end
        items[i] = {
            text = value.text,
            shortcutText = shortcutText,
            key = key,
            y = itemY,
            lineAfter = lineAfter,
        }
        itemY = itemY + lineHeight + (lineAfter and lineGap or 0)
    end

    local leftMargin = 15 -- This is part of the highlighted area
    local rightMargin = 20 -- ditto
    local contentWidth = leftMargin + maxTextWidth + maxShortcutTextWidth + rightMargin
    local w = contentWidth + borderWidth * 2
    local h = itemY + borderWidth
    if pos == KMPopupPosTopLeft then
        -- coords correct as-is
    elseif pos == KMPopupPosTopRight then
        x = x - w
    elseif pos == KMPopupPosBottomLeft then
        y = y - h
    elseif pos == KMPopupPosBottomRight then
        x = x - w
        y = y - h
    else
        error("Bad pos arg to mPOPUP")
    end
    local win = gCREATE(x, y, w, h, false, KgCreate4GrayMode | KgCreateHasShadow | 0x400)
    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94)
    for _, item in ipairs(items) do
        if item.lineAfter then
            gAT(borderWidth, item.y + lineHeight + (lineGap // 2))
            gLINEBY(contentWidth, 0)
        end
    end

    local function drawItem(i, highlighted)
        local item = items[i]
        gAT(borderWidth, item.y)
        gCOLOR(0, 0, 0)
        gFILL(contentWidth, lineHeight, highlighted and KgModeSet or KgModeClear)
        if item.key & KMenuDimmed > 0 then
            gCOLOR(0x55, 0x55, 0x55)
        elseif highlighted then
            gCOLOR(0xFF, 0xFF, 0xFF)
        end
        if item.key & (KMenuSymbolOn|KMenuCheckBox) == (KMenuSymbolOn|KMenuCheckBox) then
            gAT(borderWidth, item.y + textYPad)
            gFONT(KFontEiksym15)
            runtime:drawCmd("text", { string = "." })
        end
        gAT(borderWidth + leftMargin, item.y + textYPad)
        gFONT(kMenuFont)
        runtime:drawCmd("text", { string = item.text })
        if item.shortcutText then
            local x = borderWidth + leftMargin + maxTextWidth + textGap
            local y = item.y + textYPad + shortcutTextYOffset
            gFONT(kShortcutFont)
            runtime:drawCmd("text", { string = item.shortcutText, x = x, y = y })
        end
    end
    local selected = 1
    for i in ipairs(items) do
        drawItem(i, i == selected)
    end
    gVISIBLE(true)

    local function moveSelectionTo(i)
        if i == selected then
            return
        elseif i == 0 then
            i = numItems
        elseif i and i > numItems then
            i = 1
        end
        if selected then
            drawItem(selected, false)
        end
        if i then
            drawItem(i, true)
        end
        selected = i
    end

    local function checkEnabled(i)
        if not i then
            return nil
        end
        local item = items[i]
        local key = item.key
        if key & KMenuDimmed > 0 then
            gIPRINT("This item is not available", KBusyTopRight)
            return nil
        end
        drawItem(i, false)
        -- Draw a box and wait a bit to make it obvious it's been selected
        gAT(borderWidth, item.y)
        gCOLOR(0, 0, 0)
        gBOX(contentWidth, lineHeight)
        PAUSE(10)
        return key & 0xFF
    end

    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local evVar = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local ev = evVar()
    local evAddr = ev[1]:addressOf()
    local result = nil
    while result == nil do
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        local k = ev[KEvAType]()
        -- printf("ev[1] = %X\n", k)
        if k == KKeyUpArrow then
            moveSelectionTo(selected - 1)
        elseif k == KKeyDownArrow then
            moveSelectionTo(selected + 1)
        elseif k == KKeyEsc then
            result = 0
        elseif k == KKeyEnter then
            result = checkEnabled(selected)
        elseif k <= 26 then
            -- Check for a control-X shortcut (control modifier is implied by the code being 1-26)
            local shift = ev[KEvAKMod]() & KKmodShift > 0
            local cmd = (shift and 0x40 or 0x60) + k
            local shortcutItemIdx = shortcuts[cmd]
            if shortcutItemIdx then
                -- Actually it seems like the series 5 doesn't prevent you using
                -- a shortcut to a dimmed item, but that seems like a bug so we
                -- will.
                result = checkEnabled(shortcutItemIdx)
            end
        elseif k == KEvPtr then
            if ev[KEvAPtrWindowId]() ~= win then
                result = 0
                break
            end
            local x, y = ev[KEvAPtrPositionX](), ev[KEvAPtrPositionY]()
            local idx
            if x >= 0 and x < w and y >= 0 and y < h then
                idx = numItems
                while idx and y < items[idx].y do
                    idx = idx - 1
                    if idx == 0 then idx = nil end
                end
            end
            moveSelectionTo(idx)
            if ev[KEvAPtrType]() == KEvPtrPenUp then
                -- Pen up outside the window (ie when idx is nil) should always mean dismiss
                if idx == nil then
                    result = 0
                else
                    result = checkEnabled(idx)
                end
            end
        end
    end

    gCLOSE(win)
    runtime:restoreGraphicsState(state)
    return result
end

return _ENV
