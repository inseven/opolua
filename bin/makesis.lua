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
        "pkgFile",
        "dest",
        help = true, h = "help",
        manifest = true, m = "manifest",
        path = table, p = "path",
        verbose = true, v = "verbose",
        version = string,
    })

    if args.help or args.pkgFile == nil then
        print([[
Syntax: makesis.lua [options] <pkg-file> [<output>]

Create a SIS file based on a PKG file. If <output> is not specified, runs
dumpsis on the resulting SIS data without writing to disk.

Options:

    --manifest, -m
        If specified, only parse the pkg file and print the parsed data
        structures to stdout. <output> is ignored.

    --path <oplpath>=<realpath>
        Provide custom mapping of file source paths given in <pkg-file>. The
        file source path will be recorded as specified in <pkg-file> but the
        contents will be from <realpath>.

    --verbose, -v
        Include verbose output, particularly when combined with --manifest.

    --version <major>.<minor>
        Override the version specified in the package file.

Path rewriting

Source paths in the package file that are different to the on-disk filesystem
can be used by specifying one or more --path arguments. Each path argument can
specify either a single file, for example:

makesis.lua [...] --path '\epoc32\RELEASE\MARM\REL\Sysram1.opx'=c/SYSTEM/OPX/Sysram1.opx

or a directory (note the <oplpath> must end in a backslash):

makesis.lua [...] --path '\epoc32\RELEASE\MARM\REL\'=c/SYSTEM/OPX

Directory substitutions are not done recursively, eg the above would not match
a file in a subdirectory of REL.
]])
        os.exit(true)
    end

    local sis = require("sis")

    local dir = oplpath.dirname(args.pkgFile)
    local pkgData = readFile(args.pkgFile)
    local manifest = sis.pkgToManifest(pkgData)
    if args.manifest then
        print(dump(manifest))
        return
    end

    local pathMap = {}
    if args.path then
        for _, arg in ipairs(args.path) do
            local from, to = arg:match("(.+)%=(.+)")
            assert(from, "Expected --path foo=bar")
            pathMap[from] = to
        end
    end

    for i, file in ipairs(manifest.files) do
        if file.type ~= "FileNull" then
            file.data = {}
            for j, src in ipairs(file.src) do
                local path = pathMap[src]
                if not path then
                    local dir, file = oplpath.split(src)
                    local mappedDir = pathMap[dir]
                    if mappedDir then
                        path = path_join(mappedDir, file)
                    end
                end
                if not path then
                    path = path_join(dir, src:gsub("\\", "/"))
                end
                file.data[j] = readFile(path)
            end
        end
    end

    if args.version then
        local maj, min = args.version:match("(%d+)%.(%d+)")
        assert(maj, "Expected --version <major>.<minor>")
        manifest.version.major = tonumber(maj)
        manifest.version.minor = tonumber(min)
    end

    local sisFile = sis.makeSis(manifest)
    if args.dest then
        writeFile(args.dest, sisFile)
    else
        local sisInfo = sis.parseSisFile(sisFile, args.verbose)
        sis.describeSis(sisInfo, "")
    end
end

pcallMain()
