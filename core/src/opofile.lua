--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

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

_ENV = module()

-- POS MEANS 1-BASED LUA STRING POSITION. OFFSET OR INDEX MEANS ZERO BASED

EOplTranVersionOplS3 = 0x110F -- No idea what this should be called officially, I _think_ it's for pre-Series 3a devices
EOplTranVersionOpl1993 = 0x111F
EOplTranVersionOpler1 = 0x200A

KUidOpoLuaCompiler = 0x10286F9D

TOpoFileHeader16 = "<c16I2I2"

TOpoStoreHeader = "<I4I4I4I4I4"
TOpoRootStream = "<I4I2I2I4I4I4I2"
TOpoProcHeader = "<s1I4I2"

function parseOpo(data, verbose)
    local module = parseOpo2(data, verbose)
    return module.procTable, module.opxTable, module.era
end

function parseOpo2(data, verbose)
    local function vprintf(...)
        if verbose then
            printf(...)
        end
    end

    local result = {}
    local procTableIdx, opxTableIdx, srcNameIdx
    local tv
    if data:sub(1, 16) == "OPLObjectFile**\0" then
        -- SIBO format
        -- TOpoFileHeader16
        local sig, fileVersion, offset = string.unpack(TOpoFileHeader16, data)
        -- It appears nothing cares about fileVersion (seems to always be 1?)
        vprintf("OPL1993 version=%d offset=0x%08X\n", fileVersion, offset)
        -- TOpoModuleHeader16
        local totalSize, translatorVersion, minRunVersion, pti = string.unpack("<i4I2I2i4", data, 1 + offset)
        vprintf("translatorVersion: 0x%04X minRunVersion: 0x%04X\n", translatorVersion, minRunVersion)
        assert(translatorVersion == EOplTranVersionOplS3 or translatorVersion == EOplTranVersionOpl1993)
        assert(minRunVersion == EOplTranVersionOplS3 or minRunVersion == EOplTranVersionOpl1993)
        procTableIdx = pti
        opxTableIdx = 0 -- not supported in this version
        srcNameIdx = 0x14
        result.era = "sibo"
        tv = translatorVersion
    else
        -- TOpoStoreHeader
        local uid1, uid2, uid3, checksum, rootStreamIdx, pos = string.unpack(TOpoStoreHeader, data)
        assert(uid1 == KUidDirectFileStore, "Bad header uid1!")
        assert(require("crc").getUidsChecksum(uid1, uid2, uid3) == checksum, "Bad UID checksum!")
        -- assert(uid2 == KUidOPO, string.format("Bad header uid2 0x%08X", uid2))
        -- assert(uid3 == KUidOplInterpreter, "Bad header uid3!")
        vprintf("UID2: 0x%08X\n", uid2)
        vprintf("UID3: 0x%08X\n", uid3)
        -- printf("rootStreamIdx = 0x%x\n", rootStreamIdx)

        -- TOpoRootStream
        local interpreterUid, translatorVersion, minRunVersion, sni, pti, oti, debugFlag =
            string.unpack(TOpoRootStream, data, rootStreamIdx+1)

        -- printf("Interpreter UID: 0x%08X\n", interpreterUid)
        -- assert(interpreterUid == KUidOplInterpreter, "Bad interpreterUid!")
        vprintf("translatorVersion: 0x%04X minRunVersion: 0x%04X\n", translatorVersion, minRunVersion)
        assert(translatorVersion == EOplTranVersionOpler1, "Unexpected translatorVersion!")
        assert(minRunVersion == EOplTranVersionOpler1, "Unexpected minRunVersion!")
        srcNameIdx = sni
        procTableIdx = pti
        opxTableIdx = oti
        result.era = "er5"
        result.uid3 = uid3
        tv = translatorVersion
    end

    local sourceName
    if srcNameIdx > 0 then
        sourceName = string.unpack("<s1", data, srcNameIdx + 1)
        local unNullTerminated = sourceName:match("^(.*)\0$")
        if unNullTerminated then
            -- SIBO format can include a null terminator here
            sourceName = unNullTerminated
        end
        vprintf("Source name: %s\n", sourceName)
    end

    result.procTable = {}
    vprintf("procTableIdx: 0x%08X\n", procTableIdx)

    local nextProcIdx = procTableIdx
    while nextProcIdx do
        if string.byte(data, nextProcIdx + 1, nextProcIdx + 1) == 0 then
            break
        end
        -- TOpoProcHeader
        local procName, procOffset, lineNumber, pos = string.unpack(TOpoProcHeader, data, nextProcIdx + 1)
        table.insert(result.procTable, {
            name = procName,
            source = sourceName,
            offset = procOffset,
            data = data,
            lineNumber = lineNumber -- Note, line numbers are zero-based
        })

        nextProcIdx = pos - 1 -- Because pos is in Lua 1-based coords
    end

    for i, proc in ipairs(result.procTable) do
        parseProc(proc, tv)
    end

    if opxTableIdx ~= 0 then
        result.opxTable = {}
        local nopx, pos = string.unpack("<I2", data, 1 + opxTableIdx)
        vprintf("opxTableIdx: 0x%08X count=%d\n", opxTableIdx, nopx)
        for i = 1, nopx do
            local name, uid, version
            name, uid, version, pos = string.unpack("<s1I4I2", data, pos)
            vprintf("OPX %d: %s 0x%08X v%d\n", i - 1, name, uid, version)
            table.insert(result.opxTable, {
                name = name,
                uid = uid,
                version = version
            })
        end

    end

    return result
