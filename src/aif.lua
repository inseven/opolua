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

function parseAif(data)
    local sis = require("sis")
    local mbm = require("mbm")
    local uid1, uid2, uid3, checksum, trailerOffset = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore and uid2 == KUidAppInfoFile8, "Not an AIF file!")
    assert(require("crc").getUidsChecksum(uid1, uid2, uid3) == checksum, "Bad UID checksum!")

    local nCaptions, pos = string.unpack("<B", data, 1 + trailerOffset)
    local captions = {} -- keyed by locale
    for i = 1, (nCaptions // 2) do
        local offset, langCode
        offset, langCode, pos = string.unpack("<I4I2", data, pos)
        local captionLen = (string.unpack("B", data, 1 + offset) - 2) // 4
        local caption = data:sub(1 + offset + 1, offset + 1 + captionLen)
        local locale = assert(sis.Locales[langCode], "Unknown lang code "..langCode)
        captions[locale] = caption
    end

    local nIcons, pos = string.unpack("<B", data, pos)
    local icons = {}
    for i = 1, (nIcons // 2) do
        local offset, size
        offset, size, pos = string.unpack("<I4I2", data, pos)
        local bitmap = mbm.parseBitmap(data, offset)
        -- print(offset, size, bitmap.len)
        bitmap.imgData = bitmap:getImageData()

        local maskStart = (offset + bitmap.len)
        local mask = mbm.parseBitmap(data, maskStart)
        -- printf("Mask: 0x%08X w=%d h=%d, len=%d\n", maskStart, mask.width, mask.height, mask.len)
        mask.imgData = mask:getImageData()
        bitmap.mask = mask

        icons[i] = bitmap
    end

    return {
        uid3 = uid3,
        captions = captions,
        icons = icons,
    }
end

return _ENV
