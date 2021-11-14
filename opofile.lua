_ENV = module()

KUidDirectFileStore = 0x10000037 -- uid1
KUidOPO = 0x10000073 -- pre-unicode uid2
KUidOplInterpreter = 0x10000168

-- POS MEANS 1-BASED LUA STRING POSITION. OFFSET OR INDEX MEANS ZERO BASED

function parseOpo(data, verbose)
    local function vprintf(...)
        if verbose then
            printf(...)
        end
    end

    -- TOpoStoreHeader
    local uid1, uid2, uid3, uid4, rootStreamIdx, pos = string.unpack("<I4I4I4I4I4", data)
    assert(uid1 == KUidDirectFileStore, "Bad header uid1!")
    assert(uid2 == KUidOPO, "Bad header uid2!")
    -- assert(uid3 == KUidOplInterpreter, "Bad header uid3!")
    -- No clue what uid4 is

    -- TOpoRootStream
    local interpreterUid, translatorVersion, minRunVersion, srcNameIdx, procTableIdx, opxTableIdx, debugFlag =
        string.unpack("<I4I2I2I4I4I4I2", data, rootStreamIdx+1)

    -- printf("Interpreter UID: 0x%08X\n", interpreterUid)
    -- assert(interpreterUid == KUidOplInterpreter, "Bad interpreterUid!")

    local sourceName
    if srcNameIdx > 0 then
        sourceName = string.unpack("<s1", data, srcNameIdx + 1)
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

    return procTable
end

function parseProc(proc)
    -- See CProcedure::ConstructL()
    proc.params = {}
    proc.globals = {}
    proc.subprocs = {} -- This should really be "callables" or something

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
    for i = 1, paramsCount do
        proc.params[i] = readByte()
    end

    -- printf("globalsTableStart=0x%08X\n", offset+dataPos-1) 
    local globalsTableSize = readWord()
    local startOfGlobals = dataPos-1
    -- printf("globalsTableSize=%d\n", globalsTableSize)
    if globalsTableSize > 0 then
        local endPos = dataPos + globalsTableSize
        while dataPos < endPos do
            local name = readString()
            local type = readWord()
            local offset = readWord()
            table.insert(proc.globals, { name = name, type = type, offset = offset })
        end
        assert(dataPos == endPos, "dataPos != endPos!?")
    end
    
    local subProcTableSize = readWord()
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
    assert(readByte() == 0, "Externals not supported yet!")
    assert(readWord() == 0, "String fixups not supported yet!")
    assert(readWord() == 0, "Array fixups not supported yet!")
    -- print(dataPos, #dataDefinitions + 1)
    assert(dataPos == #dataDefinitions + 1, "Data header size not right?")
    return proc
end

return _ENV
