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

local compiler = require("compiler")
local decompiler = require("decompiler")
local opofile = require("opofile")
local Int, Long, Float, String = compiler.Int, compiler.Long, compiler.Float, compiler.String
local opcodes, fncodes = compiler.opcodes, compiler.fncodes

local EWord = DataTypes.EWord
local ELong = DataTypes.ELong
local EReal = DataTypes.EReal
local EString = DataTypes.EString
local EWordArray = DataTypes.EWordArray
local ELongArray = DataTypes.ELongArray
local ERealArray = DataTypes.ERealArray
local EStringArray = DataTypes.EStringArray

local oplFormat = compiler.OplEr5

local function assertEquals(a, b)
    local adump, bdump = dump(a), dump(b)
    if adump ~= bdump then
        error(string.format("%s != %s", adump, bdump))
    end
end

local function id(val)
    return { type = "identifier", val = val:upper() }
end

local function lit(val)
    return { type = val:sub(1,1) == '"' and "string" or "number", val = val }
end

local function percent(val)
    if type(val) ~= "table" then
        val = lit(val)
    end
    val.isPercentage = true
    return val
end

local function call(name, ...)
    return { type = "call", val = name, args = { ... } }
end

local function dyncall(name, ...)
    return { type = "dyncall", val = name, args = { ... } }
end

local function b(val)
    return string.pack("b", val)
end

local function B(val)
    return string.pack("B", val)
end

local function h(val)
    return string.pack("<h", val)
end

local function H(val)
    return string.pack("<H", val)
end

local function ConstantString(val)
    return string.pack("<Bs1", opcodes[oplFormat].ConstantString, val)
end

local function ConstantFloat(val)
    return string.pack("<Bd", opcodes[oplFormat].ConstantFloat, val)
end

local function ConstantLong(val)
    return string.pack("<Bi4", opcodes[oplFormat].ConstantLong, val)
end

local function op(name)
    local opcode = assert(opcodes[oplFormat][name], "Bad opcode name")
    if opcode >= 256 then
        return string.pack("BB", opcodes[oplFormat].NextOpcodeTable, opcode - 256)
    else
        return string.pack("B", opcode)
    end
end

local function fn(name)
    return string.pack("BB", opcodes[oplFormat].CallFunction, assert(fncodes[oplFormat][name], "Bad fn name"))
end

local function Global(name, type, offset)
    return { name = name, type = type, offset = offset }
end

local function Subproc(name, numParams, offset)
    return { name = name, numParams = numParams, offset = offset }
end

local function External(name, type)
    return { name = name, type = type }
end

