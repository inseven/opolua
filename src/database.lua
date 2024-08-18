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

_ENV = module()

KDbmsStoreDatabase = 0x10000069

FieldTypes = enum {
    Boolean = 0x0,
    Integer = 0x3,
    Long = 0x5,
    Double = 0x9,
    Date = 0xA,
    Text = 0xB,
}

-- The only types that (I think) OPL can handle
FieldTypeToOplType = {
    [FieldTypes.Integer] = DataTypes.EWord,
    [FieldTypes.Long] = DataTypes.ELong,
    [FieldTypes.Double] = DataTypes.EReal,
    [FieldTypes.Text] = DataTypes.EString,
}

local Db = {
    path = nil,
    modified = false,
    writeable = false,
    viewMap = nil, -- Maps variable name to field
    currentVars = nil,
    tables = nil,
    currentTable = nil,
    pos = nil,
    preTransactionTable = nil, -- Clone of currentTable taken by beginTransaction()
    inAppendUpdate = false, -- Prevents Insert/Modify
    inInsertModify = false, -- Prevents Append/Update
}
Db.__index = Db

function new(path, readonly)
    return setmetatable({ path = path, tables = {}, writeable = not readonly }, Db)
end

function Db:newView()
    local result = {}
    for name, field in pairs(self.viewMap) do
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
        result[self.viewMap[varName].name] = var()
    end
    for i, field in ipairs(self.currentTable.fields) do
        if result[field.name] == nil then
            result[field.name] = DefaultSimpleTypes[field.type]
        end
    end
    return result
end

function Db:setView(tableName, fields, variables)
    local tbl = self.tables[tableName]
    assert(tbl, "No such tableName in setView!")
    assert(#fields == #variables, KErrInvalidArgs)
    local map = {}
    for i, var in ipairs(variables) do
        assert(fields[i].type == var.type, KErrInvalidArgs)
        map[var.name] = fields[i]
    end
    self.currentTable = tbl
    self.viewMap = map
    self:setPos(1)
end

function Db:setPos(pos)
    if pos < 0 then
        -- Epoc treats it as unsigned, so...
        pos = math.maxinteger
    end
    self.pos = math.min(pos, self:getCount() + 1)
    if self.pos == 0 then
        self.pos = 1
    end
    self:resetInsertState()
    self.currentVars = self:newView()
    local rec = self.currentTable[pos]
    if rec then
        for varName, field in pairs(self.viewMap) do
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
        fieldMap = self.currentTable.fieldMap,
    }
    for i, record in ipairs(self.currentTable) do
        local recCopy = {}
        for k, v in pairs(record) do
            recCopy[k] = v
        end
        self.preTransactionTable[i] = recCopy
    end
end

function Db:endTransaction(commit)
    -- You can't commit or rollback a transaction if you're in the middle of
    -- editing a record; you can only commit/rollback complete records.
    assert(self:inTransaction() and not self.inInsertModify and not self.inAppendUpdate, "Not in transaction")
    if not commit then
        self.currentTable = self.preTransactionTable
        self.tables[self.currentTable.name] = self.currentTable
    end
    self.preTransactionTable = nil
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
        table.insert(self.currentTable, self.pos, self:currentVarsToRecord())
        self:setPos(self.pos + 1)
    else
        self.currentTable[self.pos] = self:currentVarsToRecord()
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
    return self.pos > #self.currentTable
end

function Db:getCount()
    return #self.currentTable
end

function Db:isModified()
    return self.modified
end

function Db:appendRecord()
    assert(self.inAppendUpdate, "Incompatible update mode")
    self:setModified()
    table.insert(self.currentTable, self:currentVarsToRecord())
    self:setPos(self:getCount())
end

function Db:deleteRecord()
    self:setModified()
    table.remove(self.currentTable, self.pos)
    self:setPos(self.pos)
end

function Db:updateRecord()
    assert(self.inAppendUpdate, "Incompatible update mode")
    local pos = self.pos
    self:appendRecord()
    table.remove(self.currentTable, pos)
    self.pos = self.pos - 1
end

