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

local DrawStyle = enum {
    normal = 0,
    highlighted = 1,
    dismissing = 2,
    unfocussedHighlighted = 3,
}

local function makeMenuPane(x, y, pos, values, selected, cutoutLen)
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
        local keyNoFlags = key & 0xFF
        local shortcutText
        if keyNoFlags <= 32 then
            shortcutText = nil
        elseif keyNoFlags >= 0x41 and keyNoFlags <= 0x5A then
            shortcutText = string.format("Shift+Ctrl+%c", keyNoFlags)
        elseif keyNoFlags >= 0x61 and keyNoFlags <= 0x7A then
            shortcutText = string.format("Ctrl+%c", keyNoFlags - 0x20)
        end
        gFONT(kMenuFont)
        local w = gTWIDTH(value.text)
        if shortcutText then
            shortcuts[keyNoFlags] = i
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
            submenu = value.submenu,
        }
        itemY = itemY + lineHeight + (lineAfter and lineGap or 0)
    end

    local leftMargin = 15 -- This is part of the highlighted area
    local rightMargin = 20 -- ditto
    local contentWidth = leftMargin + maxTextWidth + maxShortcutTextWidth + rightMargin
    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = math.min(contentWidth + borderWidth * 2, screenWidth)
    local h = math.min(itemY + borderWidth, screenHeight)
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
        error("Bad pos arg for menu")
    end
    x = math.max(0, x)
    y = math.max(0, y)

    -- Move x,y up/left to ensure it fits on screen
    if x + w > screenWidth then
        x = screenWidth - w
    end
    if y + h > screenHeight then
        y = screenHeight - h
    end

    local win = gCREATE(x, y, w, h, false, KgCreate4GrayMode | KgCreateHasShadow | 0x400)
    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94, w - 2, h - 2)

    -- TODO this doesn't look right yet...
    -- if cutoutLen then
    --     gAT(borderWidth, 0)
    --     gFILL(cutoutLen, borderWidth, KgModeClear)
    -- end

    for _, item in ipairs(items) do
        if item.lineAfter then
            gAT(borderWidth, item.y + lineHeight + (lineGap // 2))
            gLINEBY(contentWidth, 0)
        end
    end

    local function drawItem(i, style)
        local item = items[i]
        assert(item, "Index out of range in drawItem! "..tostring(i))
        gAT(borderWidth, item.y)
        if style == false then
            style = DrawStyle.normal
        elseif style == true then
            style = DrawStyle.highlighted
        end
        if style == DrawStyle.unfocussedHighlighted then
            darkGrey()
        else
            black()
        end
        local highlighted = style == DrawStyle.highlighted or style == DrawStyle.unfocussedHighlighted
        gFILL(contentWidth, lineHeight, highlighted and KgModeSet or KgModeClear)
        if style == DrawStyle.dismissing then
            gAT(borderWidth, item.y)
            gCOLOR(0, 0, 0)
            gBOX(contentWidth, lineHeight)
        end
        if item.key & KMenuDimmed > 0 then
            darkGrey()
        elseif highlighted then
            white()
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
        if item.submenu then
            gFONT(KFontEiksym15)
            local x = w - rightMargin
            local y = item.y + textYPad
            item.submenuXPos = x + gTWIDTH('"')
            runtime:drawCmd("text", { string = '"', x = x, y = y })
        end
    end
    local pane = {
        id = win,
        x = x,
        y = y,
        w = w,
        h = h,
        items = items,
        selected = selected or 1,
    }
    for i in ipairs(items) do
        drawItem(i, i == pane.selected)
    end
    gVISIBLE(true)

    pane.moveSelectionTo = function(i)
        if i == pane.selected then
            return
        elseif i == 0 then
            i = numItems
        elseif i and i > numItems then
            i = 1
        end
        if pane.selected then
            drawItem(pane.selected, false)
        end
        if i then
            drawItem(i, true)
        end
        pane.selected = i
    end

    pane.choose = function(i)
        if not i then
            return nil
        end
        local item = items[i]
        local key = item.key
        if key & KMenuDimmed > 0 then
            gIPRINT("This item is not available", KBusyTopRight)
            return nil
        end
        drawItem(i, DrawStyle.dismissing)
        -- wait a bit to make it obvious it's been selected
        PAUSE(5)
        return key & 0xFF
    end

    pane.openSubmenu = function()
        assert(pane.submenu == nil, "Submenu already open?!")
        local item = items[pane.selected]
        drawItem(pane.selected, DrawStyle.unfocussedHighlighted)
        assert(item.submenu, "No submenu to open!")
        pane.submenu = makeMenuPane(pane.x + item.submenuXPos, pane.y + item.y, KMPopupPosTopLeft, item.submenu)
    end

    pane.closeSubmenu = function()
        if pane.submenu then
            gCLOSE(pane.submenu.id)
            pane.submenu = nil
            gUSE(pane.id)
            local selected = pane.selected
            pane.selected = nil -- To force the move to redraw
            pane.moveSelectionTo(selected)
        end
    end

    return pane
end

local function within(x, y, rect)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

local function runMenuEventLoop(bar, pane, shortcuts)
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local evVar = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local ev = evVar()
    local evAddr = ev[1]:addressOf()
    local result = nil
    local highlight = nil
    local seenPointerDown = false
    while result == nil do
        if bar then
            pane = bar.pane
        end
        highlight = nil
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        local current = pane.submenu or pane
        local k = ev[KEvAType]()
        if k == KKeyMenu then
            result = 0
        elseif k == KKeyUpArrow then
            current.moveSelectionTo(current.selected - 1)
        elseif k == KKeyDownArrow then
            current.moveSelectionTo(current.selected + 1)
        elseif k == KKeyLeftArrow then
            if pane.submenu then
                pane.closeSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected - 1)
            end
        elseif k == KKeyRightArrow then
            if pane.submenu == nil and pane.items[pane.selected].submenu then
                pane.openSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected + 1)
            end
        elseif k == KKeyEsc then
            if pane.submenu then
                pane.closeSubmenu()
            else
                result = 0
            end
        elseif k == KKeyEnter then
            if current.items[current.selected].submenu then
                current.openSubmenu()
            else
                result = current.choose(current.selected)
                highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
            end
        elseif k <= 26 then
            -- Check for a control-X shortcut (control modifier is implied by the code being 1-26)
            local shift = ev[KEvAKMod]() & KKmodShift > 0
            local cmd = (shift and 0x40 or 0x60) + k
            if shortcuts[cmd] then
                result = cmd
            end
        elseif k == KEvPtr then
            local evWinId = ev[KEvAPtrWindowId]()
            local x, y = ev[KEvAPtrPositionX](), ev[KEvAPtrPositionY]()
            local handled = false
            if evWinId ~= current.id then
                if evWinId == pane.id then
                    pane.closeSubmenu()
                    current = pane
                    -- And keep going to handle it
                elseif bar and bar.selectionWin and evWinId == bar.selectionWin then
                    pane.closeSubmenu()
                    pane.moveSelectionTo(1)
                    handled = true
                elseif bar and evWinId == bar.id then
                    for i, item in ipairs(bar.items) do
                        if within(x, y, item) then
                            pane.closeSubmenu()
                            bar.moveSelectionTo(i)
                            break
                        end
                    end
                    handled = true
                elseif not seenPointerDown then
                    -- Ignore everything that might've resulted from a pen down before mPOPUP was called
                    if ev[KEvAPtrType]() == KEvPtrPenDown then
                        seenPointerDown = true
                    end
                    handled = true
                else
                    -- printf("Event not in any window!\n")
                    result = 0
                    break
                end
            end
            if not handled then
                local idx
                if x >= 0 and x < current.w and y >= 0 and y < current.h then
                    idx = #current.items
                    while idx and y < current.items[idx].y do
                        idx = idx - 1
                        if idx == 0 then idx = nil end
                    end
                end
                current.moveSelectionTo(idx)
                if ev[KEvAPtrType]() == KEvPtrPenUp then
                    -- Pen up outside the window (ie when idx is nil) should always mean dismiss
                    if idx == nil then
                        result = 0
                    elseif current.items[current.selected].submenu then
                        current.openSubmenu()
                    else
                        result = current.choose(idx)
                        highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
                    end
                end
            end
        end
    end

    if pane.submenu then
        gCLOSE(pane.submenu.id)
    end
    gCLOSE(pane.id)
    if bar then
        if bar.selectionWin then
            gCLOSE(bar.selectionWin)
        end
        gCLOSE(bar.id)
    end
    return result, highlight
