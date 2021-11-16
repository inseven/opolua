#!/usr/local/bin/lua-5.3

require("init")
local opofile = require("opofile")
local runtime = require("runtime")

function runOpo(args)
    local verbose = false
    local i = 1
    while i < #args do
        if args[i] == "--verbose" then
            verbose = true
            table.remove(args, i)
        else
            i = i + 1
        end
    end
    local filename = args[1]
    local procName = args[2]
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()

    local procTable = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime()
    rt:addModule(procTable)
    local proc = procName and rt:findProc(procName:upper()) or procTable[1]
    rt:runProc(proc, verbose)
end

-- Syntax: runopo.lua filename [fnName]
if arg then runOpo(arg) end