function Db:load(data)
    self.tables = {}
    self.currentTable = nil
    if data:sub(1, 4) == "\x50\x00\x00\x10" then -- KPermanentFileStoreLayoutUid
        -- It's an epoc binary db
        -- unimplemented("database.loadBinary")
        return self:loadBinary(data)
    else
        return self:loadText(data)
    end
end

function Db:loadText(data)
    local currentTable, currentRec
    for line in data:gmatch("[^\r\n]+") do
        local tableName = line:match("^:TABLE (.+)")
        if tableName then
            currentTable = {
                name = tableName,
                fields = {},
                fieldMap = {},
            }
            table.insert(self.tables, currentTable)
            self.tables[tableName] = currentTable
            if not self.currentTable then
                self.currentTable = currentTable
            end
        elseif line:match("^:FIELD") then
            local type, name = line:match("^:FIELD ([0-9]) (.+)")
            local field = { type = tonumber(type), name = name }
            table.insert(currentTable.fields, field)
            currentTable.fieldMap[name] = field
        elseif line:match("^:RECORD") then
            currentRec = {}
            table.insert(currentTable, currentRec)
        else
            local k, v = line:match("([^=]+)=(.*)")
            if k then
                local field = assert(currentTable.fieldMap[k], "Field not found in assignment to "..k)
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
            line(":FIELD %d %s", field.type, field.name)
        end
        for _, rec in ipairs(tbl) do
            line(":RECORD")
            for _, field in ipairs(tbl.fields) do
                local v = rec[field.name]
                if field.type == DataTypes.EString then
                    v = hexEscape(v)
                end
                line("%s=%s", field.name, v)
            end
        end
    end
    line("")
    return table.concat(lines, "\n")
end

