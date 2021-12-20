#!/usr/local/bin/lua-5.3

--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

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

function main()
    local filename = arg[1]
    local dest = arg[2]
    require("init")
    sis = require("sis")
    local f = assert(io.open(filename, "rb"))
    local data = f:read("a")
    f:close()
    local sisfile = sis.parseSisFile(data, true)

    if not dest then
        for _, file in ipairs(sisfile.files) do
            printf("%s: %s len=%d\n", sis.FileType[file.type], file.dest, file.data and #file.data or 0)
        end
        return
    end

    for _, file in ipairs(sisfile.files) do
        if file.type == sis.FileType.File then
            extractFile(file, dest)
        end
    end
end

function extractFile(file, dest)
    local outName = dest.."/c/"..file.dest:sub(4):gsub("\\", "/")
    local dir = oplpath.dirname(outName)
    -- print(dir)
    os.execute(string.format('mkdir -p "%s"', dir))
    local f = assert(io.open(outName, "wb"))
    f:write(file.data)
    f:close()
end

main()