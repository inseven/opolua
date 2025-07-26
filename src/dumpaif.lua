#!/usr/bin/env lua

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

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local args = getopt({
        "filename",
        extract = true, e = "extract",
        json = true, j = "json",
    })

    if args.help or args.filename == nil then
        print([[
Syntax: dumpaif.lua [options] <filename>

Print info about an AIF or extract the images from it, depending on whether
--extract is specified.

Options:
    --extract, -e
        Extract the image(s) from the AIF and save them in BMP format. Files
        are written alongside <filename>.
    
    --json, -j
        Print AIF info in JSON format.
]])
        os.exit(true)
    end

    local aif = require("aif")
    local mbm = require("mbm")
    local data = readFile(args.filename)
    local info = aif.parseAif(data, args.verbose)
    local cp1252 = require("cp1252")

    if not args.json then
        printf("UID3: 0x%08X\n", info.uid3)
        for lang, caption in pairs(info.captions) do
            printf("Caption[%s]: %s\n", lang, cp1252.toUtf8(caption))
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
            local mask = icon.mask
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
            icons[i] = info.icons[i]:getMetadata()
        end
        local utf8Captions = {}
        for lang, caption in pairs(info.captions) do
            utf8Captions[lang] = cp1252.toUtf8(caption)
        end
        local jsonResult = {
            type = info.type,
            uid3 = info.uid3,
            era = info.era,
            icons = icons,
            captions = utf8Captions,
        }
        print(json.encode(jsonResult))
    end
end

pcallMain()
