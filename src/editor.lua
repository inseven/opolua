-- Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

Editor = class {
    value = "",
    cursorPos = 1,
    anchor = 1,
    view = nil,
    movableCursor = true,
}

function Editor:setValue(newVal, newCursorPos)
    if newVal ~= self.value and self.view:canUpdate(newVal) then
        self.value = newVal
        if not self.movableCursor then
            newCursorPos = nil
        end
        self.cursorPos = newCursorPos or #newVal + 1
        self.anchor = self.cursorPos
        self.view:onEditorChanged(self)
    end
end

function Editor:getSelectionRange()
    return math.min(self.anchor, self.cursorPos), math.max(self.anchor, self.cursorPos) - 1
end

function Editor:getSelection()
    return self.value:sub(self:getSelectionRange())
end

function Editor:hasSelection()
    return self.anchor ~= self.cursorPos
end

function Editor:setCursorPos(pos, anchor)
    if not self.movableCursor then
        pos = #self.value + 1
        anchor = pos
    end
    if anchor == nil then
        anchor = pos
    end
    pos = math.max(1, math.min(#self.value + 1, pos))
    anchor = math.max(1, math.min(#self.value + 1, anchor))
    if pos ~= self.cursorPos or anchor ~= self.anchor then
        self.cursorPos = pos
        self.anchor = anchor
        self.view:onEditorChanged(self)
    end
end

function Editor:handleKeyPress(k, modifiers)
    local handled = true
    local anchor = nil -- in rest of fn anchor being nil also means no shift modifier held down
    if modifiers & KKmodShift ~= 0 then
        anchor = self.anchor
    end
    local hasSelection = self:hasSelection()
    -- For simplicity's sake, we will accept either 16-bit or 32-bit event keycodes here
    if k == KKeyDel then -- backspace
        local from, to
        if hasSelection then
            from, to = self:getSelectionRange()
        elseif modifiers & KKmodShift ~= 0 then
            -- Shift-backspace is forward delete in Psion land
            if self.cursorPos < #self.value + 1 then
                from = self.cursorPos
                to = from
            end
        else
            if self.cursorPos > 1 then
                from = self.cursorPos - 1
                to = from
            end
        end
        if from and to then
            self:setValue(self.value:sub(1, from - 1) .. self.value:sub(to + 1), from)
        end
    elseif k >= 0x20 and k <= 0xFF then
        self:insert(string.char(k))
    elseif k == KTabCharacter then
        -- We're not going to implement the entire tab stop logic but we can at least allow the character
        self:insert(string.char(k))
    elseif k == KKeyLeftArrow or k == KKeyLeftArrow32 then
        if hasSelection and not anchor then
            self:setCursorPos(math.min(self.anchor, self.cursorPos))
        else
            self:setCursorPos(self.cursorPos - 1, anchor)
        end
    elseif k == KKeyRightArrow or k == KKeyRightArrow32 then
        if hasSelection and not anchor then
            self:setCursorPos(math.max(self.anchor, self.cursorPos))
        else
            self:setCursorPos(self.cursorPos + 1, anchor)
        end
    elseif k == KKeyPageLeft or k == KKeyPageLeft32 then
        -- Yes this really is what the home key is called in const.oph...
        self:setCursorPos(1, anchor)
    elseif k == KKeyPageRight or k == KKeyPageRight32 then
        -- Ditto...
        self:setCursorPos(#self.value + 1, anchor)
    else
        -- print("TODO Editor:handleKeyPress", k, modifiers)
        handled = false
    end
    return handled
end

function Editor:insert(ch)
    local selStart, selEnd = self:getSelectionRange()
    self:setValue(self.value:sub(1, selStart - 1) .. ch .. self.value:sub(selEnd + 1), selStart + #ch)

end

return _ENV
