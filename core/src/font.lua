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

-- Based on https://www.davros.org/psion/psionics/font.fmt

_ENV = module()

MagicFont = "FON\xE300"
MagicFast = "FNI\xC5\x10\x10"

local function bit(data, idx)
    local byteIdx = idx // 8
    local bitIdx = idx - (byteIdx * 8)
    -- local bitIdx = 7 - (idx - (byteIdx * 8))
    if byteIdx >= #data then
        error(string.format("bit %d is out of range in data len=%d", idx, #data))
    end
    local byte = string.byte(data, 1 + byteIdx)
    return (byte & (1 << bitIdx)) ~= 0
end

function parseFont(data)
    local magic, chk, sz, lo, hi, height, descent, ascent, width, maxWidth, flags, pos =
        string.unpack("<c6HHHHHHHHHH", data)

    local fast = magic == MagicFast
    assert((magic == MagicFont) or fast, "Bad font header")
    -- printf("chk=0x%04X sz=%d lo=%d hi=%d height=%d descent=%d ascent=%d width=%d maxWidth=%d flags=0x%04X pos=%d\n",
    --     chk, sz, lo, hi, height, descent, ascent, width, maxWidth, flags, pos)

    local name = string.unpack("c16", data, 1 + 0x1A):match("^(.-) *$")
    -- printf("%q\n", name)

    -- local offsetTableSize = string.unpack("<H", data, 1 + 0x2A)

    local widths = {}
    for i = 0, lo - 1 do
        -- Fill in widths outside of the font definition
        widths[1 + i] = 0
    end
    local offsetTableStart = 1 + 0x3E
    local pos = offsetTableStart
    local charStarts = {}
    local stride
    if fast then
        for i = 0, 255 do
            widths[1 + i] = string.byte(data, pos + i)
        end
    else
        for i = lo, hi do
            local offset, nextOffset = string.unpack("<HH", data, pos)
            pos = pos + 2
            -- printf("Char %d offset = 0x%X width = %d\n", i, offset // 2, (nextOffset - offset) // 2)

            if (offset & 1) ~= 0 then
                widths[1 + i] = 0
            else
                widths[1 + i] = (nextOffset - offset) // 2
                charStarts[i] = offset // 2
            end
            if i == hi then
                -- printf("Last offset = 0x%X\n", nextOffset // 2)
                -- The stride rounds up to 16 bits
                stride = ((nextOffset // 2) + 0xF) & ~0xF
            end
        end
        for i = hi + 1, 255 do
            widths[1 + i] = 0
        end
    end
    assert(#widths == 256)

    local function echofont(str)
        -- io.stdout:write(str)
    end

    if fast then
        local dataStart = 0x13F
        error"TODO"
    else
        local dataStart = offsetTableStart + 4 + (hi - lo) * 2
        assert(dataStart == pos + 2)

        -- The characters are laid out as if it's a bit-indexed bitmap of width (in bits) equal to 'stride', and height
        -- (in bits, rounded up to the nearest byte) equal to the font height, with all the chars laid out in one long
        -- row.

        -- printf("DataStart = 0x%X stride = 0x%X\n", dataStart - 1, stride)
        local charData = data:sub(dataStart)

        local bmpDataArr = {}
        for chy = 0, 7 do
            for line = 0, height - 1 do
                for chx = 0, 31 do
                    local chIdx = chy * 32 + chx
                    local charStart = charStarts[chIdx]
                    if charStart == nil then
                        table.insert(bmpDataArr, string.rep('\xFF', maxWidth))
                        echofont(string.rep("-", maxWidth))
                    else
                        local chw = widths[1 + chIdx]
                        for i = 0, chw - 1 do
                            local b = bit(charData, charStart + stride * line + i)
                            -- echofont(b and "X" or ".")
                            echofont(b and "\u{2588}" or ".")
                            table.insert(bmpDataArr, b and '\x00' or '\xFF')
                        end

                        if chw < maxWidth then
                            -- Pad the image if necessary
                            table.insert(bmpDataArr, string.rep('\xFF', maxWidth - chw))
                            echofont(string.rep(" ", maxWidth - chw))
                        end
                    end
                    echofont(" ") -- DEBUG
                end
                echofont("\n") -- DEBUG
            end
            echofont("\n") -- DEBUG
        end

        local bmpData = table.concat(bmpDataArr)
        assert(#bmpData, 256 * maxWidth * height)

        local mbm = require("mbm")
        local bitmapw = 32 * maxWidth
        local bitmap = mbm.Bitmap {
            data = bmpData,
            len = #bmpData,
            width = bitmapw,
            height = 8 * height,
            bpp = 8,
            -- isColor = false,
            mode = KColorgCreate256GrayMode,
            stride = bitmapw,
            paletteSz = 0,
            compression = mbm.ENoBitmapCompression,
            imgStart = 0,
            imgLen = #bmpData
        }
        local metrics = {
            name = name,
            charh = height,
            ascent = height - descent,
            maxwidth = maxWidth,
            encoding = "IBM 850",
            firstch = 0,
            widths = widths,
        }
        return metrics, bitmap
    end
end

return _ENV
