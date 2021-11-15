#!/usr/local/bin/lua-5.3

require("init")
local opofile = require("opofile")
local runtime = require("runtime")

function runOpo(args)
    local filename = args[1]
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()
    local verbose = args[2] == "--verbose"

    local procTable = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime()
    rt:addModule(procTable)
    rt:runProc(procTable[1], verbose)
end

if arg then runOpo(arg) end
