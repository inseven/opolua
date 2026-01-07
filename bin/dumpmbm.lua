#!/usr/bin/env lua

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

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local args = getopt({
        "filename",
        "index",
        extract = true, e = "extract",
        help = true, h = "help",
    })

    if args.help or args.filename == nil then
        print([[
Syntax: dumpmbm.lua [options] <filename> [<index>]

Print info about an MBM or extract the images from it, depending on whether
--extract is specified. If <index> is specified, only print/extract that
indexed image.

Options:
    --extract, -e
        Extract the image(s) from the MBM and save them in BMP format. Files
        are written alongside <filename>.
]])
        os.exit(true)
    end

    mbm = require("mbm")
    local data = readFile(args.filename)
    local bitmaps = mbm.parseMbmHeader(data)
    if args.index then
        local i = tonumber(args.index)
        dump(args.filename, i, bitmaps[i], args.extract)
    else
        for i, bitmap in ipairs(bitmaps) do
            dump(args.filename, i, bitmap, args.extract)
        end
    end
end

function dump(filename, i, bitmap, extract)
    print(string.format("%d: len=%d imgLen=%d w=%d h=%d stride=%d bpp=%d col=%s paletteSz=%d compression=%s",
        i, bitmap.len, bitmap.imgLen, bitmap.width, bitmap.height, bitmap.stride, bitmap.bpp, bitmap.isColor, bitmap.paletteSz, mbm.compressionToString(bitmap.compression)))
    -- local img = mbm.decodeBitmap(bitmap)
    if extract then
        local bmpName = string.format("%s_%d_%dx%d_%dbpp.bmp", filename, i, bitmap.width, bitmap.height, bitmap.bpp)
        writeFile(bmpName, bitmap:toBmp())
    end
end

pcallMain()
