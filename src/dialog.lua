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

View = class {}

local kDialogFont = KFontArialNormal15
local kButtonFont = KFontArialBold11
local kButtonShortcutFont = KFontArialNormal11
local kButtonHeight = 23
local kButtonYOffset = 9
local kButtonMinWidth = 50
local kButtonSpacing = 10
local kDialogLineHeight = 22 -- ?
local kDialogLineGap = 1
local kDialogLineTextYOffset = 4
local kChoiceLeftArrow = "3" -- in KFontEiksym15
local kChoiceRightArrow = "1" -- in KFontEiksym15
local kTickMark = "." -- in KFontEiksym15

local function wrapIndex(i, n)
    return 1 + ((i - 1) % n)
end

function View:contains(x, y)
    return x >= self.x and x < (self.x + self.w) and y >= self.y and y < (self.y + self.h)
end

-- Returns nil if the view doesn't layout with a prompt area (ie if it spans the entire dialog width)
function View:getPromptWidth()
    return self.prompt and gTWIDTH(self.prompt) or nil
end

-- This shouldn't include prompt width, if getPromptWidth returns non-nil
function View:contentSize()
    return 0, 0
end

function View:contentHeight()
    local _, h = self:contentSize()
    return h
end

function View:handlePointerEvent(x, y, type)
    for _, subview in ipairs(self.subviews or {}) do
        if subview:contains(x, y) and subview:handlePointerEvent(x, y, type) then
            return true
        end
    end

    -- DEBUG
    -- gCOLOR(0xFF, 0, 0)
    -- gAT(self.x, self.y)
    -- gFILL(self.w, self.h)
    -- gUPDATE()
    -- self:setNeedsRedraw()

    -- By default, consume anything else within our rect. If we ever wanted to
    -- support overlapping views that weren't parent-child (for some reason)
    -- then we might need to revisit that.
    return true
end

function View:handleKeyPress(k, modifiers)
    return false -- not handled
end

function View:addSubview(subview, x, y, w, h)
    subview.x = x
    subview.y = y
    if w then
        subview.w = w
    end
    if h then
        subview.h = h
    end
    subview.parent = self
    subview.windowId = self.windowId
    if not self.subviews then
        self.subviews = {}
    end
    subview:setNeedsRedraw()
    table.insert(self.subviews, subview)
end

function View:draw()
    for _, subview in ipairs(self.subviews or {}) do
        subview:drawIfNeeded()
    end
    self.needsRedraw = false
end

function View:drawIfNeeded()
    if self.needsRedraw then
        self:draw()
    end
end

function View:setNeedsRedraw(flag)
    if flag == nil then
        flag = true
    end
    self.needsRedraw = flag
    if self.parent then
        self.parent:setNeedsRedraw(flag)
    end
end

function View:setFocus(flag)
    self.hasFocus = flag
    self:setNeedsRedraw()
    if flag then
        local view = self.parent
        while view do
            if view.onFocusChanged then
                view.onFocusChanged(view, self)
                return
            end
            view = view.parent
        end
    end
end

function View:focussable()
    return false
end

function View:setPromptWidth(w)
    self.promptWidth = w
end

function View:drawPrompt()
    local x = self.x
    if not self.prompt then
        return x
    end
    local texty = self.y + kDialogLineTextYOffset
    if self.hasFocus then
        black()
    else
        white()
    end
    gAT(self.x, texty - 1)
    gFILL(gTWIDTH(self.prompt), self.charh + 2)
    if self.hasFocus then
        white()
    else
        black()
    end
    drawText(self.prompt, x, texty)
    x = x + self.promptWidth
    black()
    return x
end