function Db:tocsv()
    assert(#self.tables == 1, "Cannot export a database with multiple tables to CSV")
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
    for i, field in ipairs(self.currentTable.fields) do
        headings[i] = field.name
    end
    line(headings)
    for _, record in ipairs(self.currentTable) do
        local rec = {}
        for i, field in ipairs(self.currentTable.fields) do
            rec[i] = record[field.name]
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
    local uid1, uid2, uid3, uidChecksum, pos = string.unpack("<I4I4I4I4", data)
    assert(uid1 == KPermanentFileStoreLayoutUid, "Bad DB UID1 "..tostring(uid1))
    -- assert(uid2 == KUidAppDllDoc8, "Bad DB UID2")

    -- TPermanentStoreHeader
    local backup, handle, ref, crc, pos = string.unpack("<I4i4i4I2", data, pos)

    local tocPos = handle == 0 and (1 + ref + 0x14) or (1 + #data - 12 - 5 * handle)
    local idBindingIdx, _, tocCount, tocEntriesPos = string.unpack("<I4I4I4", data, tocPos)
    local toc = {} -- 1-based indexes into data, pointing to start of section length word
    for i = 1, tocCount do
        local offset
        offset, tocEntriesPos = string.unpack("<xI4", data, tocEntriesPos)
        toc[i] = 1 + offset + KTocEntryOffset
    end
    -- It seems like there should be a better way of making sense of toc, but it seems like the sections are hard-coded:
    -- toc[1]: always section 1 - 9 null bytes
    -- toc[2]: first table definition section
    -- toc[3]: TOplDocRootStream
    -- toc[4]: first data section
    -- toc[5]: always section 9? Mystery, refer to Chief Aramaki

    -- There is nothing useful in TOplDocRootStream (referenced by toc[3]) so don't bother reading it.

    -- Read the sections, starting from just after TPermanentStoreHeader (ie what pos currently is set to).
    local sections = {} -- array of section positions (1 based)
    local sectionStarts = {} -- map of position to section index
    local sectionId = 1
    while pos < #data do
        sections[sectionId] = pos
        sectionStarts[pos] = sectionId
        -- bits 14 and 15 are used for something or other, plus 2 because the length doesn't include the length word itself
        local sectionLen = (string.unpack("<I2", data, pos) & 0x3FFF) + 2
        assert(sectionLen ~= 0, "Bad section length!")
        sectionId = sectionId + 1
        pos = pos + sectionLen
    end

    assert(sectionStarts[toc[2]], "toc[2] does not point to the start of a section")
    assert(string.unpack("<I4", data, toc[2] + 2) == KDbmsStoreDatabase,
        "toc[2] does not appear to point to a table definition")
    self:readTableDefinition(data, toc[2] + 2 + KTableDefinitionHeaderLen)

    local dataStartAddress = toc[4]
    local dataSection = sectionStarts[dataStartAddress]
    assert(dataSection, "toc[4] does not point to the start of a section")

    -- Now iterate through the chain of data sections
    while dataSection ~= 0 do
        if sections[dataSection] == nil then
            error(string.format("Data section %d not found!", dataSection))
        end
        local dataStart = sections[dataSection] + 2 -- +2 to skip section length field
        -- There can be up to 16 "data sets" in each data section, where I think a data set equates to a record
        -- How many there is is given by the count of bits in dataSetBitmask
        local nextSectionIndex, dataSetBitmask, pos = string.unpack("<I4I2", data, dataStart)
        local dataSetLengths = {}
        for bit = 0, 15 do
            if dataSetBitmask & (1 << bit) ~= 0 then
                local len, nextPos = readCardinality(data, pos)
                -- I don't think there will ever be gaps in the bitset, check that here
                assert(bit == 0 or dataSetLengths[bit], "Set bit found with previous bit unset!")
                dataSetLengths[1 + bit] = len
                pos = nextPos
            end
        end

        for _, dataSetLen in ipairs(dataSetLengths) do
            local rec = {}
            local startPos = pos
            local fieldIdx = 0
            while pos < startPos + dataSetLen do
                local fieldMask
                fieldMask, pos = string.unpack("B", data, pos)
                -- Ignoring the way bool fields are packed into the fieldMask since we don't support them in OPL
                for bit = 0, 7 do
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
                        end
                        rec[field.name] = val
                    end
                end
                fieldIdx = fieldIdx + 8
            end

            assert(pos == startPos + dataSetLen, "Failed to read expected number of bytes")
            -- In the interests of sanity we will zero initialise any fields missing from the file
            for _, member in ipairs(self.currentTable.fields) do
                if rec[member.name] == nil then
                    rec[member.name] = DefaultSimpleTypes[member.type]
                end
            end
            table.insert(self.currentTable, rec)
        end
        dataSection = nextSectionIndex
    end
end

function Db:readTableDefinition(data, pos)
    local function readVarLengthString(data, pos)
        local len, strStart = readVarLength(data, pos)
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
            fieldMap = {},
        }
        numFields, pos = readCardinality(data, pos)
        for _ = 1, numFields do
            local fieldName
            fieldName, pos = readVarLengthString(data, pos)
            local type = string.byte(data, pos)
            local oplType = FieldTypeToOplType[type]
            assert(oplType, "Unsupported field type!")
            pos = pos + 2 -- past the type byte and the whatever-it-is byte
            if type == FieldTypes.Text then
                pos = pos + 1 -- Skip over maxLen
            end

            local field = { type = oplType, name = fieldName }
            table.insert(tbl.fields, field)
            tbl.fieldMap[fieldName] = field
        end

        self.tables[i] = tbl
        self.tables[tableName] = tbl
    end
    self.currentTable = self.tables[1]
end

function Db:createTable(tableName, fields)
    if self.tables[tableName] then
        error(KErrExists)
    end
    self:setModified()
    local tbl = {
        name = tableName,
        fields = fields,
    }
    table.insert(self.tables, tbl)
    self.tables[tableName] = tbl
end

function parseTableSpec(spec)
    -- TODO support
    printf("parseTableSpec: %s\n", spec)
    local quoted, rest = spec:match('^"([^"]+)"%s*(.*)')
    if quoted then
        spec = quoted
    end
    local query = spec:match("^[%S]+%s+(SELECT .*)")
    if query then
        unimplemented("database.parseTableSpec")
    end
    return spec, "Table1", nil
end

return _ENV
