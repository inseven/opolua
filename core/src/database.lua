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

_ENV = module()

KDbmsStoreDatabase = 0x10000069

FieldTypes = enum {
    Boolean = 0x0,
    Integer = 0x3,
    Long = 0x5,
    Double = 0x9,
    Date = 0xA,
    Text = 0xB,
    LongText8 = 0xE,
    LongBinary = 0x10,
}

-- The only types that (I think) OPL can handle
FieldTypeToOplType = {
    [FieldTypes.Integer] = DataTypes.EWord,
    [FieldTypes.Long] = DataTypes.ELong,
    [FieldTypes.Double] = DataTypes.EReal,
    [FieldTypes.Text] = DataTypes.EString,
}

-- Inverse of FieldTypeToOplType
OplTypeToFieldType = {
    [DataTypes.EWord] = FieldTypes.Integer,
    [DataTypes.ELong] = FieldTypes.Long,
    [DataTypes.EReal] = FieldTypes.Double,
    [DataTypes.EString] = FieldTypes.Text,
}

local Db = {
    path = nil,
    modified = false,
    writeable = false,
    varMap = nil, -- Maps variable name to field
    currentVars = nil,
    tables = nil,
    currentTable = nil,
    pos = nil,
    currentView = nil, -- Array of indexes into currentTable. Might be a different order than currentTable if ORDER BY is in effect.
    preTransactionTable = nil, -- Clone of currentTable taken by beginTransaction()
    preTransactionView = nil, -- Clone of currentView
    inAppendUpdate = false, -- Prevents Insert/Modify
    inInsert = false,
    inInsertModify = false, -- Prevents Append/Update
}
Db.__index = Db

function new(path, readonly)
    return setmetatable({ path = path, tables = {}, writeable = not readonly }, Db)
end

function Db:newView()
    local result = {}
    for name, field in pairs(self.varMap) do
        local var = makeVar(field.type)
        var(DefaultSimpleTypes[field.type])
        result[name] = var
    end
    return result
end

function Db:getPath(path)
    return self.path
end

function Db:currentVarsToRecord()
    -- Turn all the vars into a record mapping names and default initialising anything not in the view
    local result = {}
    for varName, var in pairs(self.currentVars) do
        result[self.varMap[varName].name] = var()
    end
    for i, field in ipairs(self.currentTable.fields) do
        if result[field.name] == nil then
            result[field.name] = DefaultSimpleTypes[field.type]
        end
    end
    return result
end

local function oplValidField(tbl, index)
    -- It's not a straight index because we have to ignore fields that OPL skips over
    local validCount = 0
    for i, field in ipairs(tbl.fields) do
        if field.type then
            validCount = validCount + 1
        end
        if validCount == index then
            return field
        end
    end
    error("Index not found")
end

