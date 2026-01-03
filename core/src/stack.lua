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

-- Our stack isn't even close to byte-for-byte identical to the standard impl so
-- there's no real point perfectly replicating the sizes. Impose an arbitrary
-- limit of 2048 items (probably close to to 4096 byte limit on the Psion 5
-- given most stack items are 2-byte aligned).
kMaxStackSize = 2048

Stack = class {}

function Stack:push(val)
    if type(val) == "boolean" then
        -- As a convenience allow this and map to how it's expected to be represented
        if val then
            val = KTrue
        else
            val = KFalse
        end
    elseif val == nil then
        error("Can't push a nil val!")
    end
    assert(self.n < kMaxStackSize, "Stack has too many items!")
    self.n = self.n + 1
    self[self.n] = val
    -- printf("Stack push %s n=%d\n", val, self.n)
end

function Stack:pop(num)
    if num == nil or num == 1 then
        assert(self.n > 0, "Attempt to pop empty stack!")
        local result = self[self.n]
        self[self.n] = nil
        self.n = self.n - 1
        -- printf("Stack pop %s n=%d\n", result, self.n)
        return result
    else
        local results = {}
        for i = 0, num - 1 do
            results[num - i] = self:pop()
        end
        return table.unpack(results, 1, num)
    end
end

function Stack:popXY()
    return self:pop(2)
end

function Stack:popRect()
    -- returns x, y, w, h
    return self:pop(4)
end

function Stack:getSize()
    return self.n
end

function Stack:popTo(sz)
    assert(sz <= self.n, "Cannot increase stack size in popTo")
    while self.n > sz do
        self:pop()
    end
end

function Stack:remove(idx)
    assert(idx > 0 and idx <= self.n, "Bad index to Stack:remove()")
    self.n = self.n - 1
    return table.remove(self, idx)
end

function newStack()
    return Stack { n = 0 }
end

return _ENV
