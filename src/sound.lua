_ENV = module()

function parseWveFile(data)
    local uid1, uid2, uid3, checksum, tocOffset = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore)
    local toc = {}
    local tocLen, pos = string.unpack("B", data, 1 + tocOffset)
    local n = tocLen // 2 -- tocLen is count of longs (as a byte), and each entry is 2 longs (uid and offset)
    for i = 1, n do
        local uid, offset
        uid, offset, pos = string.unpack("<I4I4", data, pos)
        toc[uid] = offset
        print(string.format("0x%08X @ 0x%08X", uid, offset))
    end

    local sndDataOffset = toc[KUidSoundData]
    assert(sndDataOffset, "No sound data found in directfilestore TOC!")
    local uncompressedLen, compression, repeatCount, vol, wat, gap, compressedLen, pos = string.unpack("<I4I4I2BBI4I4", data, 1 + sndDataOffset)
    assert(compression == 0, "No support for compressed sound data!")
    assert(uncompressedLen == compressedLen)
    local sndData = data:sub(pos, pos + compressedLen - 1)
    return sndData
end

return _ENV
