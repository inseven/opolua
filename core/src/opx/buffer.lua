-- Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

fns = {
    [1] = "BufferCopy",
    [2] = "BufferFill",
    [3] = "BufferAsString",
    [4] = "BufferFromString",
    [5] = "BufferMatch",
    [6] = "BufferFind",
    [7] = "BufferLocate",
    [8] = "BufferLocateReverse",
}


-- BufferCopy:(aTargetBuffer&, aSourceBuffer&, aLength&)
function BufferCopy(stack, runtime)
    local len = stack:pop()
    local src = runtime:addrFromInt(stack:pop())
    local dest = runtime:addrFromInt(stack:pop())
    dest:write(src:read(len))
    stack:push(0)
end

-- BufferFill:(aBuffer&, aLength&, aChar%)
function BufferFill(stack, runtime)
    local ch = stack:pop()
    local len = stack:pop()
    local buf = runtime:addrFromInt(stack:pop())
    -- We don't expose a memset/fill primitive so just generate the data
    local data = string.rep(string.char(ch), len)
    buf:write(data)
    stack:push(0)
end

-- BufferAsString$:(aSourceBuffer&, aLength&)
function BufferAsString(stack, runtime)
    local len = stack:pop()
    local src = runtime:addrFromInt(stack:pop())
    local data = src:read(len)
    stack:push(data)
end

-- BufferFromString&:(aTargetBuffer&, aLength&, aSource$)
function BufferFromString(stack, runtime)
    -- Weirdly named, this copies a string into a buffer
    local str = stack:pop() -- string
    local len = stack:pop()
    local dest = runtime:addrFromInt(stack:pop())

    -- This looks like it was a USER 11 panic in the original impl
    assert(#str <= len, "BufferFromString attempt to copy too large a string")

    dest:write(str)
    stack:push(#str)
end

-- BufferMatch&:(aBuffer&, aLength&, aPattern$, aFoldMode&)
function BufferMatch(stack, runtime)
    local foldMode = stack:pop()
    local pattern = stack:pop()
    local len = stack:pop()
    local buf = runtime:addrFromInt(stack:pop())

    unimplemented("opx.buffer.BufferMatch")
end

-- BufferFind&:(aBuffer&, aLength&, aString$, aFoldMode&)
function BufferFind(stack, runtime)
    unimplemented("opx.buffer.BufferFind")
end

-- BufferLocate&:(aBuffer&, aLength&, aChar%, aFoldMode&)
function BufferLocate(stack, runtime)
    unimplemented("opx.buffer.BufferLocate")
end

-- BufferLocateReverse&:(aBuffer&, aLength&, aChar%, aFoldMode&)
function BufferLocateReverse(stack, runtime)
    unimplemented("opx.buffer.BufferLocateReverse")
end

return _ENV
