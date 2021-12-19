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

_ENV = module()

local Db = {
    path = nil,
    modified = false,
    writeable = false,
    viewMap = nil, -- Maps variable name to field
    currentVars = nil,
    tables = nil,
    currentTable = nil,
}
Db.__index = Db

function new(path, readonly)
    return setmetatable({ path = path, tables = {}, writeable = not readonly }, Db)
end

function Db:newView()
    local result = {}
    for name, field in pairs(self.viewMap) do
        result[name] = makeVar(field.type)
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
    assert(#fields == #variables, KOplErrInvalidArgs)
    local map = {}
    for i, var in ipairs(variables) do
        assert(fields[i].type == var.type, KOplErrInvalidArgs)
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
    self.currentVars = self:newView()
    local rec = self.currentTable[pos]
    -- for k,v in pairs(rec) do print("TOMSCI: %s=%s\n", k, v) end
    if rec then
        for varName, field in pairs(self.viewMap) do
            -- printf("varname %s -> fieldname %s = %s\n", varName, field.name, rec[field.name])
            self.currentVars[varName](rec[field.name])
        end
    end
end

function Db:isWriteable()
    return self.writeable
end

function Db:setModified()
    assert(self.writeable, KOplErrWrite)
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
    local pos = self.pos
    self:appendRecord()
    table.remove(self.currentTable, pos)
    self.pos = self.pos - 1
end

function Db:load(data)
    self.tables = {}
    self.currentTable = nil
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

-- TODO unfinished, broken
function Db:loadBinary(data)
    local uid1, uid2, uid3, uidChecksum, pos = string.unpack("<I4I4I4I4", data)
    assert(uid1 == KPermanentFileStoreLayoutUid, "Bad DB UID1 "..tostring(uid1))
    -- assert(uid2 == KUidAppDllDoc8, "Bad DB UID2")

    -- TPermanentStoreHeader
    local backup, handle, ref, crc, pos = string.unpack("<I4i4i4I2", data, pos)
    printf("backupToc=%08X dirty=%d handle=%08X ref=0x%08X\n", backup >> 1, backup & 1, handle, ref)

    local permanentStoreOffset = 32 -- All CPermananentStore offsets are relative to 32 bytes from the start of the file
    local toc = ref - 1 -- Whatevs. Do the backup toc checks if I can be bothered

    local function readToc(offset)
        -- CPermanentStoreToc::STocHead, read by CPermanentStoreToc::ConstructL
        local KOffsetTocHeader = 12 -- wat?
        -- printf("TOMSCIidx=%X", idx)
        local primary, avail, count = string.unpack("<i4i4I4", data, 1 + permanentStoreOffset + offset + KOffsetTocHeader)
        printf("primary=%X avail=%X, count=%X\n", primary, avail, count)
        --
        return primary
    end

    local rootOffset = readToc(toc) -- good god this was a complicated way of establishing where the bloody data is
    -- TOplDocRootStream
    local appUid, streamID = string.unpack("<I4I4", data, 1 + permanentStoreOffset + rootOffset)
    printf("appUid=0x%08X streamID=0x%08X\n", appUid, streamID)
    assert(appUid == KUidOplInterpreter, "Something's gone wrong in the file store parsing!")
    -- And yet another indirect... streamID is _finally_ where all our stuff is
end

function Db:createTable(tableName, fields)
    if self.tables[tableName] then
        error(KOplErrExists)
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
    return spec, "Table1", nil
end

return _ENV
