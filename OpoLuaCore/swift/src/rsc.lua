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

function parseRsc(data)
    local result = {}
    local tocOffset, len = string.unpack("<I2I2", data)
    local endBytes = string.unpack("<I2", data, #data - 1)
    assert(tocOffset == endBytes, "Data is not a ER5 resource file!")
    local tocEnd = tocOffset + len
    local i = 1
    while tocOffset < tocEnd - 2 do
        local offset, next = string.unpack("<I2I2", data, 1 + tocOffset)
        -- print(offset, next)
        local val = string.sub(data, 1 + offset, next)
        result[i] = val
        i = i + 1
        tocOffset = tocOffset + 2
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
