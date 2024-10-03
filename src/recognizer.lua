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

function recognize(data, verbose)
    local siboHeader = data:sub(1, 16)
    if siboHeader == "ALawSoundFile**\0" then
        return { type = "sound", data = require("sound").parseWveFile(data) }
    elseif siboHeader == "OPLObjectFile**\0" then
        return require("aif").parseAif(data)
    elseif data:sub(1, 4) == "PIC\xDC" then
        return { type = "mbm", bitmaps = getMbmBitmaps(data) }
    end

    if #data < 16 then
        return nil
    end

    -- Resources don't have a UID header either...
    local rcsTocOffset, rscTocLen = string.unpack("<I2I2", data)
    if rcsTocOffset < #data and rcsTocOffset + rscTocLen <= #data then
        local endBytes = string.unpack("<I2", data, #data - 1)
        if endBytes == rcsTocOffset then
            -- We at least try to parse it as a resource.
            local rsc = require("rsc")
            local ok, res = pcall(rsc.parseRsc, data)
            if ok then
                return {
                    type = "resource",
                    idOffset = res.idOffset,
                }
            end
        end
    end

    local uid1, uid2, uid3, checksum = string.unpack("<I4I4I4I4", data)

    -- This has to come before the checksum check because ROM MBMs don't have a checksum...
    if uid1 == KMultiBitmapRomImageUid then
        return { type = "mbm", bitmaps = getMbmBitmaps(data) }
    end

    if checksum ~= require("crc").getUidsChecksum(uid1, uid2, uid3) then
        -- It's not even an EPOC file
        return nil
    end

    if uid1 == KUidDirectFileStore and uid2 == KUidAppInfoFile8 then
        -- Because AIFs aren't actually directfilestore files and have to be parsed specially...
        local aif = require("aif")
        return aif.parseAif(data)
    end

    -- Not all MBMs have uid2 set usefully...
    if uid1 == KUidDirectFileStore and uid2 == KUidMultiBitmapFileImage then
        -- MBMs aren't directfilestore files either...
        return { type = "mbm", bitmaps = getMbmBitmaps(data) }
    end
    -- .. so just try parsing it to see what happens
    if uid1 == KUidDirectFileStore then
        local ok, bitmaps = pcall(getMbmBitmaps, data)
        if ok then
            return { type = "mbm", bitmaps = bitmaps }
        end
    end

    if uid1 == KUidDirectFileStore and uid2 == KUidOplApp then
        local procTable, opxTable, era = require("opofile").parseOpo(data, verbose)
        return { type = "opa", era = era, uid3 = uid3 }
    elseif uid1 == KUidDirectFileStore and uid2 == KUidOPO then
        local procTable, opxTable, era = require("opofile").parseOpo(data, verbose)
        return { type = "opo", era = era }
    end

    if uid1 == KUidDirectFileStore then
        local dfs = require("directfilestore")
        local toc = dfs.parse(data)
        local texted = toc[dfs.SectionUids.KUidTextEdSection]
        if texted then
            return { type = "opl", text = getOplText(data) }
        end

        local sndData = toc[dfs.SectionUids.KUidSoundData]
        if sndData then
            return { type = "sound", data = require("sound").parseWveFile(data) }
        end

        if uid2 == KUidAppDllDoc8 and uid3 == KEikUidWordApp then
            return { type = "word" }
        end
    end

    if uid1 == KPermanentFileStoreLayoutUid then
        return { type = "database" }
    end

    if (uid2 == KUidAppDllDoc8 or uid2 == KUidSisFileEr6) and uid3 == KUidInstallApp then
        local sis = require("sis")
        local info = sis.parseSisFile(data)
        if info then
            info = sis.makeManifest(info, true)
            info.files = nil
        end
        return info
    end

    return { type = "unknown", uid1 = uid1, uid2 = uid2, uid3 = uid3 }
end

local KTextEdSectionMarker = 0x1000005C
local KTextSectionMarker = 0x10000064

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
            local text = data:sub(pos, pos + len - 1):gsub("[\x06\x10]", textReplacements)
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
