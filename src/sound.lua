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

function parseWveFile(data)
    if data:sub(1, 16) == "ALawSoundFile**\0" then
        local version, numSamples, silenceSuffix, repeatCount, pos = string.unpack("<I2I4I2I2", data, 1 + 16)
        return data:sub(pos)
    end

    local dfs = require("directfilestore")
    local toc = dfs.parse(data)

    local sndDataOffset = toc[dfs.SectionUids.KUidSoundData]
    assert(sndDataOffset, "No sound data found in directfilestore TOC!")
    local uncompressedLen, compression, repeatCount, vol, wat, gap, compressedLen, pos = string.unpack("<I4I4I2BBI4I4", data, 1 + sndDataOffset)
    if compression ~= 0 then
        printf("No support for compressed sound data of type=%d\n", compression)
        return nil, KErrNotSupported
    end
    assert(uncompressedLen == compressedLen)
    local sndData = data:sub(pos, pos + compressedLen - 1)
    return sndData
end

return _ENV
