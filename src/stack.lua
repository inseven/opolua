_ENV = module()

-- Our stack isn't even close to byte-for-byte identical to the standard impl so
-- there's no real point perfectly replicating the sizes. Impose an arbitrary
-- limit of 2048 items (probably close to to 4096 byte limit on the Psion 5
-- given most stack items are 2-byte aligned).
kMaxStackSize = 2048

Stack = {}
Stack.__index = Stack

function Stack:push(val)
    if type(val) == "boolean" then
        -- As a convenience allow this and map to how it's expected to be represented
        if val then
            val = -1
        else
            val = 0
        end
    end
    assert(self.n < kMaxStackSize, "Stack has too many items!")
    self.n = self.n + 1
    self[self.n] = val
end

function Stack:pop()
    assert(self.n > 0, "Attempt to pop empty stack!")
    local result = self[self.n]
    self[self.n] = nil
    self.n = self.n - 1
    return result
end

function Stack:popString()
    local result = self:pop()
    assert(type(result) == "string", "popString on non-string value!")
    return result
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
    return setmetatable({ n = 0 }, Stack)
end

return _ENV
