--[[

Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe

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
local string_pack, string_packsize, string_unpack = string.pack, string.packsize, string.unpack

Bitmap = class {
    -- See parseSEpocBitmapHeader for members
}

function Bitmap:getImageData(expandToBitDepth)
    local imgData = decodeBitmap(self, self.data)
    if expandToBitDepth == 8 then
        local stride = self.stride
        if self.bpp < 8 then
            -- Widening the data also widens the stride
            stride = (stride * 8) // self.bpp
        end
        local wdata = widenTo8bpp(imgData, self.bpp)
        local rowWidth = self.width -- since it's now 8bpp
        -- Return the data without padding
        local trimmed = {}
        for y = 0, self.height - 1 do
            local row = wdata:sub(1 + y * stride, y * stride + rowWidth)
            trimmed[1 + y] = row
        end
        imgData = table.concat(trimmed)
    elseif expandToBitDepth then
        error("expandToBitDepth depth not supported yet")
    end
    return imgData
end

function parseMbmHeader(data)
    local uid1, pos = string_unpack("<I4", data)
    if uid1 == KMultiBitmapRomImageUid then
        local numBitmaps, tocPos = string_unpack("<I4", data, pos)
        local bitmaps = {}
        for i = 1, numBitmaps do
            local offset = string_unpack("<I4", data, tocPos + (i-1) * 4)
            local bitmap = parseRomBitmap(data, offset)
            table.insert(bitmaps, bitmap)
        end
        return bitmaps
    end

    local uid2, uid3, checksum, trailerOffset = string_unpack("<I4I4I4I4", data, pos)
    assert(uid1 == KUidDirectFileStore, "Bad uid1 in MBM file!")
    -- UID2 should be KUidMultiBitmapFileImage, and usually is, but of course
    -- there are some otherwise-valid MBMs out there where it isn't (and is eg
    -- KUidExternalOplFile)
    -- assert(uid2 == KUidMultiBitmapFileImage, "Bad uid2 in MBM file!")

    local numBitmaps, pos = string_unpack("<I4", data, 1 + trailerOffset)
    local bitmaps = {}
    for i = 1, numBitmaps do
        local headerOffset = string_unpack("<I4", data, 1 + trailerOffset + 4 + (i-1) * 4)
        local bitmap = parseBitmap(data, headerOffset)
        table.insert(bitmaps, bitmap)
    end
    return bitmaps
end

local function parseSEpocBitmapHeader(data, offset)
    local len, headerLen, x, y, twipsx, twipsy, bpp, col, paletteSz, compression, pos =
        string_unpack("<I4I4I4I4I4I4I4I4I4I4", data, 1 + offset)
    local bytesPerPixel = bpp / 8
    local bytesPerWidth = math.ceil(x * bytesPerPixel)
    local stride = (bytesPerWidth + 3) & ~3
    return Bitmap {
        data = data,
        len = len,
        headerLen = headerLen,
        width = x,
        height = y,
        bpp = bpp,
        isColor = col == 1,
        drawableMode = bppColorToMode(bpp, col == 1),
        stride = stride,
        -- not worrying about palettes yet
        paletteSz = paletteSz,
        compression = compression,
        imgLen = len - headerLen,
    }, pos
end

function parseBitmap(data, headerOffset)
    local bitmap = parseSEpocBitmapHeader(data, headerOffset)
    bitmap.imgStart = headerOffset + bitmap.headerLen
    return bitmap
end

function parseRomBitmap(data, offset)
    -- class Bitmap
    local uid, displayMode, heap, pile, byteWidth, pos = string_unpack("<I4I4I4I4I4", data, 1 + offset)
    -- struct SEpocBitmapHeader
    local bitmap, pos = parseSEpocBitmapHeader(data, pos - 1)
    local chunk, dataOffset, pos = string_unpack("<I4I4", data, pos)
    assert(dataOffset == pos - (1+offset))
    bitmap.imgStart = pos - 1
    return bitmap
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

local function scale2bpp(val)
    return val | (val << 2) | (val << 4) | (val << 6)
end

function widenTo8bpp(data, bpp)
    local len = #data
    if bpp == 4 then
        local pos = 1
        local bytes = {}
        while pos <= len do
            local b = string_unpack("B", data, pos)
            bytes[pos] = string_pack("BB", ((b & 0xF) << 4) | (b & 0xF), (b & 0xF0) | (b >> 4))
            pos = pos + 1
        end
        return table.concat(bytes)
    elseif bpp == 2 then
        local pos = 1
        local bytes = {}
        while pos <= len do
            local b = string_unpack("B", data, pos)
            bytes[pos] = string_pack("BBBB",
                scale2bpp(b & 0x3),
                scale2bpp((b & 0xC) >> 2),
                scale2bpp((b & 0x30) >> 4),
                scale2bpp((b & 0xC0) >> 6)
            )
            pos = pos + 1
        end
        return table.concat(bytes)
    else
        return data
    end
end

return _ENV
