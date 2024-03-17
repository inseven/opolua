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

sep=package.config:sub(1,1);dofile(arg[0]:sub(1, arg[0]:match(sep.."?()[^"..sep.."]+$") - 1).."cmdline.lua")

function main()
    local args = getopt({
        "path",
        "procName",
        verbose = true, v = "verbose",
        map = table, m = "map",
        defaultmap = true, d = "defaultmap",
        devicepath = true, p = "devicepath",
        noget = true,
    })

    local path = args.path
    local procName = args.procName
    local opofile = require("opofile")
    local runtime = require("runtime")
    local iohandler = require("defaultiohandler")
    for _, m in ipairs(args.map) do
        local from, to = m:match("(.*)%=(.*)")
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
    end

    if args.devicepath then
        devicePath = args.devicepath
    elseif not devicePath then
        local dir, filename = oplpath.split(path)
        devicePath = "C:\\"..filename
    end

    if args.noget then
        iohandler.getch = function()
            print("Skipping get")
            return 13 -- ie enter
        end
    end

    local progData = readFile(path)
    local typ, recog = require("recognizer").recognize(progData, true)
    if typ == "opl" then
        progData = require("compiler").compile(path, nil, recog.text, {})
    elseif path:lower():match("%.txt$") then
        progData = require("compiler").compile(path, nil, progData, {})
    elseif typ ~= "opo" then
        error("Don't recognize "..path)
    end

    local procTable, opxTable, era = opofile.parseOpo(progData)
    local rt = require("runtime").newRuntime(iohandler, era)
    rt:setInstructionDebug(args.verbose)
    rt:addModule(devicePath, procTable, opxTable)

    local procToCall = procName and procName:upper() or procTable[1].name
    local err = rt:pcallProc(procToCall)
    if err then
        print("Error: "..tostring(err))
    end
    return err and 1 or 0
end

pcallMain()
