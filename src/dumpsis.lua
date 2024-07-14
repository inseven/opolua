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
            print(json.encode(makeManifest(sisfile, not args.nolangs)))
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
        printf("%s%s: %s -> %s len=%d\n", indent, sis.FileType[file.type], src, dest, len or 0)
        if file.type == sis.FileType.SisComponent then
            local componentSis = sis.parseSisFile(file.data)
            describeSis(componentSis, "    "..indent)
        end
    end
end

function installSis(sisfile, dest)
    local langIdx = sis.getBestLangIdx(sisfile.langs)
    for _, file in ipairs(sisfile.files) do
        if file.type == sis.FileType.File then
            extractFile(file, langIdx, dest)
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

function langListToLocaleMap(langs, list)
    local result = {}
    for i = 1, math.min(#langs, #list) do
        local langName = sis.Locales[langs[i]]
        if langName then
            result[langName] = cp1252.toUtf8(list[i])
        else
            io.stderr:write(string.format("Warning: Language 0x%x not recognized!\n", langs[i]))
        end
    end
    return result
end

function makeManifest(sisfile, includeLangs)
    local langIdx
    if not includeLangs then
        langIdx = sis.getBestLangIdx(sisfile.langs)
    end

    local result = {
        name = includeLangs and json.Dict(langListToLocaleMap(sisfile.langs, sisfile.name))
            or cp1252.toUtf8(sisfile.name[langIdx]),
        version = string.format("%d.%d", sisfile.version[1], sisfile.version[2]),
        uid = sisfile.uid,
        languages = {},
        files = {},
    }
    for _, lang in ipairs(sisfile.langs) do
        table.insert(result.languages, sis.Locales[lang])
    end

    for i, file in ipairs(sisfile.files) do
        local f = {
            type = sis.FileType[file.type]
        }
        if file.type ~= sis.FileType.FileNull then
            -- It's not obvious what encoding src actually is (possibly depends on the PC the file was created on) so at
            -- the very least, treating it as CP1252 as well will ensure we output a valid UTF-8 byte sequence, even if
            -- it's not guaranteed to be correct.
            f.src = cp1252.toUtf8(file.src)
            if includeLangs then
                f.len = {}
                if file.langData then
                    for i = 1, #sisfile.langs do
                        f.len[sis.Locales[sisfile.langs[i]]] = #file.langData[i]
                    end
                else
                    for i = 1, #sisfile.langs do
                        f.len[sis.Locales[sisfile.langs[i]]] = #file.data
                    end
                end
            else
                f.len = #(file.data or file.langData[langIdx])
            end
        end
        if file.type ~= sis.FileType.FileText then
            f.dest = cp1252.toUtf8(file.dest)
        end

        if file.type == sis.FileType.SisComponent then
            local componentSis = sis.parseSisFile(file.data)
            f.sis = makeManifest(componentSis, includeLangs)
        end

        result.files[i] = f
    end

    return result
end

pcallMain()