end

local function makeLocalName(index, type)
    return string.format("local_%04X%s", index, DataTypeSuffix[type] or "")
end

function parseProc(proc, translatorVersion)
    -- See CProcedure::ConstructL()
    proc.params = {}
    proc.globals = {}
    proc.subprocs = {} -- This should really be "callables" or something
    proc.externals = {}
    proc.strings = {}
    proc.arrays = {}


    local definitionsSz, dataStart
    if translatorVersion == EOplTranVersionOplS3 then
        definitionSz = nil
        dataStart = 1 + proc.offset
    else
        definitionSz, dataStart = string.unpack("<H", proc.data, 1 + proc.offset)
    end

    local dataSize, qcodeSize, maxStack, paramsCount, dataPos = string.unpack("<HHHB", proc.data, dataStart)
    proc.codeSize = qcodeSize
    local function readString()
        local result, nextPos = string.unpack("<s1", proc.data, dataPos)
        dataPos = nextPos
        return result
    end
    local function readWord()
        local result, nextPos = string.unpack("<H", proc.data, dataPos)
        dataPos = nextPos
        return result
    end
    local function readByte()
        local result, nextPos = string.unpack("<B", proc.data, dataPos)
        dataPos = nextPos
        return result
    end
    -- print("datasz etc", dataSize, qcodeSize, maxStack, paramsCount, dataPos)
    proc.maxStack = maxStack
    -- Params are in reverse order in memory (ie last first) so flip them in proc.params
    for i = 1, paramsCount do
        table.insert(proc.params, 1, readByte())
    end

    local globalsTableSize = readWord()
    local startOfGlobals = dataPos-1
    -- printf("globalsTableSize=%d\n", globalsTableSize)
    if globalsTableSize > 0 then
        local endPos = dataPos + globalsTableSize
        while dataPos < endPos do
            local name = readString()
            local type = readByte()
            local offset = readWord()
            local global = { name = name, type = type, offset = offset }
            table.insert(proc.globals, global)
        end
        assert(dataPos == endPos, "dataPos != endPos!?")
    end

    local subProcTableSize = readWord()
    local iTotalTableSize = dataPos-1 - startOfGlobals + subProcTableSize - 2
    -- CProcedure defines iTotalTableSize weirdly, this is an easier to understand definition
    assert(iTotalTableSize == globalsTableSize + subProcTableSize, "Bad table size calculation!")
    proc.iTotalTableSize = iTotalTableSize
    proc.iDataSize = dataSize
    if subProcTableSize > 0 then
        local endPos = dataPos + subProcTableSize
        while dataPos < endPos do
            local offset = (dataPos-1) - startOfGlobals + 16 -- Don't ask me...
            local name = readString()
            local numParams = readByte()
            table.insert(proc.subprocs, {
                name = name,
                numParams = numParams,
                offset = offset
            })
        end
        assert(dataPos == endPos, "dataPos != endPos!?")
    end

    -- printf("Externals start at %X\n", proc.offset+2+dataPos-1)
    while true do
        local name = readString()
        if #name == 0 then
            break
        end
        local type = readByte()
        table.insert(proc.externals, { name = name, type = type })
    end

    while true do
        local offset = readWord()
        if offset == 0 then
            break
        end
        local maxLen = readByte()
        proc.strings[offset] = maxLen
    end

    -- Array fixups
    while true do
        local offset = readWord()
        if offset == 0 then
            break
        end
        local len = readWord()
        proc.arrays[offset] = len
    end

    if definitionSz then
        assert(dataPos == dataStart + definitionSz, "Data header size not right?")
    end
    proc.codeOffset = dataPos - 1

    -- Consult globals, strings and arrays and work out every initialised variable in the procedure so we can track them
    -- as a single ordered list (corresponding to local/global declaration order) rather than them being spread out
    -- over globals, strings and arrays.
    local vars = {}
    for _, global in ipairs(proc.globals) do
        local var = {
            name = global.name,
            directIdx = global.offset,
            type = global.type,
            isGlobal = true,
        }
        vars[var.directIdx] = var
    end
    for offset, arraySz in pairs(proc.arrays) do
        local var = vars[offset + 2]
        if var == nil then
            local stringArrayVar = vars[offset + 3]
            if stringArrayVar then
                assert(stringArrayVar.type == DataTypes.EStringArray,
                    "Found an unexpected variable type in a place it shouldn't be!")
                var = stringArrayVar
            end
        end
        if var == nil then
            -- Must be a local. This directIdx may not be correct if the variable is a string array, there's no way of
            -- knowing that here so we will fix this up below when we iterate proc.strings.
            local directIdx = offset + 2
            var = {
                name = makeLocalName(directIdx),
                directIdx = directIdx,
                -- No type because we don't know if it's a word, float etc
            }
            vars[var.directIdx] = var
        end

        var.arraySz = arraySz
    end

    for offset, maxLen in pairs(proc.strings) do
        -- Since the string byte is always adjacent to the payload (with any array len before it) the correct directIdx
        -- will always be offset + 1
        local directIdx = offset + 1
        local var = vars[directIdx]
        if var == nil then
            -- Check for a local string array that was incorrectly given a non-string array directidx above
            -- Since there can never be variables a single byte apart I don't think there's any way this can be
            -- ambiguous.
            local arrayVar = vars[offset]
            if arrayVar then
                vars[offset] = nil
                var = {
                    name = makeLocalName(directIdx, DataTypes.EStringArray),
                    directIdx = directIdx,
                    arraySz = arrayVar.arraySz,
                }
                vars[var.directIdx] = var
            end
        end
        if var == nil then
            -- Can't be a string array as that would've been handled above, must be a local string
            var = {
                name = makeLocalName(directIdx, DataTypes.EString),
                directIdx = directIdx,
            }
            vars[var.directIdx] = var
        end
        var.maxLen = maxLen
        local inferredType = var.arraySz and DataTypes.EStringArray or DataTypes.EString
        if var.type == nil then
            var.type = inferredType
        else
            assert(var.type == inferredType, "Variable type mismatch!")
        end
    end

    -- Since indirect indexes do not overlap direct indexes, we can safely add the params and externals to vars too
    for i, param in ipairs(proc.params) do
        local indirectIdx = (i - 1) * 2 + proc.iTotalTableSize + 18 -- inverse of Runtime:getIndirectVar() logic
        vars[indirectIdx] = {
            name = string.format("param_%d%s", i, DataTypeSuffix[param]),
            indirectIdx = indirectIdx,
            type = param,
        }
    end

    for i, external in ipairs(proc.externals) do
        local indirectIdx = (#proc.params + i - 1) * 2 + proc.iTotalTableSize + 18
        vars[indirectIdx] = {
            name = external.name,
            indirectIdx = indirectIdx,
            type = external.type,
        }
    end

    proc.vars = vars

    return proc
end

function printProc(proc)
    printf("%s @ 0x%08X code=0x%08X line=%d\n", proc.name, proc.offset, proc.codeOffset, proc.lineNumber)
    local numParams = #proc.params
    for _, subproc in ipairs(proc.subprocs) do
        printf('    Subproc "%s" offset=0x%04X nargs=%d\n', subproc.name, subproc.offset, subproc.numParams)
    end

    for idx, var in sortedPairs(proc.vars) do
        local var = proc.vars[idx]
        local declType = var.indirectIdx and "External" or (var.isGlobal and "Global" or "Local")
        local szStr = ""
        if var.arraySz then
            szStr = string.format(" arraySz=%d", var.arraySz)
        end
        if var.maxLen then
            szStr = string.format("%s maxLen=%d", szStr, var.maxLen)
        end
        local idxStr = var.indirectIdx and string.format("indirectIdx=0x%04X", var.indirectIdx) or
            string.format("directIdx=0x%04X", var.directIdx)
        printf('    %s "%s" (%s)%s %s\n',
            declType,
            var.name,
            DataTypes[var.type] or "?",
            szStr,
            idxStr)
    end

    printf("    maxStack: %d\n", proc.maxStack)
    printf("    iDataSize: %d (0x%08X)\n", proc.iDataSize, proc.iDataSize)
    printf("    iTotalTableSize: %d (0x%08X)\n", proc.iTotalTableSize, proc.iTotalTableSize)
end

function makeOpo(prog)
    local result = { sz = 0 }
    local function add(fmt, ...)
        local data
        if select("#", ...) == 0 then
            data = fmt
        else
            data = string.pack(fmt, ...)
        end
        table.insert(result, data)
        result.sz = result.sz + #data
    end

    local uid1, uid2, uid3 = KUidDirectFileStore, KUidOPO, KUidOplInterpreter
    if prog.aif then
        uid2 = KUidOplApp
        uid3 = prog.aif.uid3
    end
    local chk = require("crc").getUidsChecksum(uid1, uid2, uid3)
    local interpreterUid = KUidOplInterpreter
    local translatorVersion = EOplTranVersionOpler1
    local minRunVersion = EOplTranVersionOpler1
    local nominalSrcNameIdx = string.packsize(TOpoStoreHeader)
    local srcNameIdx = prog.path and nominalSrcNameIdx or 0

    local procOffset = nominalSrcNameIdx + (prog.path and (#prog.path + 1) or 0)

    local procTable = {}
    local procTableSz = 0
    for i, proc in ipairs(prog.procTable) do
        local header = { sz = 0 }
        local function addh(fmt, ...)
            local data = string.pack(fmt, ...)
            table.insert(header, data)
            header.sz = header.sz + #data
        end

        addh("<HHHB", proc.iDataSize, #proc.code, proc.maxStack, #proc.params)

        -- Params
        for i = #proc.params, 1, -1 do
            addh("B", proc.params[i])
        end

        -- Globals
        local globalsTable = {}
        for _, global in ipairs(proc.globals) do
            table.insert(globalsTable, string.pack("<s1BH", global.name, global.type, global.offset))
        end
        addh("<s2", table.concat(globalsTable))

        -- Subprocs
        local subProcTable = {}
        for _, subproc in ipairs(proc.subprocs) do
            table.insert(subProcTable, string.pack("<s1B", subproc.name, subproc.numParams))
        end
        addh("<s2", table.concat(subProcTable))

        -- Externals
        for _, external in ipairs(proc.externals) do
            addh("<s1B", external.name, external.type)
        end
        addh("B", 0)

        -- Strings
        for _, s in ipairs(proc.strings) do
            addh("<HB", s.offset, s.maxLen)
        end
        addh("<H", 0)

        -- Arrays
        for _, array in ipairs(proc.arrays) do
            addh("<HH", array.offset, array.len)
        end
        addh("<H", 0)

        local headerData = string.pack("<s2", table.concat(header))

        local procData = headerData .. proc.code
        procTable[i] = {
            name = proc.name,
            offset = procOffset,
            lineNumber = proc.lineNumber - 1, -- opo line numbers are zero-based
            data = procData,
            procTableData = string.pack(TOpoProcHeader, proc.name, procOffset, proc.lineNumber - 1)
        }
        procOffset = procOffset + #procData
        procTableSz = procTableSz + #procTable[i].procTableData
    end

    local procTableIdx = procOffset
    local rootStreamIdx = procTableIdx + procTableSz + 1 -- +1 for list terminator
    local opxTableIdx = 0

    local opxSz = 0
    for i, opx in ipairs(prog.opxTable) do
        opxSz = opxSz + #opx.name + 1 + 4 + 2
    end
    if opxSz > 0 then
        opxSz = opxSz + 2 -- For numOpx
        opxTableIdx = rootStreamIdx
        rootStreamIdx = opxTableIdx + opxSz
    end

    add(TOpoStoreHeader, uid1, uid2, uid3, chk, rootStreamIdx)

    if prog.path then
        add("s1", prog.path)
    end

    for i, proc in ipairs(procTable) do
        assert(proc.offset == result.sz, "Mismatch in proc offset!")
        add(proc.data)
    end

    assert(result.sz == procTableIdx, "Mismatch in procTableIdx!")
    for i, proc in ipairs(procTable) do
        add(proc.procTableData)
    end
    add("B", 0) -- Terminate the TOpoProcHeader list

    if opxTableIdx > 0 then
        assert(result.sz == opxTableIdx, "Mismatch in opxTableIdx")
        add("<I2", #prog.opxTable)
        for _, opx in ipairs(prog.opxTable) do
            add("<s1I4I2", opx.name, opx.uid, opx.version)
        end
    end

    local debugFlag = 0 -- ERelease
    assert(result.sz == rootStreamIdx, "Mismatch in rootStreamIdx!")
    add(TOpoRootStream, interpreterUid, translatorVersion, minRunVersion, srcNameIdx, procTableIdx, opxTableIdx, debugFlag)

    return table.concat(result)
end

return _ENV
