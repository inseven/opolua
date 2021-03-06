#!/usr/local/bin/lua-5.3

--[[

Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe

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

dofile(arg[0]:sub(1, arg[0]:match("/?()[^/]+$") - 1).."cmdline.lua")

function main()
    local args = getopt({
        "path",
        "procName",
        verbose = true, v = "verbose",
        map = table, m = "map",
        defaultmap = true, d = "defaultmap",
        noget = true,
    })

    local path = args.path
    local procName = args.procName
    local opofile = require("opofile")
    local runtime = require("runtime")
    local iohandler = require("defaultiohandler")
    for _, m in ipairs(args.map) do
        local from, to = m:match("(.*)%=(.*)")
        print(from, to)
        iohandler.fsmap(from, to) -- Not part of iohandler interface, specific to defaultiohandler
    end
    if #args.map == 0 or args.defaultmap then
        -- Setup the default one
        local dir, filename = oplpath.split(path)
        if dir == "" then
            dir = "./"
        end
        local appName = oplpath.splitext(filename)
        local appDir = string.format([[C:\SYSTEM\APPS\%s\]], appName)
        iohandler.fsmap(appDir, dir)
        devicePath = appDir..filename
    else
        -- If any maps are supplied on the commandline, the cmdline path is assumed to be a devicePath
        devicePath = path
    end

    if args.noget then
        iohandler.getch = function()
            print("Skipping get")
            return 13 -- ie enter
        end
    end

    local err = runtime.runOpo(devicePath, procName, iohandler, verbose)
    if err then
        print("Error: "..tostring(err))
    end
    return err and 1 or 0
end

pcallMain()
