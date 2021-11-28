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
    local filename = args[1]
    local procName = args[2]
    local iohandler = require("defaultiohandler")
    for _, m in ipairs(maps) do
        iohandler.fsmap(m[1], m[2]) -- Not part of iohandler interface, specific to defaultiohandler
    end
    local err = runOpo(filename, procName, iohandler, verbose)
    if err then
        print("Error: "..tostring(err))
    end
    return err and 1 or 0
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
    if err and err.code == KStopErr then
        -- Don't care about the distinction
        err = nil
    end
    return err
end

-- Syntax: runopo.lua filename [fnName]
if arg then main(arg) end
