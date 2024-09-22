--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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
    return self.prompt and gTWIDTH(self.prompt) or nil
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
    if flag then
        local view = self.parent
        while view do
            if view.onFocusChanged then
                view:onFocusChanged(self)
                return
            end
            view = view.parent
        end
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

-- Used by subclasses to prevent a dialog being dismissed due to eg invalid selections
function View:canDismiss()
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
    if self.hasFocus then
        black()
    else
        white()
    end
    gAT(x, texty - 1)
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
    local ev = runtime:makeTemporaryVar(DataTypes.ELongArray, 16)
    local evAddr = ev:addressOf()
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

function View:updateVariable()
    if self.variable and self.value then
        self.variable(self.value)
    end
end


PlaceholderView = class { _super = View }

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

DialogTitleBar = class { _super = View }

function DialogTitleBar:contentSize()
    local h = self.heightHint
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
    gFONT(kDialogFont)
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
    local h = self.heightHint
    if self.lineBelow then
        if h == kDialogTightLineHeight then
            h = h + 2
        else
            h = h + 1
        end
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

DialogItemEdit = class {
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
    return gTWIDTH(string.rep("@", self.len)) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEdit:drawPromptAndBox()
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    local boxWidth = math.min(self:contentSize(), self.w - (x - self.x))
    lightGrey()
    gAT(x, texty - 2)
    gBOX(boxWidth, self.charh + 3)
    black()
    gAT(x + 1, texty - 1)
    gFILL(boxWidth - 2, self.charh + 1, KgModeClear)
    gAT(x + 1, texty)
    return x, texty
end

function DialogItemEdit:drawValue(val)
    local x, texty = self:drawPromptAndBox()
    drawText(val, x + kEditTextSpace, texty)
    if self.editor and self.editor:hasSelection() then
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
    local textw, texth = gTWIDTH(self.editor.value:sub(1, self.editor.cursorPos - 1))
    return self.x + self.promptWidth + kEditTextSpace + textw, self.y + kDialogLineTextYOffset - 1
end

function DialogItemEdit:posToCharPos(x, y)
    local tx = x - self.x - kEditTextSpace - self.promptWidth

    -- Is there a better way to do this?
    local result = 1
    while gTWIDTH(self.editor.value:sub(1, result)) < tx do
        result = result + 1
        if result >= #self.editor.value + 1 then
            break
        end
    end
    return result
end

function DialogItemEdit:updateCursorIfFocussed()
    if self.hasFocus then
        gAT(self:getCursorPos())
        local _, h, ascent = gTWIDTH("")
        CURSOR(gIDENTITY(), ascent + 1, self.cursorWidth, h + 1)
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
            self:setFocus(true)
        end
        if x >= self.x + self.promptWidth then
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
    if flag then
        -- When focussed, the draw call triggered by View.setFocus takes care of calling CURSOR (via updateCursorIfFocussed)
        self:updateIohandler()
    else
        CURSOR(false)
        runtime:iohandler().textEditor(nil)
    end
end

function DialogItemEdit:onEditorChanged()
    if self.capturing then
        self:draw()
    else
        self:setNeedsRedraw()
    end
    if self.hasFocus then
        self:updateIohandler()
    end
end

function DialogItemEdit:updateIohandler()
    local origx, origy = gORIGINX(), gORIGINY()
    local rect = {
        x = origx + self.x + self.promptWidth,
        y = origy + self.y,
        w = self.w - self.promptWidth,
        h = self.h,
    }
    runtime:iohandler().textEditor({
        id = gIDENTITY(),
        rect = rect,
        contents = self.editor.value,
        type = self:inputType(),
        cursorPos = self.editor.cursorPos - 1, -- Zero based for native code
    })
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

DialogItemEditLong = class { _super = DialogItemEdit }

function DialogItemEditLong:contentSize()
    -- The @ sign is an example of the widest character in the dialog font (we
    -- should really have an easy API for getting max font width...)
    local maxChars = math.max(#tostring(self.min), #tostring(self.max))
    return gTWIDTH(string.rep("@", maxChars)) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditLong:inputType()
    return "integer"
end

function DialogItemEditLong:canUpdate(newVal)
    if newVal == "-" then
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

function DialogItemEditLong:canDismiss()
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

DialogItemEditFloat = class {
    _super = DialogItemEdit,
    maxChars = 17,
}

function DialogItemEditFloat:contentSize()
    return gTWIDTH(string.rep("0", self.maxChars)) + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditFloat:inputType()
    return "float"
end

function DialogItemEditFloat:canUpdate(newVal)
    local n = tonumber(newVal)
    if newVal == "-" then
        return true
    elseif n == nil or newVal:match("[xXe ]") then
        return false
    elseif #newVal > self.maxChars then
        return false
    else
        return true
    end
end

function DialogItemEditFloat:canDismiss()
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

DialogItemEditPass = class { _super = DialogItemEdit }

function DialogItemEditPass:init(lineHeight)
    DialogItemEditPass._super.init(self, lineHeight)
    self.editor.movableCursor = false
    self.cursorWidth = gTWIDTH("*")
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
    local textw, texth = gTWIDTH(val:sub(1, self.editor.cursorPos - 1))
    return self.x + self.promptWidth + kEditTextSpace + textw, self.y + kDialogLineTextYOffset - 1
end

DialogItemEditDate = class {
    _super = DialogItemEdit,
}

local kSecsFrom1900to1970 = 2208988800

function DialogItemEditDate:init(lineHeight)
    -- Skip DialogItemEdit:init()
    View.init(self, lineHeight)
    local t = os.date("!*t", self.value * 86400 - kSecsFrom1900to1970)
    self.parts = {
        string.format("%02d", t.day),
        string.format("%02d", t.month),
        string.format("%04d", t.year)
    }
    self.day = 1
    self.month = 2
    self.year = 3
    self.mins = { 1, 1, os.date("!*t", self.min * 86400 - kSecsFrom1900to1970).year }
    self.maxes = { 31, 12, os.date("!*t", self.max * 86400 - kSecsFrom1900to1970).year }
    self.widths = { gTWIDTH("00"), gTWIDTH("/00"), gTWIDTH("/0000") }
    self.editor = require("editor").Editor {
        view = self,
    }
    self.currentPart = 1
    self:setPart(self.currentPart)
end

function DialogItemEditDate:setPart(idx)
    -- This also commits any ongoing editing
    local n = tonumber(self.parts[self.currentPart], 10)
    assert(n, "Value should be a valid number in setPart!")
    local min = self.mins[self.currentPart]
    local max = self.maxes[self.currentPart]
    if n < min then
        idx = self.currentPart
        n = min
        gIPRINT("Minimum allowed value is "..tostring(min), KBusyTopRight)
    elseif n > max then
        n = max
        idx = self.currentPart
        gIPRINT("Maximum allowed value is "..tostring(max), KBusyTopRight)
    end

    self.parts[self.currentPart] = string.format("%02d", n)
    self.currentPart = idx
    self.editor:setValue(self.parts[idx])
    self.editor:setCursorPos(#self.editor.value + 1, 1)
    self:setNeedsRedraw()
end

function DialogItemEditDate:canUpdate(newVal)
    local n = tonumber(newVal, 10)
    if n == nil or n < 0 or (self.currentPart < 3 and #newVal > 2) or (self.currentPart == 3 and #newVal > 4) then
        return false
    else
        return true
    end
end

function DialogItemEditDate:onEditorChanged(editor)
    -- print("onEditorChanged", self.currentPart, editor.value)
    local cur = self.currentPart
    local prevLen = #self.parts[cur]
    local newLen = #editor.value
    self.parts[cur] = editor.value
    if cur ~= self.year and prevLen == 1 and newLen == 2 then
        -- Move cursor to next part
        self:setPart(cur + 1)
    elseif cur == self.year and prevLen == 3 and newLen == 4 then
        -- Just commit
        self:setPart(cur)
    end
    self:setNeedsRedraw()
end

function DialogItemEditDate:contentSize()
    return self.widths[1] + self.widths[2] + self.widths[3] + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditDate:draw()
    local x, texty = self:drawPromptAndBox()
    x = x + kEditTextSpace
    local oow = gTWIDTH("00")
    local slashw = gTWIDTH("/")
    for i = 1, 3 do
        drawText(self.parts[i], x, texty)

        if self.currentPart == i and self.editor:hasSelection() then
            gAT(x, texty - 1)
            gFILL(gTWIDTH(self.editor:getSelection()), self.charh + 1, KgModeInvert)
        end

        if i ~= 3 then
            x = x + oow
            drawText("/", x, texty)
            x = x + slashw
        end
    end

    self:updateCursorIfFocussed()
    View.draw(self)
end

function DialogItemEditDate:updateCursorIfFocussed()
    if self.hasFocus then
        if self.editor:hasSelection() then
            -- We don't show a cursor when there's a selection (because a selection is used to indicate the entry is
            -- complete).
            CURSOR(false)
        else
            DialogItemEdit.updateCursorIfFocussed(self)
        end
    end
end

function DialogItemEditDate:getCursorPos()
    local textw, texth = gTWIDTH(self.editor.value:sub(1, self.editor.cursorPos - 1))
    local partw = gTWIDTH("00/")
    local x = self.x + self.promptWidth + kEditTextSpace + ((self.currentPart - 1) * partw) + textw
    local y = self.y + kDialogLineTextYOffset - 1
    return x, y
end

function DialogItemEditDate:handlePointerEvent(x, y, type)
    local pos = self.x + self.promptWidth + kEditTextSpace
    if type == KEvPtrPenDown then
        for i, w in ipairs(self.widths) do
            if x >= pos and x < pos + w then
                self:setPart(i)
                break
            else
                pos = pos + w
            end
        end
    end
end

function DialogItemEditDate:handleKeyPress(k, modifiers)
    if k == KKeyLeftArrow then
        if self.currentPart > 1 then
            self:setPart(self.currentPart - 1)
        end
        return true
    elseif k == KKeyRightArrow then
        if self.currentPart < 3 then
            self:setPart(self.currentPart + 1)
        end
        return true
    elseif k == KKeyPageLeft or k == KKeyPageRight then
        -- These shouldn't do anything in a date editor
        return true
    else
        return self.editor:handleKeyPress(k, modifiers)
    end
end

function DialogItemEditDate:getDate()
    -- day and month will already have been checked to be 1-31 and 1-12, and year will already be right, so just check
    -- that the days is allowed. Technique taken from DTDaysInMonth
    local d = {
        day = 31,
        month = tonumber(self.parts[self.month], 10),
        year = tonumber(self.parts[self.year], 10),
    }
    local maxDays = 31 - os.date("!*t", runtime:iohandler().utctime(d)).day
    if maxDays == 0 then
        maxDays = 31
    end
    d.day = tonumber(self.parts[self.day])
    if d.day > maxDays then
        return nil
    else
        return d
    end
end

function DialogItemEditDate:canDismiss()
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

DialogItemEditTime = class {
    _super = DialogItemEdit,
}

function DialogItemEditTime:init(lineHeight)
    -- Skip DialogItemEdit:init()
    View.init(self, lineHeight)
end

function DialogItemEditTime:contentSize()
    return gTWIDTH("@@@@@@@@@@") + 2 * kEditTextSpace, self.heightHint
end

function DialogItemEditTime:draw()
    local timeFlags = self.timeFlags & ~KDTimeNoHours -- This flag is such gibberish I'm not supporting it.
    local str
    if timeFlags & KDTimeDuration > 0 then
        local hours = self.value // 3600
        local mins = (self.value - (hours * 3600)) // 60
        local secs = self.value - (hours * 3600) - (mins * 60)
        if timeFlags == KDTimeDurationWithSecs then
            str = string.format("%02d:%02d:%02d", hours, mins, secs)
        else
            str = string.format("%02d:%02d", hours, mins)
        end
    elseif timeFlags == KDTimeAbsNoSecs then
        str = os.date("!%I:%M %p", self.value)
    elseif timeFlags == KDTimeWithSeconds then
        str = os.date("!%I:%M:%S %p", self.value)
    elseif timeFlags == KDTime24Hour then
        str = os.date("!%H:%M", self.value)
    elseif timeFlags == KDTime24Hour | KDTimeWithSeconds then
        str = os.date("!%H:%M:%S", self.value)
    end
    self:drawValue(str)
    View.draw(self)
end

function DialogItemEditTime:updateVariable()
    if self.timeFlags & KDTimeWithSeconds == 0 then
        -- Make sure we remove any seconds (specifically if any were passed in, as hopefully the editor won't have
        -- introduced any if the KDTimeWithSeconds flag isn't set)
        self.value = (self.value // 60) * 60
    end
    self.variable(self.value)
end

DialogItemEditMulti = class { _super = DialogItemEdit }

function DialogItemEditMulti:contentSize()
    return gTWIDTH(string.rep("M", self.widthChars)) + 2 * kEditTextSpace, kDialogTightLineHeight * self.numLines
end

local function withoutNewline(line)
    return line:match("[^\x06\x07\x08]*")
end

function DialogItemEditMulti:getCursorPos()
    local pos = self.editor.cursorPos
    local line, col = self:charPosToLineColumn(pos)
    local lineInfo = self.lines[line]
    local textw = gTWIDTH(withoutNewline(lineInfo.text):sub(1, col - 1))
    local x = lineInfo.x + textw
    local y = lineInfo.y - 1
    return x, y
end

function DialogItemEditMulti:charPosToLineColumn(pos)
    -- Work out which line pos is in
    for i, line in ipairs(self.lines) do
        if pos < line.charPos + #line.text or self.lines[i + 1] == nil then
            -- It's on this line
            local textw = gTWIDTH(withoutNewline(line.text):sub(1, pos - line.charPos - 1))
            -- printf("charPosToLineColumn(%d) = %d, %d\n", pos, i, pos - line.charPos + 1)
            return i, pos - line.charPos + 1
        end
    end
end

function DialogItemEditMulti:posToCharPos(x, y)
    local tx = x - self.x - kEditTextSpace - self.promptWidth
    local ty = y - self.y - kDialogLineTextYOffset
    local lineNumber = math.min(math.max(1, 1 + (ty // kDialogTightLineHeight)), #self.lines)
    local lineInfo = self.lines[lineNumber]
    local line = withoutNewline(lineInfo.text)

    local result = 1
    while gTWIDTH(line:sub(1, result)) < tx do
        result = result + 1
        if result >= #line + 1 then
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
    local spaceWidth = gTWIDTH(" ")
    local function addWord(word)
        local wordWidth = gTWIDTH(word)
        local lineAndWordWidth = lineWidth + wordWidth
        if lineAndWordWidth <= maxWidth then
            -- Fits on current line
            addToLine(word, wordWidth)
        elseif wordWidth >= maxWidth * 3 / 4 then
            -- Uh oh the word on its own doesn't fit. Try to camelcase split it
            local w1, w2 = word:match("([A-Z][a-z]+)([A-Z][a-z]+)")
            if w1 then
                addToLine(w1, gTWIDTH(w1))
                newLine()
                addToLine(w2, gTWIDTH(w2))
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

function DialogItemEditMulti:drawValue(val)
    local x = self:drawPrompt()
    local texty = self.y + kDialogLineTextYOffset

    local boxWidth = math.min(self:contentSize(), self.w - x)
    local boxHeight = kDialogTightLineHeight * self.numLines
    lightGrey()
    gAT(x, texty - 2)
    gBOX(boxWidth, boxHeight + 3)
    black()
    gAT(x + 1, texty - 1)
    gFILL(boxWidth - 2, boxHeight + 1, KgModeClear)
    gAT(x + 1, texty)

    local lines = formatText(val, boxWidth - 2)
    self.lines = {}

    local charPos = 1
    for i, line in ipairs(lines) do
        local lineInfo = {
            text = line,
            charPos = charPos,
            x = x + kEditTextSpace,
            y = texty + (i-1) * kDialogTightLineHeight,
        }
        local printableChars = withoutNewline(lineInfo.text)
        drawText(printableChars, lineInfo.x, lineInfo.y)
        self.lines[i] = lineInfo

        charPos = charPos + #line
    end

    if self.editor:hasSelection() then
        local selStart, selEnd = self.editor:getSelectionRange()
        local startLine, startCol = self:charPosToLineColumn(selStart)
        local endLine, endCol = self:charPosToLineColumn(selEnd)
        for i = startLine, endLine do
            local line = self.lines[i]
            local printableChars = withoutNewline(line.text)
            local lineSelStart = (i == startLine) and startCol or 1
            local lineSelEnd = (i == endLine) and endCol or #printableChars
            local selOffset = gTWIDTH(printableChars:sub(1, lineSelStart - 1))
            local selWidth = gTWIDTH(printableChars:sub(lineSelStart, lineSelEnd))
            gAT(line.x + selOffset, line.y - 1)
            gFILL(selWidth, kDialogTightLineHeight, KgModeInvert)
        end
    end

    self:updateCursorIfFocussed()
end

function DialogItemEditMulti:handleKeyPress(k, modifiers)
    local anchor = nil
    if modifiers & KKmodShift ~= 0 then
        anchor = self.editor.anchor
    end
    if k == KKeyEnter and modifiers == 0 then
        self.editor:insert(KLineBreakStr)
        return true
    elseif k == KKeyUpArrow or k == KKeyDownArrow then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        local lineInfo = self.lines[line + (k == KKeyUpArrow and -1 or 1)]
        if lineInfo then
            self.editor:setCursorPos(lineInfo.charPos + col - 1, anchor)
        end
        return true
    elseif k == KKeyPageLeft then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        self.editor:setCursorPos(self.lines[line].charPos, anchor)
        return true
    elseif k == KKeyPageRight then
        local line, col = self:charPosToLineColumn(self.editor.cursorPos)
        self.editor:setCursorPos(self.lines[line].charPos + #withoutNewline(self.lines[line].text), anchor)
        return true
    else
        return DialogItemEdit.handleKeyPress(self, k, modifiers)
    end
end

function DialogItemEditMulti:updateVariable()
    local len = #self.editor.value
    self.addr:write(string.pack("<i4", len))
    local startOfData = self.addr + 4
    startOfData:write(self.editor.value)
end

DialogChoiceList = class {
    _super = View,
    choiceTextSpace = 3 -- Yep, really not the same as kEditTextSpace despite how similar the two look
}

local kChoiceArrowSpace = 2
local kChoiceArrowSize = 12 + kChoiceArrowSpace

function DialogChoiceList:init(lineHeight)
    DialogChoiceList._super.init(self, lineHeight)
end

function DialogChoiceList:getChoicesWidth()
    local maxWidth = 0
    for _, choice in ipairs(self.choices) do
        maxWidth = math.max(gTWIDTH(choice), maxWidth)
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
    if k == KKeyLeftArrow then
        self:setIndex(wrapIndex(self.index - 1, #self.choices))
        return true
    elseif k == KKeyRightArrow then
        self:setIndex(wrapIndex(self.index + 1, #self.choices))
        return true
    elseif k == KKeyTab then
        self:displayPopupMenu()
        return true
    elseif k >= string.byte("a") and k <= string.byte("z") then
        local ch = string.char(k)
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
        return true
    else
        print("Unhandled key", k)
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
        popupItems[i] = { text = choice }
    end
    local result = mPOPUPEx(gORIGINX() + self.x + self.promptWidth, gORIGINY() + self.y, KMPopupPosTopLeft, popupItems, self.index)
    if result > 0 then
        self:setIndex(result)
    end
end

function DialogChoiceList:setIndex(index)
    self.index = index
    self:setNeedsRedraw()
end

function DialogChoiceList:updateVariable()
    self.variable(self.index)
end

DialogCheckbox = class {
    _super = DialogChoiceList,
    choiceFont = KFontEiksym15,
    choiceTextSpace = 1,
}

function DialogCheckbox:init(lineHeight)
    DialogCheckbox._super.init(self, lineHeight)
    self.choices = { "", kTickMark }
    self.index = self.value == KFalse and 1 or 2
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
            view:onButtonPressed(self)
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
    local id = gCREATE(x, y, w, h, false, KgCreate256GrayMode | KgCreateHasShadow | 0x200)
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
            return nil
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

    return nil
end

function DialogWindow:onButtonPressed(button)
    for _, item in ipairs(self.items) do
        if not item:canDismiss() then
            return
        end
    end
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
    [dItemTypes.dEDITMULTI] = DialogItemEditMulti,
    [dItemTypes.dLONG] = DialogItemEditLong,
    [dItemTypes.dFLOAT] = DialogItemEditFloat,
    [dItemTypes.dXINPUT] = DialogItemEditPass,
    [dItemTypes.dDATE] = DialogItemEditDate,
    [dItemTypes.dTIME] = DialogItemEditTime,
}

function DIALOG(dialog)
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
        titleBar:init(lineHeight)
        local cw, ch = titleBar:contentSize()
        maxWidth = math.max(cw, maxWidth)
        h = h + ch + titleBarSpace
    end

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

    -- Now we have our window and prompt area sizes we can actually lay out the items

    gBOX(w, h)
    gAT(1, 1)
    gXBORDER(2, 0x94, w - 2, h - 2)

    local y = borderWidth
    if titleBar then
        local ch = titleBar:contentHeight()
        win:addSubview(titleBar, borderWidth, y, w - borderWidth * 2, ch)
        y = y + ch + titleBarSpace
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
