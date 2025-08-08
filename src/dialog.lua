-- Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

-- Reminder: everything in this file is magically imported into the global namespace by _setRuntime() in opl.lua,
-- and then into runtime by newRuntime() in runtime.lua.

_ENV = module()

local View = class {}

local kDialogFont = KFontArialNormal15
local kButtonFont = KFontArialBold11
local kButtonShortcutFont = KFontArialNormal11
local kButtonHeight = 23
local kButtonYOffset = 9
local kButtonMinWidth = 50
local kButtonSpacing = 10
local kDialogLineHeight = 22 -- ?
local kDialogTightLineHeight = 18
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
    return self.prompt and gTWIDTH(self.prompt, kDialogFont) or nil
end

function View:setHeightHint(hint)
    self.heightHint = hint
end

function View:init(lineHeight)
    self:setHeightHint(lineHeight)
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
end

function View:takeFocus()
    self:moveFocusTo(self)
end

function View:moveFocusTo(newView)
    -- By default, just pass up the chain
    if self.parent then
        self.parent:moveFocusTo(newView)
    end
end

function View:screenRect()
    local origx, origy = gORIGINX(), gORIGINY()
    return {
        x = origx + self.x,
        y = origy + self.y,
        w = self.w,
        h = self.h
    }
end

function View:focussable()
    return false
end

-- Used by subclasses to prevent a view being moved away from (or the dialog dismissed) due to eg invalid selections
function View:canLoseFocus()
    return true
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
    black()
    gAT(x, texty - 1)
    gFILL(gTWIDTH(self.prompt), self.charh + 2, self.hasFocus and KgModeSet or KgModeClear)
    if self.hasFocus then
        white()
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
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()
    while true do
        self:drawIfNeeded()
        gUPDATE()
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
            if ptrType == KEvPtrPenUp then
                break
            end
        end
    end
    self.capturing = false
    -- print("end capture")
end

function View:updateVariable()
    if self.variable and self.value then
        self.variable(self.value)
    end
end


local PlaceholderView = class { _super = View }

function PlaceholderView:contentSize()
    return gTWIDTH("TODO dItem type 0"), self.heightHint
end

function PlaceholderView:draw()
    gCOLOR(0xFF, 0, 0xFF)
    gAT(self.x, self.y)
    gFILL(self.w, self.h)
    black()
    drawText(string.format("TODO dItem type %d", self.type), self.x, self.y + kDialogLineTextYOffset)
    View.draw(self)
end

local DialogTitleBar = class { _super = View }

function DialogTitleBar:contentSize()
    local h = self.heightHint
    if self.lineBelow then
        h = h + 2
    end
    return gTWIDTH(self.value, kDialogFont), h
end

function DialogTitleBar:draw()
    gAT(self.x, self.y)
    if self.pressedX then
        white()
    else
        if runtime:isColor() then
            gCOLOR(0, 0, 0x82)
        else
            lightGrey()
        end
    end
    gFILL(self.w, self.h)
    if runtime:isColor() then
        if self.pressedX then
            black()
        else
            white()
        end
    else
        black()
    end
    drawText(self.value, self.x + self.hMargin, self.y + 2)
    black()
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

        -- Make sure any move of the window updates the native text editor tracking (since it works in screen coords)
        local focussed = self.parent:focussedItem()
        if focussed and focussed.updateIohandler then
            focussed:updateIohandler()
        end
    end
    return true
end

local DialogItemText = class { _super = View }

function DialogItemText:contentSize()
    local h = self.heightHint
    if self.lineBelow then
        if h == kDialogTightLineHeight then
            h = h + 2
        else
            h = h + 1
        end
    end
    return gTWIDTH(self.value, kDialogFont), h
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
        local y
        if self.heightHint == kDialogTightLineHeight then
            y = self.y + self.heightHint + 2
        else
            y = self.y + self.heightHint + 1
        end
        gAT(self.x, y)
        gLINEBY(self.w, 0)
    end
    View.draw(self)
end

function DialogItemText:focussable()
    return self.selectable
end

function DialogItemText:handlePointerEvent(x, y, type)
    if type == KEvPtrPenDown then
        if not self.hasFocus and self:focussable() then
            self:takeFocus()
        end
    end
    return true
end

local DialogItemEdit = class {
    _super = View,
    cursorWidth = 2,
}

