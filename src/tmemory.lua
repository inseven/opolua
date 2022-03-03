#!/usr/local/bin/lua-5.3

--[[

Copyright (c) 2022 Jason Morley, Tom Sutcliffe

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

local EWord = DataTypes.EWord
local ELong = DataTypes.ELong
local EReal = DataTypes.EReal
local EString = DataTypes.EString
local EWordArray = DataTypes.EWordArray
local ELongArray = DataTypes.ELongArray
local ERealArray = DataTypes.ERealArray
local EStringArray = DataTypes.EStringArray

function asserteq(a, b)
    if a ~= b then
        error(string.format('Assertion failed: "%s" != "%s"\n', hexEscape(tostring(a)), hexEscape(tostring(b))), 2)
    end
end

function checkFreeList(chunk, expected)
    asserteq(chunk:freeCellListStr(), expected)
end

function main()
    memory = require("memory")
    Chunk = memory.Chunk

    -- Start with some tests of the raw Chunk API
    local chunk = Chunk {}
    asserteq(chunk:read(0, 1), "\0")
    asserteq(chunk:read(1, 1), "\0")
    asserteq(chunk:read(2, 1), "\0")
    chunk:write(1, "\x12")
    -- chunk:dump()
    asserteq(chunk:read(0, 1), "\0")
    asserteq(chunk:read(1, 1), "\x12")
    asserteq(chunk:read(2, 1), "\0")
    asserteq(chunk:read(1, 2), "\x12\0")
    asserteq(chunk:read(1, 3), "\x12\0\0")

    chunk:write(0x45, "opoluarocks!")
    -- chunk:dump()
    asserteq(chunk:read(0x46, 9), "poluarock")
    asserteq(chunk:read(0x45, 11), "opoluarocks")
    asserteq(chunk:read(0x44, 4), "\0opo")
    asserteq(chunk:read(0x43, 5), "\0\0opo")
    asserteq(chunk:read(0x43, 15), "\0\0opoluarocks!\0")

    chunk:clear(0x48, 4)
    -- chunk:dump()
    asserteq(chunk:read(0x47, 7), "o\0\0\0\0oc")

    -- Now test the Variable abstraction

    local v = chunk:getVariableAtOffset(0x44, EString)
    v:fixup(16) -- sets the max len
    asserteq(v:stringMaxLen(), 16)
    chunk:write(0x44, "\x03") -- sets the length byte
    -- Because of where we've put it, there should already be data in there
    asserteq(v(), "opo")

    v("Hello world")
    -- chunk:dump()
    asserteq(chunk:read(0x44, 12), "\x0BHello world")
    asserteq(v(), "Hello world")
    -- Check that the above assignment to v didn't nuke the bytes immediately after the end of the set data
    chunk:write(0x44, "\x0C")
    asserteq(v(), "Hello world!")

    local ok, err = pcall(v, "This is too long...")
    assert(not ok and err == KErrStrTooLong, "Too long string assignment didn't fail!")

    local intv = chunk:getVariableAtOffset(0x12, EWord)
    asserteq(intv(), 0)
    intv(0x1729)
    -- chunk:dump()
    asserteq(intv(), 0x1729)
    asserteq(chunk:read(0x11, 4), "\0\x29\x17\0")

    local intv2 = chunk:getVariableAtOffset(0x14, EWord)
    intv2(-1966)
    asserteq(intv(), 0x1729)
    asserteq(intv2(), -1966)
    -- chunk:dump()

    intv(-1)
    asserteq(intv(), -1)

    -- int array tests
    chunk:clear(0, 0x50)
    local intarr = chunk:getVariableAtOffset(0x4, ELongArray)
    intarr:fixup(nil, 5)
    -- chunk:dump()

    asserteq(intarr[1](), 0)
    intarr[1](-1234)
    asserteq(intarr[1](), -1234)
    -- And the new convenience syntax
    intarr[2] = 1235
    asserteq(intarr[2](), 1235)

    ok, err = pcall(function() return intarr[99] end)
    assert(not ok)

    local strarr = chunk:getVariableAtOffset(0x10, EStringArray)
    strarr:fixup(6, 3)
    local stringArrayVar = strarr[3]
    asserteq(stringArrayVar:stringMaxLen(), 6)
    stringArrayVar("Howdy!")
    asserteq(stringArrayVar(), "Howdy!")
    strarr[2] = "Previo"
    -- chunk:dump()
    asserteq(stringArrayVar(), "Howdy!")

    -- alloc tests

    chunk = Chunk()
    chunk:setSize(100)
    chunk.maxIdx = 16
    checkFreeList(chunk, "4+100")

    local function checkAlloc(sz)
        local result = chunk:alloc(sz)
        asserteq(chunk[result//4 - 1], ((sz+3)&~3)+4) -- Heap cell size must always be 4 bigger than we requested
        return result
    end

    local alloc = checkAlloc(16)
    -- printf("%X\n", alloc)
    asserteq(alloc, 8)
    checkFreeList(chunk, "24+80")
    chunk:write(alloc, "\x0FHello world!!!!")

    local al2 = checkAlloc(4)
    asserteq(al2, 8+16+4)
    chunk:write(al2, "zzzz")

    chunk:free(al2)
    -- chunk:dump()
    checkFreeList(chunk, "24+80")

    asserteq(checkAlloc(4), al2)
    local al3 = checkAlloc(4)
    asserteq(al3, 36)
    local al4 = checkAlloc(4)
    checkFreeList(chunk, "48+56")
    chunk:free(al3)
    -- chunk:dump()
    checkFreeList(chunk, "32+8,48+56")
    chunk:free(al2)
    checkFreeList(chunk, "24+16,48+56")
    chunk:free(al4)
    checkFreeList(chunk, "24+80")
    chunk:free(alloc)
    checkFreeList(chunk, "4+100")
    -- chunk:dump()
end

main()
