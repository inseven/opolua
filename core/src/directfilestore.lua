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

SectionUids = enum {
    KUidPrintSetupStream = 0x10000105,
    KUidWordStream = 0x10000106, -- Don't know what this uid is officially called, can't find a reference...
    KUidSoundData = 0x10000052, -- Not sure what this uid is officially called, can't find a reference...
    KUidTextEdSection = KUidTextEdApp, -- It's called TextEd but it's basically the OPL editor
    KUidAppIdentifierStream = 0x10000089,
}

function parse(data)
    local uid1, uid2, uid3, checksum, tocOffset = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore)
    assert(require("crc").getUidsChecksum(uid1, uid2, uid3) == checksum, "Bad UID checksum!")
    local toc = {}
    local tocLen, pos = string.unpack("B", data, 1 + tocOffset)
    local n = tocLen // 2 -- tocLen is count of longs (as a byte), and each entry is 2 longs (uid and offset)
    for i = 1, n do
        local uid, offset
        uid, offset, pos = string.unpack("<I4I4", data, pos)
        toc[uid] = offset
        -- print(string.format("0x%08X @ 0x%08X", uid, offset))
    end
    return toc
end

return _ENV
