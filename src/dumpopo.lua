#!/usr/local/bin/lua-5.3

require("init")
_ENV = module()
opofile = require("opofile")
runtime = require("runtime")

function main(args)
    local filename = args[1]
    if filename == "--help" then
        printf("Syntax: dumpopo.lua <filename> [<fnName>|--all]\n")
        return os.exit(false)
    end
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()

    local fnName
    local all = (args[2] == "--all")
    if not all then
        fnName = args[2]
    end
    local startAddr
    if args[3] then
        startAddr = tonumber(args[3], 16)
    end
    local verbose = all or fnName == nil
    local procTable = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime()
    rt:addModule(filename, procTable)
    if fnName then
        printProc(rt:findProc(fnName:upper()))
        rt:dumpProc(fnName:upper(), startAddr)
    else
        for i, proc in ipairs(procTable) do
            printf("%d: ", i)
            printProc(proc)
            if all then
                rt:dumpProc(proc.name)
            end
        end
    end
end

function printProc(proc)
    printf("%s @ 0x%08X code=0x%08X line=%d\n", proc.name, proc.offset, proc.codeOffset, proc.lineNumber)
    local numParams = #proc.params
    for i, param in ipairs(proc.params) do
        local indirectIdx = (i - 1) * 2 + proc.iTotalTableSize + 18 -- inverse of Runtime:getIndirectVar() logic
        printf("    Param %d: %s indirectIdx=0x%04x\n", i, DataTypes[param], indirectIdx)
    end
    for _, subproc in ipairs(proc.subprocs) do
        printf('    Subproc "%s" offset=0x%04X nargs=%d\n', subproc.name, subproc.offset, subproc.numParams)
    end
    for _, global in ipairs(proc.globals) do
        printf('    Global "%s" (%s) offset=0x%04X\n', global.name, DataTypes[global.type], global.offset)
    end
    for i, external in ipairs(proc.externals) do
        local indirectIdx = (#proc.params + i - 1) * 2 + proc.iTotalTableSize + 18
        printf('    External "%s" (%s) indirectIdx=0x%04X\n', external.name, DataTypes[external.type], indirectIdx)
    end
    for _, str in ipairs(proc.strings) do
        printf("    String offset=0x%04X maxLen=%d\n", str.offset, str.maxLen)
    end
    for _, offset in ipairs(sortedKeys(proc.arrays)) do
        local len = proc.arrays[offset]
        printf("    Array offset=0x%04X len=%d\n", offset, len)
    end
    printf("    iTotalTableSize: %d (0x%08X)\n", proc.iTotalTableSize, proc.iTotalTableSize)
end

if arg then main(arg) end
