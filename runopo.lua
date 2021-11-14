#!/usr/local/bin/lua-5.3

require("init")
_ENV = module()
opofile = require("opofile")
runtime = require("runtime")

function main(args)
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

if arg then main(arg) end
