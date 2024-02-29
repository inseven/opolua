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

function recognize(data, allData)
    local siboHeader = data:sub(1, 16)
    if siboHeader == "ALawSoundFile**\0" then
        return "sound", allData and { data = require("sound").parseWveFile(data) }
    elseif data:sub(1, 4) == "PIC\xDC" then
        return "mbm", allData and { bitmaps = getMbmBitmaps(data) }
    end

    if #data < 16 then
        return nil, nil
    end

    local uid1, uid2, uid3, checksum = string.unpack("<I4I4I4I4", data)

    -- This has to come before the checksum check because ROM MBMs don't have a checksum...
    if uid1 == KMultiBitmapRomImageUid then
        return "mbm", allData and { bitmaps = getMbmBitmaps(data) }
    end

    if checksum ~= require("crc").getUidsChecksum(uid1, uid2, uid3) then
        -- It's not even an EPOC file
        return nil, nil
    end

    if uid1 == KUidDirectFileStore and uid2 == KUidAppInfoFile8 then
        -- Because AIFs aren't actually directfilestore files and have to be parsed specially...
        local aif = require("aif")
        return "aif", allData and aif.parseAif(data)
    end

    -- Not all MBMs have uid2 set to this, but hopefully this is enough to be useful...
    if uid1 == KUidDirectFileStore and uid2 == KUidMultiBitmapFileImage then
        -- MBMs aren't directfilestore files either...
        return "mbm", allData and { bitmaps = getMbmBitmaps(data) }
    end

    if uid1 == KUidDirectFileStore and uid3 == KUidOplInterpreter then
        return "opo"
    end

    if not allData and uid1 == KUidDirectFileStore then
        if uid3 == KUidTextEdApp then
            return "opl"
        elseif uid3 == KUidRecordApp then
            return "sound"
        end
    end

    if allData and uid1 == KUidDirectFileStore then
        local dfs = require("directfilestore")
        local toc = dfs.parse(data)
        local texted = toc[dfs.SectionUids.KUidTextEdSection]
        if texted then
            return "opl", allData and { text = getOplText(data) }
        end

        local sndData = toc[dfs.SectionUids.KUidSoundData]
        if sndData then
            return "sound", allData and { data = require("sound").parseWveFile(data) }
        end
    end

    return "unknown", { uid1 = uid1, uid2 = uid2, uid3 = uid3 }
end

local KTextEdSectionMarker = 0x1000005C
local KTextSectionMarker = 0x10000064

local specialChars = {
    ["\x06"] = "\n",
    ["\x10"] = " ", -- Not going to distinguish nonbreaking space, not important for OPL
}

function getOplText(data)
    local dfs = require("directfilestore")
    local toc = dfs.parse(data)
    local texted = toc[dfs.SectionUids.KUidTextEdSection]
    assert(texted, "No text found in file!")
    
    local textEdSectionMarker, pos = string.unpack("<I4", data, texted + 1)
    assert(textEdSectionMarker == KTextEdSectionMarker)
    while true do
        local id
        id, pos = string.unpack("<I4", data, pos)
        if id == KTextSectionMarker then
            -- Finally, the text section
            local len, pos = readCardinality(data, pos)
            -- 06 means "new paragraph" in TextEd land... everything else likely
            -- to appear in an OPL script is ASCII
            local text = data:sub(pos, pos + len - 1):gsub("[\x06\x10]", specialChars)
            return text
        else
            pos = pos + 4 -- Skip over offset of section we don't care about
        end
    end

end

function getMbmBitmaps(data)
    local mbm = require("mbm")
    local bitmaps = mbm.parseMbmHeader(data)
    for _, bitmap in ipairs(bitmaps) do
        bitmap.imgData = bitmap:getImageData()
    end
    return bitmaps
end

return _ENV
