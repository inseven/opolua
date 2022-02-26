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
        "filename",
        "fnName",
        "startAddr",
        all = true,
        help = true, h = "help",
    })
    local fnName = args.fnName
    local all = args.all
    if args.help then
        printf("Syntax: dumpopo.lua <filename> [--all]\n")
        printf("        dumpopo.lua <filename> [<fnName> [<startAddr>]]\n")
        return os.exit(false)
    end
    local data = readFile(args.filename)
    local startAddr = args.startAddr and tonumber(args.startAddr, 16)
    local verbose = all or fnName == nil
    opofile = require("opofile")
    runtime = require("runtime")
    local procTable, opxTable, era = opofile.parseOpo(data, verbose)
    local rt = runtime.newRuntime()
    rt:setEra(era)
    rt:addModule("C:\\module", procTable, opxTable)
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
    for _, offset in ipairs(sortedKeys(proc.strings)) do
        local maxLen = proc.strings[offset]
        printf("    String offset=0x%04X maxLen=%d\n", offset, maxLen)
    end
    for _, offset in ipairs(sortedKeys(proc.arrays)) do
        local len = proc.arrays[offset]
        printf("    Array offset=0x%04X len=%d\n", offset, len)
    end
    printf("    iTotalTableSize: %d (0x%08X)\n", proc.iTotalTableSize, proc.iTotalTableSize)
end

pcallMain()
