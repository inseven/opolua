#!/usr/local/bin/lua-5.3

--[[

Copyright (c) 2022 Jason Morley, Tom Sutcliffe

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

local KTextEdSectionMarker = 0x1000005C
local KTextSectionMarker = 0x10000064

local specialChars = {
    ["\x06"] = "\n",
    ["\x10"] = " ", -- Not going to distinguish nonbreaking space, not important for OPL
}

function main()
    dofile(arg[0]:sub(1, arg[0]:match("/?()[^/]+$") - 1).."cmdline.lua")
    local args = getopt({
        "filename",
    })

    local data = readFile(args.filename)
    local toc = require("directfilestore").parse(data)
    local texted = toc[KUidTextEdSection]
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
            print(text)
            break
        else
            pos = pos + 4 -- Skip over offset of section we don't care about
        end
    end
end

main()