function View:capturePointer()
    -- print("begin capture")
    self.capturing = true
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local evVar = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local ev = evVar()
    local evAddr = ev[1]:addressOf()
    while true do
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        local k = ev[KEvAType]()
        if k == KEvPtr then
            -- We have to present coords to handlePointerEvent in self's coordinates
            -- regardless of what window the event is in, hence we have to translate
            -- them from the screen coords
            local winX, winY = gORIGINX(), gORIGINY()
            local ptrType = ev[KEvAPtrType]()
            local x = ev[KEvAPtrScreenPosX]() - winX
            local y = ev[KEvAPtrScreenPosY]() - winY
            -- printf("Captured: x=%d y=%d t=%d\n", x, y, ptrType)
            self:handlePointerEvent(x, y, ptrType)
            self:drawIfNeeded()
            gUPDATE()
            if ptrType == KEvPtrPenUp then
                break
            end
        end
    end
    self.capturing = false
    -- print("end capture")
end

function View:updateValue()
end


PlaceholderView = class { _super = View }

function PlaceholderView:contentSize()
    return gTWIDTH("TODO dItem type 0"), kDialogLineHeight
end

function PlaceholderView:draw()
    gCOLOR(0xFF, 0, 0xFF)
    gAT(self.x, self.y)
    gFILL(self.w, self.h)
    black()
    drawText(string.format("TODO dItem type %d", self.type), self.x, self.y + kDialogLineTextYOffset)
end

DialogTitleBar = class { _super = View }

function DialogTitleBar:contentSize()
    local h = kDialogLineHeight
    if self.lineBelow then
        h = h + 2
    end
    return gTWIDTH(self.value), h
end

function DialogTitleBar:draw()
    gAT(self.x, self.y)
    if self.pressedX then
        white()
    else
        lightGrey()
    end
    gFILL(self.w, self.h)
    black()
    drawText(self.value, self.x + self.hMargin, self.y + 2)
    View.draw(self)
end

function DialogTitleBar:handlePointerEvent(x, y, type)
    if self.capturing then
        local deltax = x - self.pressedX
        local deltay = y - self.pressedY
        gSETWIN(gORIGINX() + deltax, gORIGINY() + deltay)
    elseif type == KEvPtrPenDown and self.draggable then
        self.pressedX = x
        self.pressedY = y
        self:draw()
        self:capturePointer() -- doesn't return until KEvPtrPenUp occurs
        self.pressedX = nil
        self.pressedY = nil
        self:setNeedsRedraw()
    end
    return true
end

DialogItemText = class { _super = View }

function DialogItemText:contentSize()
    local h = kDialogLineHeight
    if self.lineBelow then
        h = h + 1
    end
    return gTWIDTH(self.value), h
end

function DialogItemText:draw()
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    if not self.prompt then
        -- See if we need to check (and honour) alignment
        local w = gTWIDTH(self.value)
        if self.align == "center" then
            x = x + (self.w - w) // 2
        elseif self.align == "right" then
            x = x + self.w - w
        end
    end
    drawText(self.value, x, texty)
    if self.lineBelow then
        gAT(self.x, self.y + kDialogLineHeight + 1)
        gLINEBY(self.w, 0)
    end
    View.draw(self)
end

function DialogItemText:focussable()
    return self.selectable
end

DialogItemEdit = class { _super = View }

local kEditTextSpace = 2

function DialogItemEdit:contentSize()
    -- The @ sign is an example of the widest character in the dialog font (we
    -- should really have an easy API for getting max font width...)
    return gTWIDTH(string.rep("@", self.len)) + 2 * kEditTextSpace, kDialogLineHeight
end

function DialogItemEdit:draw()
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    local boxWidth = math.min(self:contentSize(), self.w - x)
    lightGrey()
    gAT(x, texty - 2)
    gBOX(boxWidth, self.charh + 3)
    black()
    gAT(x + 1, texty)
    gFILL(boxWidth - 2, self.charh, KgModeClear)
    drawText(self.value, x + kEditTextSpace, texty)
end

function DialogItemEdit:focussable()
    return true
end

