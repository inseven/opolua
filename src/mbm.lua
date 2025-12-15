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

-- These are stored as 0x00RRGGBB
local kEpoc4bitPalette = {
    0x000000, -- 0 Black
    0x555555, -- 1 Dark grey
    0x800000, -- 2 Dark red
    0x808000, -- 3 Dark yellow
    0x008000, -- 4 Dark green
    0xFF0000, -- 5 Red
    0xFFFF00, -- 6 Yellow
    0x00FF00, -- 7 Green
    0xFF00FF, -- 8 Magenta
    0x0000FF, -- 9 Blue
    0x00FFFF, -- A Cyan
    0x800080, -- B Dark magenta
    0x000080, -- C Dark blue
    0x008080, -- D Dark cyan
    0xAAAAAA, -- E Light grey
    0xFFFFFF, -- F White
}

-- These are stored as 0x00RRGGBB
local kEpoc8bitPalette = {
    0x000000, -- 00
    0x330000, -- 01
    0x660000, -- 02
    0x990000, -- 03
    0xCC0000, -- 04
    0xFF0000, -- 05
    0x003300, -- 06
    0x333300, -- 07
    0x663300, -- 08
    0x993300, -- 09
    0xCC3300, -- 0A
    0xFF3300, -- 0B
    0x006600, -- 0C
    0x336600, -- 0D
    0x666600, -- 0E
    0x996600, -- 0F
    0xCC6600, -- 10
    0xFF6600, -- 11
    0x009900, -- 12
    0x339900, -- 13
    0x669900, -- 14
    0x999900, -- 15
    0xCC9900, -- 16
    0xFF9900, -- 17
    0x00CC00, -- 18
    0x33CC00, -- 19
    0x66CC00, -- 1A
    0x99CC00, -- 1B
    0xCCCC00, -- 1C
    0xFFCC00, -- 1D
    0x00FF00, -- 1E
    0x33FF00, -- 1F
    0x66FF00, -- 20
    0x99FF00, -- 21
    0xCCFF00, -- 22
    0xFFFF00, -- 23
    0x000033, -- 24
    0x330033, -- 25
    0x660033, -- 26
    0x990033, -- 27
    0xCC0033, -- 28
    0xFF0033, -- 29
    0x003333, -- 2A
    0x333333, -- 2B
    0x663333, -- 2C
    0x993333, -- 2D
    0xCC3333, -- 2E
    0xFF3333, -- 2F
    0x006633, -- 30
    0x336633, -- 31
    0x666633, -- 32
    0x996633, -- 33
    0xCC6633, -- 34
    0xFF6633, -- 35
    0x009933, -- 36
    0x339933, -- 37
    0x669933, -- 38
    0x999933, -- 39
    0xCC9933, -- 3A
    0xFF9933, -- 3B
    0x00CC33, -- 3C
    0x33CC33, -- 3D
    0x66CC33, -- 3E
    0x99CC33, -- 3F
    0xCCCC33, -- 40
    0xFFCC33, -- 41
    0x00FF33, -- 42
    0x33FF33, -- 43
    0x66FF33, -- 44
    0x99FF33, -- 45
    0xCCFF33, -- 46
    0xFFFF33, -- 47
    0x000066, -- 48
    0x330066, -- 49
    0x660066, -- 4A
    0x990066, -- 4B
    0xCC0066, -- 4C
    0xFF0066, -- 4D
    0x003366, -- 4E
    0x333366, -- 4F
    0x663366, -- 50
    0x993366, -- 51
    0xCC3366, -- 52
    0xFF3366, -- 53
    0x006666, -- 54
    0x336666, -- 55
    0x666666, -- 56
    0x996666, -- 57
    0xCC6666, -- 58
    0xFF6666, -- 59
    0x009966, -- 5A
    0x339966, -- 5B
    0x669966, -- 5C
    0x999966, -- 5D
    0xCC9966, -- 5E
    0xFF9966, -- 5F
    0x00CC66, -- 60
    0x33CC66, -- 61
    0x66CC66, -- 62
    0x99CC66, -- 63
    0xCCCC66, -- 64
    0xFFCC66, -- 65
    0x00FF66, -- 66
    0x33FF66, -- 67
    0x66FF66, -- 68
    0x99FF66, -- 69
    0xCCFF66, -- 6A
    0xFFFF66, -- 6B
    0x111111, -- 6C
    0x222222, -- 6D
    0x444444, -- 6E
    0x555555, -- 6F
    0x777777, -- 70
    0x110000, -- 71
    0x220000, -- 72
    0x440000, -- 73
    0x550000, -- 74
    0x770000, -- 75
    0x001100, -- 76
    0x002200, -- 77
    0x004400, -- 78
    0x005500, -- 79
    0x007700, -- 7A
    0x000011, -- 7B
    0x000022, -- 7C
    0x000044, -- 7D
    0x000055, -- 7E
    0x000077, -- 7F
    0x000088, -- 80
    0x0000AA, -- 81
    0x0000BB, -- 82
    0x0000DD, -- 83
    0x0000EE, -- 84
    0x008800, -- 85
    0x00AA00, -- 86
    0x00BB00, -- 87
    0x00DD00, -- 88
    0x00EE00, -- 89
    0x880000, -- 8A
    0xAA0000, -- 8B
    0xBB0000, -- 8C
    0xDD0000, -- 8D
    0xEE0000, -- 8E
    0x888888, -- 8F
    0xAAAAAA, -- 90
    0xBBBBBB, -- 91
    0xDDDDDD, -- 92
    0xEEEEEE, -- 93
    0x000099, -- 94
    0x330099, -- 95
    0x660099, -- 96
    0x990099, -- 97
    0xCC0099, -- 98
    0xFF0099, -- 99
    0x003399, -- 9A
    0x333399, -- 9B
    0x663399, -- 9C
    0x993399, -- 9D
    0xCC3399, -- 9E
    0xFF3399, -- 9F
    0x006699, -- A0
    0x336699, -- A1
    0x666699, -- A2
    0x996699, -- A3
    0xCC6699, -- A4
    0xFF6699, -- A5
    0x009999, -- A6
    0x339999, -- A7
    0x669999, -- A8
    0x999999, -- A9
    0xCC9999, -- AA
    0xFF9999, -- AB
    0x00CC99, -- AC
    0x33CC99, -- AD
    0x66CC99, -- AE
    0x99CC99, -- AF
    0xCCCC99, -- B0
    0xFFCC99, -- B1
    0x00FF99, -- B2
    0x33FF99, -- B3
    0x66FF99, -- B4
    0x99FF99, -- B5
    0xCCFF99, -- B6
    0xFFFF99, -- B7
    0x0000CC, -- B8
    0x3300CC, -- B9
    0x6600CC, -- BA
    0x9900CC, -- BB
    0xCC00CC, -- BC
    0xFF00CC, -- BD
    0x0033CC, -- BE
    0x3333CC, -- BF
    0x6633CC, -- C0
    0x9933CC, -- C1
    0xCC33CC, -- C2
    0xFF33CC, -- C3
    0x0066CC, -- C4
    0x3366CC, -- C5
    0x6666CC, -- C6
    0x9966CC, -- C7
    0xCC66CC, -- C8
    0xFF66CC, -- C9
    0x0099CC, -- CA
    0x3399CC, -- CB
    0x6699CC, -- CC
    0x9999CC, -- CD
    0xCC99CC, -- CE
    0xFF99CC, -- CF
    0x00CCCC, -- D0
    0x33CCCC, -- D1
    0x66CCCC, -- D2
    0x99CCCC, -- D3
    0xCCCCCC, -- D4
    0xFFCCCC, -- D5
    0x00FFCC, -- D6
    0x33FFCC, -- D7
    0x66FFCC, -- D8
    0x99FFCC, -- D9
    0xCCFFCC, -- DA
    0xFFFFCC, -- DB
    0x0000FF, -- DC
    0x3300FF, -- DD
    0x6600FF, -- DE
    0x9900FF, -- DF
    0xCC00FF, -- E0
    0xFF00FF, -- E1
    0x0033FF, -- E2
    0x3333FF, -- E3
    0x6633FF, -- E4
    0x9933FF, -- E5
    0xCC33FF, -- E6
    0xFF33FF, -- E7
    0x0066FF, -- E8
    0x3366FF, -- E9
    0x6666FF, -- EA
    0x9966FF, -- EB
    0xCC66FF, -- EC
    0xFF66FF, -- ED
    0x0099FF, -- EE
    0x3399FF, -- EF
    0x6699FF, -- F0
    0x9999FF, -- F1
    0xCC99FF, -- F2
    0xFF99FF, -- F3
    0x00CCFF, -- F4
    0x33CCFF, -- F5
    0x66CCFF, -- F6
    0x99CCFF, -- F7
    0xCCCCFF, -- F8
    0xFFCCFF, -- F9
    0x00FFFF, -- FA
    0x33FFFF, -- FB
    0x66FFFF, -- FC
    0x99FFFF, -- FD
    0xCCFFFF, -- FE
    0xFFFFFF, -- FF
}

