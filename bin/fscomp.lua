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
        "input",
        output = string, o = "output",
        json = string, j = "json"
    })

    if args.help or args.input == nil then
        print([[
Syntax: fscomp.lua [options] <input>

Convert a .FSC font spec file into a 32x8 character bitmap image and associated
metadata JSON file, as used by OpoLua internally.

Options:
    --output <path>, -o <path>
        Path to write the .bmp file to.

    --json <path>, -j <path>
        Path to write JSON metadata to.
]])
        os.exit(true)
    end


    -- Documentation of .fsc format taken from
    -- https://dn720703.ca.archive.org/0/items/400-psion-programma/400%20psion%20programmas.zip
    -- PROG/FONTS/FONTS.TXT

    local chars = {}
    local currentch = { }
    local name, height, descent
    local maxWidth = 0
    local function addEmptyChar()
        local ch = { w = 0 }
        for i = 1, height do
            ch[i] = ""
        end
        table.insert(chars, ch)
    end

    -- These are usually CRLF
    local f = assert(io.open(args.input, "rb"))
    for line in f:lines("L") do
        local line = line:match("([^\r\n]*)\r?\n?$")
        local cmd, param = line:match("^%*([a-zA-Z])[^ ]* +(.*)")
        if cmd then
            if cmd == "h" then
                height = assert(tonumber(param))
            elseif cmd == "d" then
                descent = assert(tonumber(param))
            elseif cmd == "n" then
                name = param
            elseif cmd == "c" then
                local skipTo = assert(tonumber(param))
                assert(skipTo >= #chars, "Jumping backwards not supported")
                assert(currentch.w == nil, "Unexpected *char mid character")
                while #chars < skipTo do
                    addEmptyChar()
                end
            else
                -- print("cmd", cmd, param)
            end
        elseif line == "" then
            if currentch.w then
                table.insert(chars, currentch)
                currentch = { }
            end
        elseif line:match("^ *;") then
            -- Comment, ignore
        else
            local charline = line:match("^([01]+)")
            assert(charline, "Unhandled line "..line)
            if currentch.w == nil then
                currentch.w = #charline
                maxWidth = math.max(maxWidth, currentch.w)
            else
                assert(#charline == currentch.w, "Mismatching char width!")
            end
            -- Convert 0->white and 1->black
            local lineData = charline:gsub(".", { ['0'] = '\xFF', ['1'] = '\x00' })
            assert(#lineData == #charline)
            table.insert(currentch, lineData)
        end
    end

    if currentch.w then
        -- Finish final character
        table.insert(chars, currentch)
    end

    -- We want a full character set
    while #chars < 256 do
        addEmptyChar()
    end

    f:close()

    if args.output then
        local bmpDataArr = {}
        for y = 0, 7 do
            for line = 1, height do
                for x = 0, 31 do
                    local chIdx = 1 + y * 32 + x
                    -- print(y, line, x, chIdx)
                    local chLineData = assert(chars[chIdx][line])
                    table.insert(bmpDataArr, chLineData)
                    if #chLineData < maxWidth then
                        -- Pad the image if necessary
                        table.insert(bmpDataArr, string.rep('\xFF', maxWidth - #chLineData))
                    end
                end
            end
        end
        local bmpData = table.concat(bmpDataArr)
        assert(#bmpData, 256 * maxWidth * height)

        local mbm = require("mbm")
        local bitmapw = 32 * maxWidth
        local bitmap = mbm.Bitmap {
            data = bmpData,
            len = #bmpData,
            width = bitmapw,
            height = 8 * height,
            bpp = 8,
            -- isColor = false,
            mode = KColorgCreate256GrayMode,
            stride = bitmapw,
            paletteSz = 0,
            compression = mbm.ENoBitmapCompression,
            imgStart = 0,
            imgLen = #bmpData
        }

        local bmpf = assert(io.open(args.output, "wb"))
        bmpf:write(bitmap:toBmp())
        bmpf:close()
    end

    if args.json then
        local widths = {}
        for i, char in ipairs(chars) do
            widths[i] = char.w
        end
        local obj = {
            name = name,
            charh = height,
            ascent = height - descent,
            maxwidth = maxWidth,
            encoding = "IBM 850",
            firstch = 0,
            widths = widths,
        }
        local f = assert(io.open(args.json, "w"))
        f:write(dump(obj, "json"))
        f:close()
    end
end

pcallMain()