local function checklex(text, expected)
    local tokens = compiler.lex(text, nil, compiler.OplEr5Language)
    local function assertEquals(a, b)
        local adump, bdump = dump(a), dump(b)
        if adump ~= bdump then
            for i, tok in ipairs(tokens) do
                printf("tokens[%d] = { type = %s, val = %s }\n", i, tok.type, tok.val)
            end
            error(string.format("%s != %s", adump, bdump))
        end
    end

    assertEquals(#tokens, #expected)
    for i, expectedTok in ipairs(expected) do
        if type(expectedTok) == "string" then
            assertEquals(tokens[i].type, expectedTok)
        else
            assertEquals(tokens[i].type, expectedTok.type)
            assertEquals(tokens[i].val, expectedTok.val)
        end
    end
end

local function stripTokenSources(expression)
    if type(expression) ~= "table" then
        return expression
    end

    if expression.type then
        local args
        if expression.args then
            args = {}
            for i, arg in ipairs(expression.args) do
                args[i] = stripTokenSources(arg)
            end
        end
        return { type = expression.type, val = expression.val, args = args, isPercentage = expression.isPercentage }
    else
        return {
            op = expression.op,
            isPercentage = expression.isPercentage,
            stripTokenSources(expression[1]),
            stripTokenSources(expression[2]),
        }
    end
end

local function checkExpression(text, expected)
    local tokens = compiler.lex(text, nil, compiler.OplEr5Language)
    tokens.oplFormat = compiler.OplEr5
    local ok, result = xpcall(function() return stripTokenSources(compiler.parseExpression(tokens)) end, debug.traceback)
    if not ok then
        print("Current token", table.unpack(tokens:current()))
        error(result)
    end
    assertEquals(result, expected)
end

local function checkNumber(text, expectedType, expectedVal)
    local type, result = compiler.literalToNumber(text)
    assertEquals(type, expectedType)
    assertEquals(result, expectedVal)
end

local function checkProg(prog, expected)
    local dummyPath = "C:\\module"
    local ok, progObj = xpcall(compiler.docompile, debug.traceback, dummyPath, nil, prog, {}, oplFormat)
    if not ok then
        error(dump(progObj))
    end

    local opoData = opofile.makeOpo(progObj)
    local procTable, opxTable = opofile.parseOpo(opoData)
    assertEquals(#procTable, #expected)
    for procIdx, proc in ipairs(procTable) do
        local expectedProc = expected[procIdx]
        local code = proc.data:sub(1 + proc.codeOffset, proc.codeOffset + proc.codeSize)

        -- Remove things we don't care about from proc (because we validate the more-derived data parseProc adds)
        local minimalProc = {}
        for k, v in pairs(proc) do
            minimalProc[k] = v
        end
        for _, member in ipairs{"source", "offset", "data", "lineNumber", "codeOffset", "codeSize", "maxStack"} do
            minimalProc[member] = nil
        end

        for _, member in ipairs{"arrays", "externals", "globals", "params", "strings", "subprocs", "vars"} do
            if expectedProc[member] == nil then
                expectedProc[member] = {}
            end
        end
        if not expectedProc.iDataSize then
            expectedProc.iDataSize = 18
        end
        if not expectedProc.iTotalTableSize then
            expectedProc.iTotalTableSize = 0
        end
        if procIdx == 1 and expectedProc.name == nil then
            expectedProc.name = "MAIN"
        end

        local expectedCode = {}
        for i, instr in ipairs(expectedProc) do
            if type(instr) == "number" then
                expectedCode[i] = B(instr)
            else
                expectedCode[i] = instr
            end
            expectedProc[i] = nil
        end
        expectedCode = table.concat(expectedCode)

        if dump(expectedProc) ~= dump(minimalProc) then
            print(dump(minimalProc))
            print(dump(expectedProc))
            error("Proc metadata did not match")
        end

        if code ~= expectedCode then
            local rt = require("runtime").newRuntime()
            rt:addModule(dummyPath, opofile.parseOpo(opoData))
            printf("%s:\n", proc.name)
            rt:dumpProc(proc.name)
            error("Generated code did not match")
        end
    end

    if progObj.aif and progObj.aif.icons then
        -- Strip the tokens, they aren't useful to test
        for _, icon in ipairs(progObj.aif.icons) do
            icon.token = nil
        end
    end

    assertEquals(progObj.aif, expected.aif)
    assertEquals(opxTable, expected.opxTable)

    -- Now check we can decompile it
    local output = {}
    local function outputFn(location, ...)
        table.insert(output, string.format(...))
    end
    assert(decompiler.decompile(procTable, {
        opxTable = opxTable,
        format = compiler.OplEr5,
        annotate = false,
        outputFn = outputFn,
    }))
    local decompiledText = table.concat(output)
    -- And that the decompiled output compiles, and that when we decompile _that_ we get the same text as from the first
    -- decompile.
    ok, recompiledProgObj = xpcall(compiler.docompile, debug.traceback, dummyPath, nil, decompiledText, {}, compiler.OplEr5)
    if not ok then
        print(decompiledText)
        error(dump(recompiledProgObj))
    end
    local recompiledOpoData = opofile.makeOpo(recompiledProgObj)
    local procTable, opxTable = opofile.parseOpo(opoData)
    output = {}
    assert(decompiler.decompile(procTable, {
        opxTable = opxTable,
        format = compiler.OplEr5,
        annotate = false,
        outputFn = outputFn,
    }))
    local secondDecompileText = table.concat(output)
    assertEquals(decompiledText, secondDecompileText)
end

local checkCodeWrapper = [[
    CONST ci%% = -123
    PROC main:
%s
%s
    ENDP
]]

local function checkCodeRet(statement, expectedCode)
    expectedCode.iTotalTableSize = 0
    expectedCode.iDataSize = 18
    -- Conditionally add i% and/or l& local variables, if statement mentions them
    local locals = {}
    local localsDecl
    if statement:match("i%%") then
        expectedCode.iDataSize = expectedCode.iDataSize + 2
        table.insert(locals, "i%")
    end
    if statement:match("l&") then
        expectedCode.iDataSize = expectedCode.iDataSize + 4
        table.insert(locals, "l&")
    end
    if #locals == 0 then
        localsDecl = ""
    else
        localsDecl = "LOCAL "..table.concat(locals, ", ").."\n"
    end
    local prog = string.format(checkCodeWrapper, localsDecl, statement)
    checkProg(prog, { expectedCode })
end

local function checkCode(statement, expectedCode)
    table.insert(expectedCode, op"ZeroReturnFloat")
    checkCodeRet(statement, expectedCode)
end

local function checkSyntaxError(statement, expectedError)
    local prog = string.format(checkCodeWrapper, "", statement)
    local ok, err = pcall(compiler.docompile, "C:\\module", nil, prog, {}, compiler.OplEr5)
    assert(not ok, "Compile unexpectedly succeeded!")
    assert(err.src, "Error didn't include src!? "..tostring(err))
    -- Line number should always be 4 because that's where checkCodeWrapper puts statement
    local expectedErrWithPrefix = "C:\\module:4:" .. expectedError
    local errStr = string.format("%s:%d:%d: %s", err.src.path, err.src.line, err.src.column, err.msg)
    assertEquals(errStr, expectedErrWithPrefix)
end

checklex("print a% --3.14e1 ** 2,", { id"PRINT", id"a%", "sub", "sub", lit"3.14e1", "pow", lit"2", "comma", "eos" })
checklex('string:"abc""" "def"\n', { id"STRING:", lit'"abc"""', lit'"def"', "eos"})
checklex("( woop + &300", { "oparen", id"WOOP", "add", lit"&300", "eos" })
checklex("Rem comment:\nREMnot a comment", { "eos", id"REMNOT", id"a", id"comment", "eos"})
checklex('@%("name")', { { type="dyncall", val="@%" }, "oparen", lit'"name"', "cloparen", "eos" })
checklex("a1: a1:: a1%::", { id"a1:", {type="label", val="A1::"}, id"A1%:", {type="colon", val=":"}, "eos" })
checklex("1+2%", { lit"1", "add", lit"2", "percent", "eos"})

-- Check all callables resolve
for cmd, callable in pairs(compiler.Callables) do
    if callable.type == "fn" then
        if callable.name == nil then
            local handler = "handleFn_"..cmd
            assert(compiler[handler], "Missing implementation of "..handler)
        else
            local found = compiler.fncodes[compiler.OplEr5][callable.name] or
                compiler.fncodes[compiler.Opl93][callable.name]
            assert(found, "No fncode for "..callable.name)
        end
    elseif callable.type == "op" then
        if callable.name == nil then
            local handler = "handleOp_"..cmd
            assert(compiler[handler], "Missing implementation of "..handler)
        else
            local found = compiler.opcodes[compiler.OplEr5][callable.name] or
                compiler.opcodes[compiler.Opl93][callable.name]
            assert(found, "No opcode for "..callable.name)
            if callable.args.numParams then
                assert(callable.args.numFixedParams, cmd.." specifies numParams but not numFixedParams")
            end
        end
    else
        error("Bad callable type!")
    end
end

checkExpression("a", id"a" )

checkExpression("a + b * c", { id"a", op="add", { id"b", op="mul", id"c" } })

checkExpression("(a + b) * c", { { id"a", op="add", id"b" }, op="mul", id"c"})

checkExpression("not a", { {}, op="NOT", id"a" })

checkExpression("not a or b", { { {}, op="NOT", id"a" }, op="OR", id"b"})

checkExpression("a ** b + c", { { id"a", op="pow", id"b" }, op="add", id"c" } )

checkExpression("a ** b ** c + d", { { id"a", op="pow", { id"b", op="pow", id"c" } }, op="add", id"D" })

checkExpression("not not a or b", { { {}, op="NOT", { {}, op="NOT", id"a" } }, op="OR", id"b" })

checkExpression("not not a ** b", { {}, op="NOT", { {}, op="NOT", { id"a", op="pow", id"b" } } })

checkExpression("a or not not b", { id"a", op="OR", { {}, op="NOT", { {}, op="NOT", id"b" } } })

checkExpression("a - b", { id"a", op="sub", id"b" })

checkExpression("a - -b", { id"a", op="sub", { {}, op="unm", id"b" } })

checkExpression("a-(-b)", { id"a", op="sub", { {}, op="unm", id"b" } })

checkExpression("1 + DOW(DAY, MONTH, YEAR)", { lit"1", op="add", call("DOW", id"DAY", id"MONTH", id"YEAR") })

checkExpression('"aa" + CHR$(7)', { lit'"aa"', op="add", call("CHR$", lit"7") })

checkExpression("proccall%:", id"PROCCALL%:")

checkExpression("proccall:(1+1, woop)", call("PROCCALL:", { lit"1", op="add", lit"1" }, id"woop"))

checkExpression('a + @%("name"):(b, c)', { id"a", op="add", dyncall("@%", lit'"name"', id"b", id"c") })

checkExpression("1 + 2%", { lit"1", op="add", percent"2" })

checkExpression("1 + 2 + 3%", {{ lit"1", op="add", lit"2" }, op="add", percent"3" })

checkExpression("1 + (2 + 3)%", { lit"1", op="add", percent{ lit"2", op="add", lit"3" } })

-- checkExpression("a b", {})

checkNumber("123", Int, 123)
checkNumber("123.0", Float, 123.0)
checkNumber("32767", Int, 32767)
checkNumber("32768", Long, 32768)
checkNumber("123456", Long, 123456)
checkNumber("1e2", Float, 100.0)
checkNumber("1E+2", Float, 100.0)
checkNumber("$8000", Int, -32768) -- KMinInt
checkNumber("&8000", Long, 32768)
checkNumber("&80000000", Long, -2147483648) -- KMinLong
checkNumber("2147483648", Float, 2147483648)

checkCode("CHR$(&7)", {
    op"StackByteAsLong", 7,
    op"LongToInt",
    fn"ChrStr",
    op"DropString",
})

checkCode('PRINT "wat", i%', {
    ConstantString("wat"),
    op"PrintString",
    op"PrintSpace",
    op"SimpleDirectRightSideInt", H(0x12),
    op"PrintInt",
    op"PrintCarriageReturn",
})

checkCode('PRINT 1;2;', {
    op"StackByteAsWord", 1,
    op"PrintInt",
    op"StackByteAsWord", 2,
    op"PrintInt",
})

checkCode("i% = ci%", {
    op"SimpleDirectLeftSideInt", H(0x12),
    op"StackByteAsWord", b(-123),
    op"AssignInt",
})

checkCodeRet("", {
    op"ZeroReturnFloat"
})

checkCodeRet("RETURN", {
    op"ZeroReturnFloat"
})

checkCodeRet("RETURN 0", {
    op"StackByteAsWord", 0,
    op"IntToFloat",
    op"Return"
})

checkCode("CHR$(1+2*&3)", {
    op"StackByteAsWord", 1,
    op"IntToLong",
    op"StackByteAsWord", 2,
    op"IntToLong",
    op"StackByteAsLong", 3,
    op"MultiplyLong",
    op"AddLong",
    op"LongToInt",
    fn"ChrStr",
    op"DropString",
})

-- This is horrible, but that really is what OPL does. INT really shouldn't be the thing to use here, since it really
-- is for converting floats to longs, but there isn't a dedicated "force int to long" cmd that doesn't force a float
-- intermediary. Of course there is that available by type coercing, but if you want to do it explicitly, you have to
-- do it by a type coercion to float followed by a float-to-long command.
checkCode("CHR$(INT(4))", {
    op"StackByteAsWord", 4,
    op"IntToFloat",
    fn"IntLong",
    op"LongToInt",
    fn"ChrStr",
    op"DropString",
})

checkCodeRet("RETURN 1.0/3", {
    ConstantFloat(1.0),
    op"StackByteAsWord", 3,
    op"IntToFloat",
    op"DivideFloat",
    op"Return",
})

checkCodeRet("RETURN 1/3.0", {
    op"StackByteAsWord", 1,
    op"IntToFloat",
    ConstantFloat(3.0),
    op"DivideFloat",
    op"Return",
})

checkCode('@%("foo"):("bar")', {
    ConstantString("foo"),
    ConstantString("bar"),
    op"StackByteAsWord", DataTypes.EString,
    op"CallProcByStringExpr", 1, "%",
    op"DropInt",
})

-- Check we handle >256 opcodes
checkCode("DEFAULTWIN 5", {
    op"StackByteAsWord",
    5,
    -- op"DefaultWin",
    0xFF,
    1,
})

checkCode([[LOADM "Z:\System\OPL\TOOLBAR.OPO"]], {
    ConstantString([[Z:\System\OPL\TOOLBAR.OPO]]),
    op"LoadM",
})

checkCode('ALERT("single")', {
    ConstantString("single"),
    fn"Alert",
    1,
    op"DropInt",
})

checkCode('dBUTTONS "OK", 13, "Cancel", -27, "Tab", 9, "A", %a, "B", -%b', {
    ConstantString("OK"),
    op"StackByteAsWord", 13,
    ConstantString("Cancel"),
    op"StackByteAsWord", 27,
    op"UnaryMinusInt",
    ConstantString("Tab"),
    op"StackByteAsWord", 9,
    ConstantString("A"),
    op"StackByteAsWord", 97,
    ConstantString("B"),
    op"StackByteAsWord", 98,
    op"UnaryMinusInt",
    op"dItem", 10, 5,
})

checkCode('dCHECKBOX i%, "Prompt"', {
    op"SimpleDirectLeftSideInt", h(0x12),
    ConstantString("Prompt"),
    op"dEditCheckbox",
})

-- numParams/qualifier on Ops is so inconsistent...
-- gBORDER is normal, gPRINTB doesn't include first arg in its numParams (which we represent by numFixedParams=1)
checkCode("gBORDER 0 : gBORDER 0, 1, 2", {
    op"StackByteAsWord", 0,
    op"gBorder", 1,
    op"StackByteAsWord", 0,
    op"StackByteAsWord", 1,
    op"StackByteAsWord", 2,
    op"gBorder", 3,
})

checkCode('gPRINTB "Wat", 11, 22', {
    ConstantString("Wat"),
    op"StackByteAsWord", 11,
    op"StackByteAsWord", 22,
    op"gPrintBoxText", 2,
})

checkCode("gUPDATE OFF", {
    op"gUpdate",
    0,
})

checkCode("PRINT A.Foo& + R.Bar%;", {
    ConstantString("FOO&"),
    op"FieldRightSideLong", 0,
    ConstantString("BAR%"),
    op"FieldRightSideInt",
    string.byte("R") - string.byte("A"),
    op"IntToLong",
    op"AddLong",
    op"PrintLong",
})

checkCode("B.foo = A.bar", {
    ConstantString("FOO"),
    op"FieldLeftSideFloat", 1,
    ConstantString("BAR"),
    op"FieldRightSideFloat", 0,
    op"AssignFloat",
})

checkCode("ADDR(i%)", {
    op"SimpleDirectLeftSideInt", h(0x12),
    fn"Addr",
    op"DropLong",
})

checkCode("ADDR(l&)", {
    op"SimpleDirectLeftSideLong", h(0x12),
    fn"Addr",
    op"DropLong",
})

checkCode("IOC(0, 1, i%, l&)", {
    op"StackByteAsWord", 0,
    op"StackByteAsWord", 1,
    op"SimpleDirectLeftSideInt", h(0x12),
    fn"Addr",
    op"SimpleDirectLeftSideLong", h(0x14),
    fn"Addr",
    fn"Ioc", 4,
    op"DropInt",
})

checkCode("USE z", {
    op"Use",
    25,
})

checkCodeRet("RETURN 1 + 2%", {
    op"StackByteAsWord", 1,
    op"IntToFloat",
    op"StackByteAsWord", 2,
    op"IntToFloat",
    op"PercentAdd",
    op"Return",
})

checkCode('DELETE "foo"', {
    ConstantString("foo"),
    op"Delete",
})

checkCode('DELETE "foo", "bar"', {
    ConstantString("foo"),
    ConstantString("bar"),
    op"DeleteTable",
})

checkCode("gVISIBLE ON", {
    op"gVisible", 1,
})

checkCode("CURSOR OFF", {
    op"Cursor", 0,
})

checkCode("CURSOR ON", {
    op"Cursor", 1,
})

checkCode("CURSOR 1, 2, 3, 4", {
    op"StackByteAsWord", 1,
    op"StackByteAsWord", 2,
    op"StackByteAsWord", 3,
    op"StackByteAsWord", 4,
    op"Cursor", 3,
})

checkCode("CURSOR 1, 2, 3, 4, 5", {
    op"StackByteAsWord", 1,
    op"StackByteAsWord", 2,
    op"StackByteAsWord", 3,
    op"StackByteAsWord", 4,
    op"StackByteAsWord", 5,
    op"Cursor", 4,
})

checkCode('mPOPUP(1, 2, 0, "a", 0)', {
    op"StackByteAsWord", 1,
    op"StackByteAsWord", 2,
    op"StackByteAsWord", 0,
    ConstantString("a"),
    op"StackByteAsWord", 0,
    fn"mPopup", 5,
    op"DropInt",
})

checkCode('MENU', {
    fn"Menu",
    op"DropInt",
})

checkCode('OFF : OFF 5', {
    op"Off",
    op"StackByteAsWord", 5,
    op"OffFor",
})

checkSyntaxError("ALERT()", "1: Zero-argument calls should not have ()")

checkSyntaxError("alert(a$, b$, c$, d$, e$, f$)", "1: Wrong number of arguments to ALERT")

checkSyntaxError("PRINT 1, ASC(123)", "10: Argument 1 type Int not compatible with declaration type String")

checkSyntaxError("ASC(A$", "7: Expected token cloparen")

checkSyntaxError("ASC(A$, ,)", "9: Expected expression")

checkSyntaxError(" ASC(A$, B$)", "2: Expected 1 args to ASC, not 2")

-- First of these is fine, hence the check for column=41
checkSyntaxError("LOCAL a1234567890123456789012345678901, a12345678901234567890123456789012", "41: Variable name is too long")

checkSyntaxError("a12345678901234567890123456789012 = 1", "1: Variable name is too long")

checkSyntaxError("LOCAL f$(256)", "10: String is too long")

checkSyntaxError("LOCAL a&(30000)", "7: Procedure variables exceed maximum size")

checkSyntaxError("MAX", "1: Wrong number of arguments to MAX")

checkSyntaxError('mPOPUP(1, 2, 0, "a")', "1: Wrong number of arguments to mPOPUP")
-- Cannot have an additional item without another key arg
checkSyntaxError('mPOPUP(1, 2, 0, "a", 0, "b")', "1: Wrong number of arguments to mPOPUP")

checkSyntaxError("PRINT AND 1", "7: Expected operand")
checkSyntaxError("PRINT 1 AND AND 1", "13: Expected operand")
checkSyntaxError("PRINT 1 == 1", "10: Expected operand")

callbystr = [[
PROC main:
    @("woop"):(1)
ENDP

PROC woop:(x%)
    PRINT x%;
ENDP
]]

checkProg(callbystr, {
    {
        name = "MAIN",
        ConstantString("woop"),
        op"StackByteAsWord", 1,
        op"StackByteAsWord", 0,
        op"CallProcByStringExpr", 1, 0,
        op"DropFloat",
        op"ZeroReturnFloat",
    },
    {
        name = "WOOP",
        params = { EWord },
        vars = {
            [18] = { indirectIdx = 18, name = "param_1%", type = EWord },
        },
        iDataSize = 20,
        op"SimpleInDirectRightSideInt", H(0x0012),
        op"PrintInt",
        op"ZeroReturnFloat",
    }
})

globint = [[
PROC main:
    LOCAL bar&
    GLOBAL foo&
    GLOBAL unused&
    foo& = 6
    bar& = 124
    fn:(bar&)
ENDP

PROC fn:(x&)
    LOCAL fnloc&
    GLOBAL nest&
    fnloc& = &B00B5
    PRINT foo&;
    REM PRINT x&
    RETURN fn2&: + x&
ENDP

PROC fn2&:
    RETURN nest& + 3
ENDP
]]
-- This is a good test of all kinds of offset and indirectIdx related funsies
checkProg(globint, {
    {
        name = "MAIN",
        globals = {
            Global("FOO&", ELong, 0x29),
            Global("UNUSED&", ELong, 0x2D),
        },
        subprocs = {
            Subproc("FN", 1, 0x25),
        },
        vars = {
            [0x29] = { directIdx = 0x29, name = "FOO&", type = ELong, isGlobal = true },
            [0x2D] = { directIdx = 0x2D, name = "UNUSED&", type = ELong, isGlobal = true },
        },
        iDataSize = 53,
        iTotalTableSize = 23,

        op"SimpleDirectLeftSideLong", H(0x0029),
        op"StackByteAsWord", 6,
        op"IntToLong",
        op"AssignLong",
        op"SimpleDirectLeftSideLong", H(0x0031),
        op"StackByteAsWord", 124,
        op"IntToLong",
        op"AssignLong",
        op"SimpleDirectRightSideLong", H(0x0031),
        op"StackByteAsWord", 1,
        op"RunProcedure", H(0x0025),
        op"DropFloat",
        op"ZeroReturnFloat",
    },
    {
        name = "FN",
        params = { ELong },
        globals = {
            Global("NEST&", ELong, 0x25),
        },
        subprocs = {
            Subproc("FN2&", 0, 0x1B),
        },
        externals = {
            External("FOO&", ELong),
        },
        vars = {
            [0x21] = { indirectIdx = 0x21, name = "param_1&", type = ELong },
            [0x23] = { indirectIdx = 0x23, name = "FOO&", type = ELong },
            [0x25] = { directIdx = 0x25, name = "NEST&", type = ELong, isGlobal = true },
        },
        iDataSize = 45,
        iTotalTableSize = 15,

        op"SimpleDirectLeftSideLong", H(0x0029),
        ConstantLong(0xB00B5),
        op"AssignLong",
        op"SimpleInDirectRightSideLong", H(0x0023),
        op"PrintLong",
        op"RunProcedure", H(0x001B),
        op"SimpleInDirectRightSideLong", H(0x0021),
        op"AddLong",
        op"LongToFloat",
        op"Return",
    },
    {
        name = "FN2&",
        externals = {
            External("NEST&", ELong),
        },
        vars = {
            [0x12] = { indirectIdx = 0x12, name = "NEST&", type = ELong },
        },
        iDataSize = 20,

        op"SimpleInDirectRightSideLong", H(0x0012),
        op"StackByteAsWord", 3,
        op"IntToLong",
        op"AddLong",
        op"Return",
    }
})

globals = [[
PROC main:
    GLOBAL foo$(4)
    foo$ = "Baa"
    fn:(123, "yarp")
    GET
ENDP

PROC fn:(x%, y$)
    PRINT foo$;
    PRINT x%; y$;
ENDP
]]
checkProg(globals, {
    {
        globals = {
            Global("FOO$", EString, 0x1F),
        },
        subprocs = {
            Subproc("FN", 2, 0x1A),
        },
        strings = {
            [30] = 4,
        },
        vars = {
            [0x1F] = { directIdx = 0x1F, name = "FOO$", type = EString, maxLen = 4, isGlobal = true },
        },
        iDataSize = 36,
        iTotalTableSize = 12,

        op"SimpleDirectLeftSideString", H(0x001F),
        ConstantString("Baa"),
        op"AssignString",
        op"StackByteAsWord", 123,
        op"StackByteAsWord", 0,
        ConstantString("yarp"),
        op"StackByteAsWord", 3,
        op"RunProcedure", H(0x001A),
        op"DropFloat",
        fn"Get",
        op"DropInt",
        op"ZeroReturnFloat",
    },
    {
        name = "FN",
        params = { EWord, EString },
        externals = {
            External("FOO$", EString),
        },
        vars = {
            [0x12] = { indirectIdx = 0x12, name = "param_1%", type = EWord },
            [0x14] = { indirectIdx = 0x14, name = "param_2$", type = EString },
            [0x16] = { indirectIdx = 0x16, name = "FOO$", type = EString },
        },
        iDataSize = 24,
        op"SimpleInDirectRightSideString", H(0x0016),
        op"PrintString",
        op"SimpleInDirectRightSideInt", H(0x0012),
        op"PrintInt",
        op"SimpleInDirectRightSideString", H(0x0014),
        op"PrintString",
        op"ZeroReturnFloat",
    }
})

checkProg('include "const.oph"', {})

aiftest = [[
APP ThisIsIgnored, &10286F9C
    CAPTION "Welcome", 2
    ICON "welc.mbm"
ENDA
]]
checkProg(aiftest, {
    aif = {
        uid3 = 0x10286F9C,
        captions = {
            { 2, "Welcome" },
        },
        icons = {
            { path = "welc.mbm" },
        },
    },
})

dir = [[
PROC main:
    LOCAL d$(255)
    d$ = DIR$("C:\SYSTEM\APPS\")
    WHILE d$ <> ""
        PRINT d$
        d$ = DIR$("")
    ENDWH
ENDP
]]
checkProg(dir, {
    {
        strings = {
            [0x12] = 255,
        },
        vars = {
            [0x13] = { directIdx = 0x13, name = "local_0013$", type = EString, maxLen = 255 },
        },
        iDataSize = 275,

        op"SimpleDirectLeftSideString", H(0x0013),
        ConstantString("C:\x5CSYSTEM\x5CAPPS\x5C"),
        fn"DirStr",
        op"AssignString",
        op"SimpleDirectRightSideString", H(0x0013),
        ConstantString(""),
        op"CompareNotEqualString",
        op"BranchIfFalse", h(19),
        op"SimpleDirectRightSideString", H(0x0013),
        op"PrintString",
        op"PrintCarriageReturn",
        op"SimpleDirectLeftSideString", H(0x0013),
        ConstantString(""),
        fn"DirStr",
        op"AssignString",
        op"GoTo", h(-22),
        op"ZeroReturnFloat",
    }
})

extern = [[
DECLARE EXTERNAL

EXTERNAL sub:

PROC main:
    GLOBAL arr%(5)
    sub:
    PRINT arr%(5);
ENDP

PROC sub:
    EXTERNAL arr%()
    arr%(5) = 123
ENDP
]]
checkProg(extern, {
    {
        globals = {
            Global("ARR%", EWordArray, 0x21),
        },
        subprocs = {
            Subproc("SUB", 0, 0x1A),
        },
        arrays = {
            [0x1F] = 5,
        },
        vars = {
            [0x21] = { directIdx = 0x21, name = "ARR%", type = EWordArray, arraySz = 5, isGlobal = true },
        },
        iDataSize = 43,
        iTotalTableSize = 13,

        op"RunProcedure", H(0x1A),
        op"DropFloat",
        op"StackByteAsWord", 5,
        op"ArrayDirectRightSideInt", H(0x21),
        op"PrintInt",
        op"ZeroReturnFloat",
    },
    {
        name = "SUB",
        externals = {
            External("ARR%", EWordArray),
        },
        vars = {
            [0x12] = { indirectIdx = 0x12, name = "ARR%", type = EWordArray },
        },
        iDataSize = 20,

        op"StackByteAsWord", 5,
        op"ArrayInDirectLeftSideInt", H(0x12),
        op"StackByteAsWord", 123,
        op"AssignInt",
        op"ZeroReturnFloat",
    }
})

ifTest = [[
PROC main:
    LOCAL x%
    x% = 1
    IF x% = 0
        PRINT "Bad";
    ELSEIF x% = 1
        PRINT "Good";
    ELSE
        Print "ohnonotmore";
    ENDIF
    PRINT " Done"
ENDP
]]
checkProg(ifTest, {
    {
        iDataSize = 20,

        op"SimpleDirectLeftSideInt", H(0x0012),
        op"StackByteAsWord", 1,
        op"AssignInt",
        op"SimpleDirectRightSideInt", H(0x0012),
        op"StackByteAsWord", 0,
        op"CompareEqualInt",
        op"BranchIfFalse", h(12),
        ConstantString("Bad"),
        op"PrintString",
        op"GoTo", h(36),
        op"SimpleDirectRightSideInt", h(0x0012),
        op"StackByteAsWord", 1,
        op"CompareEqualInt",
        op"BranchIfFalse", h(13),
        ConstantString("Good"),
        op"PrintString",
        op"GoTo", h(17),
        ConstantString("ohnonotmore"),
        op"PrintString",
        ConstantString(" Done"),
        op"PrintString",
        op"PrintCarriageReturn",
        op"ZeroReturnFloat",
    }
})

opx = [[
DECLARE EXTERNAL
INCLUDE "SYSTEM.OXH"
INCLUDE "BMP.OXH"

PROC main:
    RETURN MOD&:(&1, &3)
ENDP
]]
checkProg(opx, {
    opxTable = {
        {
            name = "SYSTEM",
            uid = 0x1000025C,
            version = 257,
        }
    },
    {
        op"StackByteAsLong", 1,
        op"StackByteAsLong", 3,
        op"CallOpxFunc", 0, H(41),
        op"LongToFloat",
        op"Return",
    }
})

-- Check that KLong is considered a Long even though its raw value identifies it as an Int
constfu = [[
CONST KLong& = 1
PROC main:
    RETURN KLong& = &2
ENDP
]]
checkProg(constfu, {
    {
        op"StackByteAsLong", 1,
        op"StackByteAsLong", 2,
        op"CompareEqualLong",
        op"IntToFloat",
        op"Return"
    }
})

vector = [[
PROC main:
    vec:(5)
ENDP

PROC vec:(k%)
    LOCAL ret%
    VECTOR k%
        a, b, c, d, e, f
    ENDV
    PRINT "Out of range"
    a::
    b::
    c::
    d::
        GOTO nope
    e::
        PRINT "YES"
        GOTO exit
    f::
    nope::
        PRINT "OH NO"
    exit::
    GET
ENDP
]]
checkProg(vector, {
    {
        subprocs = {
            { name = "VEC", numParams = 1, offset = 18 },
        },
        iDataSize = 23,
        iTotalTableSize = 5,

        op"StackByteAsWord", 5,
        op"StackByteAsWord", 0,
        op"RunProcedure", h(0x0012),
        op"DropFloat",
        op"ZeroReturnFloat",
    },
    {
        name = "VEC",
        params = { EWord },
        vars = {
            [0x12] = { indirectIdx = 0x12, name = "param_1%", type = EWord },
        },
        iDataSize = 22,

        op"SimpleInDirectRightSideInt", h(0x0012),
        op"Vector", h(6),
        h(31),
        h(31),
        h(31),
        h(31),
        h(34),
        h(44),
        ConstantString("Out of range"),
        op"PrintString",
        op"PrintCarriageReturn",
        op"GoTo", h(13),
        ConstantString("YES"),
        op"PrintString",
        op"PrintCarriageReturn",
        op"GoTo", h(12),
        ConstantString("OH NO"),
        op"PrintString",
        op"PrintCarriageReturn",
        fn"Get",
        op"DropInt",
        op"ZeroReturnFloat",
    }
})

eval = [[
INCLUDE "const.oph"

PROC main:
    LOCAL n$(64)
    WHILE 1
        PRINT "Input expression: ";
        TRAP INPUT n$
        IF ERR=KErrEsc%
            BREAK
        ENDIF
        IF n$=""
            CONTINUE
        ENDIF
        ONERR checkerr
        PRINT n$;"=";EVAL(n$)
        ONERR OFF
        checkerr::
        IF ERR
            PRINT "Error"
            TRAP RAISE 0
        ENDIF
    ENDWH
ENDP
]]
checkProg(eval, {
    {
        strings = {
            [0x12] = 64,
        },
        vars = {
            [0x13] = { directIdx = 0x13, name = "local_0013$", type = EString, maxLen = 64 },
        },
        iDataSize = 84,

        op"StackByteAsWord", 1,
        op"BranchIfFalse", h(94),
        ConstantString("Input expression: "),
        op"PrintString",
        op"Trap",
        op"SimpleDirectLeftSideString", h(0x0013),
        op"InputString",
        fn"Err",
        op"StackByteAsWord", 0x8E,
        op"CompareEqualInt",
        op"BranchIfFalse", h(6),
        op"GoTo", h(57),
        op"SimpleDirectRightSideString", h(0x0013),
        ConstantString(""),
        op"CompareEqualString",
        op"BranchIfFalse", h(6),
        op"GoTo", h(-51),
        op"OnErr", h(21),
        op"SimpleDirectRightSideString", h(0x0013),
        op"PrintString",
        ConstantString("="),
        op"PrintString",
        op"SimpleDirectRightSideString", h(0x0013),
        fn"Eval",
        op"PrintFloat",
        op"PrintCarriageReturn",
        op"OnErr", h(0),
        fn"Err",
        op"BranchIfFalse", h(16),
        ConstantString("Error"),
        op"PrintString",
        op"PrintCarriageReturn",
        op"Trap",
        op"StackByteAsWord", 0,
        op"Raise",
        op"GoTo", h(-93),
        op"ZeroReturnFloat",
    },
})

addr = [[
PROC main:
    LOCAL l&
    LOCAL buf&(10)

    REM I think these are both valid (and behave the same)...
    l& = ADDR(buf&)
    l& = ADDR(buf&())

    l& = ADDR(buf&(2))
ENDP
]]
checkProg(addr, {
    {
        arrays = {
            [0x16] = 10,
        },
        vars = {
            [0x18] = { directIdx = 0x18, name = "local_0018", arraySz = 10 },
        },
        iDataSize = 64,

        op"SimpleDirectLeftSideLong", h(0x12),
        op"StackByteAsWord", 1,
        op"ArrayDirectLeftSideLong", h(0x18),
        fn"Addr",
        op"AssignLong",

        op"SimpleDirectLeftSideLong", h(0x12),
        op"StackByteAsWord", 1,
        op"ArrayDirectLeftSideLong", h(0x18),
        fn"Addr",
        op"AssignLong",

        op"SimpleDirectLeftSideLong", h(0x12),
        op"StackByteAsWord", 2,
        op"ArrayDirectLeftSideLong", h(0x18),
        fn"Addr",
        op"AssignLong",
        op"ZeroReturnFloat",
    }
})

dow = [[
PROC main:
    PRINT "Today is", DAYNAME$(DOW(DAY, MONTH, YEAR))
    REM these won't be expected to work at start/end of month
    REM but good enough for testing
    PRINT "Yesterday was", DAYNAME$(DOW(DAY-1, MONTH, YEAR))
    PRINT "Tomorrow will be", DAYNAME$(DOW(DAY + 1, MONTH, YEAR))
    GET
ENDP
]]

beep = [[

PROC main:
    BEEP 5, 300
    PRINT CHR$(7)
ENDP
]]

pause = [[
PROC main:
    LOCAL k%
    PRINT "Pausing..."
    KEY REM flush anything out
    PAUSE -100
    PRINT "Done"
    k% = KEY
    IF k% <> 0
        PRINT "Pause completed by keypress", k%
    ENDIF
    GET
ENDP
]]

simple = [[
PROC main:
    PRINT "hello world"
    wat:
    GET
ENDP

PROC wat:
    PRINT "Waaaat"
ENDP
]]


prog = compiler.docompile("D:\\const.oph", nil, require("includes.const_oph"), {}, compiler.OplEr5)
prog = compiler.docompile("D:\\beep.opl", nil, beep, {}, compiler.OplEr5)
prog = compiler.docompile("D:\\pause.opl", nil, pause, {}, compiler.OplEr5)
prog = compiler.docompile("D:\\simple.opl", nil, simple, {}, compiler.OplEr5)
prog = compiler.docompile("D:\\globint.opl", nil, globint, {}, compiler.OplEr5)
prog = compiler.docompile("D:\\globals.opl", nil, globals, {}, compiler.OplEr5)

-- progData = require("opofile").makeOpo(prog)
-- rt = require("runtime").newRuntime({ fsop = function(op) assert(op=="read"); return progData end })
-- rt.instructionDebug = true
-- rt:loadModule(prog.path)
-- opofile.printProc(rt:findProc("MAIN"))
-- rt:dumpProc("MAIN")

print("All tests passed.")
