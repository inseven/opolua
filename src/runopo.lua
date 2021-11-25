#!/usr/local/bin/lua-5.3

require("init")
local opofile = require("opofile")
local runtime = require("runtime")

function main(args)
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
    return runOpo(filename, procName, nil, verbose)
end

function runOpo(filename, procName, iohandler, verbose)
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()

    local procTable = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime(iohandler)
    rt:setInstructionDebug(verbose)
    rt:addModule(filename, procTable)
    local procToCall = procName and procName:upper() or procTable[1].name
    local err = rt:pcallProc(procToCall)
    if err and err.code ~= KStopErr then
        print("Error: "..tostring(err))
    end
end

-- Syntax: runopo.lua filename [fnName]
if arg then main(arg) end
