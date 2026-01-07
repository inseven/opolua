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

function parseAif(data)
    local sis = require("sis")
    local mbm = require("mbm")

    if data:sub(1, 16) == "OPLObjectFile**\0" then
        -- Series 3 OPA files have their AIF metadata built in - for simplicity, treat them like a special kind of AIF
        -- Not entirely clear how to establish if this is an OPA with metadata or just an OPO without - we will peek
        -- for a PIC header and assume that means we're an OPA

        -- local _, _, era = require("opofile").parseOpo(data)

        local sourceName, pos = string.unpack("<s1", data, 21)
        local len, hdr = string.unpack("<I2c4", data, pos)
        if hdr == "PIC\xDC" then
            local picDataPos = pos + 2
            local picData = data:sub(picDataPos, picDataPos + len - 1)
            local icons = mbm.parseMbmHeader(picData)

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
        local offset, width
        offset, width, pos = string.unpack("<I4I2", data, pos)
        local bitmap = mbm.parseBitmap(data, offset)
        -- printf("Icon %d offset=0x%08X width=%d len=%d\n", i, offset, width, bitmap.len)

        local maskStart = (offset + bitmap.len)
        local mask = mbm.parseBitmap(data, maskStart)
        -- printf("Mask %d offset=0x%08X width=%d height=%d len=%d\n", i, maskStart, mask.width, mask.height, mask.len)
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

function parseAifToNative(data)
    local result = parseAif(data)
    if result then
        for i, icon in ipairs(result.icons) do
            result.icons[i] = {
                bitmap = icon:toNative()
            }
            if icon.mask then
                result.icons[i].mask = icon.mask:toNative()
            end
        end
    end
    return result
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

    addf("<I4I4I4I4", require("crc").getUids(KUidDirectFileStore, KUidAppInfoFile8, info.uid3))

    addf("<I4", 0) -- parts[2] = trailerOffset, will be replaced at end

    local iconOffsets = {}
    for i = 1, #info.icons, 2 do
        table.insert(iconOffsets, parts.n)
        local icon = info.icons[i]
        local mask = info.icons[i + 1]
        -- Don't call icon:getImageData() or mbm.decodeBitmap() here, we want the compressed data as stored in the mbm
        local imgData = icon.data:sub(1 + icon.offset, icon.offset + icon.len)
        add(imgData)
        local maskData = mask.data:sub(1 + mask.offset, mask.offset + mask.len)
        add(maskData)
    end

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

    addf("B", #info.icons) -- nIcons
    for i, offset in ipairs(iconOffsets) do
        addf("<I4I2", offset, info.icons[2 * i - 1].width)
    end

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

function toMbm(aif)
    local parts = { n = 0 }
    local function add(data)
        table.insert(parts, data)
        parts.n = parts.n + #data
    end
    local function addf(fmt, ...)
        local data = string.pack(fmt, ...)
        add(data)
    end

    addf("<I4I4I4I4", require("crc").getUids(KUidDirectFileStore, KUidMultiBitmapFileImage, 0))
    addf("<I4", 0) -- parts[2] = trailerOffset, will be replaced at end

    local imageOffsets = {}
    for _, icon in ipairs(aif.icons) do
        table.insert(imageOffsets, parts.n)
        add(icon.data:sub(1 + icon.offset, icon.offset + icon.len))
        table.insert(imageOffsets, parts.n)
        add(icon.mask.data:sub(1 + icon.mask.offset, icon.mask.offset + icon.mask.len))
    end

    parts[2] = string.pack("<I4", parts.n) -- trailerOffset
    addf("<I4", #imageOffsets) -- numBitmaps
    for _, offset in ipairs(imageOffsets) do
        addf("<I4", offset)
    end

    return table.concat(parts)
end

return _ENV
