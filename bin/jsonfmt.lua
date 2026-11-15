#!/usr/bin/env lua

-- Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local args = getopt({
        "filename",
    })

    local data = readFile(args.filename)
    local obj = json.decode(data)
    io.stdout:write(json.encode(obj))
end

pcallMain()
