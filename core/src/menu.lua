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

-- Reminder: everything in this file is magically imported into the global namespace by _setRuntime() in opl.lua,
-- and then into runtime by newRuntime() in runtime.lua.

_ENV = module()

local kMenuFont = KFontArialNormal15
local kShortcutFont = KFontArialNormal11

local DrawStyle = enum {
    normal = 0,
    highlighted = 1,
    dismissing = 2,
    unfocussedHighlighted = 3,
}

local MenuPane = class {}

function MenuPane:draw()
    local scrollbar = self.scrollbar
    -- Something has to draw the gap between the start of the content area and the content offset of the first item
    -- (which is not right up against the top of the content area)
    local topGap = self.items[1].contentOffset - self.contentOffset
    if topGap > 0 then
        gAT(self.inset.left, self.inset.top)
        gFILL(self.contentWidth, topGap, KgModeClear)
    end

    for i, item in ipairs(self.items) do
        if self:itemAtLeastPartiallyVisible(i) then
            self:drawItem(i, i == self.selected)
            if item.lineAfter then
                black()
                gAT(self.inset.left, self:drawPosForContentOffset(item.contentOffset) + self.lineHeight)
                gFILL(self.contentWidth, self.lineGap, KgModeClear)
                gMOVE(0, self.lineGap // 2)
                gLINEBY(self.contentWidth, 0)
            end
        end
    end

    if self.scrollbar then
        self.scrollbar:draw()
    end

    -- Draw border last so if items overflow, it gets covered up
    self:drawBorder()
end

-- This more like drawNonContentArea...
function MenuPane:drawBorder()
    black()
    gAT(0, 0)
    if runtime:isSeries3() then
        gMOVE(1, 0)
        gBORDER(1, self.w - 2, self.h - 1)
    else
        gBOX(self.w, self.h)
        gMOVE(1, 1)
        gXBORDER(2, 0x94, self.w - 2, self.h - 2)
        local nonBorderInset = self.inset.left - self.border.left
        gAT(self.border.left, self.border.top)
        local fillWidth = nonBorderInset + self.contentWidth
        gFILL(fillWidth, nonBorderInset, KgModeClear)
        gAT(self.border.left, self.h - self.inset.top)
        gFILL(fillWidth, nonBorderInset, KgModeClear)
    end
end

function MenuPane:drawItem(i, style)
    local item = self.items[i]
    local inset, contentWidth, lineHeight = self.inset, self.contentWidth, self.lineHeight
    local margin, textGap = self.margin, self.textGap
    assert(item, "Index out of range in drawItem! "..tostring(i))
    local y = self:drawPosForContentOffset(item.contentOffset)
    -- printf("drawItem(%d) contentOffset=%d y=%d\n", i, item.contentOffset, y)
    gAT(inset.left, y)
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
    local fillMode = (runtime:isSeries3() or not highlighted) and KgModeClear or KgModeSet
    gFILL(contentWidth, lineHeight, fillMode)
    if not runtime:isSeries3() then
        if style == DrawStyle.dismissing then
            gAT(inset, y)
            black()
            gBOX(contentWidth, lineHeight)
        end
        if item.key & KMenuDimmed > 0 then
            darkGrey()
        elseif highlighted then
            white()
        end
    end
    if item.key & (KMenuSymbolOn|KMenuCheckBox) == (KMenuSymbolOn|KMenuCheckBox) then
        gAT(inset.left, y + margin.top)
        gFONT(KFontEiksym15)
        runtime:drawText(".")
    end
    gAT(inset.left + margin.left, y + margin.top)
    gFONT(self.menuFont)
    runtime:drawText(item.text)
    if item.shortcutText then
        local tx = inset.left + margin.left + self.maxTextWidth + textGap
        local ty = y + margin.top + self.shortcutTextYOffset
        gFONT(self.shortcutFont)
        runtime:drawText(item.shortcutText, tx, ty)
    end
    if item.submenu then
        gFONT(KFontEiksym15)
        local tx = self.w - margin.right
        if self.scrollbar then
            tx = tx - self.scrollbar.w
        end
        local ty = y + margin.top
        item.submenuXPos = tx + gTWIDTH('"')
        runtime:drawText('"', tx, ty)
        gFONT(self.menuFont)
    end
    if style ~= DrawStyle.normal and runtime:isSeries3() then
        gAT(inset.left, y)
        gINVERT(contentWidth, lineHeight)
    end
end

local function inrange(min, val, rangeLen)
    return val >= min and val < min + rangeLen
end

local function within(x, y, rect)
    return inrange(rect.x, x, rect.w) and inrange(rect.y, y, rect.h)
end

function MenuPane:itemAtLeastPartiallyVisible(i)
    if self.scrollbar == nil then
        -- Then it'll always be visible (assuming i is a valid item index...)
        return true
    end
    local start = self.contentOffset
    local visibleContentHeight = self:visibleContentHeight()
    local item = self.items[i]
    return inrange(start, item.contentOffset, visibleContentHeight) or
        inrange(start, item.contentOffset + item.h, visibleContentHeight)
end

function MenuPane:firstFullyVisibleItem()
    for i, item in ipairs(self.items) do
        if item.contentOffset >= self.contentOffset then
            return i
        end
    end
    error("No visible items!?")
end

function MenuPane:moveSelectionTo(i)
    if i == self.selected then
        return
    elseif i == 0 then
        i = #self.items
    elseif i and i > #self.items then
        i = 1
    end
    local currentContentOffset = self.contentOffset
    local newContentOffset = currentContentOffset
    local item = i and self.items[i]
    local visHeight = self:visibleContentHeight()

    if item and item.contentOffset < self.contentOffset then
        newContentOffset = item.contentOffset
    elseif item and item.contentOffset + item.h > self.contentOffset + visHeight then
        newContentOffset = math.max(0, item.contentOffset + item.h - visHeight)
    end

    -- printf("moveSelectionTo(%d) visHeight=%d currentContentOffset=%d newContentOffset=%d\n", i, visHeight, currentContentOffset, newContentOffset)
    if newContentOffset == currentContentOffset then
        local selectedIsVisible = self.selected and self:itemAtLeastPartiallyVisible(self.selected)
        if selectedIsVisible then
            self:drawItem(self.selected, false)
        end
        self.selected = i
        if self.selected then
            self:drawItem(self.selected, true)
        end
        if self.scrollbar then
            self:drawBorder() -- In case we trampled it...
        end
    else
        -- We're scrolling, have to redraw everything
        self.selected = i
        self.contentOffset = newContentOffset
        self:updateScrollbar()
        self:draw()
    end
end

function MenuPane:updateScrollbar()
    if self.scrollbar then
        self.scrollbar:setContentOffset(self.contentOffset)
    end
end

function MenuPane:choose(i)
    if not i then
        return nil
    end
    local item = self.items[i]
    local key = item.key
    if key & KMenuDimmed > 0 then
        gIPRINT("This item is not available", KBusyTopRight)
        return nil
    end
    self:drawItem(i, DrawStyle.dismissing)
    -- wait a bit to make it obvious it's been selected
    gUPDATE()
    PAUSE(5)
    -- If there's no key (in the case of mPOPUPEx) then return the index
    return (key == 0 and i) or (key & 0xFF)
end

function MenuPane:openSubmenu()
    assert(self.submenu == nil, "Submenu already open?!")
    local item = self.items[self.selected]
    self:drawItem(self.selected, DrawStyle.unfocussedHighlighted)
    assert(item.submenu, "No submenu to open!")
    self.submenu = MenuPane.new(self.x + item.submenuXPos, self:drawPosForContentOffset(item.contentOffset), KMPopupPosTopLeft, item.submenu)
end

function MenuPane:closeSubmenu()
    if self.submenu then
        gCLOSE(self.submenu.id)
        self.submenu = nil
        gUSE(self.id)
        local selected = self.selected
        self.selected = nil -- To force the move to redraw
        self:moveSelectionTo(selected)
    end
end

function MenuPane:drawPosForContentOffset(yoffset)
    return self.inset.top + (yoffset - self.contentOffset)
end

function MenuPane:scrollbarContentOffsetChanged(scrollbar)
    self.contentOffset = scrollbar.contentOffset
    self:draw()
end

function MenuPane:scrollbarDidScroll(inc)
    local newContentOffset
    local firstVisible = self:firstFullyVisibleItem()
    if inc < 0 then
        if firstVisible == 1 then
            newContentOffset = 0
        else
            newContentOffset = self.items[firstVisible - 1].contentOffset
        end
    else
        local nextItem = self.items[firstVisible + 1]
        if nextItem then
            newContentOffset = nextItem.contentOffset
        else
            return
        end
    end

    -- We'll let scrollbar worry about bounds checking
    self.scrollbar:setContentOffset(newContentOffset)
    self:scrollbarContentOffsetChanged(self.scrollbar)
end

function MenuPane:contentHeight()
    local items = self.items
    local lastItem = items[#items]
    return lastItem.contentOffset + lastItem.h
end

function MenuPane:visibleContentHeight()
    return self.h - self.inset.top - self.inset.bottom
end

function MenuPane.new(x, y, pos, values, selected, cutoutLen)
    -- This is the number of pixels the border occupies, nothing else should draw in here.
    local border

    -- This is how much the content is inset by. The numbers include the border.
    -- If there is no space between the content and the border this will be the
    -- same as border.
    local inset

    -- This is how much the text is indented by, from the edge of the content
    -- area. So the text x coord would be inset.left + margin.left
    local margin

    -- The initial value of this is the extra y offset of where the first item
    -- is laid out when not scrolling (aka scroll area offset)
    local contentOffset

    -- Horizontal space between menu text and shortcut
    local textGap

    local shortcutFont, menuFont, createFlags, shadowHeight, lineGap

    -- local device = runtime:getDeviceName()
    -- if device == "psion-series-3" then
    if runtime:isSeries3() then
        -- todo 3a/3c
        border = { top = 2, left = 3, bottom = 4, right = 4 }
        inset = border
        margin = { top = 1, left = 2, bottom = 1, right = 2 }
        contentOffset = 0
        textGap = 14
        lineGap = 2 -- No space above line, one below
        menuFont = 1
        shortcutFont = 1
        shadowHeight = 0
        createFlags = KColorgCreate2GrayMode
    else
        border = { top = 4, left = 4, bottom = 4, right = 4 }
        inset = { top = 5, left = 5, bottom = 5, right = 5 }
        margin = { top = 3, left = 15, bottom = 1, right = 20 }
        contentOffset = 2
        textGap = 6
        lineGap = 5 -- 2 pixels space each side of the horizontal line
        menuFont = kMenuFont
        shortcutFont = kShortcutFont
        shadowHeight = 8
        createFlags = KColorgCreate4GrayMode | KgCreateHasShadow | ((shadowHeight // 2) << 4)
    end

    -- Get required font metrics
    gFONT(menuFont)
    local textHeight = gINFO().fontHeight
    local ascent = gINFO().fontAscent
    gFONT(shortcutFont)
    local shortcutAscent = gINFO().fontAscent
    local lineHeight = textHeight + margin.top + margin.bottom
    local shortcutTextYOffset = ascent - shortcutAscent

    -- Work out content and window size
    local numItems = #values
    local items = {}
    local maxTextWidth = 20
    local maxShortcutTextWidth = 0
    local shortcuts = {}
    for i, value in ipairs(values) do
        -- For menus in a menubar, key should always be set. But in a dialog dCHOICE popup, there are no shortcuts so
        -- key will be nil
        assert((value.key == nil or value.key ~= 0) and value.text, KErrInvalidArgs)
        local key = value.key or 0
        local lineAfter = key < 0
        if lineAfter then
            key = -key
        end
        local keyNoFlags = key & 0xFF
        local shortcutText
        if keyNoFlags <= 32 then
            shortcutText = nil
        elseif keyNoFlags >= 0x41 and keyNoFlags <= 0x5A then
            if runtime:isSeries3() then
                shortcutText = string.format("Shift\x02%c", keyNoFlags)
            else
                shortcutText = string.format("Shift+Ctrl+%c", keyNoFlags)
            end
        elseif keyNoFlags >= 0x61 and keyNoFlags <= 0x7A then
            if runtime:isSeries3() then
                shortcutText = string.format("\x02%c", keyNoFlags - 0x20)
            else
                shortcutText = string.format("Ctrl+%c", keyNoFlags - 0x20)
            end
        end
        gFONT(menuFont)
        local w = gTWIDTH(value.text)
        if shortcutText then
            shortcuts[keyNoFlags] = i
            gFONT(shortcutFont)
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
            contentOffset = contentOffset,
            h = lineHeight + (lineAfter and lineGap or 0),
            lineAfter = lineAfter,
            submenu = value.submenu,
        }
        contentOffset = contentOffset + items[i].h
    end

    local contentWidth = margin.left + maxTextWidth + maxShortcutTextWidth + margin.right
    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = math.min(contentWidth + inset.left + inset.right, screenWidth)
    local h = inset.top + contentOffset + inset.bottom
    local scrollbar = nil

    local maxHeight = (pos == nil) and (screenHeight - shadowHeight - y) or screenHeight
    if h > maxHeight then
        h = maxHeight
        local scrollbarTop = border.top
        local scrollbarHeight = h - border.top - border.bottom -- Note, larger than visibleContentHeight!
        local visibleContentHeight = h - inset.top - inset.bottom -- Same defn as MenuPane:visibleContentHeight()
        local contentHeight = contentOffset -- Should be same as MenuPane:contentHeight()
        local Scrollbar = runtime:require("scrollbar").Scrollbar
        scrollbar = Scrollbar.newVertical(w - inset.right + 2, scrollbarTop, scrollbarHeight, visibleContentHeight, contentHeight)
        w = w + scrollbar.w + 1
        if w > screenWidth then
            scrollbar.x = screenWidth - scrollbar.w
            w = screenWidth
        end
    end

    -- pos == nil means it's MENU not mPOPUP and the position is top left and not moveable
    if pos == KMPopupPosTopLeft or pos == nil then
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
    if y + h + shadowHeight > screenHeight then
        y = math.max(0, screenHeight - h - shadowHeight)
    end

    local win = gCREATE(x, y, w, h, false, createFlags)
    if scrollbar then
        darkGrey()
        gAT(scrollbar.x - 1, scrollbar.y)
        gLINEBY(0, scrollbar.h)
    end

    -- TODO this doesn't look right yet...
    -- if cutoutLen then
    --     gAT(inset, 0)
    --     gFILL(cutoutLen, inset, KgModeClear)
    -- end

    local pane = MenuPane {
        id = win,
        x = x,
        y = y,
        w = w,
        h = h,
        shortcutFont = shortcutFont,
        menuFont = menuFont,
        inset = inset,
        border = border,
        textGap = textGap,
        lineGap = lineGap,
        margin = margin,
        contentWidth = contentWidth,
        lineHeight = lineHeight,
        items = items,
        selected = 1,
        contentOffset = 0,
        scrollbar = scrollbar,
        shortcutTextYOffset = shortcutTextYOffset,
        maxTextWidth = maxTextWidth,
    }

    pane:draw()
    if pane.scrollbar then
        pane.scrollbar.observer = pane
        pane.scrollbar:draw()
    end
    if selected then
        pane:moveSelectionTo(selected)
    end
    gVISIBLE(true)

    return pane
end

local function runMenuEventLoop(bar, pane, shortcuts)
    gUPDATE(false)
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()
    local result = nil
    local highlight = nil
    local seenPointerDown = false
    local capturedByControl = nil
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
        elseif k == KKeyUpArrow32 then
            current:moveSelectionTo(current.selected - 1)
        elseif k == KKeyDownArrow32 then
            current:moveSelectionTo(current.selected + 1)
        elseif k == KKeyLeftArrow32 then
            if pane.submenu then
                pane:closeSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected - 1)
            end
        elseif k == KKeyRightArrow32 then
            if pane.submenu == nil and pane.items[pane.selected].submenu then
                pane:openSubmenu()
            elseif bar then
                bar.moveSelectionTo(bar.selected + 1)
            end
        elseif k == KKeyPageUp32 then
            local newContentOffset = current.items[current.selected].contentOffset - current:visibleContentHeight()
            local newIndex = current.selected
            while newIndex > 1 and current.items[newIndex].contentOffset > newContentOffset do
                newIndex = newIndex - 1
            end
            current:moveSelectionTo(newIndex)
        elseif k == KKeyPageDown32 then
            local newContentOffset = current.items[current.selected].contentOffset + current:visibleContentHeight()
            local newIndex = current.selected
            while newIndex < #current.items and current.items[newIndex].contentOffset < newContentOffset do
                newIndex = newIndex + 1
            end
            current:moveSelectionTo(newIndex)
        elseif k == KKeyPageLeft32 then
            if bar then
                bar.moveSelectionTo(1)
            else
                current:moveSelectionTo(1)
            end
        elseif k == KKeyPageRight32 then
            if bar then
                bar.moveSelectionTo(#bar.items)
            else
                current:moveSelectionTo(#current.items)
            end
        elseif k == KKeyEsc then
            if pane.submenu then
                pane:closeSubmenu()
            else
                result = 0
            end
        elseif k == KKeyEnter then
            if current.items[current.selected].submenu then
                current:openSubmenu()
            else
                result = current:choose(current.selected)
                highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
            end
        elseif k <= 26 and not runtime:isSeries3() then
            -- Check for a control-X shortcut (control modifier is implied by the code being 1-26)
            local shift = ev[KEvAKMod]() & KKmodShift > 0
            local cmd = (shift and 0x40 or 0x60) + k
            if shortcuts[cmd] then
                result = cmd
            end
        elseif (k & 0x200) ~= 0 then
            -- Could check for the psion modifier key but there's no need while the 0x200 doesn't happen to anything
            -- else (and all keys that the 0x200 applies to are ones that can be used as shortcuts)
            local cmd = k & ~0x200
            if shortcuts[cmd] then
                result = cmd
            end
        elseif k == KEvPtr then
            local evWinId = ev[KEvAPtrWindowId]()
            local x, y = ev[KEvAPtrPositionX](), ev[KEvAPtrPositionY]()
            local eventType = ev[KEvAPtrType]()
            local handled = false
            if capturedByControl then
                capturedByControl:handlePointerEvent(x, y, eventType)
                handled = true
                if eventType == KEvPtrPenUp then
                    capturedByControl = nil
                end
            elseif evWinId ~= current.id then
                if evWinId == pane.id then
                    pane:closeSubmenu()
                    current = pane
                    -- And keep going to handle it
                elseif bar and bar.selectionWin and evWinId == bar.selectionWin then
                    pane:closeSubmenu()
                    pane:moveSelectionTo(1)
                    handled = true
                elseif bar and evWinId == bar.id then
                    for i, item in ipairs(bar.items) do
                        if within(x, y, item) then
                            pane:closeSubmenu()
                            bar.moveSelectionTo(i)
                            break
                        end
                    end
                    handled = true
                elseif not seenPointerDown then
                    -- Ignore everything that might've resulted from a pen down before mPOPUP was called
                    if eventType == KEvPtrPenDown then
                        seenPointerDown = true
                    end
                    handled = true
                else
                    -- printf("Event not in any window!\n")
                    result = 0
                    break
                end
            end
            local idx
            if not handled then
                if x >= 0 and x < current.w and y >= 0 and y < current.h then
                    if current.scrollbar and x >= current.scrollbar.x and eventType == KEvPtrPenDown then
                        capturedByControl = current.scrollbar
                        current.scrollbar:handlePointerEvent(x, y, eventType)
                        handled = true
                    else
                        idx = #current.items
                        while idx and y < current:drawPosForContentOffset(current.items[idx].contentOffset) do
                            idx = idx - 1
                            if idx == 0 then idx = nil end
                        end
                    end
                end
            end
            if not handled then
                current:moveSelectionTo(idx)
                if eventType == KEvPtrPenUp then
                    -- Pen up outside the window (ie when idx is nil) should always mean dismiss
                    if idx == nil then
                        result = 0
                    elseif current.items[current.selected].submenu then
                        current:openSubmenu()
                    else
                        result = current:choose(idx)
                        highlight = bar and (bar.selected - 1) * 256 + (pane.selected - 1)
                    end
                end
            end
        end
        gUPDATE()
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

function mPOPUP(x, y, pos, values)
    for _, item in ipairs(values) do
        assert(item.key and item.key ~= 0, KErrInvalidArgs)
    end
    return mPOPUPEx(x, y, pos, values, nil)
end

-- This is an opolua extension that allows an initial value to be specified, and also doesn't require a key shortcut to
-- be specified (which also means menus with more than 32 items without keyboard shortcuts are allowed).
function mPOPUPEx(x, y, pos, values, init)
    local state = runtime:saveGraphicsState()

    local shortcuts = {}
    for _, item in ipairs(values) do
        local key = item.key
        if key then
            if key < 0 then
                key = -key
            end
            if key > 32 then
                shortcuts[key & 0xFF] = true
            end
        end
    end

    local pane = MenuPane.new(x, y, pos, values, init)
    local result = runMenuEventLoop(nil, pane, shortcuts)
    runtime:restoreGraphicsState(state)
    return result
end

function MENU(menubar)
    local state = runtime:saveGraphicsState()

    -- Draw the menu bar
    local barGap, barCreateFlags, menuFont
    local border, textPad, firstItemGap
    if runtime:isSeries3() then
        menuFont = 1
        barGap = 21
        firstItemGap = 9
        border = { top = 3, left = 3, bottom = 4, right = 4 }
        textPad = { top = 0, bottom = 1 }
        barCreateFlags = KColorgCreate2GrayMode
    else
        menuFont = kMenuFont
        barGap = 21
        firstItemGap = barGap
        border = { top = 5, left = 5, bottom = 5, right = 5 }
        textPad = { top = 2, bottom = 2 }
        barCreateFlags = KColorgCreate4GrayMode | KgCreateHasShadow | 0x200
    end
    gFONT(menuFont)
    local barItems = {}
    local textx = border.left + firstItemGap
    local textHeight = gINFO().fontHeight
    local barHeight = border.top + border.bottom + textHeight + textPad.top + textPad.bottom
    for i, card in ipairs(menubar) do
        local textw = gTWIDTH(card.title)
        barItems[i] = {
            x = textx - barGap // 2,
            textx = textx,
            text = card.title,
            y = border.top + textPad.top,
            w = textw + barGap,
            h = barHeight,

        }
        textx = textx + textw + barGap
    end

    local barWidth = textx + border.right
    local barWin
    if runtime:isSeries3() then
        local x = (runtime:getGraphics().screenWidth - barWidth) // 2
        barWin = gCREATE(x, 0, barWidth, barHeight, false, barCreateFlags)
        gFONT(1)
        gAT(1, 1)
        gBORDER(1, barWidth - 2, barHeight - 2)
    else
        barWin = gCREATE(2, 2, barWidth, barHeight, false, barCreateFlags)
        gFONT(kMenuFont)
        lightGrey()
        gFILL(barWidth, barHeight)
        black()
        gBOX(barWidth, barHeight)
        gAT(1, 1)
        gXBORDER(2, 0x94, barWidth - 2, barHeight - 2)
    end
    for _, item in ipairs(barItems) do
        gAT(item.textx, item.y)
        runtime:drawText(item.text)
    end
    gVISIBLE(true)

    -- There are at most 4 UI elements in play while displaying the menubar:
    -- 1: bar itself.
    -- 2: bar.selectionWin, which hovers over bar drawing the highlighted menu name.
    -- 3: pane, the currently displayed top-level menu.
    -- 4: pane.submenu, optionally. OPL doesn't support nested submenus.

    local bar = {
        w = barWidth,
        h = barHeight,
        id = barWin,
        items = barItems,
        selected = nil,
        selectionWin = nil,
    }
    local firstMenuY -- In screen coords
    if runtime:isSeries3() then
        -- 3 being one less than the height of the bottom of a gBORDER(1), such that firstMenuY is in line with the top
        -- pixel of the bottom of the gBORDER
        firstMenuY = gORIGINY() + barHeight - 3
    else
        firstMenuY = gORIGINY() + barHeight - border.top
    end
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
            bar.selectionWin = gCREATE(-1, -1, 1, 1, true, barCreateFlags)
        end
        local item = bar.items[bar.selected]
        gUSE(bar.id)
        local x = gORIGINX() + item.x
        local y = gORIGINY()
        local w = item.w
        local h = firstMenuY --TODO?? - bar.y
        gUSE(bar.selectionWin)
        gFONT(menuFont)
        gSETWIN(x, y, w, h)
        gAT(0, 0)
        black()
        gFILL(w, h, KgModeClear)
        if runtime:isSeries3() then
            gAT(1, 1)
            gBORDER(1, w - 2, h + 3)
        else
            gBOX(w, h + 5)
            gAT(1, 1)
            gXBORDER(2, 0x94, w - 2, h + 5)
        end
        runtime:drawText(item.text, item.textx - item.x, item.y)
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
           bar.pane:closeSubmenu()
           gCLOSE(bar.pane.id)
           bar.pane = nil
        end
        local item = bar.items[bar.selected]
        gUSE(bar.id)
        bar.pane = MenuPane.new(gORIGINX() + item.x, firstMenuY, nil, menubar[bar.selected], 1, item.w)
    end

    bar.moveSelectionTo(initBarIdx)
    bar.pane:moveSelectionTo(initPaneIdx)

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
