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

local function path_join(path, component)
    local sep = path:match("/^") and "" or "/"
    return path..sep..component
end

local function path_basename(path)
    return (path:match("/?([^/]+)$"))
end

function main()
    local args = getopt({
        "filename",
        "dest",
        verbose = true, v = "verbose",
        json = true, j = "json",
        quiet = true, q = "quiet",
        interactive = true, i = "interactive",
        language = string, l = "language",
        stub = true, s = "stub",
        help = true, h = "help",
        uninstall = true, u = "uninstall",
    })

    if args.help or args.filename == nil or (args.uninstall and args.dest == nil) then
        print([[
Syntax: dumpsis.lua [options] <filename> [<output>]

If no <output> is supplied, list the contents of the SIS <filename> to stdout.
If <output> is supplied, extract the SIS file to that location, treating that
location as the root of a hypothetical C: drive.

Options:
    --json, -j
        When listing the SIS file, output in JSON format. Has no effect if
        <output> is specified.

    --language, -l
        When extracting the SIS, control which file language is extracted. If
        specified with --json and without <output>, only mention this language
        in the JSON output rather than listing all of them. If not
        specified, extraction defaults to using the en_GB resources (or next
        best).

    --quiet, -q
        By default any show-on-install text files are printed to stdout when
        extracting a SIS. Specify --quiet to suppress this. Either way, all
        queries are automatically accepted unless --interactive is specified.

    --interactive, -i
        Prompt after any show-on-install text files are printed. Cannot be
        combined with --quiet.

    --stub, -s
        If specified, also write an uninstall stub in C:\System\Install\.

    --verbose, -v
        When listing the SIS file, print extra debug information.

    --uninstall, -u
        Uninstall the files referenced by the sis <filename> from <output>.
        Requires that the SIS was installed with the --stub option.
]])
        os.exit(true)
    end

    if args.quiet and args.interactive then
        error("Cannot specify both --quiet and --interactive")
    end

    sis = require("sis")

    if args.language then
        assert(sis.Locales[args.language], "Bad --language argument")
    end

    cp1252 = require("cp1252")
    local data = readFile(args.filename)

    if args.dest then
        local iohandler = require("defaultiohandler")
        iohandler.fsmap("C:\\", path_join(args.dest, ""))

        if args.uninstall then
            local sisfile = sis.parseSisFile(data)
            sis.uninstallSis(nil, sisfile.uid, iohandler)
            return
        end

        if args.interactive then
            setTerminalCharMode(true)
            iohandler.sisInstallQuery = sisInstallQueryInteractive
        elseif args.quiet then
            iohandler.sisInstallQuery = sisInstallQueryQuiet
        end

        if args.language then
            iohandler.setConfig("locale", args.language)
        end

        local err = sis.installSis(path_basename(args.filename), data, iohandler, args.stub, args.verbose)
        if err then
            printf("Install failed, err=%s\n", err.type)
        end
    else
        local sisfile = sis.parseSisFile(data, args.verbose)
        if args.json then
            local manifest = manifestToUtf8(sis.makeManifest(sisfile, args.language, true))
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

function manifestToUtf8(manifest)
    local result = {
        type = manifest.type,
        version = manifest.version,
        uid = manifest.uid,
        files = {},
        languages = manifest.languages,
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

function sisInstallQueryInteractive(info, text, type)
    print(text)
    if type == sis.FileTextDetails.Continue then
        print("-- Press any key to continue --")
        io.stdin:read(1)
        return true
    else
        print("-- Press [Y]es or [N]o to continue --")
        while true do
            local ch = io.stdin:read(1)
            if ch == "Y" or ch == "y" then
                return true
            elseif ch == "N" or ch == "n" then
                return false
            end
        end
    end
end

function sisInstallQueryQuiet(info, text, type)
    return true
end

pcallMain()
