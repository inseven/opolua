#!/usr/local/bin/lua-5.3

require("init")
local opofile = require("opofile")
local runtime = require("runtime")

function main(args)
    local verbose = false
    local i = 1
    local maps = {}
    while i < #args do
        if args[i] == "--verbose" or args[i] == "-v" then
            verbose = true
            table.remove(args, i)
        elseif args[i] == "--map" or args[i] == "-m" then
            table.insert(maps, { args[i+1], args[i+2] })
            table.remove(args, i)
            table.remove(args, i)
            table.remove(args, i)
        else
            i = i + 1
        end
    end
    local path = args[1]
    local procName = args[2]
    local iohandler = require("defaultiohandler")
    for _, m in ipairs(maps) do
        iohandler.fsmap(m[1], m[2]) -- Not part of iohandler interface, specific to defaultiohandler
    end

    if #maps == 0 then
        -- Setup the default one
        local dir, filename = oplpath.split(path)
        local appName = oplpath.splitext(filename)
        local appDir = string.format([[C:\SYSTEM\APPS\%s\]], appName)
        iohandler.fsmap(appDir, dir.."/")
        devicePath = appDir..filename
    else
        -- If any maps are supplied on the commandline, the cmdline path is assumed to be a devicePath
        devicePath = path
    end

    local err = runtime.runOpo(devicePath, procName, iohandler, verbose)
    if err then
        print("Error: "..tostring(err))
    end
    return err and 1 or 0
end

-- Syntax: runopo.lua filename [fnName]
if arg then main(arg) end
