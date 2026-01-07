--[[

Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe

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

--[[
We make some assumptions about valid file structure because resource files have very little metadata so we need to be
stricter in order to weed out false positives (particularly for the recognizer). In addition to minimum required of the
format, we also assume:

* The TOC is at the end of the file.
* Resources start immediately after the header, ie at offset 4.
* The TOC is ordered by resource offset.
* There are no gaps between resources, ie each resource's 'next' offset is a TOC entry (except the last one).
]]
function parseRsc(data)
    local result = {}
    local tocOffset, len = string.unpack("<I2I2", data)
    assert(tocOffset >= 4, "Bad tocOffset")
    assert(tocOffset + len == #data, "Truncated TOC!")
    local tocEnd = tocOffset + len
    local i = 1
    local tocStart = tocOffset
    local expectedOffset = 4
    while tocOffset < tocEnd - 2 do
        local offset, next = string.unpack("<I2I2", data, 1 + tocOffset)
        assert(offset == expectedOffset, "Unexpected offset!")
        assert(next >= offset and next <= tocStart, "Unexpected resource end!")
        -- printf("%04X %04X\n", offset, next)
        local val = string.sub(data, 1 + offset, next)
        result[i] = val
        i = i + 1
        tocOffset = tocOffset + 2
        expectedOffset = next
    end
    local first = result[1]
    if first and #first == 8 then
        local len, id = string.unpack("<I4I4", first)
        if len == 4 then
            result.idOffset = id
        end
    end
    return result
end

return _ENV
