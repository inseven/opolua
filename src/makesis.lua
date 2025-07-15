#!/usr/bin/env lua

-- Copyright (c) 2025 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local args = getopt({
        "pkgFile",
        "dest",
        help = true, h = "help",
        verbose = true, v = "verbose",
        manifest = true, m = "manifest",
    })

    if args.help or args.pkgFile == nil then
        print([[
Syntax: makesis.lua [options] <pkg-file> [<output>]
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

    for i, file in ipairs(manifest.files) do
        if file.type ~= "FileNull" then
            file.data = {}
            for j, src in ipairs(file.src) do
                file.data[j] = readFile(path_join(dir, src:gsub("\\", "/")))
            end
        end
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
