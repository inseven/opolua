#!/usr/local/bin/lua-5.3

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

dofile(arg[0]:sub(1, arg[0]:match("/?()[^/]+$") - 1).."cmdline.lua")

function main()
    local args = getopt({
        "filename"
    })

    directfilestore = require("directfilestore")
    local data = readFile(args.filename, "rb")
    local toc = directfilestore.parse(data)
    local offsets = {}
    local offsetToUid = {}
    for uid, offset in pairs(toc) do
        table.insert(offsets, offset)
        offsetToUid[offset] = uid
    end
    table.sort(offsets)
    for _, offset in ipairs(offsets) do
        local uid = offsetToUid[offset]
        printf("%08X: 0x%08X", offset, uid)
        local uidName = directfilestore.SectionUids[uid]
        if uidName then
            printf(" %s", uidName)
        end
        printf("\n")
    end
end

pcallMain()
