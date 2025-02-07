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

function parseAif(data, verbose)
    local sis = require("sis")
    local mbm = require("mbm")

    if data:sub(1, 16) == "OPLObjectFile**\0" then
        -- Series 3 OPA files have their AIF metadata built in - for simplicity, treat them like a special kind of AIF
        -- Not entirely clear how to establish if this is an OPA with metadata or just an OPO without - we will peek
        -- for a PIC header and assume that means we're an OPA

        -- local _, _, era = require("opofile").parseOpo(data, verbose)

        local sourceName, pos = string.unpack("<s1", data, 21)
        local len, hdr = string.unpack("<I2c4", data, pos)
        if hdr == "PIC\xDC" then
            local picDataPos = pos + 2
            local picData = data:sub(picDataPos, picDataPos + len - 1)
            local icons = mbm.parseMbmHeader(picData)
            for _, bitmap in ipairs(icons) do
                bitmap.imgData = bitmap:getImageData()
            end

            local infoPos = picDataPos + len
            local infoLen, name, path, type = string.unpack("<I2c14c20I2", data, infoPos)
            -- name is actually the default filename but that seems to be constructed from the APP <name> plus EXT <ext>
            name = oplpath.splitext(name)

            return {
                type = "opa",
                uid3 = 0,
                captions = {
                    en_GB = name,
                },
                icons = icons,
                era = "sibo",
            }
        else
            return nil
        end
    end


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
        type = "aif",
        uid3 = uid3,
        captions = captions,
        icons = icons,
    }
end

function makeAif(info)
    local sis = require("sis")

    local parts = { n = 0 }
    local function add(data)
        table.insert(parts, data)
        parts.n = parts.n + #data
    end
    local function addf(fmt, ...)
        local data = string.pack(fmt, ...)
        add(data)
    end

    local chk = require("crc").getUidsChecksum(KUidDirectFileStore, KUidAppInfoFile8, info.uid3)
    addf("<I4I4I4I4", KUidDirectFileStore, KUidAppInfoFile8, info.uid3, chk)

    addf("<I4", 0) -- parts[2] = trailerOffset, will be replaced at end

    -- MBM icons would go here

    local captionOffsets = {}
    for _, cap in ipairs(info.captions) do
        table.insert(captionOffsets, parts.n)
        local caption = cap[2]
        addf("B", #caption * 4 + 2) -- I don't know why the length is stored like this, but it is...
        add(caption)
    end

    parts[2] = string.pack("<I4", parts.n) -- trailerOffset

    local nCaptions = #info.captions * 2 -- Again, unsure why nCaptions is doubled here
    addf("B", nCaptions) 
    for i, cap in ipairs(info.captions) do
        local langId = cap[1]
        addf("<I4I2", captionOffsets[i], langId)
    end

    addf("B", 0) -- nIcons

    addf("<I4I4I4I4I4B",
        1, -- (unknown),
        0, -- KAppNotEmbeddable
        0, -- KAppDoesNotSupportNewFile
        0, -- KAppNotHidden
        1, -- (unknown)
        0  -- (unknown)
    )

    return table.concat(parts, "")
end

return _ENV
