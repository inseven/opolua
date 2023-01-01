--[[

Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe

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

EOplTranVersionOpl1993 = 0x111F
EOplTranVersionOpler1 = 0x200A

function parseOpo(data, verbose)
    local function vprintf(...)
        if verbose then
            printf(...)
        end
    end

    local procTableIdx, opxTableIdx, srcNameIdx, era
    if data:sub(1, 16) == "OPLObjectFile**\0" then
        -- SIBO format
        -- TOpoFileHeader16
        local sig, fileVersion, offset = string.unpack("<c16I2I2", data)
        -- It appears nothing cares about fileVersion (seems to always be 1?)
        vprintf("OPL1993 version=%d offset=0x%08X\n", fileVersion, offset)
        -- TOpoModuleHeader16
        local totalSize, translatorVersion, minRunVersion, pti = string.unpack("<i4I2I2i4", data, 1 + offset)
        vprintf("translatorVersion: 0x%04X minRunVersion: 0x%04X\n", translatorVersion, minRunVersion)
        assert(translatorVersion == EOplTranVersionOpl1993)
        assert(minRunVersion == EOplTranVersionOpl1993)
        procTableIdx = pti
        opxTableIdx = 0 -- not supported in this version
        srcNameIdx = 0x14
        era = "sibo"
    else
        -- TOpoStoreHeader
        local uid1, uid2, uid3, checksum, rootStreamIdx, pos = string.unpack("<I4I4I4I4I4", data)
        assert(uid1 == KUidDirectFileStore, "Bad header uid1!")
        assert(require("crc").getUidsChecksum(uid1, uid2, uid3) == checksum, "Bad UID checksum!")
        -- assert(uid2 == KUidOPO, string.format("Bad header uid2 0x%08X", uid2))
        -- assert(uid3 == KUidOplInterpreter, "Bad header uid3!")
        vprintf("UID3: 0x%08X\n", uid3)

        -- TOpoRootStream
        local interpreterUid, translatorVersion, minRunVersion, sni, pti, oti, debugFlag =
            string.unpack("<I4I2I2I4I4I4I2", data, rootStreamIdx+1)

        -- printf("Interpreter UID: 0x%08X\n", interpreterUid)
        -- assert(interpreterUid == KUidOplInterpreter, "Bad interpreterUid!")
        vprintf("translatorVersion: 0x%04X minRunVersion: 0x%04X\n", translatorVersion, minRunVersion)
        assert(translatorVersion == EOplTranVersionOpler1, "Unexpected translatorVersion!")
        assert(minRunVersion == EOplTranVersionOpler1, "Unexpected minRunVersion!")
        srcNameIdx = sni
        procTableIdx = pti
        opxTableIdx = oti
        era = "er5"
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

    local procTable = {}
    vprintf("procTableIdx: 0x%08X\n", procTableIdx)

    local nextProcIdx = procTableIdx
    while nextProcIdx do
        -- TOpoProcHeader
        local procName, procOffset, lineNumber, pos = string.unpack("<s1I4I2", data, nextProcIdx + 1)
        table.insert(procTable, {
            name = procName,
            source = sourceName,
            offset = procOffset,
            data = data,
            lineNumber = lineNumber -- Note, line numbers are zero-based
        })
        if data:sub(pos, pos) == "\0" then
            nextProcIdx = nil
        else
            nextProcIdx = pos - 1 -- Because pos is in Lua 1-based coords
        end
    end

    for i, proc in ipairs(procTable) do
        parseProc(proc)
    end

    local opxTable = nil
    if opxTableIdx ~= 0 then
        opxTable = {}
        local nopx, pos = string.unpack("<I2", data, 1 + opxTableIdx)
        vprintf("opxTableIdx: 0x%08X count=%d\n", opxTableIdx, nopx)
        for i = 1, nopx do
            local filename, uid, version
            filename, uid, version, pos = string.unpack("<s1I4I2", data, pos)
            vprintf("OPX %d: %s 0x%08X v%d\n", i - 1, filename, uid, version)
            table.insert(opxTable, {
                filename = filename:lower(),
                uid = uid,
                version = version
            })
        end

    end

    return procTable, opxTable, era
end

function parseProc(proc)
    -- See CProcedure::ConstructL()
    proc.params = {}
    proc.globals = {}
    proc.subprocs = {} -- This should really be "callables" or something
    proc.externals = {}
    proc.strings = {}
    proc.arrays = {}

    local dataDefinitions, qcodePos = string.unpack("<s2", proc.data, proc.offset+1)
    local dataSize, qcodeSize, maxStack, paramsCount, dataPos = string.unpack("<HHHB", dataDefinitions)
    proc.codeSize = qcodeSize
    proc.codeOffset = qcodePos - 1
    local function readString()
        local result, nextPos = string.unpack("<s1", dataDefinitions, dataPos)
        dataPos = nextPos
        return result
    end
    local function readWord()
        local result, nextPos = string.unpack("<H", dataDefinitions, dataPos)
        dataPos = nextPos
        return result
    end
    local function readByte()
        local result, nextPos = string.unpack("<B", dataDefinitions, dataPos)
        dataPos = nextPos
        return result
    end
    -- print(dataSize, qcodeSize, maxStack, paramsCount, dataPos)
    -- Params are in reverse order in memory (ie last first) so flip them in proc.params
    for i = 1, paramsCount do
        table.insert(proc.params, 1, readByte())
    end

    -- printf("globalsTableStart=0x%08X\n", proc.offset+2+dataPos-1)
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
            local nameForLookupByName = name
            if isArrayType(type) then
                -- Array variable names live in a separate namespace to scalars,
                -- for the purposes of global variable lookup, the simplest
                -- solution is to disambiguate them here.
                nameForLookupByName = nameForLookupByName.."[]"
            end
            proc.globals[nameForLookupByName] = global -- support lookup by name too
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

    -- print(dataPos, #dataDefinitions + 1)
    assert(dataPos == #dataDefinitions + 1, "Data header size not right?")
    return proc
end

return _ENV
