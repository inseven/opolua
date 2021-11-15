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
    local verbose = all or fnName == nil
    local procTable = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime()
    rt:addModule(procTable)
    if fnName then
        rt:dumpProc(fnName:upper())
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
        -- Params are listed in reverse order (ie as per how they'd be pushed
        -- onto the stack) so reflect that in the indexes we print here
        printf("    Param %d: %s\n", numParams + 1 - i, DataTypes[param])
    end
    for _, subproc in ipairs(proc.subprocs) do
        printf('    Subproc "%s" offset=0x%04X nargs=%d\n', subproc.name, subproc.offset, subproc.numParams)
    end
    for _, global in ipairs(proc.globals) do
        printf('    Global "%s" (%s) offset=0x%04X\n', global.name, DataTypes[global.type], global.offset)
    end
    for _, external in ipairs(proc.externals) do
        printf('    External "%s" (%s)\n', external.name, DataTypes[external.type])
    end
    printf("    iTotalTableSize: %d (0x%08X)\n", proc.iTotalTableSize, proc.iTotalTableSize)
end

if arg then main(arg) end
