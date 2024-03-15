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

-- Use to bootstrap cmdline scripts with the following magic:
-- dofile(arg[0]:sub(1, arg[0]:match("/?()[^/]+$") - 1).."cmdline.lua")
-- local args = getopt({ ... })

local args = arg
-- Have to redo the calculation of our base path here, which is a bit annoying
local launchFile = args[0]
package.path = launchFile:sub(1, launchFile:match("/?()[^/]+$") - 1).."?.lua"
require("init")

local function printHelp(params)
    local positionalArgNames
    if #params == 0 then
        positionalArgNames = "..."
    else
        local names = {}
        for i, name in ipairs(params) do
            names[i] = string.format("<%s>", name)
        end
        positionalArgNames = table.concat(names, " ")
    end
    printf("Syntax: %s [options] %s\n", launchFile, positionalArgNames)
    local opts = {}
    local shorts = {} -- map of long to short opts
    for k, v in pairs(params) do
        if type(k) == "string" then
            if type(v) == "string" then
                shorts[v] = k
            else
                table.insert(opts, k)
            end
        end
    end
    table.sort(opts)
    if #opts > 0 then
        printf("Options:\n")
    end
    for _, opt in ipairs(opts) do
        local shortopt = shorts[opt] and string.format("|-%s", shorts[opt]) or ""
        if params[opt] == string then
            printf("    --%s%s <value>\n", opt, shortopt)
        elseif params[opt] == table then
            printf("    --%s%s <value> [--%s%s <value> ...]\n", opt, shortopt, opt, shortopt)
        else
            printf("    --%s%s\n", opt, shortopt)
        end
    end
end


--[[

Helper fn for parsing command-line options and arguments, based on the specified
params table.

Args
====

Positional arguments are specified as a list of arg names. For example a script
which is called with syntax:

foo.lua <param1> <param2>

would call getopt with:

args = getopt({"param1", "param2"})
if args.param1 == "bar" then
    -- ..
end

If more arguments are present on the command line than are listed in params, the
excess are appended to the result as array items. For example:

foo.lua arg1 arg2 arg3

would result in args = { param1 = "arg1", param2 = "arg2", [1] = arg3 }

Options
=======

Options are specified using <optionName> = <specifier> syntax.

Boolean options (ie, options that do not take an additional parameter) are
specified as optionName=true, for example:

foo.lua --bar

would be parsed using:

args = getopt({bar = true})
-- args is { bar = 1 } if --bar was specified

Boolean options all support being specified multiple times, in which case the
count of how many times it was specified is what is returned.

String options (ie options that consume an additional parameter) are specified
as optionName=string, for example:

foo.lua --param "Parameter value"

would be parsed using:

args = getopt({param = string})
-- args is { param = "Parameter value" }

Equivalent short options can be specified with the syntax
{ <shortOpt> = "<longOpt>" }. For example, to accept -p as equivalent to --param
in the above example, you'd write:

args = getopt({param = string, p = "param"})

The result will always use the long opt name even if the short option was used
on the commandline.

Combining options and positional arguments
===============================

Options (using the dictionary part of the params table) and positional
arguments (using the array part of the params table) can be combined. For
example, to parse a command line like:

foo.lua bar baz -i widgets -v -v

you'd call:

args = getopt({
    "param1",
    "param2",
    include = string, i = "include",
    verbose = true, v = "verbose",
})
-- args is { param1 = "bar", param2 = "baz", include = "widgets", verbose = 2 }

]]
function getopt(params)
    local simulateHelp = false
    if not params.help then
        params.help = true
        simulateHelp = true
        if not params.h then
            params.h = "help"
        end
    end
    local result = {}
    -- Set up any table results
    for k, v in pairs(params) do
        if v == table then
            result[k] = {}
        end
    end
    local positionalIdx = 1
    local i = 1
    local postDashDash = false
    local function handleOpt(opt)
        local optType = params[opt]
        if opt == "" then
            postDashDash = true
        elseif optType == true then
            result[opt] = (result[opt] or 0) + 1
        elseif optType == string then
            i = i + 1
            local val = args[i]
            assert(val, "No value for option --"..opt)
            result[opt] = val
        elseif optType == table then
            i = i + 1
            local val = args[i]
            assert(val, "No value for option --"..opt)
            table.insert(result[opt], val)
        elseif optType == nil then
            error("Unhandled option --"..opt)
        else
            error("Unrecognised option parameter")
        end
    end
    while i <= #args do
        local arg = args[i]
        local opt = not postDashDash and arg:match("^%-%-(.*)")
        if opt then
            handleOpt(opt)
        elseif not postDashDash and arg:match("^%-.$") then
            local shortopt = arg:sub(2)
            local longOpt = params[shortopt]
            assert(longOpt, "No long option for short opt "..arg)
            handleOpt(longOpt)
        else
            local argName = params[positionalIdx]
            if argName then
                result[argName] = arg
            else
                table.insert(result, arg)
            end
            positionalIdx = positionalIdx + 1
        end
        i = i + 1
    end

    if simulateHelp and result.help then
        printHelp(params)
        os.exit(false)
    end

    return result
end

function readFile(filename)
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()
    return data
end

function writeFile(filename, data)
    local f = assert(io.open(filename, "wb"))
    f:write(data)
    f:close()
end

function pcallMain()
    local runtime = require("runtime")
    local ok, err = xpcall(main, runtime.traceback)
    if not ok then
        if err.src then
            printf("%s:%d:%d: ", err.src.path, err.src.line, err.src.column)
        end
        print(err.msg)
        print(err.luaStack)
        os.exit(false)
    end
end
