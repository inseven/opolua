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

function main()
    local filename = arg[1]
    local dumpIcons = arg[2] == "--expand"
    require("init")
    local aif = require("aif")
    local mbm = require("mbm")
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()
    local info = aif.parseAif(data)
    printf("UID3: 0x%08X\n", info.uid3)
    for lang, caption in pairs(info.captions) do
        printf("Caption[%s]: %s\n", lang, caption)
    end
    for _, icon in ipairs(info.icons) do
        printf("Icon %dx%d bpp=%d\n", icon.width, icon.height, icon.bpp)
        if dumpIcons then
            local iconName = string.format("%s_icon_%dx%d_%dbpp.bin", filename, icon.width, icon.height, icon.bpp)
            local f = assert(io.open(iconName, "wb"))
            f:write(mbm.widenTo8bpp(icon.imgData, icon.bpp))
            f:close()
        end
    end
end

main()
