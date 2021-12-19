--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

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

local string_byte, string_rep, string_sub = string.byte, string.rep, string.sub

function parseMbmHeader(data)
    local uid1, uid2, uid3, checksum, trailerOffset = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore, "Bad uid1 in MBM file!")
    assert(uid2 == KUidMultiBitmapFileImage, "Bad uid2 in MBM file!")

    local numBitmaps, pos = string.unpack("<I4", data, 1 + trailerOffset)
    local bitmaps = {}
    for i = 1, numBitmaps do
        local headerOffset = string.unpack("<I4", data, 1 + trailerOffset + 4 + (i-1) * 4)
        -- print(headerOffset)
        local len, headerLen, x, y, twipsx, twipsy, bpp, col, paletteSz, compression, pos =
            string.unpack("<I4I4I4I4I4I4I4I4I4I4", data, 1 + headerOffset)

        local bytesPerPixel = bpp / 8
        local bytesPerWidth = math.ceil(x * bytesPerPixel)
        local stride = (bytesPerWidth + 3) & ~3
        local bitmap = {
            width = x,
            height = y,
            bpp = bpp,
            color = col,
            stride = stride,
            -- not worrying about palettes yet
            compression = compression,
            imgStart = headerOffset + headerLen,
            imgLen = len - headerLen,
        }
        table.insert(bitmaps, bitmap)
    end
    return bitmaps
end

function decodeBitmap(bitmap, data)
    local imgData
    local pos = 1 + bitmap.imgStart
    local len = bitmap.imgLen
    if bitmap.compression == 0 then
        return data:sub(pos, pos + len)
    elseif bitmap.compression == 1 then
        imgData = rle8decode(data, pos, len)
    else
        error("Unknown compression scheme!")
    end
    return imgData
end

function rle8decode(data, pos, len)
    local bytes = {}
    local i = 1
    local endPos = pos + len
    while pos+1 <= endPos do
        local b = string_byte(data, pos)
        if b < 0x80 then
            -- b+1 repeats of byte pos+1
            bytes[i] = string_rep(string_sub(data, pos + 1, pos + 1), b + 1)
            pos = pos + 2
        else
            -- 256-b bytes of raw data follow
            local n = 256 - b
            bytes[i] = string_sub(data, pos + 1, pos + n)
            pos = pos + 1 + n
        end
        i = i + 1
    end
    local result = table.concat(bytes)
    return result
end

function getBitmap(data, index)
    local bitmap = parseMbmHeader(data)[index]
    local imgData = decodeBitmap(bitmap, data)
    return bitmap.width, bitmap.height, imgData
end

return _ENV
