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

function parseAif(data)
    local sis = require("sis")
    local mbm = require("mbm")
    local uid1, uid2, uid3, checksum, trailerOffset = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore and uid2 == KUidAppInfoFile8, "Not an AIF file!")

    local nCaptions, pos = string.unpack("<B", data, 1 + trailerOffset)
    local captions = {} -- keyed by lang code
    for i = 1, (nCaptions // 2) do
        local offset, langCode
        offset, langCode, pos = string.unpack("<I4I2", data, pos)
        local captionLen = (string.unpack("B", data, 1 + offset) - 2) // 4
        local caption = data:sub(1 + offset + 1, offset + 1 + captionLen)
        local lang = assert(sis.Langs[langCode], "Unknown lang code!")
        captions[lang] = caption
    end

    local nIcons, pos = string.unpack("<B", data, pos)
    local icons = {}
    for i = 1, (nIcons // 2) do
        local offset, size
        offset, size, pos = string.unpack("<I4I2", data, pos)
        local bitmap = mbm.parseBitmap(data, offset)
        bitmap.imgData = mbm.decodeBitmap(bitmap, data)
        icons[i] = bitmap
    end

    return {
        captions = captions,
        icons = icons,
    }
end

return _ENV
