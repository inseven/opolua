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
        json = true, j = "json",
        verbose = true, v = "verbose",
    })

    recognizer = require("recognizer")
    cp1252 = require("cp1252")
    local data = readFile(args.filename)

    local info = recognizer.recognize(data, true)

    -- replace any icons with the result of Bitmap:getMetadata()
    info = filter(info)

    if not info then
        info = { type = "unknown" }
    end
    if args.json then
        print(json.encode(info))
    else
        print(dump(info))
    end
end

-- This fn recursively iterates info and any table implementing getMetadata is replaced by the result of calling that
-- fn. This lets us filter out all icons/bitmaps without having to hardcode each type. We also use it to ensure all the
-- strings are UTF-8.
function filter(info)
    local t = type(info)
    if t == "table" then
        if type(info.getMetadata) == "function" then
            return info:getMetadata()
        else
            local result = {}
            for k, v in pairs(info) do
                result[k] = filter(v)
            end
            return result
        end
    elseif t == "string" then
        return cp1252.toUtf8(info)
    else
        return info
    end
end


pcallMain()
