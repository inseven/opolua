#!/usr/bin/env lua

--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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
        extract = true, e = "extract",
        json = true, j = "json",
    })

    local aif = require("aif")
    local mbm = require("mbm")
    local data = readFile(args.filename)
    local info = aif.parseAif(data)
    if not args.json then
        printf("UID3: 0x%08X\n", info.uid3)
        for lang, caption in pairs(info.captions) do
            printf("Caption[%s]: %s\n", lang, caption)
        end
        for i, icon in ipairs(info.icons) do
            printf("Icon %dx%d bpp=%d compression=%s", icon.width, icon.height, icon.bpp, mbm.compressionToString(icon.compression))
            local mask = icon.mask
            if mask then
                printf(" mask %dx%d bpp=%d compression=%s", mask.width, mask.height, mask.bpp, mbm.compressionToString(icon.compression))
            end
            printf("\n")
        end
    end

    if args.extract then
        for i, icon in ipairs(info.icons) do
            local iconName = string.format("%s_%d_%dx%d_%dbpp.bmp", args.filename, i, icon.width, icon.height, icon.bpp)
            -- printf("toBmp icon %s\n", iconName)
            writeFile(iconName, icon:toBmp())
            if mask then
                local maskName = string.format("%s_%d_mask_%dx%d_%dbpp.bmp", args.filename, i, mask.width, mask.height, mask.bpp)
                -- printf("toBmp icon %s\n", maskName)
                writeFile(maskName, mask:toBmp())
            end
        end
    end

    if args.json then
        local icons = {}
        -- There's a lot of stuff in icons that isn't relevant to the JSON output
        for i, icon in ipairs(info.icons) do
            local jsonIcon = {
                width = icon.width,
                height = icon.height,
                bpp = icon.bpp,
                compression = mbm.compressionToString(icon.compression),
            }
            if icon.mask then
                jsonIcon.mask = {
                    width = icon.mask.width,
                    height = icon.mask.height,
                    bpp = icon.mask.bpp,
                    compression = mbm.compressionToString(icon.mask.compression),
                }
            end
            icons[i] = jsonIcon
        end
        info.icons = icons
        print(json.encode(info))
    end
end

pcallMain()