end

function mPOPUP(x, y, pos, values, init)
    -- Note, init isn't part of the actual OPL mPOPUP API but is needed to implement dialog choicelists properly
    local state = runtime:saveGraphicsState()

    local shortcuts = {}
    for _, item in ipairs(values) do
        local key = item.key
        if key < 0 then
            key = -key
        end
        if key > 32 then
            shortcuts[key & 0xFF] = true
        end
    end

    local pane = makeMenuPane(x, y, pos, values, init)
    local result = runMenuEventLoop(nil, pane, shortcuts)
    runtime:restoreGraphicsState(state)
    return result
end

function MENU(menubar)
    local state = runtime:saveGraphicsState()

    -- Draw the menu bar
    local barGap = 21
    local borderWidth = 5
    local barItems = {}
    local textx = borderWidth + barGap
    gFONT(kMenuFont)
    local _, textHeight, ascent = gTWIDTH("0")
    local textYPad = 2
    local barHeight = borderWidth * 2 + textHeight + textYPad * 2
    for i, card in ipairs(menubar) do
        local textw = gTWIDTH(card.title)
        barItems[i] = {
            x = textx - barGap // 2,
            textx = textx,
            text = card.title,
            y = borderWidth + textYPad,
            w = textw + barGap,
            h = barHeight,

        }
        textx = textx + textw + barGap
    end
    
    local barWidth = textx + borderWidth
    local barWin = gCREATE(1, 1, barWidth, barHeight, false, KgCreate4GrayMode | KgCreateHasShadow | 0x200)
    lightGrey()
    gFILL(barWidth, barHeight)
    black()
    gBOX(barWidth, barHeight)
    gAT(1, 1)
    gXBORDER(2, 0x94, barWidth - 2, barHeight - 2)
    for _, item in ipairs(barItems) do
        gAT(item.textx, item.y)
        runtime:drawCmd("text", { string = item.text })
    end
    gVISIBLE(true)

    -- There are at most 4 UI elements in play while displaying the menubar:
    -- 1: bar itself.
    -- 2: bar.selectionWin, which hovers over bar drawing the highlighted menu name.
    -- 3: pane, the currently displayed top-level menu.
    -- 4: pane.submenu, optionally. OPL doesn't support nested submenus.

    local bar = {
        x = 1,
        y = 1,
        w = barWidth,
        h = barHeight,
        id = barWin,
        items = barItems,
        selected = nil,
        selectionWin = nil,
    }
    local firstMenuY = bar.y + barHeight - borderWidth
    local initBarIdx = menubar.highlight and (1 + (menubar.highlight // 256)) or 1
    if initBarIdx > #bar.items then
        initBarIdx = 1
    end
    local initPaneIdx = menubar.highlight and (1 + (menubar.highlight - ((initBarIdx - 1) * 256))) or 1
    if initPaneIdx > #menubar[initBarIdx] then
        initPaneIdx = 1
    end

    local function drawBarSelection()
        if not bar.selectionWin then
            bar.selectionWin = gCREATE(-1, -1, 1, 1, true, KgCreate4GrayMode | KgCreateHasShadow | 0x200)
        end
        gUSE(bar.selectionWin)
        gFONT(kMenuFont)
        local item = bar.items[bar.selected]
        local w = item.w
        local h = firstMenuY - bar.y
        gSETWIN(bar.x + item.x, bar.y, w, h)
        gAT(0, 0)
        black()
        gFILL(w, h, KgModeClear)
        gBOX(w, h + 5)
        gAT(1, 1)
        gXBORDER(2, 0x94, w - 2, h + 5)
        runtime:drawCmd("text", { string = item.text, x = item.textx - item.x, y = item.y })
    end

    bar.moveSelectionTo = function(i)
        if i == bar.selected then
            return
        elseif i == 0 then
            i = #bar.items
        elseif i and i > #bar.items then
            i = 1
        end
        bar.selected = i
        drawBarSelection()
        if bar.pane then
           bar.pane.closeSubmenu()
           gCLOSE(bar.pane.id)
           bar.pane = nil
        end
        local item = bar.items[bar.selected]
        bar.pane = makeMenuPane(bar.x + item.x, firstMenuY, KMPopupPosTopLeft, menubar[bar.selected], 1, item.w)
    end

    bar.moveSelectionTo(initBarIdx)
    bar.pane.moveSelectionTo(initPaneIdx)

    -- Construct shorcuts
    local shortcuts = {}
    for _, pane in ipairs(menubar) do
        for _, item in ipairs(pane) do
            local key = item.key
            if key < 0 then
                key = -key
            end
            if key > 32 then
                shortcuts[key & 0xFF] = true
            end
        end
    end

    local result, highlight = runMenuEventLoop(bar, nil, shortcuts)
    runtime:restoreGraphicsState(state)
    return result, highlight
end

return _ENV
