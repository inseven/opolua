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
        "dest",
        verbose = true, v = "verbose",
        json = true, j = "json",
        nolangs = true, n = "nolangs",
    })

    sis = require("sis")
    cp1252 = require("cp1252")
    local data = readFile(args.filename)
    local sisfile = sis.parseSisFile(data, args.verbose)

    if args.dest then
        installSis(sisfile, args.dest)
    else
        if args.json then
            local manifest = manifestToUtf8(sis.makeManifest(sisfile, not args.nolangs))
            print(json.encode(manifest))
        else
            describeSis(sisfile, "")
        end
    end
end

function describeSis(sisfile, indent)
    for _, name in ipairs(sisfile.name) do
        printf("%sName: %s\n", indent, cp1252.toUtf8(name))
    end

    printf("%sVersion: %d.%d\n", indent, sisfile.version[1], sisfile.version[2])
    
    printf("%sUid: 0x%08X\n", indent, sisfile.uid)

    for _, lang in ipairs(sisfile.langs) do
        printf("%sLanguage: 0x%04X (%s)\n", indent, lang, sis.Locales[lang])
    end

    local langIdx = sis.getBestLangIdx(sisfile.langs)
    for _, file in ipairs(sisfile.files) do
        local len
        if file.data then
            len = #file.data
        elseif file.langData then
            len = #(file.langData[langIdx])
        end
        local src = cp1252.toUtf8(file.src)
        local dest = cp1252.toUtf8(file.dest)
        printf("%s%s: %s -> %s", indent, sis.FileType[file.type], src, dest)
        if len then
            printf(" len=%d", len)
        end
        printf("\n")

        if file.type == sis.FileType.SisComponent and file.data then
            local componentSis = sis.parseSisFile(file.data)
            describeSis(componentSis, "    "..indent)
        end
    end
end

function installSis(sisfile, dest)
    local langIdx = sis.getBestLangIdx(sisfile.langs)
    for _, file in ipairs(sisfile.files) do
        if file.type == sis.FileType.File then
            if file.data or (file.langData and file.langData[langIdx]) then
                extractFile(file, langIdx, dest)
            else
                printf("Warning: Skipping truncated file %s\n", file.dest)
            end
        elseif file.type == sis.FileType.SisComponent then
            local componentSis = sis.parseSisFile(file.data)
            installSis(componentSis, dest)
        end
    end
end

function extractFile(file, langIdx, dest)
    local destName = cp1252.toUtf8(file.dest)
    local outName = dest.."/c/"..destName:sub(4):gsub("\\", "/")
    local dir = oplpath.dirname(outName)
    -- print(dir)
    os.execute(string.format('mkdir -p "%s"', dir))
    local data = file.data
    if not data then
        data = file.langData[langIdx]
    end
    writeFile(outName, data)
end

function manifestToUtf8(manifest)
    local result = {
        type = manifest.type,
        version = manifest.version,
        uid = manifest.uid,
        files = {},
    }
    if type(manifest.name) == "string" then
        result.name = cp1252.toUtf8(manifest.name)
    else
        result.name = {}
        for lang, name in pairs(manifest.name) do
            result.name[lang] = cp1252.toUtf8(name)
        end
    end

    for i, file in ipairs(manifest.files) do
        result.files[i] = {
            -- It's not obvious what encoding src actually is (possibly depends on the PC the file was created on) so at
            -- the very least, treating it as CP1252 as well will ensure we output a valid UTF-8 byte sequence, even if
            -- it's not guaranteed to be correct.
            src = file.src and cp1252.toUtf8(file.src),
            dest = file.dest and cp1252.toUtf8(file.dest),
            len = file.len,
        }
    end

    return result
end

pcallMain()
