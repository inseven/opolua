#!/usr/bin/env lua

--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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
        "output",
        dump = true, d = "dump",
        include = table, i = "include",
        source = string, s = "source",
        help = true, h = "help"
    })

    if args.help then
        print([[
Syntax: compile.lua [options] <filename> [<ouput>]

Compile a Series 5 era OPL program. If neither <output> nor --dump are
specified, the result is written to <filename>.opo alongside <filename>.

<filename> can be either a plain text file, or an OPL file. OPL files are
converted to text as per opltotext.lua. 

Options:
    --dump, -d
        Prints the bytecode of the resulting binary to stdout.

    --include <dir>, -i <dir>
        Add <dir> to the list of locations to be searched when an INCLUDE
        statement is encountered. If no paths are specified, only the standard
        built-in headers can be INCLUDEed. Note, paths MUST end in the
        appropriate filesystem path separator, for example "-i ./". Note also
        that while includes of built-ins are case-insensitive, when including
        files from the filesystem the include name is case-sensitive if the
        filesystem is.

    --source <path>, -s <path>
        Override the source file path included in the output. If not specified,
        will be set to <filename>.
]])
        os.exit(false)
    end

    local compiler = require("compiler")
    local progText = readFile(args.filename)
    if progText:sub(1, 4) == string.pack("<I4", KUidDirectFileStore) then
        -- Assume it's a .opl file
        progText = require("recognizer").getOplText(progText)
    end
    local ok, result = xpcall(compiler.compile, traceback, args.source or args.filename, args.filename, progText, args.include)
    if not ok then
        if type(result) == "string" then
            print(result)
            print("Internal compiler error, please report to https://github.com/inseven/opolua/issues")
            print("including the above error message and if possible the file being compiled.")
        else
            printf("%s:%d:%d: %s\n%s\n", result.src.path, result.src.line, result.src.column, result.msg, result.traceback)
        end
        os.exit(false)
        return
    end

    if args.dump then
        opofile = require("opofile")
        runtime = require("runtime")
        local procTable, opxTable, era = opofile.parseOpo(result, true)
        local rt = runtime.newRuntime(nil, era)
        rt:addModule("C:\\module", procTable, opxTable)
        for i, proc in ipairs(procTable) do
            printf("%d: ", i)
            opofile.printProc(proc)
            rt:dumpProc(proc.name)
        end
    end
    if args.output or not args.dump then
        writeFile(args.output or (args.filename .. ".opo"), result)
    end
end

function traceback(err)
    if type(err) == "table" then
        err.traceback = debug.traceback(nil, 2)
        return err
    else
        return debug.traceback(err, 2)
    end
end

pcallMain()
