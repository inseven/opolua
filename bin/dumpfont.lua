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
        output = string, o = "output",
        json = true, j = "json",
        unicode = true, u = "unicode",
        ascii = true, a = "ascii",
        help = true, h = "help",
    })

    if args.help or args.filename == nil then
        print([[
Syntax: dumpfont.lua [options] <filename>

Parse a SIBO-era font file (.FON).

Options:
    --output <path>, -o <path>
        If specified, write a .bmp of the font to this path.

    --json <path>, -j <path>
        If specified, write a JSON manifest describing the font to this path.

    --ascii
        Render the font to stdout using ASCII characters for each pixel.

    --ascii
        Render the font to stdout using unicode box-drawing characters for each
        pixel.
]])
        os.exit(true)
    end

    local font = require("font")
    local data = readFile(args.filename)
    local metrics, bmp = font.parseFont(data)
    if args.output then
        assert(bmp:toBmp())
        writeFile(args.output, bmp:toBmp())
    end
    if args.json then
        writeFile(args.json, dump(metrics, "json"))
    end

    if args.ascii or args.unicode then
        for y = 0, bmp.height - 1 do
            for x = 0, bmp.width - 1 do
                -- Figure out what character this pixel is representing, so we can be fancy and draw character bounds
                local chIdx = ((y // metrics.charh) * 32) + (x // metrics.maxwidth)
                local chx = x % metrics.maxwidth
                local charw = metrics.widths[1 + chIdx]
                local b = string.byte(bmp.data, 1 + (y * bmp.stride) + x)
                if b == 0 then
                    io.stdout:write(args.unicode and "\u{2588}" or "X")
                -- elseif charw == 0 then
                --     io.stdout:write("-")
                elseif chx >= charw then
                    io.stdout:write(" ")
                else
                    io.stdout:write(".")
                end
                if (x + 1) % metrics.maxwidth == 0 then
                    io.stdout:write("|")
                end
            end
            io.stdout:write("\n")
            if (y + 1) % metrics.charh == 0 then
                io.stdout:write(string.rep(args.unicode and "\u{2500}" or "-", 32 * (metrics.maxwidth + 1)).."\n")
            end
        end
    end

    if args.output == nil and args.json == nil then
        metrics.widths = nil
        print(dump(metrics))
    end

end

pcallMain()
