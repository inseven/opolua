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

function main()
    local args = dofile(arg[0]:sub(1, arg[0]:match("/?()[^/]+$") - 1).."cmdline.lua").getopt({
        "filename",
        "index",
        expand = true, e = "expand",
    })

    mbm = require("mbm")
    local f = assert(io.open(args.filename, "rb"))
    local data = f:read("a")
    f:close()
    local bitmaps = mbm.parseMbmHeader(data)
    if args.index then
        local i = tonumber(args.index)
        dump(args.filename, i, bitmaps[i], data, args.expand)
    else
        for i, bitmap in ipairs(bitmaps) do
            dump(args.filename, i, bitmap, data, args.expand)
        end
    end
end

function dump(filename, i, bitmap, data, expand)
    print(string.format("%d: len=%d w=%d h=%d stride=%d bpp=%d col=%s paletteSz=%d compression=%d",
        i, bitmap.imgLen, bitmap.width, bitmap.height, bitmap.stride, bitmap.bpp, bitmap.isColor, bitmap.paletteSz, bitmap.compression))
    local img = mbm.decodeBitmap(bitmap, data)
    if expand then
        local bmpName = string.format("%s_%d_%dx%d_%dbpp.bmp", filename, i, bitmap.width, bitmap.height, bitmap.bpp)
        local f = assert(io.open(bmpName, "wb"))
        local imgData = bitmap:toBmp()
        f:write(imgData)
        f:close()
    end
end

main()