function Db:setView(tableName, fieldNames, variables, filterPredicate, sortSpec)
    -- tableName and fieldNames are not guaranteed to be the correct case, so fix them up now (sigh).
    if self.tables[tableName] == nil then
        local nameLower = tableName:lower()
        for i, tbl in ipairs(self.tables) do
            if tbl.name:lower() == nameLower then
                tableName = tbl.name
                break
            end
        end
    end

    local tbl = self.tables[tableName]
    assert(tbl, "No such tableName "..tableName)

    if fieldNames and #fieldNames == 1 and fieldNames[1] == "*" then
        -- Equivalent to all the fields in the table, in order
        fieldNames = {}
        for i, field in ipairs(tbl.fields) do
            fieldNames[i] = field.name
        end
    end

    if fieldNames then
        for i, fieldName in ipairs(fieldNames) do
            if tbl.fields[fieldName] == nil then
                local lowerName = fieldName:lower()
                for _, field in ipairs(tbl.fields) do
                    if field.name:lower() == lowerName then
                        fieldNames[i] = field.name
                        break
                    end
                end
            end
        end
    end

    assert(fieldNames == nil or #fieldNames == #variables, KErrInvalidArgs)
    local map = {}
    for i, var in ipairs(variables) do
        local fieldName = fieldNames and fieldNames[i] or oplValidField(tbl, i).name
        if tbl.fields[fieldName].type ~= var.type then
            printf("Error: Field %s type is %d, var %s type is %d\n", fieldName, tbl.fields[fieldName].type, var.name, var.type)
            error(KErrInvalidArgs)
        end
        map[var.name] = {
            name = fieldName,
            type = var.type,
        }
    end
    self.currentTable = tbl
    self.varMap = map

    -- Construct the view on the table. Without a filterPredicate ("WHERE") or sortSpec ("ORDER BY") this is a
    -- one-to-one mapping to the table records.
    local view = {}
    for i = 1, #tbl do
        if filterPredicate then
            -- For the purposes of predicate evaluation, all field names must be upper cased (because of reusing the
            -- compiler.lua parser which uppercases all identifiers)
            local rec = {}
            for k, v in pairs(tbl[i]) do
                rec[k:upper()] = v
            end
            if filterPredicate(rec) then
                table.insert(view, i)
            end
        else
            view[i] = i
        end
    end
    if sortSpec then
        table.sort(view, function(lidx, ridx)
            local lhs = tbl[lidx]
            local rhs = tbl[ridx]
            for _, sortField in ipairs(sortSpec) do
                local fieldName = sortField.name
                if lhs[fieldName] == rhs[fieldName] then
                    -- Keep going
                else
                    if sortField.ascending then
                        return lhs[fieldName] < rhs[fieldName]
                    else
                        return lhs[fieldName] > rhs[fieldName]
                    end
                end
            end
            -- If we get here, all fields a tie
            return false
        end)
    end

    self.currentView = view

    self:setPos(1)
end

-- pos is an index into currentView, not directly into currentTable.
function Db:setPos(pos)
    if pos < 0 then
        -- Epoc treats it as unsigned, so...
        pos = math.maxinteger
    end
    self.pos = math.min(pos, #self.currentView + 1)
    if self.pos == 0 then
        self.pos = 1
    end
    self:resetInsertState()
    self.currentVars = self:newView()
    local rec = self.currentTable[self.currentView[pos]]
    if rec then
        for varName, field in pairs(self.varMap) do
            -- printf("varname %s -> fieldname %s = %s\n", varName, field.name, rec[field.name])
            self.currentVars[varName](rec[field.name])
        end
    end
end

function Db:getCurrentVar(name)
    if not self.inInsertModify then
        self.inAppendUpdate = true
    end
    local var = assert(self.currentVars[name], KErrNoFld)
    return var
end

-- Note, does not set inAppendUpdate, unlike when doing assignment via getCurrentVar
function Db:getCurrentVal(name)
    local var = assert(self.currentVars[name], KErrNoFld)
    return var()
end

function Db:inTransaction()
    return self.preTransactionTable ~= nil
end

function Db:beginTransaction()
    assert(not self:inTransaction(), "In transaction")
    self.preTransactionTable = {
        name = self.currentTable.name,
        fields = self.currentTable.fields,
    }
    for i, record in ipairs(self.currentTable) do
        local recCopy = {}
        for k, v in pairs(record) do
            recCopy[k] = v
        end
        self.preTransactionTable[i] = recCopy
    end
    self.preTransactionView = {}
    for i, index in ipairs(self.currentView) do
        self.preTransactionView[i] = index
    end
end

function Db:endTransaction(commit)
    -- You can't commit or rollback a transaction if you're in the middle of
    -- editing a record; you can only commit/rollback complete records.
    assert(self:inTransaction() and not self.inInsertModify and not self.inAppendUpdate, "Not in transaction")
    if not commit then
        self.currentTable = self.preTransactionTable
        self.tables[self.currentTable.name] = self.currentTable
        self.currentView = self.preTransactionView
    end
    self.preTransactionTable = nil
    self.preTransactionView = nil
end

function Db:resetInsertState()
    self.inAppendUpdate = false
    self.inInsertModify = false
    self.inInsert = false
end

function Db:modify()
    assert(not self.inAppendUpdate and not self.inInsertModify, "Incompatible update mode")
    self.inInsertModify = true
    -- There's nothing else modify actually needs to do...?
end

function Db:insert()
    assert(not self.inAppendUpdate and not self.inInsertModify, "Incompatible update mode")
    self.inInsertModify = true
    self.inInsert = true
    self.currentVars = self:newView()
end

function Db:cancel()
    assert(self.inInsertModify, "Incompatible update mode")
    self:resetInsertState()
    self:setPos(self.pos) -- Will reset any assignments
end

function Db:put()
    assert(self.inInsertModify, "Incompatible update mode")
    self:setModified()
    if self.inInsert then
        -- Inserts still always insert the new record at the end of the file/view
        local newPos = #self.currentView + 1
        table.insert(self.currentTable, self:currentVarsToRecord())
        self.currentView[newPos] = newPos
        self:setPos(newPos)
    else
        self.currentTable[self.currentView[self.pos]] = self:currentVarsToRecord()
    end
    self.inInsertModify = false
end

function Db:isWriteable()
    return self.writeable
end

function Db:setModified()
    assert(self.writeable, KErrWrite)
    self.modified = true
end

function Db:getPos()
    return self.pos
end

function Db:eof()
    return self.pos > #self.currentView
end

function Db:getCount()
    assert(not self.inAppendUpdate and not self.inInsertModify, "Incompatible update mode")
    return #self.currentView
end

function Db:isModified()
    return self.modified
end

function Db:appendRecord()
    -- inAppendUpdate need not be set here; doing an APPEND without having set any fields at all is permissable
    assert(not self.inInsertModify, "Incompatible update mode")
    self:setModified()
    local newPos = #self.currentView + 1
    table.insert(self.currentTable, self:currentVarsToRecord())
    self.currentView[newPos] = newPos
    self:setPos(newPos)
end

function Db:deleteRecord()
    self:setModified()
    local recordIndex = self.currentView[self.pos]
    -- We have to go through the whole of currentView here and update the indexes
    for i, index in ipairs(self.currentView) do
        if index > recordIndex then
            self.currentView[i] = index - 1
        end
    end

    table.remove(self.currentView, self.pos)
    table.remove(self.currentTable, recordIndex)
    self:setPos(self.pos)
end

function Db:updateRecord()
    -- inAppendUpdate need not be set here; doing an UPDATE without having modified any fields at all is permissable
    assert(not self.inInsertModify, "Incompatible update mode")
    local pos = self.pos
    self:appendRecord()
    self:setPos(pos)
    self:deleteRecord()
    self:setPos(#self.currentView)
end

function Db:load(data)
    self.tables = {}
    self.currentTable = nil
    if data:sub(1, 4) == "\x50\x00\x00\x10" then -- KPermanentFileStoreLayoutUid
        -- It's an epoc binary db
        self:loadBinary(data)
    elseif data:sub(1, 15) == "OPLDatabaseFile" then -- Series 3 ODB
        self:loadOdbBinary(data)
    else
        self:loadText(data)
    end
end

function Db:tableCount()
    return #self.tables
end

function Db:getTableNames()
    local result = {}
    for i, tbl in ipairs(self.tables) do
        result[i] = tbl.name
    end
    return result
end

function Db:loadText(data)
    local currentTable, currentRec
    for line in data:gmatch("[^\r\n]+") do
        local tableName = line:match("^:TABLE (.+)")
        if tableName then
            currentTable = {
                name = tableName,
                fields = {},
            }
            table.insert(self.tables, currentTable)
            self.tables[tableName] = currentTable
            if not self.currentTable then
                self.currentTable = currentTable
            end
        elseif line:match("^:FIELD") then
            local type, name = line:match("^:FIELD ([0-9]) (.+)")
            local rawType = assert(OplTypeToFieldType[tonumber(type)])
            local field = { type = tonumber(type), name = name, rawType = rawType }
            table.insert(currentTable.fields, field)
            currentTable.fields[name] = field
        elseif line:match("^:RECORD") then
            currentRec = {}
            table.insert(currentTable, currentRec)
        else
            local k, v = line:match("([^=]+)=(.*)")
            if k then
                local field = assert(currentTable.fields[k], "Field not found in assignment to "..k)
                if field.type == DataTypes.EString then
                    v = hexUnescape(v)
                else
                    v = tonumber(v)
                end
                currentRec[k] = v
            else
                printf("Db:load(): Unrecognised line %s\n", line)
            end
        end
    end
end

function Db:save()
    local i, lines = 1, {}
    local function line(...)
        lines[i] = string.format(...)
        i = i + 1
    end
    for _, tbl in ipairs(self.tables) do
        line(":TABLE %s", tbl.name)
        for _, field in ipairs(tbl.fields) do
            if field.type then
                -- can be nil for fields OPL can't represent
                line(":FIELD %d %s", field.type, field.name)
            end
        end
        for _, rec in ipairs(tbl) do
            line(":RECORD")
            for _, field in ipairs(tbl.fields) do
                local v = rec[field.name]
                if field.type == DataTypes.EString then
                    v = hexEscape(v)
                end
                if v then
                    -- can be nil for fields OPL can't represent
                    line("%s=%s", field.name, v)
                end
            end
        end
    end
    line("")
    return table.concat(lines, "\n")
end

function Db:tocsv(tableName)
    if tableName == nil then
        assert(#self.tables == 1, "A table name must be supplied when the database has multiple tables")
        tableName = self.tables[1].name
    end

    local tbl = self.tables[tableName]
    assert(tbl, "Table name "..tableName.. "not found")

    local result = {}
    local function line(vals)
        local escaped = {}
        for i, val in ipairs(vals) do
            if type(val) == "string" then
                if val:match('[",]') then
                    local escaped = val:gsub('"', '""')
                    escaped[i] = '"'..escaped..'"'
                else
                    escaped[i] = val
                end
            else
                escaped[i] = val
            end
        end
        table.insert(result, table.concat(escaped, ","))
    end

    local headings = {}
    for i, field in ipairs(tbl.fields) do
        if field.type then
            table.insert(headings, field.name)
        end
    end
    line(headings)
    for _, record in ipairs(tbl) do
        local rec = {}
        for i, fieldName in ipairs(headings) do
            rec[i] = record[fieldName]
        end
        line(rec)
    end
    return table.concat(result, "\n")
end

KTableDefinitionHeaderLen = 9
-- What to add to TOC entry offsets to convert to a file offset (to the start of the section - add 0x20 to skip the
-- section's length word).
KTocEntryOffset = 0x1E

function Db:loadBinary(data)
    data = depageBinary(data)
    local uid1, uid2, uid3, uidChecksum, pos = string.unpack("<I4I4I4I4", data)
    assert(uid1 == KPermanentFileStoreLayoutUid, "Bad DB UID1 "..tostring(uid1))
    -- assert(uid2 == KUidAppDllDoc8, "Bad DB UID2")

    -- TPermanentStoreHeader
    local backup, handle, ref, crc, pos = string.unpack("<I4i4i4I2", data, pos)

    local tocPos
    if handle == 0 then
        if ref + 0x14 >= #data then
            tocPos = 1 + (backup >> 1) + 0x14
        else
            tocPos = 1 + ref + 0x14
        end
    else
        tocPos = 1 + #data - 12 - 5 * handle
    end

    local rootStreamIdx, _, tocCount, tocEntriesPos = string.unpack("<I4I4I4", data, tocPos)
    local toc = {} -- 1-based indexes into data, pointing to start of section length word
    for i = 1, tocCount do
        local offset
        offset, tocEntriesPos = string.unpack("<xI4", data, tocEntriesPos)
        toc[i] = offset == 0 and 0 or (1 + offset + KTocEntryOffset + 2)
    end
    -- It seems like there should be a better way of making sense of toc, but it seems like the sections are hard-coded:
    -- toc[1]: always section 1 - 9 null bytes
    -- toc[2]: first table definition section
    -- toc[3]: TOplDocRootStream
    -- toc[4]: first data section
    -- toc[5]: always a 15 byte section
    -- other data sections potentially follow

    -- There is nothing useful in TOplDocRootStream (referenced by toc[3]) so don't bother reading it.

    -- Read the sections, starting from just after TPermanentStoreHeader (ie what pos currently is set to).
    -- local sections = {} -- array of section positions (1 based)
    -- local sectionStarts = {} -- map of position to section index
    -- local sectionId = 1
    -- while pos < #data do
    --     sections[sectionId] = pos
    --     sectionStarts[pos] = sectionId
    --     -- bits 14 and 15 are used for something or other, plus 2 because the length doesn't include the length word itself
    --     local sectionLen = (string.unpack("<I2", data, pos) & 0x3FFF) + 2
    --     assert(sectionLen ~= 0, "Bad section length!")
    --     sectionId = sectionId + 1
    --     pos = pos + sectionLen
    -- end

    assert(string.unpack("<I4", data, toc[2]) == KDbmsStoreDatabase,
        "toc[2] does not appear to point to a table definition")
    self:readTableDefinition(data, toc[2] + KTableDefinitionHeaderLen)

    for i = 1, #self.tables do
        self:loadTable(data, toc, i)
    end
end

function Db:loadTable(data, toc, tableIndex)
    local tbl = self.tables[tableIndex]
    local dataSection = tbl.dataIndex

    -- Now iterate through the chain of data sections
    while dataSection ~= 0 do
        local dataStart = toc[dataSection]
        if dataStart == 0 then
            -- Sometimes nextSectionIndex will point to a toc entry that's zero, rather than simply being zero, to
            -- terminate the data section list. Who knows...
            break
        end
        -- There can be up to 16 records in each data section. How many there is given by the count of bits in
        -- recordBitmask.
        local nextSectionIndex, recordBitmask, pos = string.unpack("<I4I2", data, dataStart)
        if recordBitmask & 1 == 0 and nextSectionIndex ~= 0 then
            -- Non-OPL databases can put a dummy section here which just points to the real first data section
            assert(dataSection == 4, "Empty recordBitmask encountered not in first data section "..dataSection)
            dataSection = nextSectionIndex
            dataStart = toc[dataSection]
            nextSectionIndex, recordBitmask, pos = string.unpack("<I4I2", data, dataStart)
        end

        local recordLengths = {}
        for bit = 0, 15 do
            if recordBitmask & (1 << bit) ~= 0 then
                local len, nextPos = readCardinality(data, pos)
                -- I don't think there will ever be gaps in the bitset, check that here
                assert(bit == 0 or recordLengths[bit], "Set bit found with previous bit unset!")
                recordLengths[1 + bit] = len
                pos = nextPos
            end
        end

        for _, recordLen in ipairs(recordLengths) do
            local rec = {}
            local startPos = pos
            local fieldIdx = 0
            while pos < startPos + recordLen do
                local fieldMask
                fieldMask, pos = string.unpack("B", data, pos)
                local bit = 0
                while bit < 8 do
                    if fieldMask & (1 << bit) ~= 0 then
                        local field = assert(self.currentTable.fields[1 + fieldIdx + bit])
                        local val
                        if field.type == DataTypes.EWord then
                            val, pos = string.unpack("<i2", data, pos)
                        elseif field.type == DataTypes.ELong then
                            val, pos = string.unpack("<i4", data, pos)
                        elseif field.type == DataTypes.EReal then
                            val, pos = string.unpack("<d", data, pos)
                        elseif field.type == DataTypes.EString then
                            val, pos = string.unpack("<s1", data, pos)
                        elseif field.rawType == FieldTypes.Boolean then
                            -- We don't support it, so just skip the value bit in the fieldMask
                            bit = bit + 1
                        elseif field.rawType == FieldTypes.Date then
                            pos = pos + 8
                        elseif field.rawType == FieldTypes.LongText8 then
                            bit = bit + 1
                            local inline = fieldMask & (1 << bit) ~= 0
                            if inline then
                                local len
                                len, pos = readSpecialEncoding(data, pos)
                                pos = pos + len
                            else
                                pos = pos + 8 -- Skip tocIndex and len
                            end
                        elseif field.rawType == FieldTypes.LongBinary then
                            bit = bit + 1
                            local inline = fieldMask & (1 << bit) ~= 0
                            if inline then
                                local len
                                len, pos = readSpecialEncoding(data, pos)
                                pos = pos + len
                            else
                                pos = pos + 4
                            end
                        else
                            error("Unhandled field type")
                        end
                        rec[field.name] = val
                    end
                    assert(bit < 8, "Multibit val at end of byte??")
                    bit = bit + 1
                end
                fieldIdx = fieldIdx + 8
            end

            assert(pos == startPos + recordLen, "Failed to read expected number of bytes")
            -- In the interests of sanity we will zero initialise any fields missing from the file
            for _, member in ipairs(tbl.fields) do
                if rec[member.name] == nil then
                    rec[member.name] = DefaultSimpleTypes[member.type]
                end
            end
            table.insert(tbl, rec)
        end
        dataSection = nextSectionIndex
    end
end

function Db:readTableDefinition(data, pos)
    local function readVarLengthString(data, pos)
        local len, strStart = readSpecialEncoding(data, pos)
        local str = string.sub(data, strStart, strStart + len - 1)
        return str, strStart + len
    end
    self.tables = {}
    local numTables, pos = readCardinality(data, pos)
    for i = 1, numTables do
        local tableName, numFields
        tableName, pos = readVarLengthString(data, pos)
        local tbl = {
            name = tableName,
            fields = {},
        }
        numFields, pos = readCardinality(data, pos)
        for _ = 1, numFields do
            local fieldName
            fieldName, pos = readVarLengthString(data, pos)
            local type = string.byte(data, pos)
            local oplType = FieldTypeToOplType[type]
            -- oplType is allowed to be nil in the case of fields not representable in OPL (which are just skipped)
            pos = pos + 2 -- past the type byte and the whatever-it-is byte
            if type == FieldTypes.Text then
                pos = pos + 1 -- Skip over maxLen
            end

            local field = { type = oplType, name = fieldName, rawType = type }
            table.insert(tbl.fields, field)
            tbl.fields[fieldName] = field
        end
        local dataIndex
        dataIndex, pos = string.unpack("<xI4x", data, pos)
        tbl.dataIndex = dataIndex - 1 -- Not sure why these are one more than the (already 1-based) TOC index

        self.tables[i] = tbl
        self.tables[tableName] = tbl
    end
    self.currentTable = self.tables[1]
end

function Db:createTable(tableName, fieldNames, types)
    if self.tables[tableName] then
        error(KErrExists)
    end
    self:setModified()
    local fields = {}
    assert(#fieldNames == #types, "fieldNames and types length mismatch!")
    for i, fieldName in ipairs(fieldNames) do
        fields[i] = {
            name = fieldName,
            type = types[i],
        }
        fields[fieldName] = fields[i]
    end
    local tbl = {
        name = tableName,
        fields = fields,
    }
    table.insert(self.tables, tbl)
    self.tables[tableName] = tbl
end

function Db:deleteTable(tableName)
    -- TODO need to revisit this once table-granularity database sharing is done
    assert(self.currentTable == nil, "Cannot delete a table when currentTable is set")
    for i, tbl in ipairs(self.tables) do
        if tbl.name == tableName then
            table.remove(self.tables, i)
            self.tables[tableName] = nil
            return
        end
    end
    -- Not an error to delete a non-existent table
end

local function trimTrailingSpace(val)
    return val:match("(.-)%s*$")
end

function splitQuery(query)
    local keywords = {
        "SELECT",
        "FIELDS",
        "FROM",
        "WHERE",
        "TO",
        "ORDER BY",
    }
    query = " "..query -- Logic is simpler if we can assume there's always at least one space before keywords
    local queryUpper = query:upper()
    assert(#query == #queryUpper, "Case conversion fail!")

    -- Stomp anything in single quotes (in case a keyword appears in there)
    -- Since we only use queryUpper for spltting keywords, This Is Fine
    queryUpper = queryUpper:gsub("'([^']*)'", function(contents) return string.rep("X", #contents + 2) end)

    local pos = 1
    local prevKeyword = nil
    local result = {}
    while true do
        local foundKeyword
        for i, keyword in ipairs(keywords) do
            local prevGroupEnd, nextPos = queryUpper:match("()%s+"..keyword.."%s*()", pos)
            if nextPos then
                -- Found a keyword. Assemble everything prior to this to prevKeyword, if applicable
                foundKeyword = keyword
                if prevKeyword then
                    result[prevKeyword] = query:sub(pos, prevGroupEnd - 1)
                end
                prevKeyword = keyword
                pos = nextPos
                break
            end
        end
        if not foundKeyword then
            break
        end
    end

    -- Handle last keyword
    if prevKeyword then
        result[prevKeyword] = trimTrailingSpace(query:sub(pos))
    end

    return result
end

function commaSplit(str)
    local result = {}
    for val in str:gmatch("%s*([^,]*)") do
        table.insert(result, trimTrailingSpace(val))
    end
    return result
end

function spaceSplit(str)
    local result = {}
    for val in str:gmatch("([^ ]*)") do
        table.insert(result, val)
    end
    return result
end

local function synassert(cond, ...)
    if not cond then
        print(string.format(...))
        error(KErrSyntax, 2)
    end
end

function parseTableSpec(spec)
    local filename = spec
    local quoted, rest = spec:match('^"([^"]+)%s*(.*)')
    if quoted then
        filename = quoted
        spec = rest
    else
        filename, rest = spec:match("(%S+)%s*(.*)")
        spec = rest
    end

    if filename == nil then
        return "", "Table1", nil, nil, nil
    end

    local query = splitQuery(spec)

    -- Check this is a legal combination of query items
    if query.FIELDS then
        synassert(query.TO, "If FIELDS is specified, TO must be as well") -- Apparently...
        synassert(query.SELECT == nil and query.FROM == nil and query["ORDER BY"] == nil,
            "Invalid queries after a FIELDS")
    elseif query.SELECT then
        synassert(query.TO == nil, "TO is not valid after SELECT")
        synassert(query.FROM, "FROM must be specified after SELECT")
    else
        synassert(next(query) == nil, "Any queries must start with FIELDS or SELECT")
    end

    local fieldNames
    local fieldsQuery = query.SELECT or query.FIELDS
    if fieldsQuery then
        fieldNames = commaSplit(fieldsQuery)
        -- Split any max lengths from FIELDS declarations, we don't care about them
        for i, field in ipairs(fieldNames) do
            fieldNames[i] = field:match("[^(]+")
        end
    end

    local tableName = query.FROM or query.TO or "Table1"

    local filterPredicate
    if query.WHERE then
        filterPredicate = parseWhere(query.WHERE)
    end

    local sortSpec
    if query["ORDER BY"] then
        sortSpec = {}
        local orders = commaSplit(query["ORDER BY"])
        for i, o in ipairs(orders) do
            local name
            local ascending
            local parts = spaceSplit(o)
            if #parts == 1 then
                name = o
                ascending = true
            else
                synassert(#parts == 2, "Couldn't parse ORDER BY spec '%s'", o)
                name = parts[1]
                local sortOrder = parts[2]:upper()
                synassert(sortOrder == "ASC" or sortOrder == "DESC", "Unexpected sort order '%s'", parts[2])
                ascending = sortOrder == "ASC"
            end
            table.insert(sortSpec, { name = name, ascending = ascending })
        end
    end

    return filename, tableName, fieldNames, filterPredicate, sortSpec
end

-- Database files appear to have some sort of paging scheme whereby 2 extra bytes are inserted every 0x4000 bytes,
-- starting from 0x4020. These bytes aren't part of the format and must be stripped out before any of the indexes will
-- be correct. Or at least it's easier to do that than to fix up every index operation.
function depageBinary(data)
    local pos = 0x20
    local pages = { data:sub(1, pos) }
    while pos < #data do
        local page = data:sub(1 + pos, pos + 0x4000)
        table.insert(pages, page)
        pos = pos + 0x4000 + 2
    end
    return table.concat(pages)
end

local function globToMatch(glob)
    local m = glob:gsub("[.+%%^$%(%)%[%]-]", "%%%0"):gsub("%?", "."):gsub("%*", ".*")
    return "^" .. m .. "$"
end

local function recordContains(tbl, record, matchText, firstField, lastField, caseSensitive)
    for i, field in ipairs(tbl.fields) do
        local fieldValue = record[field.name]
        if i >= firstField and i <= lastField and field.type == FieldTypes.Text then
            if caseSensitive and fieldValue:match(matchText) then
                return true
            elseif not caseSensitive and fieldValue:lower():match(matchText) then
                return true
            end
        end
    end
    return false
end

function Db:findField(text, start, num, flags)
    local matchText = globToMatch(text)
    local lastField = num == nil and #self.currentTable.fields or start + num

    local inc
    if (flags & KFindForwards) ~= 0 then
        inc = 1
    else
        inc = -1
    end

    local count = #self.currentView
    local pos
    if (flags & 3) == KFindBackwardsFromEnd then
        pos = count
    elseif (flags & 3) == KFindForwardsFromStart then
        pos = 1
    else
        pos = self.pos
    end

    local caseSensitive = (flags & KFindCaseDependent) ~= 0
    if not caseSensitive then
        matchText = matchText:lower()
    end

    while pos <= count and pos > 0 do
        local record = self.currentTable[self.currentView[pos]]
        if recordContains(self.currentTable, record, matchText, start, lastField, caseSensitive) then
            self:setPos(pos)
            return pos
        end
        pos = pos + inc
    end

    return 0 -- Indicates not found
end

local string_match, string_sub = string.match, string.sub

sqlWhereLang = {
    statemachine = {
        ['<'] = {
            [''] = 'lt',
            ['>'] = 'neq',
            ['='] = 'le',
        },
        ['>'] = {
            [''] = 'gt',
            ['='] = 'ge',
        },
        ['='] = 'eq',
        ['%-?[0-9]+'] = {
            [''] = 'number', -- int or long
            ['[eE][%+%-]?[0-9]+'] = 'number', -- int or long with exponent
            ['%.[0-9]*'] = {
                [''] = 'number', -- float
                ['[eE][%+%-]?[0-9]+'] = 'number', -- float with exponent
            },
        },
        ['%('] = 'oparen',
        ['%)'] = 'cloparen',
        ['[ \t]+'] = 'space',
        ["'"] = function(text, tokenStart)
            local pos = tokenStart + 1
            while true do
                local delim, nextPos = string_match(text, "(['\r\n])()", pos)
                if delim == "'" then
                    if string_sub(text, nextPos, nextPos) == "'" then
                        -- Double-' means an escaped ', keep going
                        pos = nextPos + 1
                    else
                        -- End of string
                        return "string", string_sub(text, tokenStart, nextPos - 1)
                    end
                else
                    error("Unmatched '")
                end
            end
        end,
        ['[a-zA-Z_][a-zA-Z0-9_]*'] = 'identifier',
    },
    identifierTokens = enum {
        "AND", "OR", "NOT", "LIKE",
        "IS", "NULL",
    },
    precedences = enum {
        noop = 0,
        OR = 1,
        AND = 2,
        eq = 3,
        lt = 3,
        le = 3,
        gt = 3,
        ge = 3,
        neq = 3,
        NOT = 4,
        LIKE = 5,
        NOT_LIKE = 5,
    },
    unaryOperators = {
        NOT = true,
    },
    rightAssociativeOperators = {}
}


function parseWhere(str)
    local compiler = require("compiler")
    -- print(dump(compiler.lex(str, nil, sqlWhereLang)))
    local tokens = compiler.lex(str, nil, sqlWhereLang)
    -- SQL has "NOT LIKE" which is effectively an operator, and the expression parser expects operators to be a single
    -- token, so fix that up here.
    for i, tok in ipairs(tokens) do
        if tok.type == "NOT" and tokens[i + 1] and tokens[i + 1].type == "LIKE" then
            table.remove(tokens, i + 1)
            tok.type = "NOT_LIKE"
        end
    end

    local exp = compiler.parseUntypedExpression(compiler.lex(str, nil, sqlWhereLang))
    assert(exp.op, "Expected op!")
    
    -- Expressions are converted to a function which evaluates against an env. This technically accepts a bunch of
    -- things that wouldn't be legal SQL but we don't care.
    local function evalExpression(exp)
        local op = exp.op
        if op then
            local lhs = evalExpression(exp[1])
            local rhs = evalExpression(exp[2])
            local function dbg(fn)
                -- return function(env)
                --     printf("%s %s %s\n", op, lhs(env), rhs(env))
                --     return fn(env)
                -- end
                return fn
            end
            if op == "OR" then
                return dbg(function(env) return lhs(env) or rhs(env) end)
            elseif op == "AND" then
                return dbg(function(env) return lhs(env) and rhs(env) end)
            elseif op == "eq" then
                return dbg(function(env) return lhs(env) == rhs(env) end)
            elseif op == "lt" then
                return dbg(function(env) return lhs(env) < rhs(env) end)
            elseif op == "le" then
                return dbg(function(env) return lhs(env) <= rhs(env) end)
            elseif op == "gt" then
                return dbg(function(env) return lhs(env) > rhs(env) end)
            elseif op == "ge" then
                return dbg(function(env) return lhs(env) >= rhs(env) end)
            elseif op == "neq" then
                return dbg(function(env) return lhs(env) ~= rhs(env) end)
            elseif op == "NOT" then
                return dbg(function(env) return not rhs(env) end)
            elseif op == "LIKE" then
                return dbg(function(env)
                    return lhs(env):match(globToMatch(rhs(env))) ~= nil
                end)
            elseif op == "NOT_LIKE" then
                return dbg(function(env)
                    return lhs(env):match(globToMatch(rhs(env))) == nil
                end)
            else
                error("Unhandled op "..op)
            end
        elseif exp.type == "number" then
            return function()
                local _, val = compiler.literalToNumber(exp.val)
                return val
            end
        elseif exp.type == "string" then
            return function() return assert(exp.val:match("^'(.*)'$")):gsub("''", "'") end
        elseif exp.type == "identifier" then
            return function(env)
                -- printf("ENV[%s]=%s\n", exp.val, env[exp.val])
                return env[exp.val]
            end
        else
            error("Unhandled expression "..exp.type)
        end
    end

    return evalExpression(exp)
end

local kMergableDataRecordType = 1
local kFieldRecordType = 2

function Db:loadOdbBinary(data)
    self.currentTable = {
        name = "Table1",
    }
    table.insert(self.tables, self.currentTable)
    self.tables[self.currentTable.name] = self.currentTable

    local magic, version, dataStart, minVer, pos = string.unpack("<c15HHH", data)
    -- printf("version=0x%X, dataStart=0x%X, minVer=0x%X\n", version, dataStart, minVer)
    -- What's between the end of the header and dataStart, who knows. Stale data awaiting decompress?
    
    -- HACK: I've no idea what dataStart is, it seems wrong
    local recordStart = 22 --dataStart
    
    while recordStart < #data do
        local header, pos = string.unpack("<H", data, 1 + recordStart, pos)
        local recordLen = header & 0xFFF
        local recordType = header >> 12
        -- printf("%04X: record len=0x%X, type=%d\n", recordStart, recordLen, recordType)
        if self.currentTable.fields == nil then
            self.currentTable.fields = {}
            assert(recordType == kFieldRecordType)
            for i = 0, recordLen - 1 do
                local type
                type, pos = string.unpack("B", data, pos)
                local field = {
                    type = type,
                    name = string.format("Field%d", i + 1),
                    rawType = OplTypeToFieldType[type],
                }
                table.insert(self.currentTable.fields, field)
                self.currentTable.fields[field.name] = field
                -- printf("Field %d type %s\n", i + 1, DataTypes[type])
            end
        elseif recordType == kMergableDataRecordType then
            local record = {}
            for i, field in ipairs(self.currentTable.fields) do
                local t = field.type
                local val
                if t == DataTypes.EWord then
                    val, pos = string.unpack("<h", data, pos)
                elseif t == DataTypes.ELong then
                    val, pos = string.unpack("<i4", data, pos)
                elseif t == DataTypes.EReal then
                    val, pos = string.unpack("<d", data, pos)
                elseif t == DataTypes.EString then
                    val, pos = string.unpack("<s1", data, pos)
                else
                    error("Unknown field type!")
                end
                record[field.name] = val
            end
            table.insert(self.currentTable, record)
        else
            printf("Unhandled record type %d\n", recordType)
        end

        recordStart = recordStart + 2 + recordLen
    end
end

return _ENV
