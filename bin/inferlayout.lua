#!/usr/bin/env lua

-- Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local recognizer = require("recognizer")
    local args = getopt({
        "dir",
        version = string,
        help = true,
        h = "help",
        v = "version",
    })

    if args.help then
        print([[
Syntax: inferlayout.lua [options] <dirPath>

Create a package (.pkg) file from a directory of files, inferring what the
on-device file layout probably should be. The resulting pkg file can be passed
to makesis.lua.

Options:

    --version <value>, -v <value>
        Specify the version in the resulting pkg/sis file. If not specified,
        defaults to "1.0".
]])
        os.exit(false)
    end

    local paths = ls(args.dir)
    local files = {}
    for i, path in ipairs(paths) do
        local nativePath = path_join(args.dir, path_tonative(path))
        local file = recognizer.recognize(readFile(nativePath), false) or { type = "unknown" }
        file.path = path
        files[path] = file
        table.insert(files, file)
    end

    local sis = require("sis")
    local actions = sis.inferLayoutFromFiles(files)
    -- print(dump(actions))

    actions.version = args.version
    print(sis.makePackageFile(actions))
end

function ls(path)
    local files = {}
    local h = io.popen('ls -Rp1 "'..path..'"')
    local currentDir = ""
    for line in h:lines() do
        local subdir = line:match("^"..path.."/?(.*):$")
        if subdir then
            currentDir = subdir:gsub("/", "\\").."\\"
        elseif line == "" or line:match("/$") then
            -- skip
        else
            table.insert(files, currentDir..line)
        end
    end
    local ok, err, num = h:close()
    if not ok then
        error("ls failed with "..err.." "..tostring(num))
    end
    return files
end

pcallMain()