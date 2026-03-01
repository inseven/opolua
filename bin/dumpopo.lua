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
        "procName",
        "startAddr",
        all = true, a = "all",
        help = true, h = "help",
        decompile = true, d = "decompile",
        annotate = true, t = "annotate",
        name = table, n = "name",
        aif = string, i = "aif",
    })
    local procName = args.procName
    local all = args.all
    if args.help then
        printf("%s", [=[
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

    --name <proc>:<name>=<newname>
        Manually specify a name for a local in the given proc. Can be used
        multiple times for multiple variables. For example to rename local_00AC%
        to event% in the MAIN proc, specify --name MAIN:local_00AC=event. Has
        no effect unless --decompile is specified.

    --aif <path>, -i <path>
        Adds an APP...ENDA block to the decompile output based on the given AIF
        file.
]=])
        return os.exit(false)
    end
    local data = readFile(args.filename)
    local startAddr = args.startAddr and tonumber(args.startAddr, 16)
    local verbose = not args.decompile and (all or procName == nil)
    opofile = require("opofile")
    runtime = require("runtime")
    local prog = opofile.parseOpo2(data, verbose)
    local rt = runtime.newRuntime(nil, prog.era)
    rt:addModule("C:\\module", prog.procTable, prog.opxTable)
    if args.decompile then
        local names = {} -- map of module name to table of name->newname
        for _, rename in ipairs(args.name) do
            local proc, oldName, newName = rename:match("(.*):([A-Za-z0-9_]+)%=(.*)")
            if not proc then
                io.stderr:write("Syntax: --name PROCNAME:<oldname>=<newname>")
                return os.exit(false)
            end
            if not names[proc] then
                names[proc] = {}
            end
            names[proc][oldName] = newName
        end

        local aif = nil
        if args.aif then
            local aifData = readFile(args.aif)
            aif = require("aif").parseAif(aifData)
        end

        local options = {
            path = args.filename,
            opxTable = prog.opxTable,
            annotate = args.annotate,
            outputFn = function(location, ...)
                if args.annotate then
                    if location then
                        printf("%08X: ", location)
                    else
                        printf("          ")
                    end
                end
                printf(...)
            end,
            format = prog.translatorVersion,
            renames = names,
            aif = aif,
        }
        local ok, err
        if procName then
            ok, err = require("decompiler").decompileProc(rt:findProc(procName:upper()), options)
        else
            ok, err = require("decompiler").decompile(prog.procTable, options)
        end

        if not ok then
            print(err)
            os.exit(false)
        end
    elseif procName then
        opofile.printProc(rt:findProc(procName:upper()))
        rt:dumpProc(procName:upper(), startAddr)
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
