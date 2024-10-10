-- Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

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

local MenuPane = class {
    inset = 5, -- Nothing draws inside this except for borders and scrollbar
    borderWidth = 4, -- See drawBorder(), 3 from the gXBORDER and 1 from the gBOX
    textGap = 6,
    lineGap = 5, -- 2 pixels space each side of the horizontal line
    leftMargin = 15, -- This is part of the highlighted area
    rightMargin = 20, -- ditto
    textYPad = 3,
}

function MenuPane:draw()
    local scrollbar = self.scrollbar
    -- Something has to draw the gap between the start of the content area and the content offset of the first item
    -- (which is not right up against the top of the content area)
    local topGap = self.items[1].contentOffset - self.contentOffset
    if topGap > 0 then
        gAT(self.inset, self.contentStartY)
        gFILL(self.contentWidth, topGap, KgModeClear)
    end

    for i, item in ipairs(self.items) do
        if self:itemAtLeastPartiallyVisible(i) then
            self:drawItem(i, i == self.selected)
            if item.lineAfter then
                black()
                gAT(self.inset, self:drawPosForContentOffset(item.contentOffset) + self.lineHeight)
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
    gBOX(self.w, self.h)
    gMOVE(1, 1)
    gXBORDER(2, 0x94, self.w - 2, self.h - 2)
    local nonBorderInset = self.inset - self.borderWidth
    gAT(self.borderWidth, self.borderWidth)
    local fillWidth = nonBorderInset + self.contentWidth
    gFILL(fillWidth, nonBorderInset, KgModeClear)
    gAT(self.borderWidth, self.h - self.inset)
    gFILL(fillWidth, nonBorderInset, KgModeClear)
end

function MenuPane:drawItem(i, style)
    local item = self.items[i]
    local inset, contentWidth, lineHeight = self.inset, self.contentWidth, self.lineHeight
    local leftMargin, textGap, textYPad = self.leftMargin, self.textGap, self.textYPad
    assert(item, "Index out of range in drawItem! "..tostring(i))
    local y = self:drawPosForContentOffset(item.contentOffset)
    gAT(inset, y)
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
        gAT(inset, y)
        black()
        gBOX(contentWidth, lineHeight)
    end
    if item.key & KMenuDimmed > 0 then
        darkGrey()
    elseif highlighted then
        white()
    end
    if item.key & (KMenuSymbolOn|KMenuCheckBox) == (KMenuSymbolOn|KMenuCheckBox) then
        gAT(inset, y + textYPad)
        gFONT(KFontEiksym15)
        runtime:drawCmd("text", { string = "." })
    end
    gAT(inset + leftMargin, y + textYPad)
    gFONT(kMenuFont)
    runtime:drawCmd("text", { string = item.text })
    if item.shortcutText then
        local tx = inset + leftMargin + self.maxTextWidth + textGap
        local ty = y + textYPad + self.shortcutTextYOffset
        gFONT(kShortcutFont)
        runtime:drawCmd("text", { string = item.shortcutText, x = tx, y = ty })
    end
    if item.submenu then
        gFONT(KFontEiksym15)
        local tx = self.w - self.rightMargin
        if self.scrollbar then
            tx = tx - self.scrollbar.w
        end
        local ty = y + textYPad
        item.submenuXPos = tx + gTWIDTH('"')
        runtime:drawCmd("text", { string = '"', x = tx, y = ty })
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
    return self.contentStartY + (yoffset - self.contentOffset)
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
    return self.h - self.inset * 2
end

function MenuPane.new(x, y, pos, values, selected, cutoutLen)
    -- Get required font metrics
    gFONT(kMenuFont)
    local textHeight = gINFO().fontHeight
    local ascent = gINFO().fontAscent
    local lineHeight = textHeight + MenuPane.textYPad * 2
    gFONT(kShortcutFont)
    local shortcutAscent = gINFO().fontAscent
    local shortcutTextYOffset = ascent - shortcutAscent

    -- Work out content and window size
    local inset = MenuPane.inset
    local textGap = MenuPane.textGap
    local lineGap = MenuPane.lineGap -- 2 pixels space each side of the horizontal line
    local numItems = #values
    local items = {}
    local contentStartY = inset
    local contentOffset = 2 -- Gap between start of content area and first item
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
            contentOffset = contentOffset,
            h = lineHeight + (lineAfter and lineGap or 0),
            lineAfter = lineAfter,
            submenu = value.submenu,
        }
        contentOffset = contentOffset + items[i].h
    end

    local leftMargin = 15 -- This is part of the highlighted area
    local rightMargin = 20 -- ditto
    local shadowHeight = 8
    local contentWidth = leftMargin + maxTextWidth + maxShortcutTextWidth + rightMargin
    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = math.min(contentWidth + inset * 2, screenWidth)
    local h = contentStartY + contentOffset + inset
    local scrollbar = nil

    local maxHeight = (pos == nil) and (screenHeight - shadowHeight - y) or screenHeight
    if h > maxHeight then
        h = maxHeight
        local scrollbarTop = MenuPane.borderWidth
        local scrollbarHeight = h - (MenuPane.borderWidth * 2) -- Note, larger than visibleContentHeight!
        local visibleContentHeight = h - inset * 2 -- Same defn as MenuPane:visibleContentHeight()
        local contentHeight = contentOffset -- Should be same as MenuPane:contentHeight()
        local Scrollbar = runtime:require("scrollbar").Scrollbar
        scrollbar = Scrollbar.newVertical(w - inset + 2, scrollbarTop, scrollbarHeight, visibleContentHeight, contentHeight)
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

    local win = gCREATE(x, y, w, h, false, KColorgCreate4GrayMode | KgCreateHasShadow | 0x400)
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
        contentWidth = contentWidth,
        contentStartY = contentStartY,
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
    local barGap = 21
    local borderWidth = 5
    local barItems = {}
    local textx = borderWidth + barGap
    gFONT(kMenuFont)
    local textHeight = gINFO().fontHeight
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
    local barWin = gCREATE(2, 2, barWidth, barHeight, false, KColorgCreate4GrayMode | KgCreateHasShadow | 0x200)
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
            bar.selectionWin = gCREATE(-1, -1, 1, 1, true, KColorgCreate4GrayMode | KgCreateHasShadow | 0x200)
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
           bar.pane:closeSubmenu()
           gCLOSE(bar.pane.id)
           bar.pane = nil
        end
        local item = bar.items[bar.selected]
        bar.pane = MenuPane.new(bar.x + item.x, firstMenuY, nil, menubar[bar.selected], 1, item.w)
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
