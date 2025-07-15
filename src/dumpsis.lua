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

local sis = require("sis")

local shortFileTextDetails = enum {
    TC = sis.FileTextDetails.continue,
    TS = sis.FileTextDetails.skip,
    TA = sis.FileTextDetails.abort,
    TE = sis.FileTextDetails.exit,
}

local shortFileRunDetails = enum {
    RI = sis.FileRunDetails.RunInstall,
    RR = sis.FileRunDetails.RunRemove,
    RB = sis.FileRunDetails.RunBoth,
    RE = sis.FileRunDetails.RunSendEnd,
    RW = sis.FileRunDetails.RunWait,
}

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
        allfiles = true, a = "allfiles",
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

    --allfiles, -a
        Write out all files in the sis, including alternative languages,
        embedded SIS files and FileText files, which normally wouldn't be saved
        to the psion filesystem. Implies --quiet. Does not recursively
        extract the meta files from embedded SIS files.

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

    if args.allfiles and args.interactive then
        error("Cannot specify both --allfiles and --interactive")
    end

    if args.allfiles then
        args.quiet = true
    end

    if args.language then
        assert(sis.Locales[args.language], "Bad --language argument")
    end

    cp1252 = require("cp1252")
    local data = readFile(args.filename)

    if args.dest then
        local iohandler = require("defaultiohandler")
        iohandler.fsmap("C:\\", path_join(args.dest, ""))
        -- Have to create C drive up front because iohandler can't
        os.execute(string.format('mkdir -p "%s"', args.dest))

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
            return
        end

        if args.allfiles then
            -- Extract all the things the normal installer skips over
            local sisfile = sis.parseSisFile(data, args.verbose)
            local FileType = sis.FileType
            for i = #sisfile.files, 1, -1 do
                local file = sisfile.files[i]
                if file.type == FileType.SisComponent then
                    local path = string.format("C:\\SisComponent_%i_%s", i, path_basename(file.src))
                    iohandler.fsop("write", path, file.data)
                elseif file.langData then
                    local basename
                    local suffix
                    if file.type == FileType.FileText then
                        basename = string.format("FileText_%i_", i)
                        suffix = ".txt"
                    else
                        basename = file.dest
                        suffix = ""
                    end
                    for langIdx, langData in ipairs(file.langData) do
                        local path = basename .. sisfile.langs[langIdx] .. suffix
                        iohandler.fsop("write", path, langData)
                    end
                elseif file.type == FileType.FileText then
                    local path = string.format("C:\\FileText_%i_%s", i, file.src:match("[^/\\]+$"))
                    iohandler.fsop("write", path, file.data)
                end
            end
        end
    else
        local sisfile = sis.parseSisFile(data, args.verbose)
        if args.json then
            local manifest = manifestToUtf8(sis.makeManifest(sisfile, args.language, true))
            print(json.encode(manifest))
        else
            sis.describeSis(sisfile, "")
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