local string_byte, string_char, string_rep, string_sub = string.byte, string.char, string.rep, string.sub
local string_pack, string_packsize, string_unpack = string.pack, string.packsize, string.unpack
local table_insert = table.insert

local ENoBitmapCompression = 0
local EByteRLECompression = 1
local ETwelveBitRLECompression = 2
local ESixteenBitRLECompression = 3
local ETwentyFourBitRLECompression = 4

local GrayBppToMode = {
    [1] = KColorgCreate2GrayMode,
    [2] = KColorgCreate4GrayMode,
    [4] = KColorgCreate16GrayMode,
    [8] = KColorgCreate256GrayMode,
}

local ColorBppToMode = {
    [4] = KColorgCreate16ColorMode,
    [8] = KColorgCreate256ColorMode,
    [12] = KColorgCreate4KColorMode,
    [16] = KColorgCreate64KColorMode,
    [24] = KColorgCreate16MColorMode,
    [32] = KColorgCreateRGBColorMode,
}

function bppColorToMode(bpp, color)
    local result = (color and ColorBppToMode or GrayBppToMode)[bpp]
    if not result then
        error(string.format("Invalid bpp=%d color=%s combination", bpp, color))
    end
    return result
end

Bitmap = class {
    -- See parseSEpocBitmapHeader for members
}