function DialogItemEdit:init(lineHeight)
    View.init(self, lineHeight)
    local editorValue = tostring(self.value)
    self.value = nil -- From now on, managed by editor
    self.editor = require("editor").Editor {
        view = self,
    }
    self.editor:setValue(editorValue)
    -- Edit items start with the whole text selected, it seems
    self.editor:setCursorPos(#editorValue + 1, 1)
end

local kEditTextSpace = 2

function DialogItemEdit:contentSize()
    -- The @ sign is an example of the widest character in the dialog font (we
    -- should really have an easy API for getting max font width...)
    return gTWIDTH(string.rep("@", self.len), kDialogFont) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEdit:drawPromptAndBox()
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    local boxWidth = math.min(self:contentSize(), self.w - (x - self.x))
    lightGrey()
    gAT(x, texty - 2)
    gBOX(boxWidth, self.charh + 3)
    white()
    gAT(x + 1, texty - 1)
    gFILL(boxWidth - 2, self.charh + 1)
    black()
    gAT(x + 1, texty)
    return x, texty
end

function DialogItemEdit:drawValue(val)
    if self.hasFocus then
        -- So it doesn't get drawn by native side while we're drawing ourselves
        CURSOR(nil)
    end
    local x, texty = self:drawPromptAndBox()
    drawText(val, x + kEditTextSpace, texty)
    if self.hasFocus and self.editor and self.editor:hasSelection() then
        local selStart, selEnd = self.editor:getSelectionRange()
        local selText = self.editor.value:sub(selStart, selEnd)
        local selOffset = gTWIDTH(self.editor.value:sub(1, selStart - 1))
        local selWidth = gTWIDTH(selText)
        gAT(x + kEditTextSpace + selOffset, texty - 1)
        gFILL(selWidth, self.charh + 1, KgModeInvert)
    end

    self:updateCursorIfFocussed()
end

function DialogItemEdit:getCursorPos()
    local textw, texth = gTWIDTH(self.editor.value:sub(1, self.editor.cursorPos - 1), kDialogFont)
    return self.x + self.promptWidth + kEditTextSpace + textw, self.y + kDialogLineTextYOffset - 1
end

function DialogItemEdit:posToCharPos(x, y)
    local tx = x - self.x - kEditTextSpace - self.promptWidth

    -- Is there a better way to do this?
    local result = 1
    while gTWIDTH(self.editor.value:sub(1, result), kDialogFont) < tx do
        result = result + 1
        if result >= #self.editor.value + 1 then
            break
        end
    end
    return result
end

function DialogItemEdit:updateCursorIfFocussed()
    if self.hasFocus then
        local x, y = self:getCursorPos()
        CURSOR(gIDENTITY(), x, y, self.cursorWidth, self.charh + 1)
        self:updateIohandler()
    end
end

function DialogItemEdit:draw()
    self:drawValue(self.editor.value)
    View.draw(self)
end

function DialogItemEdit:focussable()
    return true
end

function DialogItemEdit:inputType()
    return "text"
end

function DialogItemEdit:handlePointerEvent(x, y, type)
    if self.capturing then
        self.editor:setCursorPos(self:posToCharPos(x, y), self.editor.anchor)
    elseif type == KEvPtrPenDown then
        if not self.hasFocus then
            self:takeFocus()
        end
        if x >= self.x + self.promptWidth then
            self.nextIoHandlerUpdateUserRequested = true
            self.editor:setCursorPos(self:posToCharPos(x, y))
            self:capturePointer()
            self:setNeedsRedraw()
        end
    end
    return true
end

function DialogItemEdit:handleKeyPress(k, modifiers)
    return self.editor:handleKeyPress(k, modifiers)
end

function DialogItemEdit:setFocus(flag)
    DialogItemEdit._super.setFocus(self, flag)
    if not flag then
        CURSOR(nil)
        runtime:iohandler().textEditor(nil)
    end
end

function DialogItemEdit:onEditorChanged()
    self:setNeedsRedraw()
end

function DialogItemEdit:updateIohandler()
    local controlRect = {
        x = self.x + self.promptWidth,
        y = self.y,
        w = self.w - self.promptWidth,
        h = self.h,
    }
    local cursorx, cursory = self:getCursorPos()
    -- The cursor might not actually be showing at this point (eg when DialogItemPartEditor supresses the cursor) but
    -- this is where it _should_ be.
    local cursorRect = {
        x = cursorx,
        y = cursory,
        w = self.cursorWidth,
        h = self.charh + 1, --  This is not quite correct for DialogItemEditMulti but it doesn't really matter
    }
    local userFocusRequested = false
    if self.nextIoHandlerUpdateUserRequested then
        userFocusRequested = true
        self.nextIoHandlerUpdateUserRequested = false
    end
    runtime:declareTextEditor(gIDENTITY(), self:inputType(), controlRect, cursorRect, userFocusRequested)
end

-- returning false from canUpdate() should only be if newVal cannot _become_
-- valid with more text. So really only for rejecting too many chars or
-- character classes that are not legal.
function DialogItemEdit:canUpdate(newVal)
    if self.len and #newVal > self.len then
        gIPRINT("Maximum number of characters reached", KBusyTopRight)
        return false
    else
        return true
    end
end

function DialogItemEdit:updateVariable()
    self.variable(self.editor.value)
end

local DialogItemEditLong = class { _super = DialogItemEdit }

function DialogItemEditLong:contentSize()
    -- The @ sign is an example of the widest character in the dialog font (we
    -- should really have an easy API for getting max font width...)
    local maxChars = math.max(#tostring(self.min), #tostring(self.max))
    return gTWIDTH(string.rep("@", maxChars), kDialogFont) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditLong:inputType()
    return "integer"
end

function DialogItemEditLong:canUpdate(newVal)
    if newVal == "" then
        return true
    elseif newVal == "-" then
        -- Allowed as an in-progress negative number
        return true
    end
    local n = tonumber(newVal, 10)
    local maxChars = math.max(#tostring(self.min), #tostring(self.max))
    if n == nil or math.tointeger(n) == nil or newVal:match("[xX.e]") then
        return false
    elseif #newVal > maxChars then
        return false
    else
        return true
    end
end

function DialogItemEditLong:canLoseFocus()
    if self.editor.value == "" then
        gIPRINT("No number has been entered", KBusyTopRight)
        self.editor:setValue(tostring(self.max))
        return false
    end
    local n = tonumber(self.editor.value, 10) or 0

    if n > self.max then
        gIPRINT(string.format("Maximum allowed value is %d", self.max), KBusyTopRight)
        self.editor:setValue(tostring(self.max))
        return false
    elseif n < self.min then
        gIPRINT(string.format("Minimum allowed value is %d", self.min), KBusyTopRight)
        self.editor:setValue(tostring(self.min))
        return false
    else
        return true
    end
end

function DialogItemEditLong:updateVariable()
    self.variable(tonumber(self.editor.value))
end

local DialogItemEditFloat = class {
    _super = DialogItemEdit,
    maxChars = 17,
}

function DialogItemEditFloat:contentSize()
    return gTWIDTH(string.rep("0", self.maxChars), kDialogFont) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditFloat:inputType()
    return "float"
end

function DialogItemEditFloat:canUpdate(newVal)
    local n = tonumber(newVal)
    if newVal == "" or newVal == "-" then
        return true
    elseif n == nil or newVal:match("[xXe ]") then
        return false
    elseif #newVal > self.maxChars then
        return false
    else
        return true
    end
end

function DialogItemEditFloat:canLoseFocus()
    if self.editor.value == "" or self.editor.value == "-" then
        gIPRINT("Please enter a number", KBusyTopRight)
        return false
    end
    local n = assert(tonumber(self.editor.value))

    if n > self.max then
        gIPRINT(string.format("Maximum allowed value is %g", self.max), KBusyTopRight)
        return false
    elseif n < self.min then
        gIPRINT(string.format("Minimum allowed value is %g", self.min), KBusyTopRight)
        return false
    else
        return true
    end
end

function DialogItemEditFloat:updateVariable()
    self.variable(tonumber(self.editor.value))
end

local DialogItemEditPass = class { _super = DialogItemEdit }

function DialogItemEditPass:init(lineHeight)
    DialogItemEditPass._super.init(self, lineHeight)
    self.editor.movableCursor = false
    self.cursorWidth = gTWIDTH("*", kDialogFont)
    -- Don't select the contents (undo what DialogItemEdit:init() did)
    self.editor:setCursorPos(#self.editor.value + 1)    
end

function DialogItemEditPass:contentSize()
    return self.cursorWidth * (self.len + 1) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditPass:draw()
    self:drawValue(string.rep("*", #self.editor.value))
    View.draw(self)
end

function DialogItemEditPass:getCursorPos()
    local val = string.rep("*", #self.editor.value)
    local textw, texth = gTWIDTH(val:sub(1, self.editor.cursorPos - 1), kDialogFont)
    return self.x + self.promptWidth + kEditTextSpace + textw, self.y + kDialogLineTextYOffset - 1
end

local DialogItemPartEditor = class {
    _super = DialogItemEdit,
}

function DialogItemPartEditor:init(lineHeight)
    -- Skip DialogItemEdit:init()
    View.init(self, lineHeight)
    self.editor = require("editor").Editor {
        view = self,
    }
    self.currentPart = 1
    self:setPart(self.currentPart)
end

function DialogItemPartEditor:canLoseFocus()
    return self:validateCurrentPart()
end

function DialogItemPartEditor:validateCurrentPart()
    local part = self.parts[self.currentPart]
    local n
    if part.format then
        n = tonumber(part.value, 10)
        -- assert(n, "Value should be a valid number in canLoseFocus!")
    end
    if part.min and n < part.min then
        gIPRINT("Minimum allowed value is "..tostring(part.min), KBusyTopRight)
        part.value = string.format(part.format, part.min)
        return false
    elseif part.max and n > part.max then
        gIPRINT("Maximum allowed value is "..tostring(part.max), KBusyTopRight)
        part.value = string.format(part.format, part.max)
        return false
    end

    if part.format then
        part.value = string.format(part.format, n)
    end
    return true
end

function DialogItemPartEditor:setFocus(flag)
    DialogItemPartEditor._super.setFocus(self, flag)
    if not flag then
        -- Losing focus always resets back to part 1
        self:setPart(1)
    end
end

function DialogItemPartEditor:setPart(idx)
    -- This also commits any ongoing editing
    if not self:validateCurrentPart() then
        -- Stay on current part
        idx = self.currentPart
    end

    self.currentPart = idx
    self.editor:setValue(self.parts[idx].value)
    self.editor:setCursorPos(#self.editor.value + 1, 1)
    self:setNeedsRedraw()
end

function DialogItemPartEditor:getPart(type, nth)
    local foundCount = 0
    for i, part in ipairs(self.parts) do
        if type == nil or type == part.type then
            foundCount = foundCount + 1
            if nth == nil or nth == foundCount then
                return part
            end
        end
    end
    return nil
end

function DialogItemPartEditor:getPartValue(type, nth)
    local part = self:getPart(type, nth)
    return part and part.value
end

function DialogItemPartEditor:getValueAsString()
    local parts = {}
    for i, part in ipairs(self.parts) do
        parts[i] = (part.prefix or "")..part.value
    end
    return table.concat(parts)
end

function DialogItemPartEditor:canUpdate(newVal)
    local n = tonumber(newVal, 10)
    local currentPart = self.parts[self.currentPart]

    if newVal == "" then
        return true
    elseif currentPart.min and currentPart.min < 0 and newVal == "-" then
        -- This is allowed as an in-progress negative number
        return true
    elseif (currentPart.min or currentPart.max) and n == nil then
        return false
    elseif currentPart.maxChars and #newVal > currentPart.maxChars then
        return false
    else
        return true
    end
end

function DialogItemPartEditor:onEditorChanged(editor)
    -- print("onEditorChanged", self.currentPart, editor.value)

    local currentPart = self.parts[self.currentPart]
    local prevLen = #currentPart.value
    local newLen = #editor.value
    currentPart.value = editor.value
    if currentPart.maxChars and prevLen == currentPart.maxChars - 1 and newLen == currentPart.maxChars then
        if self.currentPart < #self.parts then
            -- Move cursor to next part
            self:setPart(self.currentPart + 1)
        else
            -- Just commit
            self:setPart(self.currentPart)
        end
    end
    self:setNeedsRedraw()
end

function DialogItemPartEditor:contentSize()
    local sz = 0
    for _, part in ipairs(self.parts) do
        if part.width then
            sz = sz + part.width
        else 
            if part.prefix then
                sz = sz + gTWIDTH(part.prefix, kDialogFont)
            end
            sz = sz + (part.maxValueWidth or gTWIDTH(string.rep("0", part.maxChars), kDialogFont))
        end
    end
    return sz + 2 * kEditTextSpace, self.heightHint
end

function DialogItemPartEditor:draw()
    local x, texty = self:drawPromptAndBox()
    x = x + kEditTextSpace

    for i, part in ipairs(self.parts) do
        part.startx = x
        if part.prefix then
            drawText(part.prefix, x, texty)
            x = x + gTWIDTH(part.prefix)
        end
        drawText(part.value, x, texty)

        if self.hasFocus and self.currentPart == i and self.editor:hasSelection() then
            gAT(x, texty - 1)
            gFILL(gTWIDTH(self.editor:getSelection()), self.charh + 1, KgModeInvert)
        end

        x = x + (part.maxValueWidth or gTWIDTH(string.rep("0", part.maxChars)))
        part.width = x - part.startx
    end

    self:updateCursorIfFocussed()
    View.draw(self)
end

function DialogItemPartEditor:updateCursorIfFocussed()
    if self.hasFocus then
        if self.editor:hasSelection() then
            -- We don't show a cursor when there's a selection (because a selection is used to indicate the entry is
            -- complete).
            CURSOR(nil)
        else
            DialogItemEdit.updateCursorIfFocussed(self)
        end
    end
end

function DialogItemPartEditor:getCursorPos()
    local textw, texth = gTWIDTH(self.editor.value:sub(1, self.editor.cursorPos - 1), kDialogFont)
    local currentPart = self.parts[self.currentPart]
    local x = currentPart.startx + textw
    if currentPart.prefix then
        x = x + gTWIDTH(currentPart.prefix, kDialogFont)
    end
    local y = self.y + kDialogLineTextYOffset - 1
    return x, y
end

function DialogItemPartEditor:handlePointerEvent(x, y, type)
    if type == KEvPtrPenDown then
        if not self.hasFocus then
            self:takeFocus()
        end
        for i, part in ipairs(self.parts) do
            if x >= part.startx and x < part.startx + part.width then
                self:setPart(i)
                break
            end
        end
    end
end

function DialogItemPartEditor:handleKeyPress(k, modifiers)
    if k == KKeyLeftArrow32 then
        if self.currentPart > 1 then
            self:setPart(self.currentPart - 1)
        end
        return true
    elseif k == KKeyRightArrow32 then
        if self.currentPart < #self.parts then
            self:setPart(self.currentPart + 1)
        end
        return true
    elseif k == KKeyPageLeft32 or k == KKeyPageRight32 then
        -- These shouldn't do anything in a date editor
        return true
    else
        return self.editor:handleKeyPress(k, modifiers)
    end
end

local DialogItemEditDate = class {
    _super = DialogItemPartEditor,
}

local kSecsFrom1900to1970 = 2208988800

function DialogItemEditDate:init(lineHeight)
    local t = os.date("!*t", self.value * 86400 - kSecsFrom1900to1970)
    self.parts = {
        {
            type = "day",
            min = 1,
            max = 31,
            maxChars = 2,
            format = "%02d",
            value = string.format("%02d", t.day)
        },
        {
            type = "month",
            min = 1,
            max = 12,
            maxChars = 2,
            format = "%02d",
            prefix = "/",
            value = string.format("%02d", t.month)
        },
        {
            type = "year",
            min = os.date("!*t", self.min * 86400 - kSecsFrom1900to1970).year,
            max = os.date("!*t", self.max * 86400 - kSecsFrom1900to1970).year,
            maxChars = 4,
            prefix = "/",
            format = "%04d",
            value = string.format("%04d", t.year),
        },
    }
    DialogItemPartEditor.init(self, lineHeight)
end

function DialogItemEditDate:getDate()
    -- day and month will already have been checked to be 1-31 and 1-12, and year will already be right, so just check
    -- that the days is allowed. Technique taken from DTDaysInMonth
    local d = {
        day = 31,
        month = tonumber(self:getPartValue("month"), 10),
        year = tonumber(self:getPartValue("year"), 10),
    }
    local maxDays = 31 - os.date("!*t", runtime:iohandler().utctime(d)).day
    if maxDays == 0 then
        maxDays = 31
    end
    d.day = tonumber(self:getPartValue("day"))
    if d.day > maxDays then
        return nil
    else
        return d
    end
end

function DialogItemEditDate:canLoseFocus()
    local date = self:getDate()
    if date == nil then
        gIPRINT("Invalid date", KBusyTopRight)
        return false
    end

    return true
end

function DialogItemEditDate:updateVariable()
    local d = assert(self:getDate())
    local t = (runtime:iohandler().utctime(d) + kSecsFrom1900to1970) // 86400
    self.variable(t)
end

local DialogItemEditTime = class {
    _super = DialogItemPartEditor,
}

function DialogItemEditTime:init(lineHeight)
    local hpart = {
        type = "hour",
        min = 0,
        max = 23,
        format = "%02d",
        maxChars = 2,
    }
    local mpart = {
        type = "min",
        min = 0,
        max = 59,
        format = "%02d",
        prefix = ":",
        maxChars = 2,
    }
    local spart = {
        type = "sec",
        min = 0,
        max = 59,
        format = "%02d",
        prefix = ":",
        maxChars = 2,
    }
    local am = "am" -- os.date("!%p", 0)
    local pm = "pm" -- os.date("!%p", 12 * 3600)
    local ampmpart = {
        type = "ampm",
        prefix = " ",
        am = am,
        pm = pm,
        maxValueWidth = math.max(gTWIDTH(am, kDialogFont), gTWIDTH(pm, kDialogFont)),
    }

    self.parts = {}

    if self.timeFlags & KDTimeNoHours == 0 then
        table.insert(self.parts, hpart)
    else
        mpart.prefix = nil
    end
    table.insert(self.parts, mpart)
    if self.timeFlags & KDTimeWithSeconds ~= 0 then
        table.insert(self.parts, spart)
    end

    if self.timeFlags & (KDTimeDuration | KDTime24Hour) == 0 then
        table.insert(self.parts, ampmpart)
    end

    self:setTime(self.value)

    DialogItemPartEditor.init(self, lineHeight)
end

function DialogItemEditTime:setTime(t)
    local h = self:getPart("hour")
    local m = self:getPart("min")
    local s = self:getPart("sec")
    local ampm = self:getPart("ampm")

    if h then
        if self.timeFlags & (KDTimeDuration | KDTime24Hour) ~= 0 then
            h.value = os.date("!%H", t)
        else
            h.value = os.date("!%I", t)
        end
    end
    if m then
        m.value = os.date("!%M", t)
    end
    if s then
        s.value = os.date("!%S", t)
    end
    if ampm then
        ampm.value = (os.date("!%p", t) == os.date("!%p", 0)) and ampm.am or ampm.pm
    end

    self:setNeedsRedraw()
end

function DialogItemEditTime:canUpdate(newVal)
    local part = self.parts[self.currentPart]
    if part.type == "ampm" then
        return newVal == part.am or newVal == part.pm
            or newVal:lower() == part.am:sub(1, 1):lower()
            or newVal:lower() == part.pm:sub(1, 1):lower()
    else
        return DialogItemEditTime._super.canUpdate(self, newVal)
    end
end

function DialogItemEditTime:canLoseFocus()
    if DialogItemEditTime._super.canLoseFocus(self) then
        local t = self:getTime()
        if t < self.min then
            local timeOrDuration = self.timeFlags & KDTimeDuration == 0 and "time" or "duration"
            self:setTime(self.min)
            gIPRINT(string.format("Minimum allowed %s is %s", timeOrDuration, self:getValueAsString()), KBusyTopRight)
            return false
        elseif t > self.max then
            local timeOrDuration = self.timeFlags & KDTimeDuration == 0 and "time" or "duration"
            self:setTime(self.max)
            gIPRINT(string.format("Maximum allowed %s is %s", timeOrDuration, self:getValueAsString()), KBusyTopRight)
            return false
        else
            return true
        end
    else
        return false
    end
end

function DialogItemEditTime:onEditorChanged(editor)
    local part = self.parts[self.currentPart]
    local val = editor.value
    if part.type == "ampm" and val ~= part.am and val ~= part.pm then
        if editor.value:lower() == part.am:sub(1, 1):lower() then
            val = part.am
        elseif editor.value:lower() == part.pm:sub(1, 1):lower() then
            val = part.pm
        else
            error("ampm not an expected value: "..val)
        end
        part.value = val
        self:setPart(self.currentPart)
    else
        DialogItemEditTime._super.onEditorChanged(self, editor)
    end
end

function DialogItemEditTime:getTime()
    local h = tonumber(self:getPartValue("hour"))
    local m = tonumber(self:getPartValue("min"))
    local s = tonumber(self:getPartValue("sec"))
    local ampm = self:getPart("ampm")
    if ampm and ampm.value == ampm.pm then
        h = h + 12
    end
    local t = 0
    if h then
        t = t + h * 3600
    end
    if m then
        t = t + m * 60
    end
    if s then
        t = t + s
    end
    return t
end

function DialogItemEditTime:updateVariable()
    self.value = self:getTime()
    if self.timeFlags & KDTimeWithSeconds == 0 then
        -- Make sure we remove any seconds (specifically if any were passed in, as hopefully the editor won't have
        -- introduced any if the KDTimeWithSeconds flag isn't set)
        self.value = (self.value // 60) * 60
    end
    self.variable(self.value)
end

local DialogItemEditMulti = class { _super = DialogItemEdit }

function DialogItemEditMulti:init(lineHeight)
    self.firstDrawnLine = 1
    DialogItemEdit.init(self, lineHeight)
end

function DialogItemEditMulti:lineHeight()
    return self.charh + 4
end

function DialogItemEditMulti:contentSize()
    return gTWIDTH(string.rep("M", self.widthChars), kDialogFont) + 2 * kEditTextSpace, self:lineHeight() * self.numLines + 3
end

local function withoutNewline(line)
    return line:match("[^\x06\x07\x08]*")
end

function DialogItemEditMulti:scrollOffset()
    if not self.lines then
        return 0
    end
    local result = self.lines[self.firstDrawnLine].y - self.lines[1].y
    assert(result == (self.firstDrawnLine - 1) * self:lineHeight())
    return result
end

function DialogItemEditMulti:getCursorPos()
    if self.lines == nil then
        return nil
    end
    local pos = self.editor.cursorPos
    local line, col = self:charPosToLineColumn(pos)
    if line < self.firstDrawnLine or line >= self.firstDrawnLine + self.numLines then
        return nil
    end
    local lineInfo = self.lines[line]
    local textw = gTWIDTH(withoutNewline(lineInfo.text):sub(1, col - 1), kDialogFont)
    local x = lineInfo.x + textw
    local y = lineInfo.y - self:scrollOffset() - 1
    return x, y
end

function DialogItemEditMulti:charPosToLineColumn(pos)
    -- Work out which line pos is in
    for i, line in ipairs(self.lines) do
        if pos < line.charPos + #line.text or self.lines[i + 1] == nil then
            -- It's on this line
            local textw = gTWIDTH(withoutNewline(line.text):sub(1, pos - line.charPos - 1), kDialogFont)
            -- printf("charPosToLineColumn(%d) = %d, %d\n", pos, i, pos - line.charPos + 1)
            return i, pos - line.charPos + 1
        end
    end
end

function DialogItemEditMulti:posToCharPos(x, y)
    local tx = x - self.x - kEditTextSpace - self.promptWidth
    local ty = y - self.y - kDialogLineTextYOffset + self:scrollOffset()
    local lineNumber = math.min(math.max(1, 1 + (ty // self:lineHeight())), #self.lines)
    local lineInfo = self.lines[lineNumber]
    local line = withoutNewline(lineInfo.text)

    local result = 0
    while gTWIDTH(line:sub(1, result), kDialogFont) < tx do
        result = result + 1
        if result >= #line then
            break
        end
    end
    return lineInfo.charPos + result
end

local function formatText(text, maxWidth)
    local lines = {}
    local currentLine = {}
    local lineWidth = 0
    local function newLine()
        table.insert(lines, table.concat(currentLine))
        currentLine = {}
        lineWidth = 0
    end
    local function addToLine(word, wordWidth)
        table.insert(currentLine, word)
        lineWidth = lineWidth + wordWidth
    end
    local spaceWidth = gTWIDTH(" ", kDialogFont)
    local function addWord(word)
        local wordWidth = gTWIDTH(word, kDialogFont)
        local lineAndWordWidth = lineWidth + wordWidth
        if lineAndWordWidth <= maxWidth then
            -- Fits on current line
            addToLine(word, wordWidth)
        elseif wordWidth >= maxWidth * 3 / 4 then
            -- Uh oh the word on its own doesn't fit. Try to camelcase split it
            local w1, w2 = word:match("([A-Z][a-z]+)([A-Z][a-z]+)")
            if w1 then
                addToLine(w1, gTWIDTH(w1, kDialogFont))
                newLine()
                addToLine(w2, gTWIDTH(w2, kDialogFont))
            else
                -- Give up
                if lineWidth > 0 then
                    newLine()
                end
                addToLine(word, wordWidth)
            end
        else
            if lineWidth > 0 then
                newLine()
            end
            addToLine(word, wordWidth)
        end
    end

    local pos = 1
    while true do
        local ch = text:sub(pos, pos)
        if ch == "" then
            break
        elseif ch == " " then
            addWord(ch)
            pos = pos + 1
        elseif ch == KLineBreakStr or ch == KParagraphDelimiterStr then
            addToLine(ch, 0)
            newLine()
            pos = pos + 1
        else
            local word, nextPos = text:match("([\x21-\xFF]+)()", pos)
            addWord(word)
            pos = nextPos
        end
    end
    newLine()
    return lines
end

function DialogItemEditMulti:getTextWidth()
    local boxWidth = math.min(self:contentSize(), self.w - (self.x + self.promptWidth))
    local textWidth = boxWidth - 2
    if self:shouldDrawScrollbar() and self.scrollbar then
        textWidth = textWidth - self.scrollbar.w - 1 -- Extra -1 for the line we draw to left of scrollbar
    end
    return textWidth
end

function DialogItemEditMulti:formatTextIntoLines()
    local lines = formatText(self.editor.value, self:getTextWidth())
    self.lines = {}

    local texty = self.y + kDialogLineTextYOffset
    local lineHeight = self:lineHeight()
    local charPos = 1
    for i, line in ipairs(lines) do
        local lineInfo = {
            text = line,
            charPos = charPos,
            x = self.x + self.promptWidth + kEditTextSpace,
            y = texty + (i-1) * lineHeight,
        }
        local printableChars = withoutNewline(lineInfo.text)
        self.lines[i] = lineInfo

        charPos = charPos + #line
    end
end

function DialogItemEditMulti:shouldDrawScrollbar()
    return self.lines and #self.lines > self.numLines and self.numLines > 1
end

function DialogItemEditMulti:draw()
    if self.hasFocus then
        -- So it doesn't get drawn by native side while we're drawing ourselves
        CURSOR(nil)
    end
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    local boxWidth = math.min(self:contentSize(), self.w - x)
    local lineHeight = self:lineHeight()
    local boxHeight = lineHeight * self.numLines
    lightGrey()
    gAT(x, texty - 2)
    gBOX(boxWidth, boxHeight + 3)
    white()
    gAT(x + 1, texty - 1)
    gFILL(boxWidth - 2, boxHeight + 1)
    black()
    gAT(x + 1, texty)

    local scrollbarWasVisible = self.scrollbar and self:shouldDrawScrollbar()
    self:formatTextIntoLines()
    local shouldDrawScrollbar = self:shouldDrawScrollbar()

    if shouldDrawScrollbar and self.scrollbar == nil then
        local Scrollbar = runtime:require("scrollbar").Scrollbar
        self.scrollbar = Scrollbar.newVertical(0,
            texty - 1,
            boxHeight + 1,
            boxHeight,
            #self.lines * lineHeight)
        self.scrollbar.x = x + boxWidth - 1 - self.scrollbar.w
        self.scrollbar.observer = self
        self:formatTextIntoLines()
    elseif scrollbarWasVisible and not shouldDrawScrollbar then
        -- Have to reformat
        self:formatTextIntoLines()
        self.firstDrawnLine = 1
    end

    local scrollOffset = self:scrollOffset()
    for i = self.firstDrawnLine, self.firstDrawnLine + self.numLines - 1 do
        local line = self.lines[i]
        if line == nil then
            break
        end
        drawText(withoutNewline(line.text), line.x, line.y - scrollOffset)
    end

    if shouldDrawScrollbar then
        darkGrey()
        gAT(self.scrollbar.x - 1, self.scrollbar.y)
        gLINEBY(0, self.scrollbar.h)
        if not self.scrollbar.tracking then
            self.scrollbar:setContentHeight(#self.lines * lineHeight)
            self.scrollbar:setContentOffset(scrollOffset)
        end
        self.scrollbar:draw()
    end

    if self.hasFocus and self.editor:hasSelection() then
        black()
        local selStart, selEnd = self.editor:getSelectionRange()
        local startLine, startCol = self:charPosToLineColumn(selStart)
        local endLine, endCol = self:charPosToLineColumn(selEnd)
        for i = math.max(startLine, self.firstDrawnLine), math.min(endLine, self.firstDrawnLine + self.numLines - 1) do
            local line = self.lines[i]
            local printableChars = withoutNewline(line.text)
            local lineSelStart = (i == startLine) and startCol or 1
            local lineSelEnd = (i == endLine) and endCol or #printableChars
            local selOffset = gTWIDTH(printableChars:sub(1, lineSelStart - 1))
            local selWidth = gTWIDTH(printableChars:sub(lineSelStart, lineSelEnd))
            gAT(line.x + selOffset, line.y - scrollOffset - 1)
            gFILL(selWidth, self:lineHeight(), KgModeInvert)
        end
    end

    self:updateCursorIfFocussed()
    View.draw(self)
end

function DialogItemEditMulti:setFirstDrawnLine(newVal)
    self.firstDrawnLine = math.min(math.max(1, newVal), #self.lines - self.numLines + 1)
    self:setNeedsRedraw()
end

function DialogItemEditMulti:updateCursorIfFocussed()
    if self.hasFocus then
        local x, y = self:getCursorPos()
        if x then
            CURSOR(gIDENTITY(), x, y, self.cursorWidth, self:lineHeight())
            self:updateIohandler()
        else
            -- Cursor not visible in the currently shown lines
            CURSOR(nil)
            runtime:declareTextEditor(nil)
        end
    end
end

function DialogItemEditMulti:handlePointerEvent(x, y, type)
    -- printf("DialogItemEditMulti:handlePointerEvent(%d, %d, %d)\n", x, y, type)
    if self.scrollbar and (self.scrollbar.tracking or (x >= self.scrollbar.x)) then
        self.scrollbar:handlePointerEvent(x, y, type)
        if self.scrollbar.tracking and not self.capturing then
            self:drawIfNeeded()
            self:capturePointer()
        end
    elseif self.capturing then
        self.editor:setCursorPos(self:posToCharPos(x, y), self.editor.anchor)
    elseif type == KEvPtrPenDown then
        if not self.hasFocus then
            self:takeFocus()
        end
        if x >= self.x + self.promptWidth then
            self.nextIoHandlerUpdateUserRequested = true
            self.editor:setCursorPos(self:posToCharPos(x, y))
            self:capturePointer()
            self:setNeedsRedraw()
        end
    end
    return true
end

function DialogItemEditMulti:handleKeyPress(k, modifiers)
    local anchor = nil
    if modifiers & KKmodShift ~= 0 then
        anchor = self.editor.anchor
    end
    if k == KKeyEnter and modifiers == 0 then
        if self.numLines > 1 then
            self.editor:insert(KLineBreakStr)
        end
        return true
    elseif k == KKeyUpArrow32 or k == KKeyDownArrow32 then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        if k == KKeyUpArrow32 and line == 1 then
            if col == 1 then
                -- Allow the keypress to move the focus
                return false
            else
                line = 2
                col = 1
            end
        elseif k == KKeyDownArrow32 and line == #self.lines then
            if col > #self.lines[line].text then
                -- Allow the keypress to move the focus
                return false
            else
                col = #self.lines[line].text + 1
                line = line - 1
            end
        end
        local lineInfo = self.lines[line + (k == KKeyUpArrow32 and -1 or 1)]
        if lineInfo then
            self.editor:setCursorPos(lineInfo.charPos + col - 1, anchor)
        end
        return true
    elseif k == KKeyPageLeft32 then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        self.editor:setCursorPos(self.lines[line].charPos, anchor)
        return true
    elseif k == KKeyPageRight32 then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        self.editor:setCursorPos(self.lines[line].charPos + #withoutNewline(self.lines[line].text), anchor)
        return true
    elseif k == KKeyPageDown32 then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        local newLine = math.min(line + self.numLines, #self.lines)
        -- Keep cursor in roughly the same place
        self.firstDrawnLine = math.min(self.firstDrawnLine + (newLine - line), #self.lines - self.numLines)
        local newCol = math.min(col, #withoutNewline(self.lines[newLine].text) + 1)
        self.editor:setCursorPos(self.lines[newLine].charPos + newCol - 1, anchor)
    elseif k == KKeyPageUp32 then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        local newLine = math.max(line - self.numLines, 1)
        -- Keep cursor in roughly the same place
        self.firstDrawnLine = math.max(self.firstDrawnLine + (newLine - line), 1)
        local newCol = math.min(col, #withoutNewline(self.lines[newLine].text) + 1)
        self.editor:setCursorPos(self.lines[newLine].charPos + newCol - 1, anchor)
    else
        return DialogItemEdit.handleKeyPress(self, k, modifiers)
    end
end

function DialogItemEditMulti:onEditorChanged()
    -- Have to check whether we need to scroll to keep the cursor visible
    if not self.lines then
        return
    end
    self:formatTextIntoLines()
    local line = self:charPosToLineColumn(self.editor.cursorPos)
    if line < self.firstDrawnLine then
        self:setFirstDrawnLine(line)
    elseif line >= self.firstDrawnLine + self.numLines then
        self:setFirstDrawnLine(line - self.numLines + 1)
    end

    DialogItemEditMulti._super.onEditorChanged(self)
end

function DialogItemEditMulti:scrollbarDidScroll(inc)
    self:setFirstDrawnLine(self.firstDrawnLine + inc)
end

function DialogItemEditMulti:scrollbarContentOffsetChanged()
    local newOffset = self.scrollbar.contentOffset
    -- printf("DialogItemEditMulti:scrollbarContentOffsetChanged() newOffset=%d\n", newOffset)
    self.firstDrawnLine = 1
    while self.lines[self.firstDrawnLine].y - self.y + self:lineHeight() < newOffset do
        self.firstDrawnLine = self.firstDrawnLine + 1
    end
    -- printf("new firstDrawnLine = %d offset=%d\n", self.firstDrawnLine, self.lines[self.firstDrawnLine].y)
    self:setNeedsRedraw()
end

function DialogItemEditMulti:updateVariable()
    local len = #self.editor.value
    self.addr:write(string.pack("<i4", len))
    local startOfData = self.addr + 4
    startOfData:write(self.editor.value)
end

local DialogChoiceList = class {
    _super = View,
    choiceTextSpace = 3, -- Yep, really not the same as kEditTextSpace despite how similar the two look
    typeable = false,
    cursorPos = 1, -- Only for typeable=true
}

local kChoiceArrowSpace = 2
local kChoiceArrowSize = 12 + kChoiceArrowSpace

function DialogChoiceList:init(lineHeight)
    if #self.choices == 0 then
        print("Empty choices list in dCHOICE!")
        error(KErrInvalidArgs)
    end
    DialogChoiceList._super.init(self, lineHeight)
end

function DialogChoiceList:getChoicesWidth()
    local maxWidth = 0
    for _, choice in ipairs(self.choices) do
        maxWidth = math.max(gTWIDTH(choice, kDialogFont), maxWidth)
    end
    return maxWidth + 2 * self.choiceTextSpace
end

function DialogChoiceList:contentSize()
    local maxWidth = self:getChoicesWidth()
    return maxWidth + kChoiceArrowSize, self.heightHint
end

function DialogChoiceList:focussable()
    return true
end

function DialogChoiceList:draw()
    if self.typeable and self.hasFocus then
        -- So it doesn't get drawn by native side while we're drawing ourselves
        CURSOR(nil)
    end

    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset
    self.leftArrowX = x - kChoiceArrowSize -- Left arrow draws before content area

    local choicesWidth = self:getChoicesWidth()
    lightGrey()
    gAT(x, texty - 2)
    gBOX(choicesWidth, self.charh + 3)
    gAT(x + 1, texty - 1)
    white()
    gFILL(choicesWidth - 2, self.charh + 1)
    if self.choiceFont then
        gFONT(self.choiceFont)
    end
    local text = self.choices[self.index]
    black()
    drawText(text, x + self.choiceTextSpace, texty)

    self.rightArrowX = x + choicesWidth + kChoiceArrowSpace
    gFONT(KFontEiksym15)
    local arrowMode = self.hasFocus and KgModeSet or KgModeClear
    drawText(kChoiceLeftArrow, self.leftArrowX, texty, arrowMode)
    drawText(kChoiceRightArrow, self.rightArrowX, texty, arrowMode)
    gFONT(kDialogFont)

    if self.typeable and self.hasFocus then
        local cursorx, cursory = self:getCursorPos()
        CURSOR(gIDENTITY(), cursorx, texty, gTWIDTH(text:sub(self.cursorPos, self.cursorPos)))
        self:updateIohandler()
    end

    View.draw(self)
end

function DialogChoiceList:getCursorPos()
    if self.typeable then
        local texty = self.y + kDialogLineTextYOffset
        local text = self.choices[self.index]
        local cursorx = self.x + self.promptWidth + self.choiceTextSpace + gTWIDTH(text:sub(1, self.cursorPos - 1))
        local cursory = self.y + kDialogLineTextYOffset
        return cursorx, cursory
    else
        return nil
    end
end

function DialogChoiceList:updateIohandler()
    if self.typeable then
        local controlRect = {
            x = self.x + self.promptWidth,
            y = self.y,
            w = self.w - self.promptWidth,
            h = self.h,
        }
        local cursorx, cursory = self:getCursorPos()
        local cursorRect = {
            x = cursorx,
            y = cursory,
            w = 2,
            h = self.charh + 1, --  This is not quite correct for DialogItemEditMulti but it doesn't really matter
        }
        local userFocusRequested = false
        if self.nextIoHandlerUpdateUserRequested then
            userFocusRequested = true
            self.nextIoHandlerUpdateUserRequested = false
        end
        runtime:declareTextEditor(gIDENTITY(), "text", controlRect, cursorRect, userFocusRequested)
    end
end

function DialogChoiceList:handlePointerEvent(x, y, type)
    if type == KEvPtrPenDown then
        if not self.hasFocus then
            self:takeFocus()
        end
        if x >= self.leftArrowX and x < self.leftArrowX + kChoiceArrowSize then
            self:setIndex(wrapIndex(self.index - 1, #self.choices))
        elseif x >= self.leftArrowX + kChoiceArrowSize and x < self.rightArrowX then
            self:displayPopupMenu()
        elseif x >= self.rightArrowX and x < self.rightArrowX + kChoiceArrowSize then
            self:setIndex(wrapIndex(self.index + 1, #self.choices))
        end
    end
    return true
end

function DialogChoiceList:handleKeyPress(k, modifiers)
    if modifiers ~= 0 then
        return false
    end
    if k == KKeyLeftArrow32 then
        self:setIndex(wrapIndex(self.index - 1, #self.choices))
        return true
    elseif k == KKeyRightArrow32 then
        self:setIndex(wrapIndex(self.index + 1, #self.choices))
        return true
    elseif k == KKeyTab then
        self:displayPopupMenu()
        return true
    elseif k >= 0x20 and k <= 0x7E then
        local ch = string.char(k)
        if self.typeable then
            local prefix = string.lower(self.choices[self.index]:sub(1, self.cursorPos - 1) .. ch)
            -- Find first item (possibly including current) with this prefix
            for i = self.index, #self.choices do
                if self.choices[i]:sub(1, #prefix):lower() == prefix then
                    self.index = i
                    self.cursorPos = #prefix + 1
                    self:setNeedsRedraw()
                    break
                end
            end
        else
            -- Find the next thing after current pos that starts with ch
            local i = self.index + 1
            while true do
                if self.choices[i] == nil then
                    -- Wrap around
                    i = 1
                end
                if i == self.index then
                    -- We've been all the way round, bail
                    break
                elseif self.choices[i]:sub(1, 1):lower() == ch then
                    self:setIndex(i)
                    break
                end
                i = i + 1
            end
        end
        return true
    elseif self.typeable and k == KKeyDel then
        if self.cursorPos > 1 then
            self.cursorPos = self.cursorPos - 1
            self:setNeedsRedraw()
        end
    else
        -- print("Unhandled key", k)
    end
    return false
end

function DialogChoiceList:setFocus(flag)
    DialogChoiceList._super.setFocus(self, flag)
    if not flag then
        CURSOR(false)
        runtime:iohandler().textEditor(nil)
    end
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
        popupItems[i] = { text = choice }
    end
    local result = mPOPUPEx(gORIGINX() + self.x + self.promptWidth, gORIGINY() + self.y, KMPopupPosTopLeft, popupItems, self.index)
    if result > 0 then
        self:setIndex(result)
    end
end

function DialogChoiceList:setIndex(index)
    self.index = index
    self.cursorPos = 1
    self:setNeedsRedraw()
end

function DialogChoiceList:updateVariable()
    self.variable(self.index)
end

local DialogCheckbox = class {
    _super = DialogChoiceList,
    choiceFont = KFontEiksym15,
    choiceTextSpace = 1,
}

function DialogCheckbox:init(lineHeight)
    self.choices = { "", kTickMark }
    self.index = self.value == KFalse and 1 or 2
    DialogCheckbox._super.init(self, lineHeight)
end

function DialogCheckbox:getChoicesWidth()
    return 18
end

function DialogCheckbox:displayPopupMenu()
    self.index = wrapIndex(self.index + 1, 2)
    self:setNeedsRedraw()
end

function DialogCheckbox:updateVariable()
    self.variable(self.index == 1 and KFalse or KTrue)
end

local DialogItemFileChooser = class {
    _super = DialogChoiceList,
}

function DialogItemFileChooser:init(lineHeight)
    self.typeable = true
    local dir, name = oplpath.split(self.path)
    assert(dir ~= "", "Bad path for DialogItemFileChooser")
    self:update(dir, name)
    self._super.init(self, lineHeight)
end

function DialogItemFileChooser:getChoicesWidth()
    return 350
end

function DialogItemFileChooser:update(dir, name)
    printf("DialogItemFileChooser:update(%s, %s)\n", dir, name)

    local canonName = name and oplpath.canon(name)
    local dirContents = runtime:ls(dir)
    self.choices = {}
    self.paths = {}
    self.index = 1
    for _, item in ipairs(dirContents) do
        if not runtime:isdir(item) then
            local itemName = oplpath.basename(item)
            table.insert(self.paths, item)
            table.insert(self.choices, itemName)
            if oplpath.canon(itemName) == canonName then
                self.index = #self.choices
            end
        end
    end
    if #self.paths == 0 then
        self.choices[1] = "(No files)"
    end
    self.path = self.paths[self.index] or dir
    self:setNeedsRedraw()
end

function DialogItemFileChooser:getPath()
    return self.path
end

function DialogItemFileChooser:canLoseFocus()
    if self.flags & KDFileAllowNullStrings == 0 and #self.paths == 0 then
        gIPRINT("No filename entered", KBusyTopRight)
        return false
    end
    return true
end

function DialogItemFileChooser:updateVariable()
    self.variable(self.path)
end

function DialogItemFileChooser:setIndex(index)
    self.path = oplpath.join(oplpath.dirname(self.path), self.choices[index])
    DialogChoiceList.setIndex(self, index)
end

local DialogItemFileEdit = class {
    _super = DialogItemEdit,
}

function DialogItemFileEdit:init(lineHeight)
    self._super.init(self, lineHeight)
    local dir, name = oplpath.split(self.path)
    assert(dir ~= "", "Bad path for DialogItemFileEdit")
    self:update(dir, name)
end

function DialogItemFileEdit:contentSize()
    return 350, self.heightHint
end

function DialogItemFileEdit:update(dir, name)
    printf("DialogItemFileEdit:update(%s, %s)\n", dir, name)
    self.path = dir
    self.editor:setValue(name or "")
    self.editor:setCursorPos(#self.editor.value + 1, 1)
end

function DialogItemFileEdit:getPath()
    return oplpath.join(self.path, self.editor.value)
end

function DialogItemFileEdit:canLoseFocus()
    -- print("DialogItemFileEdit:canLoseFocus()", self.path, self.editor.value, self:getPath())
    if self.editor.value == "" then
        if self.flags & KDFileAllowNullStrings == 0 then
            gIPRINT("No filename entered", KBusyTopRight)
            return false
        else
            -- This is allowed without query even though the returned path is an existing directory
            return true
        end
    elseif self.flags & KDFileEditorDisallowExisting ~= 0 and runtime:EXIST(self:getPath()) then
        gIPRINT("File with this name already exists", KBusyTopRight)
        return false
    elseif self.flags & KDFileEditorQueryExisting ~= 0 and runtime:EXIST(self:getPath()) then
        local ret = DIALOG({
            title = "Confirm file replace",
            flags = 0,
            xpos = 0,
            ypos = 0,
            items = {
                {
                type = dItemTypes.dTEXT,
                align = "center",
                value = string.format('Replace file "%s"?', self.editor.value),
                },
            },
            buttons = {
                { key = string.byte("n") | KDButtonPlainKey | KDButtonNoLabel, text = "No" },
                { key = string.byte("y") | KDButtonPlainKey | KDButtonNoLabel, text = "Yes" },
            },
        })
        return ret == string.byte("y")
    else
        return true
    end
end

function DialogItemFileEdit:updateVariable()
    self.variable(oplpath.join(self.path, self.editor.value))
end

local DialogItemFolder = class {
    _super = DialogChoiceList,
}

function DialogItemFolder:init(lineHeight)
    self:updateFolders()
    DialogItemFolder._super.init(self, lineHeight)
end

function DialogItemFolder:getChoicesWidth()
    return 350
end

function DialogItemFolder:updateVariable()
    -- Nothing needed, all handled by DialogItemFileChooser/DialogItemFileEdit
end

function DialogItemFolder:updateFolders()
    self.paths = {}
    self.choices = {} -- Keep this separate to self.paths so we can reuse baseclass logic
    local disk = self.fileItem:getPath():sub(1, 3)
    self:addDir(disk)
    self.index = 1
    local targetDir = oplpath.canon(oplpath.dirname(self.fileItem:getPath()))
    for i, dir in ipairs(self.paths) do
        if oplpath.canon(oplpath.join(dir, "")) == targetDir then
            self.index = i
            break
        end
    end
    self:setNeedsRedraw()
end

function DialogItemFolder:addDir(path)
    -- print("addDir", path)
    table.insert(self.paths, path)
    local base = oplpath.basename(path)
    if base == "" then
        base = path
    end
    table.insert(self.choices, path)
    for _, item in ipairs(runtime:ls(path)) do
        if runtime:isdir(item) then
            self:addDir(item)
        end
    end
end

function DialogItemFolder:setIndex(index)
    if index ~= self.index then
        self.fileItem:update(self.paths[index])
        DialogItemFolder._super.setIndex(self, index)
    end
end

-- function DialogItemFolder:displayPopupMenu()
--     -- TODO the folder icon is Z:\System\Data\eikon.mbm index 4 (20x16)
-- end

local DialogItemDisk = class {
    _super = DialogChoiceList,
}

function DialogItemDisk:init(lineHeight)
    self.choices = runtime:getDisks()
    local showZ = self.fileItem.flags & KDFileSelectorWithRom ~= 0
    if not showZ and self.choices[#self.choices] == "Z" then
        self.choices[#self.choices] = nil
    end
    self.index = 1
    for i, disk in ipairs(self.choices) do
        if self.fileItem.path:match("^"..disk..":\\") then
            self.index = i
            break
        end
    end
    DialogItemDisk._super.init(self, lineHeight)
end

function DialogItemDisk:updateVariable()
    -- Nothing needed, all handled by DialogItemFileChooser/DialogItemFileEdit
end

function DialogItemDisk:setIndex(index)
    if index ~= self.index then
        self.fileItem:update(self.choices[index]..":\\", nil)
        self.folderItem:updateFolders()
        DialogItemDisk._super.setIndex(self, index)
    end
end

local DialogItemSeparator = class { _super = View }

function DialogItemSeparator:contentSize()
    return 0, 1
end

function DialogItemSeparator:draw()
    gAT(self.x, self.y)
    gLINEBY(self.w, 0)
    View.draw(self)
end

local Button = class { _super = View }

function Button:contentSize()
    local w = math.max(gTWIDTH(self.text, kButtonFont) + 8, kButtonMinWidth)
    return w, kButtonHeight
end

function Button:draw()
    gFONT(kButtonFont)
    gAT(self.x, self.y)
    local state = self.pressed and 1 or 0
    gBUTTON(self.text, KButtS5, self.w, self.h, state)
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
        -- It's an alphabet key in which case modifiers must match. Oddly, space is halfway between the two in that it
        -- _is_ a bare key by default, but does _not_ accept any modifiers.
        local requiredModifiers = ((shortcut == 32) or (self:getKey() & KDButtonPlainKey > 0)) and 0 or KKmodControl
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
            view:onButtonPressed(self)
            return
        end
        view = view.parent
    end
    printf("Button %s pressed but unhandled\n", self:shortcut())
end

local DialogButtonGroup = class { _super = View }

function DialogButtonGroup:contentSize()
    -- All buttons are the same size, which can grow to fit the longest button text
    local maxButtonWidth = 0
    local numButtons = #self
    local hasLabels = false
    for _, button in ipairs(self) do
        maxButtonWidth = math.max(button:contentSize(), maxButtonWidth)
        if button:getLabel() then
            hasLabels = true
        end
    end
    local h
    if hasLabels then
       h = kDialogLineHeight * 2
    else
       h = kButtonYOffset + kButtonHeight
    end

    if self.side then
        return maxButtonWidth + kButtonSpacing, h * numButtons, maxButtonWidth
    else
        local buttonsWidth = maxButtonWidth * numButtons + kButtonSpacing * (numButtons - 1)
        return buttonsWidth, h, maxButtonWidth
    end
end

function DialogButtonGroup:addButtonsToView()
    local cw, ch, buttonWidth = self:contentSize()
    local buttonHeight = ch // #self
    if self.side then
        local x = self.x
        local y = self.y
        for _, button in ipairs(self) do
            self:addSubview(button, x, y, buttonWidth, kButtonHeight)
            y = y + buttonHeight
        end
    else
        local x = self.x + ((self.w - cw) // 2)
        local buttonY = self.y + kButtonYOffset
        for _, button in ipairs(self) do
            self:addSubview(button, x, buttonY, buttonWidth, kButtonHeight)
            x = x + buttonWidth + kButtonSpacing
        end
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

local DialogWindow = class { _super = View }

function DialogWindow.new(items, x, y, w, h)
    local mode = runtime:isColor() and KColorgCreate256ColorMode or KColorgCreate4GrayMode
    local id = gCREATE(x, y, w, h, false, mode | KgCreateHasShadow | 0x200)
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
    local modifiers
    if k & KEvNotKeyMask == 0 then
        -- Key press event. Note, buttons shortcuts take precedence over the focussed control
        modifiers = ev[KEvAKMod]()
        if self.buttons then
            handled = self.buttons:handleKeyPress(k, modifiers)
        end
        if not handled and self.focussedItemIndex then
            handled = self.items[self.focussedItemIndex]:handleKeyPress(k, modifiers)
        end
        if handled then
            return nil
        end
    end

    if k == KKeyEsc then
        return 0
    elseif k == KKeyUpArrow32 and modifiers == 0 and self.focussedItemIndex then
        local newIdx = self.focussedItemIndex
        repeat
            newIdx = wrapIndex(newIdx - 1, #self.items)
        until self.items[newIdx]:focussable()
        if newIdx ~= self.focussedItemIndex then
            self:moveFocusTo(self.items[newIdx])
        end
    elseif k == KKeyDownArrow32 and modifiers == 0 and self.focussedItemIndex then
        local newIdx = self.focussedItemIndex
        repeat
            newIdx = wrapIndex(newIdx + 1, #self.items)
        until self.items[newIdx]:focussable()
        if newIdx ~= self.focussedItemIndex then
            self:moveFocusTo(self.items[newIdx])
        end
    elseif k == KKeyEnter then
        -- If we get here, there can't be a button with enter as a shortcut
        if self:canDismiss() then
            return self.focussedItemIndex
        end
    elseif k == KEvPtr then
        if ev[KEvAPtrWindowId]() ~= self.windowId then
            return nil
        end
        local ptrType = ev[KEvAPtrType]()
        local x = ev[KEvAPtrPositionX]()
        local y = ev[KEvAPtrPositionY]()
        self:handlePointerEvent(x, y, ptrType)
    end

    return nil
end

function DialogWindow:canDismiss()
    -- Strictly speaking, only the currently focussed item should be able to prevent this, because anything not focussed
    -- should have a valid value
    for _, item in ipairs(self.items) do
        if not item:canLoseFocus() then
            return false
        end
    end
    return true
end

function DialogWindow:onButtonPressed(button)
    if button:getResultCode() <= 0 or self:canDismiss() then
        self.buttonPressed = button
    end
end

function DialogWindow:moveFocusTo(newView)
    local currentFocus = self.focussedItemIndex and self.items[self.focussedItemIndex]
    if currentFocus then
        if not currentFocus:canLoseFocus() then
            return
        end
        currentFocus:setFocus(false)
    end
    self.focussedItemIndex = assert(newView.focusOrderIndex)
    newView:setFocus(true)
end

function DialogWindow:focussedItem()
    return self.focussedItemIndex and self.items[self.focussedItemIndex]
end

local itemTypes = {
    [dItemTypes.dTEXT] = DialogItemText,
    [dItemTypes.dCHOICE] = DialogChoiceList,
    [dItemTypes.dSEPARATOR] = DialogItemSeparator,
    [dItemTypes.dCHECKBOX] = DialogCheckbox,
    [dItemTypes.dEDIT] = DialogItemEdit,
    [dItemTypes.dEDITMULTI] = DialogItemEditMulti,
    [dItemTypes.dLONG] = DialogItemEditLong,
    [dItemTypes.dFLOAT] = DialogItemEditFloat,
    [dItemTypes.dXINPUT] = DialogItemEditPass,
    [dItemTypes.dDATE] = DialogItemEditDate,
    [dItemTypes.dTIME] = DialogItemEditTime,
    [dItemTypes.dFILECHOOSER] = DialogItemFileChooser,
    [dItemTypes.dFILEEDIT] = DialogItemFileEdit,
    [dItemTypes.dFILEFOLDER] = DialogItemFolder,
    [dItemTypes.dFILEDISK] = DialogItemDisk,
}

function DIALOG(dialog)
    -- print(dump(dialog, "minimal"))

    -- Special case for defaultiohandler
    local iohandlerDialog = runtime:iohandler().dialog
    if iohandlerDialog then
        return iohandlerDialog(dialog)
    end

    local state = runtime:saveGraphicsState()

    local borderWidth = 4 -- 1 px black box plus 3 px for the gXBORDER
    local hMargin = 8
    local bottomMargin = 4
    -- local titleIndent = 3
    local titleBarSpace = 4 -- extra gap between title bar and first item
    local maxPromptWidth = 0
    local maxContentWidth = 0
    local maxWidth = 0 -- For anything that doesn't split into prompt and content
    local maxButtonWidth = 30 -- ?
    local promptGap = 22 -- Must be at least as big as kChoiceArrowSize because the lefthand arrow goes in the prompt gap
    local lineHeight = (dialog.flags & KDlgDensePack) == 0 and kDialogLineHeight or kDialogTightLineHeight

    gFONT(kDialogFont)
    View.charh = gINFO().fontHeight
    local titleBar
    local h = borderWidth
    if dialog.title and (dialog.flags & KDlgNoTitle) == 0 then
        titleBar = DialogTitleBar {
            hMargin = hMargin,
            value = dialog.title,
            draggable = (dialog.flags & KDlgNoDrag) == 0,
        }
        titleBar:init(lineHeight)
        local cw, ch = titleBar:contentSize()
        maxWidth = math.max(cw, maxWidth)
        h = h + ch + titleBarSpace
    end
    local titleBarHeight = h

    for i, item in ipairs(dialog.items) do
        -- printf("Item %i is type %d\n", i, item.type)
        setmetatable(item, itemTypes[item.type] or PlaceholderView)
        item:init(lineHeight)
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

    -- All buttons are the same size, which can grow to fit the longest button text
    local butw, buth
    local numButtons = dialog.buttons and #dialog.buttons or 0
    if numButtons > 0 then
        dialog.buttons.side = dialog.flags & KDlgButRight ~= 0
        setmetatable(dialog.buttons, DialogButtonGroup)
        for i, button in ipairs(dialog.buttons) do
            setmetatable(button, Button)
            -- printf("Button %i key: %d text: %s\n", i, button.key, button.text)
        end
        butw, buth = dialog.buttons:contentSize()
        if dialog.buttons.side then
            h = math.max(h, titleBarHeight + buth + bottomMargin + borderWidth)
        else
            maxWidth = math.max(butw, maxWidth)
            h = h + buth + kDialogLineGap
        end
    end

    if maxPromptWidth > 0 or maxContentWidth > 0 then
        maxWidth = math.max(maxPromptWidth + promptGap + maxContentWidth, maxWidth)
    end

    local screenWidth, screenHeight = runtime:getScreenInfo()
    local w = maxWidth + (borderWidth + hMargin) * 2
    local rightHandButtonWidth = 0
    if numButtons > 0 and dialog.buttons.side then
        rightHandButtonWidth = butw + hMargin
        w = w + rightHandButtonWidth
    end
    w = math.min(w, screenWidth)
    h = math.min(h, screenHeight)
    if dialog.flags & KDlgFillScreen ~= 0 then
        w = screenWidth
        h = screenHeight
    end
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
    if runtime:isColor() then
        gCOLORBACKGROUND(0xCC, 0xCC, 0xCC)
    else
        gCOLORBACKGROUND(0xFF, 0xFF, 0xFF)
    end

    -- Now we have our window and prompt area sizes we can actually lay out the items

    gFILL(w, h, KgModeClear)
    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94, w - 2, h - 2)

    local y = borderWidth
    if titleBar then
        local ch = titleBar:contentHeight()
        win:addSubview(titleBar, borderWidth, y, w - borderWidth * 2, ch)
        y = y + ch + titleBarSpace
    end

    local itemWidth = w - (borderWidth + hMargin) * 2 - rightHandButtonWidth
    for i, item in ipairs(dialog.items) do
        item:setPromptWidth(maxPromptWidth + promptGap)
        local ch = item:contentHeight()
        item.focusOrderIndex = i
        win:addSubview(item, borderWidth + hMargin, y, itemWidth, ch)
        if win.focussedItemIndex == nil and item:focussable() then
            win:moveFocusTo(item)
        end
        y = y + ch + kDialogLineGap
    end

    if numButtons > 0 then
        win.buttons = dialog.buttons
        if dialog.buttons.side then
            win:addSubview(dialog.buttons, w - borderWidth - butw, h - bottomMargin - borderWidth - buth, butw, buth)
        else
            win:addSubview(dialog.buttons, borderWidth + hMargin, y, itemWidth, buth)
        end
        win.buttons:addButtonsToView()
    end

    gUPDATE(false)
    win:draw()
    gUPDATE()
    gVISIBLE(true)

    -- event loop
    local stat = runtime:makeTemporaryVar(DataTypes.EWord)
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()

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

    if result > 0 then
        for _, item in ipairs(win.items) do
            item:updateVariable()
        end
    end

    runtime:restoreGraphicsState(state)
    return result
end

return _ENV
