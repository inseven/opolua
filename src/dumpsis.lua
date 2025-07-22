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

local fileTextDetails = enum {
    TEXTCONTINUE = sis.FileTextDetails.continue,
    TEXTSKIP = sis.FileTextDetails.skip,
    TEXTABORT = sis.FileTextDetails.abort,
    TEXTEXIT = sis.FileTextDetails.exit,
}

local fileRunDetails = enum {
    RUNINSTALL = sis.FileRunDetails.RunInstall,
    RUNREMOVE = sis.FileRunDetails.RunRemove,
    RUNBOTH = sis.FileRunDetails.RunBoth,
    RUNSENDEND = sis.FileRunDetails.RunSendEnd,
    RUNWAITEND = sis.FileRunDetails.RunWait,
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
        pkg = true, p = "pkg",
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

    --pkg, -p
        When listing the SIS file, output as a PKG file. Has no effect if
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
        extract the meta files from embedded SIS files. Cannot be combined with
        --language.

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
    elseif args.allfiles and args.interactive then
        error("Cannot specify both --allfiles and --interactive")
    elseif args.allfiles and args.language then
        error("Cannot specify both --allfiles and --language")
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
            local firstLang = sis.LangShortCodes[sisfile.langs[1]]
            for i = #sisfile.files, 1, -1 do
                local file = sisfile.files[i]
                if file.type == FileType.SisComponent then
                    local path = string.format("C:\\_SisComponent_%i\\%s", i, oplpath.basename(file.src))
                    iohandler.fsop("mkdir", oplpath.dirname(path))
                    if file.langData then
                        -- I don't recall ever seeing this used, but it is allowed
                        local base, ext = oplpath.splitext(oplpath.basename(file.src))
                        for i, data in file.langData do
                            iohandler.fsop("write", path .. base .. LangShortCodes[sisfile.langs[i]] .. ext, data)
                        end
                    else
                        iohandler.fsop("write", path, file.data)
                    end
                elseif file.langData then
                    local dest
                    if file.type == FileType.FileText then
                        dest = string.format("C:\\_FileText_%i\\%s", i, oplpath.basename(file.src))
                        iohandler.fsop("mkdir", oplpath.dirname(dest))
                    else
                        dest = file.dest:gsub("^.:\\", "C:\\")
                    end
                    for langIdx, langData in ipairs(file.langData) do
                        local path = langRename(file.src, dest, firstLang, sis.LangShortCodes[sisfile.langs[langIdx]])
                        iohandler.fsop("write", path, langData)
                    end
                elseif file.type == FileType.FileText then
                    local path = string.format("C:\\FileText_%i\\%s", i, oplpath.basename(file.src))
                    iohandler.fsop("write", path, file.data)
                end
            end
        end
    else
        local sisfile = sis.parseSisFile(data, args.verbose)
        if args.json then
            local manifest = manifestToUtf8(sis.makeManifest(sisfile, args.language, true))
            print(json.encode(manifest))
        elseif args.pkg then
            -- For each file work out what names we're going to use for src/srcs (and possibly nativeDest), because it's
            -- frequently not exactly what's in the SIS file metadata (and we need the nativeDests for the --path args
            -- we're putting into the generated comment, so they need to match what dumpsis --allfiles does).
            local FileType = sis.FileType
            local files = {}
            for i, file in ipairs(sisfile.files) do
                local multiLang = file.langData ~= nil
                if file.type == sis.FileType.FileNull then
                    table.insert(files, {
                        type = file.type,
                        details = file.details,
                        sources = { "" },
                        dest = file.dest,
                    })
                else
                    local sources
                    if multiLang then
                        -- SIS format only stores the first language's source path, so we have to make something up
                        sources = makeLanguageVariants(file.src, sisfile.langs)
                    else
                        sources = { file.src }
                    end
                    local dest
                    if file.type == FileType.SisComponent then
                        dest = string.format("_SisComponent_%d/%s", i, oplpath.basename(file.src))
                    elseif file.type == FileType.FileText then
                        dest = string.format("_FileText_%d/%s", i, oplpath.basename(file.src))
                    else
                        dest = file.dest:match("^.:\\(.*)"):gsub("\\", "/")
                    end

                    table.insert(files, {
                        type = file.type,
                        details = file.details,
                        sources = sources,
                        dest = file.dest,
                        nativeDest = dest,
                        data = file.data,
                        langData = file.langData,
                    })
                end
            end

            -- Pre-pass to work out all the file paths to map - the idea here is that for anything where the file isn't
            -- renamed, we'll try to map the directory it's in, to try to avoid having a --path arg for every item.
            -- Items like FileText and SisComponent which have no dest will always require a per-item path mapping.
            local paths = {}
            local mappedPaths = {}
            for _, file in ipairs(files) do
                if file.nativeDest then
                    local srcDir, srcName = oplpath.split(file.sources[1])
                    local destDir, destName = oplpath.split(file.nativeDest)
                    if srcName == destName or file.langData then
                        if mappedPaths[srcDir] == nil then
                            table.insert(paths, string.format("--path '%s'=%s", srcDir, destDir))
                            mappedPaths[srcDir] = destDir
                        end
                    else
                        table.insert(paths, string.format("--path '%s'=%s", file.sources[1], file.dest))
                    end
                end
            end

            printf("; Generated by dumpsis.lua --pkg '%s'\n", args.filename)
            printf("; Recreate with (assuming cwd for the install root):\n")
            printf("; dumpsis.lua --allfiles '%s' .\n", args.filename)
            printf("; makesis.lua %s <pkg>\n\n", table.concat(paths, " "))
            local langCodes = {}
            for i, lang in ipairs(sisfile.langs) do
                langCodes[i] = sis.LangShortCodes[lang]
            end
            printf("&%s\n\n", table.concat(langCodes, ","))
            local quotedNames = quotedStringList(sisfile.name)
            printf("#{%s},(0x%08X),%d,%d,0\n\n",
                table.concat(quotedNames, ","),
                sisfile.uid,
                sisfile.version[1],
                sisfile.version[2])

            for _, file in ipairs(files) do
                local multiLang = file.langData ~= nil
                local startDelim, endDelim = "", ""
                if multiLang then
                    startDelim = "{"
                    endDelim = "}"
                end
                if file.type == sis.FileType.SisComponent then
                    printf("%s%s%s, (0x%08X)\n",
                        startDelim,
                        table.concat(quotedStringList(file.sources, '@"', '"'), " "),
                        endDelim,
                        file.details)
                else
                    local suffix = ""
                    if file.type == sis.FileType.FileNull then
                        suffix = ", FILENULL"
                    elseif file.type == sis.FileType.FileText then
                        suffix = ", FILETEXT, "..fileTextDetails[file.details]
                    elseif file.type == sis.FileType.FileRun then
                        suffix = ", FILERUN, "..fileRunDetails[file.details & 0xF]
                        if file.details & sis.FileRunDetails.RunSendEnd > 0 then
                            suffix = suffix..", "..fileRunDetails[sis.FileRunDetails.RunSendEnd]
                        end
                        if file.details & sis.FileRunDetails.RunWait > 0 then
                            suffix = suffix..", "..fileRunDetails[sis.FileRunDetails.RunWait]
                        end
                    end
                    printf('%s%s%s-"%s"%s\n',
                        startDelim,
                        table.concat(quotedStringList(file.sources, '"', '"'), " "),
                        endDelim,
                        file.dest,
                        suffix)
                end
            end
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


function quotedStringList(tbl, startQuote, endQuote)
    local result = {}
    for i, name in ipairs(tbl) do
        result[i] = (startQuote or '"')..name..(endQuote or '"')
    end
    return result
end

function makeLanguageVariants(src, langs)
    local result = {}
    -- The first result must be the unappended prefix, to ensure we can round-trip a generated package
    for i, lang in ipairs(langs) do
        if i == 1 then
            result[i] = src
        else
            -- result[i] = string.format("%s_%s", prefix, sis.LangShortCodes[lang])
            result[i] = langRename(src, nil, sis.LangShortCodes[langs[1]], sis.LangShortCodes[lang])
        end
    end
    return result
end

function langRename(src, dest, baseLang, lang)
    -- Source file paths frequently use one of the following syntaxes, from which we can infer what the paths to the
    -- other files were.
    local outStr = dest or src

    -- print("langRename", src, dest, baseLang, lang)

    -- C:\...\foo.rXX -> foo.rsc (or similar non-language-specific extension
    if src:match("%.."..baseLang.."$") then
        return outStr:sub(1, -3)..lang
    end

    -- C:\...\fooXX.bar" -> foo.bar
    local base, ext = oplpath.splitext(src)
    if base:match(baseLang.."$") then
        local outBase, outExt
        if dest then
            outBase, outExt = oplpath.splitext(dest)
            if outBase:match(baseLang.."$") then
                -- To handle --allfiles on a FileText where we've generated the dest from the src so will also have the
                -- lang appended.
                outBase = outBase:sub(1, -3)
            end
            return outBase .. lang .. outExt
        else
            return base:sub(1, -3)..lang..ext
        end
    end

    -- No clue, just append the lang
    return outStr.."_"..lang
end

pcallMain()