local function roundUp(val, alignment)
    if not alignment or alignment <= 1 then
        return val
    end
    return (val + (alignment - 1)) & ~(alignment - 1)
end

local function byteWidth(pixelWidth, bpp)
    if bpp == 1 then
        return 4 * ((pixelWidth + 31) // 32)
    elseif bpp == 2 then
        return 4 * ((pixelWidth + 15) // 16)
    elseif bpp == 4 then
        return 4 * ((pixelWidth + 7) // 8)
    elseif bpp == 8 then
        return 4 * ((pixelWidth + 3) // 4)
    elseif bpp == 12 or bpp == 16 then
        return 4 * ((pixelWidth + 1) // 2)
    elseif bpp == 24 then
        return 4 * ((((pixelWidth * 3) + 11) // 12) * 3)
    elseif bpp == 32 then
        return 4 * ((pixelWidth + 15) // 16)
    else
        error("Bad bit depth!")
    end
end

function Bitmap:getImageData(expandToBitDepth, resultStride)
    local imgData = decodeBitmap(self)
    if expandToBitDepth == 8 then
        if resultStride == nil then
            resultStride = self.width
        end
        local stride = self.stride
        assert(self.bpp <= 8, "Cannot expand to a smaller bit depth")
        if self.bpp < 8 then
            -- Widening the data also widens the stride
            stride = (stride * 8) // self.bpp
        end
        local wdata = widenTo8bpp(imgData, self.bpp, self.isColor)
        local rowWidth = self.width -- since it's now 8bpp
        local rowPad = string.rep("\0", resultStride - rowWidth)
        local trimmed = {}
        for y = 0, self.height - 1 do
            local row = wdata:sub(1 + y * stride, y * stride + rowWidth)
            trimmed[1 + y] = row..rowPad
        end
        imgData = table.concat(trimmed)
        -- print(#imgData, resultStride, self.height, resultStride * self.height)
        assert(#imgData == resultStride * self.height, "getImageData did not return expected size")
    elseif expandToBitDepth == 24 or expandToBitDepth == 32 then
        local bytes
        if self.bpp == 12 or self.bpp == 16 or self.bpp == 24 then
            -- These are handled directly by getPixel() below
            bytes = imgData
        else
            -- First expand to 8bpp with no padding
            bytes = self:getImageData(8, nil)
        end
        local bytesPerPixel = expandToBitDepth // 8
        local alphaByte = (expandToBitDepth == 32) and '\xFF' or ''
        local rowPad = string.rep("\0", (resultStride or 0) - (self.width * bytesPerPixel))
        local color = self.isColor
        local function getPixel(x, y)
            if self.bpp == 12 then
                local pos = 1 + (y * self.stride + x * 2)
                -- Note the endianness is probably wrong here, but is balanced by returning r g and b in the wrong order
                -- at the end. Probably.
                local value = string.unpack(">I2", bytes, pos)
                local b = ((value >> 8) & 0xF) * 17
                local g = ((value >> 4) & 0xF) * 17
                local r = (value & 0xF) * 17
                return string_char(r & 0xFF, g & 0xFF, b & 0xFF)
            elseif self.bpp == 16 then
                local pos = 1 + (y * self.stride + x * 2)
                local value = string.unpack("<I2", bytes, pos)
                local r = (value & 0xF800) >> 8
                local g = (value & 0x7E0) >> 3
                local b = (value & 0x1f) << 3
                -- Adding an extra bit on to each value looks weird to me, but it's what
                -- https://github.com/SymbianSource/oss.API_REF.Public_API/blob/c8cfcfafc002d82a4e96f1197865cc7acf7f6fc3/epoc32/include/gdi.inl#L326
                -- did...
                return string_char(b + (b >> 5), g + (g >> 6), r + (r >> 5))..alphaByte
            elseif self.bpp == 24 then
                local pos = 1 + (y * self.stride + x * 3)
                return string_sub(bytes, pos, pos + 2)..alphaByte
            end
            local pos = 1 + (y * self.width + x)
            local b = string_byte(bytes, pos, pos)
            if color then
                if self.bpp == 8 then
                    return string_pack("<I3", kEpoc8bitPalette[1 + b])..alphaByte
                elseif self.bpp == 4 then
                    return string_pack("<I3", kEpoc4bitPalette[1 + b])..alphaByte
                else
                    error("Bad depth!")
                end
            else
                return string_char(b, b, b)..alphaByte
            end
        end
        local result = {}
        for y = 0, self.height - 1 do
            local row = {}
            for x = 0, self.width - 1 do
                row[1 + x] = getPixel(x, y)
            end
            row[1 + self.width] = rowPad
            result[1 + y] = table.concat(row)
        end
        return table.concat(result)
    elseif expandToBitDepth then
        error("expandToBitDepth depth not supported yet")
    end
    return imgData
end

function Bitmap:toNative()
    return {
        width = self.width,
        height = self.height,
        isColor = self.isColor,
        normalizedImgData = self:getImageData(self.isColor and 32 or 8)
    }
end

function parseMbmHeader(data)
    if data:sub(1, 4) == "PIC\xDC" then
        -- Series 3 .PIC file
        local formatVer, runtimeVer, numBitmaps, pos = string_unpack("<BBI2", data, 5)
        assert(formatVer == 0x30 and runtimeVer == 0x30, "Unexpected PIC version!")
        local bitmaps = {}
        for i = 1, numBitmaps do
            local crc, width, height, numBytes, offset, nextPos = string_unpack("<I2I2I2I2I4", data, pos)
            local dataOffset = (nextPos - 1) + offset
            -- Note, PICs round to 16-bit not 32 like 1bpp MBMs
            local stride = 2 * ((width + 15) // 16)
            local bmp = Bitmap {
                data = data,
                len = (nextPos + offset) - pos,
                width = width,
                height = height,
                bpp = 1,
                isColor = false,
                mode = KColorgCreate2GrayMode,
                stride = stride,
                paletteSz = 0,
                compression = ENoBitmapCompression,
                imgStart = dataOffset,
                imgLen = stride * height,
            }
            bitmaps[i] = bmp
            pos = nextPos
        end
        return bitmaps
    end

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
    -- KUidOplFile)
    -- assert(uid2 == KUidMultiBitmapFileImage, "Bad uid2 in MBM file!")

    -- printf("Uids: 0x%08X 0x%08X 0x%08X\n", uid1, uid2, uid3)

    local numBitmaps, pos = string_unpack("<I4", data, 1 + trailerOffset)
    local bitmaps = {}
    for i = 1, numBitmaps do
        local headerOffset
        headerOffset, pos = string_unpack("<I4", data, pos)
        local bitmap = parseBitmap(data, headerOffset)
        table.insert(bitmaps, bitmap)
    end
    return bitmaps
end

local ModeToBpp = {
    [KColorgCreate2GrayMode] = 1,
    [KColorgCreate4GrayMode] = 2,
    [KColorgCreate16GrayMode] = 4,
    [KColorgCreate256GrayMode] = 8,
    [KColorgCreate16ColorMode] = 4,
    [KColorgCreate256ColorMode] = 8,
    [KColorgCreate4KColorMode] = 12,
    [KColorgCreate64KColorMode] = 16,
    [KColorgCreate16MColorMode] = 24,
    [KColorgCreateRGBColorMode] = 32,
}

local SEpocBitmapHeader = "<I4I4I4I4I4I4I4I4I4I4"

function makeMbm(uid2, bitmaps)
    local parts = { n = 0 }
    local function add(data)
        table.insert(parts, data)
        parts.n = parts.n + #data
    end
    local function addf(fmt, ...)
        local data = string_pack(fmt, ...)
        add(data)
    end

    addf("<I4I4I4I4", require("crc").getUids(KUidDirectFileStore, uid2, 0))
    addf("<I4", 0) -- parts[2] = trailerOffset, will be replaced at end
    local bitmapOffsets = {}

    for i, bitmap in ipairs(bitmaps) do
        bitmapOffsets[i] = parts.n
        local headerLen = string_packsize(SEpocBitmapHeader)

        -- normalizedImgData is 8-bit for any greyscale mode, and 32-bit for any color
        -- with zero line padding
        local isColor = bitmap.mode >= KColorgCreate16ColorMode
        local bpp = ModeToBpp[bitmap.mode]
        local stride = byteWidth(bitmap.width, bpp)
        local pixels = {}
        local compression = ENoBitmapCompression
        local function copyPixels832()
            local pixelSz = (bpp // 8)
            local padSz = stride - (pixelSz * bitmap.width)
            assert(padSz >= 0)
            local pad = string_rep("\0", padSz)
            for i = 0, bitmap.width - 1 do
                pixels[i + 1] = bitmap.normalizedImgData:sub(1 + bitmap.width * i * pixelSz, bitmap.width * (i + 1) * pixelSz) .. pad
            end
        end
        local function copyPixelsPacked()
            local pixelsPerByte = 8 // bpp
            local rshift = 8 - bpp
            for y = 0, bitmap.height - 1 do
                local offset = bitmap.width * y
                local line = string_sub(bitmap.normalizedImgData, 1 + offset, offset + bitmap.width).."\0\0\0\0"
                local x = 0
                while x < bitmap.width do
                    local packedByte = 0
                    for i = 1, pixelsPerByte do
                        local px = string_byte(line, x + i)
                        packedByte = packedByte | ((px >> rshift) << ((i-1) * bpp))
                    end
                    table_insert(pixels, string_char(packedByte))
                    x = x + pixelsPerByte
                end
                table_insert(pixels, string.rep("\0", stride - (bitmap.width + pixelsPerByte - 1) // pixelsPerByte))
            end
        end
        if (bpp == 8 and not isColor) or bpp == 32 then
            if bpp == 8 then 
                compression = EByteRLECompression
            end
            copyPixels832()
        elseif bpp < 8 then
            compression = EByteRLECompression
            copyPixelsPacked()
        else
            unimplemented("mbm.makeMbm.mode"..tostring(bitmap.mode))
        end

        local paddedData = table.concat(pixels)
        if compression == EByteRLECompression then
            paddedData = rleEncode(paddedData, 1)
        elseif compression == ESixteenBitRLECompression then
            paddedData = rleEncode(paddedData, 2)
        elseif compression == ETwentyFourBitRLECompression then
            paddedData = rleEncode(paddedData, 3)
        elseif compression == ETwelveBitRLECompression then
            unimplemented("mbm.makeMbm.rle12")
        end
        addf(SEpocBitmapHeader,
            #paddedData + headerLen, -- len
            headerLen,
            bitmap.width,
            bitmap.height,
            math.floor(bitmap.width * 11.90625 + 0.5), -- twipsx
            math.floor(bitmap.height * 11.90625 + 0.5), -- twipsy
            bpp,
            isColor and 1 or 0,
            0, -- paletteSz,
            compression)
        add(paddedData)
    end

    parts[2] = string_pack("<I4", parts.n) -- trailerOffset
    addf("I4", #bitmapOffsets)
    for _, offset in ipairs(bitmapOffsets) do
        addf("I4", offset)
    end

    return table.concat(parts)
end

local function parseSEpocBitmapHeader(data, offset)
    local len, headerLen, x, y, twipsx, twipsy, bpp, col, paletteSz, compression, pos =
        string_unpack(SEpocBitmapHeader, data, 1 + offset)
    -- printf("x=%d y=%d twipsx=%d twipsy=%d headerLen=%d\n", x, y, twipsx, twipsy, headerLen)
    return Bitmap {
        offset = offset,
        data = data,
        len = len,
        headerLen = headerLen,
        width = x,
        height = y,
        bpp = bpp,
        isColor = col == 1,
        mode = bppColorToMode(bpp, col == 1),
        stride = byteWidth(x, bpp),
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

function decodeBitmap(bitmap)
    local data = bitmap.data
    local imgData
    local pos = 1 + bitmap.imgStart
    local len = bitmap.imgLen
    if bitmap.compression == ENoBitmapCompression then
        local expectedImgSize = bitmap.stride * bitmap.height
        if len < expectedImgSize then
            -- Workaround: Some AIFs appear to have an incorrectly-calculated length in the header (failing to include
            -- headerLen) so we will allow this (on uncompressed bitmaps only) and just hope the data is otherwise
            -- correct.
            print("Working around bad len", len, expectedImgSize, bitmap.headerLen)
            len = expectedImgSize
        end

        return data:sub(pos, pos + len - 1)
    elseif bitmap.compression == EByteRLECompression then
        imgData = rleDecode(data, pos, len, 1)
    elseif bitmap.compression == ETwelveBitRLECompression then
        imgData = rle12decode(data, pos, len)
    elseif bitmap.compression == ESixteenBitRLECompression then
        imgData = rleDecode(data, pos, len, 2)
    elseif bitmap.compression == ETwentyFourBitRLECompression then
        imgData = rleDecode(data, pos, len, 3)
    else
        error("Unknown compression scheme "..tostring(bitmap.compression))
    end
    return imgData
end

function rle12decode(data, pos, len)
    local bytes = {}
    local i = 1
    local endPos = pos + len
    while pos+1 <= endPos do
        local value = string_unpack("<I2", data, pos)
        pos = pos + 2
        local runLength = (value >> 12) + 1
        -- I'm too tired to figure out why this only works if bytes is written out big-endian here...
        bytes[i] = string_rep(string_pack(">I2", value & 0xFFF), runLength)
        i = i + 1
    end
    local result = table.concat(bytes)
    return result
end

function rleDecode(data, pos, len, pixelSize)
    local bytes = {}
    local i = 1
    local endPos = pos + len
    while pos+1 <= endPos do
        local b = string_byte(data, pos)
        if b < 0x80 then
            -- b+1 repeats of pixel pos+1
            bytes[i] = string_rep(string_sub(data, pos + 1, pos + pixelSize), b + 1)
            pos = pos + 1 + pixelSize
        else
            -- 256-b pixels of raw data follow
            local n = 256 - b
            bytes[i] = string_sub(data, pos + 1, pos + (n * pixelSize))
            pos = pos + 1 + (n * pixelSize)
        end
        i = i + 1
    end
    local result = table.concat(bytes)
    return result
end

function rleEncode(data, pixelSize)
    local result = {}
    local current = nil -- nil if currently in a raw block, non-nil if in a run block of that character
    local prev = nil -- previous raw-block byte
    local start = 1 -- Where the current block started (indexes are pixel-based, not byte based)
    local function indexToPos(i)
        return (i - 1) * pixelSize + 1
    end
    for i = 1, #data // pixelSize do
        local b = string_sub(data, indexToPos(i), indexToPos(i) + pixelSize - 1)
        assert(#b == pixelSize)
        local blockLen = i - start + 1 -- Assuming b is the same type as the current block

        if current and b == current and blockLen == 0x81 then
            -- We have to end the run now (without including byte i) because i won't fit in the 0x80 max repeat count
            table.insert(result, string_char(0x7F)..current)
            current = nil
            start = i
            blockLen = 1
        end

        if current then
            assert(prev == nil)
            if b == current then
                -- Keep adding to the run
            else
                -- end the run
                table.insert(result, string_char(i - start - 1)..current)
                current = nil
                start = i
            end
        else -- current == nil
            if prev == b then
                -- start a run, by first ending the raw block
                local len = (i - 1) - start
                if len > 0 then
                    table.insert(result, string_char(256 - len))
                    table.insert(result, string_sub(data, indexToPos(start), indexToPos(i - 1) - 1))
                end
                start = i - 1
                current = b
                prev = nil
            elseif blockLen == 0x81 then
                -- We have to end the raw block anyway due to becoming too big
                table.insert(result, string_char(0x80))
                local block = string_sub(data, indexToPos(start), indexToPos(i) - 1)
                printf("start=%d, i=%d, #block=%d, #data=%d\n", start, i, #block, #data)
                assert(#block == (blockLen - 1) * pixelSize)
                table.insert(result, block)
                start = i
                prev = b
            else
                -- Keep adding to the raw block
                prev = b
            end
        end
    end
    if start ~= (#data // pixelSize) + 1 then
        if current then
            local len = (#data // pixelSize) - (start - 1)
            table.insert(result, string_char(len - 1)..current)
        else
            local block = string_sub(data, indexToPos(start))
            table.insert(result, string_char(256 - (#block // pixelSize)))
            table.insert(result, block)
        end
    end
    return table.concat(result)
end

local compressionNames = {
    [ENoBitmapCompression] = "none",
    [EByteRLECompression] = "rle",
    [ETwelveBitRLECompression] = "rle12",
    [ESixteenBitRLECompression] = "rle16",
    [ETwentyFourBitRLECompression] = "rle24",
}

function compressionToString(c)
    return compressionNames[c] or string.format("Unknown compression scheme %d", c)
end

local function scale2bpp(val)
    return val | (val << 2) | (val << 4) | (val << 6)
end

local function bitToByte(byte, bitIdx)
    return (byte & (1 << bitIdx)) > 0 and 0x0 or 0xFF
end

function widenTo8bpp(data, bpp, color)
    local pos = 1
    local len = #data
    local bytes = {}
    if bpp == 4 and color then
        while pos <= len do
            local b = string_unpack("B", data, pos)
            bytes[pos] = string_pack("BB", b & 0xF, b >> 4)
            pos = pos + 1
        end
        return table.concat(bytes)
    elseif bpp == 4 then
        while pos <= len do
            local b = string_unpack("B", data, pos)
            bytes[pos] = string_pack("BB", ((b & 0xF) << 4) | (b & 0xF), (b & 0xF0) | (b >> 4))
            pos = pos + 1
        end
        return table.concat(bytes)
    elseif bpp == 2 then
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
    elseif bpp == 1 then
        while pos <= len do
            local b = string_unpack("B", data, pos)
            bytes[pos] = string_pack("BBBBBBBB",
                bitToByte(b, 0),
                bitToByte(b, 1),
                bitToByte(b, 2),
                bitToByte(b, 3),
                bitToByte(b, 4),
                bitToByte(b, 5),
                bitToByte(b, 6),
                bitToByte(b, 7)
            )
            pos = pos + 1
        end
        return table.concat(bytes)
    else
        assert(bpp == 8, "Logic fail!")
        return data
    end
end

function Bitmap:toBmp()
    local KFileHeaderFmt = "<c2I4I2I2I4"
    local KBitmapHeaderFmt = "<I4i4i4I2I2I4I4i4i4I4I4"

    local fileHeaderSize = string_packsize(KFileHeaderFmt)
    local bmpHeaderSize = string_packsize(KBitmapHeaderFmt)
    local byteWidth = roundUp(self.width * 3, 4)
    local destLength = self.height * byteWidth

    local bmpHeader = string_pack(KBitmapHeaderFmt,
        bmpHeaderSize,
        self.width,
        -self.height, -- Indicates our rows are top-down not bottom-up
        1, -- planes
        24, -- bitcount
        0, -- compression
        0, -- sizeImage (really?)
        0, -- xpm
        0, -- ypm
        0, -- clrUsed
        0 -- clrImportant
        )

    local fileHeader = string_pack(KFileHeaderFmt,
        "BM",
        fileHeaderSize + bmpHeaderSize + destLength,
        0,
        0,
        fileHeaderSize + bmpHeaderSize
    )

    local pixels = self:getImageData(24, byteWidth)
    local pad = string.rep("\0", destLength - #pixels)
    return fileHeader..bmpHeader..pixels..pad
end

function Bitmap:getMetadata()
    local result = {
        width = self.width,
        height = self.height,
        bpp = self.bpp,
        compression = compressionToString(self.compression),
    }
    if self.mask then
        result.mask = self.mask:getMetadata()
    end
    return result
end

return _ENV
