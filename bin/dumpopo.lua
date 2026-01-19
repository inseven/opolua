#!/usr/bin/env lua

--[[

Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe

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

dofile(arg[0]:match("^(.-)[a-z]+%.lua$").."cmdline.lua")

function main()
    local args = getopt({
        "filename",
        "fnName",
        "startAddr",
        all = true, a = "all",
        help = true, h = "help",
        decompile = true, d = "decompile",
        annotate = true, n = "annotate",
    })
    local fnName = args.fnName
    local all = args.all
    if args.help then
        printf([=[
Syntax: dumpopo.lua <filename> [options] [<procName> [<startAddr>]]

Prints information about the specified OPO (compiled OPL) file.

If just a filename is specified, prints information about the file and all the
procedures it contains. With --all or a <procName>, prints an assembly listing
of all procedures or the specified procedure, respectively. The <startAddr>
argument can be used to skip over some amount of the procedure code, which can
be useful when debugging code using obfuscation techniques.

Options:

    --all, -a
        Prints assembly listing of all procedures, if neither <procName> or
        --decompile is specified.

    --decompile, -d
        Convert the compiled code back to OPL source code and print to stdout.
        Decompiles all procedures unless <procName> is specified.

    --annotate, -n
        Adds some annotations to the output of --decompile, such as labels and
        GOTOs that normally wouldn't appear in the source.
]=])
        return os.exit(false)
    end
    local data = readFile(args.filename)
    local startAddr = args.startAddr and tonumber(args.startAddr, 16)
    local verbose = not args.decompile and (all or fnName == nil)
    opofile = require("opofile")
    runtime = require("runtime")
    local prog = opofile.parseOpo2(data, verbose)
    local rt = runtime.newRuntime(nil, prog.era)
    rt:addModule("C:\\module", prog.procTable, prog.opxTable)
    if args.decompile then
        local options = {
            path = args.filename,
            opxTable = prog.opxTable,
            annotate = args.annotate,
            printFn = printf,
            format = prog.translatorVersion,
        }
        local ok, err
        if fnName then
            ok, err = require("decompiler").decompileProc(rt:findProc(fnName:upper()), options)
        else
            ok, err = require("decompiler").decompile(prog.procTable, options)
        end

        if not ok then
            print(err)
            os.exit(false)
        end
    elseif fnName then
        opofile.printProc(rt:findProc(fnName:upper()))
        rt:dumpProc(fnName:upper(), startAddr)
    else
        for i, proc in ipairs(prog.procTable) do
            printf("%d: ", i)
            opofile.printProc(proc)
            if all then
                rt:dumpProc(proc.name)
            end
        end
    end
end

pcallMain()