function DialogItemEdit:handlePointerEvent(x, y, type)
    if type == KEvPtrPenDown then
        if not self.hasFocus then
            self:setFocus(true)
        end
        if x >= self.promptWidth then
            self:showEditor()
        end
    end
    return true
end

function DialogItemEdit:handleKeyPress(k, modifiers)
    if modifiers == 0 and k == KKeyTab then
        self:showEditor()
        return true
    end
    return false
end

function DialogItemEdit:showEditor()
    local result = runtime:iohandler().editValue({
        type = "text",
        initialValue = self.value,
        prompt = self.prompt,
        allowCancel = true
    })
    if result then
        self.value = result
    end
    self:setNeedsRedraw()
end

DialogItemEditLong = class { _super = DialogItemEdit }

function DialogItemEditLong:contentSize()
    -- The @ sign is an example of the widest character in the dialog font (we
    -- should really have an easy API for getting max font width...)
    local maxChars = math.max(#tostring(self.min), #tostring(self.max))
    return gTWIDTH(string.rep("@", maxChars)) + 2 * kEditTextSpace, kDialogLineHeight
end

function DialogItemEditLong:showEditor()
    local result = runtime:iohandler().editValue({
        type = "integer",
        initialValue = self.value,
        prompt = self.prompt,
        allowCancel = true,
        min = self.min,
        max = self.max,
    })
    if result then
        self.value = tostring(math.min(self.max, math.max(tonumber(result), self.min)))
    end
    self:setNeedsRedraw()
end


DialogChoiceList = class {
    _super = View,
    choiceTextSpace = 3 -- Yep, really not the same as kEditTextSpace despite how similar the two look
}

local kChoiceArrowSpace = 2
local kChoiceArrowSize = 12 + kChoiceArrowSpace

function DialogChoiceList:getChoicesWidth()
    local maxWidth = 0
    for _, choice in ipairs(self.choices) do
        maxWidth = math.max(gTWIDTH(choice), maxWidth)
    end
    return maxWidth + 2 * self.choiceTextSpace
end

function DialogChoiceList:contentSize()
    local maxWidth = self:getChoicesWidth()
    return maxWidth + kChoiceArrowSize, kDialogLineHeight
end

function DialogChoiceList:focussable()
    return true
end

function DialogChoiceList:draw()
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset
    self.leftArrowX = x - kChoiceArrowSize -- Left arrow draws before content area

    local choicesWidth = self:getChoicesWidth()
    lightGrey()
    gAT(x, texty - 2)
    gBOX(choicesWidth, self.charh + 3)
    black()
    gAT(x + 1, texty)
    gFILL(choicesWidth - 2, self.charh, KgModeClear)
    if self.choiceFont then
        gFONT(self.choiceFont)
    end
    drawText(self.choices[self.index], x + self.choiceTextSpace, texty)

    self.rightArrowX = x + choicesWidth + kChoiceArrowSpace
    gFONT(KFontEiksym15)
    if self.hasFocus then
        black()
    else
        white()
    end
    drawText(kChoiceLeftArrow, self.leftArrowX, texty)
    drawText(kChoiceRightArrow, self.rightArrowX, texty)
    gFONT(kDialogFont)
    black()

    View.draw(self)
end

function DialogChoiceList:handlePointerEvent(x, y, type)
    if type == KEvPtrPenDown then
        if not self.hasFocus then
            self:setFocus(true)
        end
        if x >= self.leftArrowX and x < self.leftArrowX + kChoiceArrowSize then
            self.index = wrapIndex(self.index - 1, #self.choices)
            self:setNeedsRedraw()
        elseif x >= self.leftArrowX + kChoiceArrowSize and x < self.rightArrowX then
            self:displayPopupMenu()
        elseif x >= self.rightArrowX and x < self.rightArrowX + kChoiceArrowSize then
            self.index = wrapIndex(self.index + 1, #self.choices)
            self:setNeedsRedraw()
        end
    end
    return true
end

function DialogChoiceList:handleKeyPress(k, modifiers)
    if modifiers ~= 0 then
        return false
    end
    if k == KKeyLeftArrow then
        self.index = wrapIndex(self.index - 1, #self.choices)
        self:setNeedsRedraw()
        return true
    elseif k == KKeyRightArrow then
        self.index = wrapIndex(self.index + 1, #self.choices)
        self:setNeedsRedraw()
        return true
    elseif k == KKeyTab then
        self:displayPopupMenu()
        return true
    end
    return false
end

function DialogChoiceList:displayPopupMenu()
    if self.needsRedraw then
        -- This is a bit of a hack, exploiting the fact we know what our view
        -- hierarchy looks like and that a sibling might've lost focus and also
        -- need redrawing.
        self.parent:draw()
    end
    local popupItems = {}
    for i, choice in ipairs(self.choices) do
        popupItems[i] = { key = i, text = choice }
    end
    local result = mPOPUP(gORIGINX() + self.x + self.promptWidth, gORIGINY() + self.y, KMPopupPosTopLeft, popupItems, self.index)
    if result > 0 then
        self.index = result
        self:setNeedsRedraw()
    end
end

function DialogChoiceList:updateValue()
    self.value = tostring(self.index)
end

DialogCheckbox = class {
    _super = DialogChoiceList,
    choiceFont = KFontEiksym15,
    choiceTextSpace = 1,
}

function DialogCheckbox:getChoicesWidth()
    return 18
end

function DialogCheckbox:displayPopupMenu()
    self.index = wrapIndex(self.index + 1, 2)
    self:setNeedsRedraw()
end

function DialogCheckbox:updateValue()
    self.value = self.index == 1 and "false" or "true"
end

DialogItemSeparator = class { _super = View }

function DialogItemSeparator:contentSize()
    return 0, 1
end

function DialogItemSeparator:draw()
    gAT(self.x, self.y)
    gLINEBY(self.w, 0)
    View.draw(self)
end

Button = class { _super = View }

function Button:contentSize()
    gFONT(kButtonFont)
    local w = math.max(gTWIDTH(self.text) + 8, kButtonMinWidth)
    return w, kButtonHeight
end

function Button:draw()
    gFONT(kButtonFont)
    gAT(self.x, self.y)
    local state = self.pressed and 1 or 0
    gBUTTON(self.text, 2, self.w, self.h, state, nil, nil, KButtTextTop)
    gFONT(kDialogFont)
    View.draw(self)
end

function Button:getShortcut()
    return self:getKey() & 0xFF
end

function Button:getKey()
    local k = self.key
    return k < 0 and -k or k
end

function Button:getResultCode()
    -- Which is neither getShortcut nor getKey - it's the raw code less modifier flags, but still negated if necessary
    local k = self.key
    local sign = k < 0 and -1 or 1
    local code = ((sign * k) & 0xFF)
    if code >= 0x41 and code < 0x5A then
        -- if you request an upper-case key, the result you'll get will always be lowercase. Yes really!
        code = code + 0x20
    end
    return code * sign
end

local dialogKeyNames = {
    [KDButtonDel] = "Del",
    [KDButtonTab] = "Tab",
    [KDButtonEnter] = "Enter",
    [KDButtonEsc] = "Esc",
    [KDButtonSpace] = "Space",
}

function Button:getLabel()
    local key = self:getKey()
    if key & KDButtonNoLabel == 0 then
        local rawKey = key & 0xFF
        local keyName = dialogKeyNames[rawKey] or string.char(rawKey):upper()
        if keyName:match("^[A-Z]$") and key & KDButtonPlainKey == 0 then
            keyName = "Ctrl+"..keyName
        end
        return keyName
    else
        return nil
    end
end

function Button:handleKeyPress(k, modifiers)
    local shortcut = self:getShortcut()
    if shortcut < 32 then
        -- It's a non-alphabetic key, which can be compared directly to k (and any modifiers are acceptable)
        if shortcut == k then
            self:press()
            return true
        end
    else
        -- It's an alphabet key in which case modifiers must match
        local requiredModifiers = (self:getKey() & KDButtonPlainKey > 0) and 0 or KKmodControl
        if modifiers & KKmodControl > 0 and k < 32 then
            -- massage k back to the keycode range, sigh
            k = k + 0x40
        end
        if modifiers == requiredModifiers and (k & ~0x20) == (shortcut & ~0x20) then
            self:press()
            return true
        end
    end
    return false
end

function Button:handlePointerEvent(x, y, type)
    if self.capturing then
        local inside = self:contains(x, y)
        if inside and type == KEvPtrPenUp then
            inside = false
            self:press()
        end
        if inside ~= self.pressed then
            self.pressed = inside
            self:setNeedsRedraw()
        end
    elseif type == KEvPtrPenDown then
        self.pressed = true
        self:draw()
        self:capturePointer() -- doesn't return until KEvPtrPenUp occurs
        return true
    end
end

function Button:press()
    -- walk up the view hierarchy to find something that implements onButtonPressed
    local view = self.parent
    while view do
        if view.onButtonPressed then
            view.onButtonPressed(view, self)
            return
        end
        view = view.parent
    end
    printf("Button %s pressed but unhandled\n", self:shortcut())
end

DialogButtonGroup = class { _super = View }

function DialogButtonGroup:contentSize()
    -- All buttons are the same size, which can grow to fit the longest button text
    -- TODO support buttons on side
    local maxButtonWidth = 0
    gFONT(kButtonFont)
    local numButtons = #self
    local hasLabels = false
    for _, button in ipairs(self) do
        maxButtonWidth = math.max(button:contentSize(), maxButtonWidth)
        if button:getLabel() then
            hasLabels = true
        end
    end
    local buttonsWidth = maxButtonWidth * numButtons + kButtonSpacing * (numButtons - 1)
    gFONT(kDialogFont)

    local h
    if hasLabels then
       h = kDialogLineHeight * 2
    else
       h = kButtonYOffset + kButtonHeight
    end
    return buttonsWidth, h, maxButtonWidth
end

function DialogButtonGroup:addButtonsToView()
    local cw, ch, buttonWidth = self:contentSize()
    local x = self.x + ((self.w - cw) // 2)
    local buttonY = self.y + kButtonYOffset
    for _, button in ipairs(self) do
        self:addSubview(button, x, buttonY, buttonWidth, kButtonHeight)
        x = x + buttonWidth + kButtonSpacing
    end
end

function DialogButtonGroup:handleKeyPress(k, modifiers)
    for _, button in ipairs(self) do
        if button:handleKeyPress(k, modifiers) then
            return true
        end
    end
    return false
end

function DialogButtonGroup:draw()
    -- Draw the actual buttons (which are subviews)
    View.draw(self)
    -- And any shortcut labels they may have
    gFONT(kButtonShortcutFont)
    for _, button in ipairs(self) do
        local label = button:getLabel()
        if label then
            local textw = gTWIDTH(label)
            gAT(button.x + (button.w - textw) // 2, button.y + button.h + 2)
            drawText(label)
        end
    end
    gFONT(kDialogFont)
end

DialogWindow = class { _super = View }

function DialogWindow.new(items, x, y, w, h)
    local id = gCREATE(x, y, w, h, false, KgCreate256ColorMode | KgCreateHasShadow | 0x200)
    return DialogWindow {
        x = x,
        y = y,
        w = w,
        h = h,
        subviews = {},
        parent = nil,
        windowId = id,
        items = items,
        needsRedraw = true,
    }
end

function DialogWindow:handlePointerEvent(x, y, type)
    -- Unlike views, the window x and y aren't in view coords
    if x >= 0 and x < self.w and y >= 0 and y < self.h then
        for _, subview in ipairs(self.subviews) do
            if subview:contains(x, y) and subview:handlePointerEvent(x, y, type) then
                return true
            end
        end
        return true
    else
        return false
    end
end

function DialogWindow:processEvent(ev)
    local k = ev[KEvAType]()
    local handled = false
    if k & KEvNotKeyMask == 0 then
        -- Key press event. Note, buttons shortcuts take precedence over the focussed control
        local modifiers = ev[KEvAKMod]()
        if self.buttons then
            handled = self.buttons:handleKeyPress(k, modifiers)
        end
        if not handled and self.focussedItemIndex then
            handled = self.items[self.focussedItemIndex]:handleKeyPress(k, modifiers)
        end
        if handled then
            return
        end
    end

    if k == KKeyEsc then
        return 0
    elseif k == KKeyUpArrow and self.focussedItemIndex then
        local newIdx = self.focussedItemIndex
        repeat
            newIdx = wrapIndex(newIdx - 1, #self.items)
        until self.items[newIdx]:focussable()
        if newIdx ~= self.focussedItemIndex then
            self.items[newIdx]:setFocus(true)
        end
    elseif k == KKeyDownArrow and self.focussedItemIndex then
        local newIdx = self.focussedItemIndex
        repeat
            newIdx = wrapIndex(newIdx + 1, #self.items)
        until self.items[newIdx]:focussable()
        if newIdx ~= self.focussedItemIndex then
            self.items[newIdx]:setFocus(true)
        end
    elseif k == KKeyEnter then
        -- If we get here, there can't be a button with enter as a shortcut
        return self.focussedItemIndex
    elseif k == KEvPtr then
        if ev[KEvAPtrWindowId]() ~= self.windowId then
            return
        end
        local ptrType = ev[KEvAPtrType]()
        local x = ev[KEvAPtrPositionX]()
        local y = ev[KEvAPtrPositionY]()
        self:handlePointerEvent(x, y, ptrType)
    end
end

function DialogWindow:onButtonPressed(button)
    self.buttonPressed = button
end

function DialogWindow:onFocusChanged(view)
    if self.focussedItemIndex then
        self.items[self.focussedItemIndex]:setFocus(false)
    end
    self.focussedItemIndex = assert(view.focusOrderIndex)
end

local itemTypes = {
    [dItemTypes.dTEXT] = DialogItemText,
    [dItemTypes.dCHOICE] = DialogChoiceList,
    [dItemTypes.dSEPARATOR] = DialogItemSeparator,
    [dItemTypes.dCHECKBOX] = DialogCheckbox,
    [dItemTypes.dEDIT] = DialogItemEdit,
    [dItemTypes.dLONG] = DialogItemEditLong,
}

function DIALOG(dialog)
    local state = runtime:saveGraphicsState()

    local borderWidth = 4 -- 1 px black box plus 3 px for the gXBORDER
    local hMargin = 4
    local bottomMargin = 4
    -- local titleIndent = 3
    local maxPromptWidth = 0
    local maxContentWidth = 0
    local maxWidth = 0 -- For anything that doesn't split into prompt and content
    local maxButtonWidth = 30 -- ?
    local promptGap = 22 -- Must be at least as big as kChoiceArrowSize because the lefthand arrow goes in the prompt gap

    gFONT(kDialogFont)
    local _, charh = gTWIDTH("0")
    View.charh = charh
    local titleBar
    local h = borderWidth
    if dialog.title and (dialog.flags & KDlgNoTitle) == 0 then
        titleBar = DialogTitleBar {
            hMargin = hMargin,
            value = dialog.title,
            draggable = (dialog.flags & KDlgNoDrag) == 0,
        }
        local cw, ch = titleBar:contentSize()
        maxWidth = math.max(cw, maxWidth)
        h = h + ch
    end

    for i, item in ipairs(dialog.items) do
        -- printf("Item %i is type %d\n", i, item.type)
        setmetatable(item, itemTypes[item.type] or PlaceholderView)
        if item.type == dItemTypes.dCHOICE then
            item.index = tonumber(item.value)
        elseif item.type == dItemTypes.dCHECKBOX then
            item.choices = { "", kTickMark }
            item.index = item.value == "true" and 2 or 1
        end
        local cw, ch = item:contentSize()
        local promptWidth = item:getPromptWidth()
        if promptWidth then
            maxPromptWidth = math.max(promptWidth, maxPromptWidth)
            maxContentWidth = math.max(cw, maxContentWidth)
        else
            maxWidth = math.max(cw, maxWidth)
        end
        h = h + ch + kDialogLineGap
    end
    h = h + bottomMargin + borderWidth

    -- -- All buttons are the same size, which can grow to fit the longest button text
    local numButtons = dialog.buttons and #dialog.buttons or 0
    if numButtons > 0 then
        setmetatable(dialog.buttons, DialogButtonGroup)
        for i, button in ipairs(dialog.buttons) do
            setmetatable(button, Button)
            -- printf("Button %i key: %d text: %s\n", i, button.key, button.text)
        end
        local cw, ch = dialog.buttons:contentSize()
        maxWidth = math.max(cw, maxWidth)
        h = h + ch + kDialogLineGap
    end

    if maxPromptWidth > 0 or maxContentWidth > 0 then
        maxWidth = math.max(maxPromptWidth + promptGap + maxContentWidth, maxWidth)
    end

    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = maxWidth + (borderWidth + hMargin) * 2
    w = math.min(w, screenWidth)
    h = math.min(h, screenHeight)
    local winX, winY
    if dialog.xpos < 0 then
        winX = 0
    elseif dialog.xpos == 0 then
        winX = (screenWidth - w) // 2
    else
        winX = screenWidth - w
    end
    if dialog.ypos < 0 then
        winY = 0
    elseif dialog.ypos == 0 then
        winY = (screenHeight - h) // 2
    else
        winY = screenHeight - h
    end

    local win = DialogWindow.new(dialog.items, winX, winY, w, h)
    gFONT(kDialogFont)

    -- Now we have our window and prompt area sizes we can actually lay out the items

    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94, w - 2, h - 2)

    local y = borderWidth
    if titleBar then
        local ch = titleBar:contentHeight()
        win:addSubview(titleBar, borderWidth, y, w - borderWidth * 2, ch)
        y = y + ch
    end

    local itemWidth = w - (borderWidth + hMargin) * 2
    for i, item in ipairs(dialog.items) do
        item:setPromptWidth(maxPromptWidth + promptGap)
        local ch = item:contentHeight()
        item.focusOrderIndex = i
        win:addSubview(item, borderWidth + hMargin, y, itemWidth, ch)
        if win.focussedItemIndex == nil and item:focussable() then
            item:setFocus(true)
        end
        y = y + ch + kDialogLineGap
    end

    if numButtons > 0 then
        win.buttons = dialog.buttons
        local cw, ch = dialog.buttons:contentSize()
        win:addSubview(dialog.buttons, borderWidth + hMargin, y, itemWidth, ch)
        win.buttons:addButtonsToView()
    end

    gUPDATE(false)
    win:draw()
    gUPDATE()
    gVISIBLE(true)

    -- event loop
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local evVar = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local ev = evVar()
    local evAddr = ev[1]:addressOf()

    local result = nil
    -- local highlight = nil
    while result == nil do
        GETEVENTA32(stat, evAddr)
        runtime:waitForRequest(stat)
        result = win:processEvent(ev)
        if not result and win.buttonPressed then
            result = win.buttonPressed:getResultCode()
        end
        win:drawIfNeeded()
        gUPDATE()
    end

    gCLOSE(win.windowId)

    for _, item in ipairs(win.items) do
        item:updateValue()
    end

    runtime:restoreGraphicsState(state)
    return result
end

return _ENV
