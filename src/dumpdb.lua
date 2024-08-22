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
        csv = true,
        verbose = true,
        v = "verbose",
    })

    local database = require("database")
    KDbmsStoreDatabase = database.KDbmsStoreDatabase
    FieldTypes = database.FieldTypes
    KTocEntryOffset = database.KTocEntryOffset

    local data = readFile(args.filename)

    if args.verbose then
        dumpDb(database.depageBinary(data))
    end

    local db = database.new(args.filename, true)
    db:load(data)
    if args.csv then
        print(db:tocsv())
    else
        print(db:save())
    end
end

require("struct").import(_ENV)

TCheckedUid = Struct {
    name = "TCheckedUid",
    { "uid1", UINT },
    { "uid2", UINT },
    { "uid3", UINT },
    { "uidCheck", UINT },
}

TPermanentStoreHeader = Struct {
    name = "TPermanentStoreHeader",
    { "iBackup", UINT },
    { "iHandle", LONG },
    { "iRef", LONG },
    { "iCrc", USHORT }
}

Toc = Struct {
    name = "Toc",
    { "rootStreamIndex", UINT },
    { "unknown", UINT },
    { "count", UINT },
    -- Rest is count * TocEntry
}

TocEntry = Struct {
    name = "TocEntry",
    { "flags", BYTE },
    { "offset", UINT },
}

TOplDocRootStream = Struct {
    name = "TOplDocRootStream",
    { "iAppUid", UINT },
    { "iStreamId", UINT },
}

DbmsStoreDbHeader = Struct {
    name = "DbmsStoreDbHeader",
    { "KDbmsStoreDatabase", UINT },
    { "version?", USHORT },
    { "noclue", UINT },
}

TableDefinitionSectionHeader = Struct {
    name = "TableSection",
    { "KDbmsStoreDatabase", UINT },
    { "nullbyte", BYTE },
    { "unknown", UINT },
    { "tableCount", TCARDINALITY },
    -- `tableCount` number of Tables follow
}

TableStruct = Struct {
    name = "Table",
    { "tableName", SSTRING },
    { "fieldCount", TCARDINALITY },
    -- Variable number of fields, then TableFooter
}

FieldStruct = Struct {
    name = "Field",
    { "fieldName", SSTRING },
    { "type", BYTE },
    { "unknown", BYTE },
    -- Possibly a maxLength here
}

TableFooter = Struct {
    name = "TableFooter",
    { "unknown1", USHORT },
    { "unknown2", UINT },
}

TableContentSectionHeader = Struct {
    name = "TableContentSection",
    { "nextSectionIndex", UINT },
    { "recordBitmask", USHORT },
}

RecordLengthTable = Struct {
    name = "RecordLengthTable",
    -- Variable length, so no fixed definitions
}

-- This is slightly fancier than the usual hexdump because it aligns the dumped data to the appropriate 16 byte boundary
function hexdump(data, pos, len)
    local result = {}
    local start = pos & ~ 0xF
    for i = start, pos + len - 1, 16 do
        local line = {}
        table.insert(line, string.format("%08X  ", i))
        local lineDataStart = i
        if i < pos then
            table.insert(line, string.rep("   ", pos - i))
            lineDataStart = pos
        end
        local lineEnd = math.min(i + 16, pos + len)
        local lineLen = lineEnd - lineDataStart
        for j = 0, lineLen - 1 do
            table.insert(line, string.format("%02X ", string.byte(data, 1 + lineDataStart + j)))
        end
        table.insert(line, string.rep("   ", i + 16 - lineEnd))
        table.insert(line, " ")
        if i < pos then
            table.insert(line, string.rep(" ", pos - i))
        end
        for j = 0, lineLen - 1 do
            table.insert(line, (string.sub(data, 1 + lineDataStart + j, 1 + lineDataStart + j):gsub("[\x00-\x1F\x7F-\xFF]", ".")))
        end
        table.insert(result, table.concat(line))
    end
    table.insert(result, "")
    return table.concat(result, "\n")
end


-- Note, zero based. (Name comes from https://frodo.looijaard.name/psifiles/Basic_Elements nomenclature)
function readExtra(data, pos)
    local result, nextPos = readCardinality(data, 1 + pos)
    return result, nextPos - 1
end

function dumpDb(data)
    local parsed = {}
    local currentPos = 0
    local function addArea(area)
        table.insert(parsed, area)
        table.sort(parsed, function(a, b)
            if a._pos == b._pos then
                -- Longer areas should come first
                return a._size > b._size
            else
                return a._pos < b._pos
            end
        end)
        if area then
            currentPos = area._pos + area._size
        end
        return area

    end
    local function read(structFmt, pos)
        if pos == nil then
            pos = currentPos
        end
        local instance = structFmt:unpack(data, pos)
        return addArea(instance)
    end
    local function readTableDefinition(pos)
        local tableSection = TableDefinitionSectionHeader:unpack(data, pos)
        pos = tableSection:endPos()
        local tables = {}
        for i = 1, tableSection.tableCount do
            local tbl = TableStruct:unpack(data, pos)
            local fields = {}
            pos = tbl:endPos()
            for fieldIdx = 1, tbl.fieldCount do
                local field = FieldStruct:unpack(data, pos)
                field:annotate("type", FieldTypes[field.type] or "??")
                if field.type == FieldTypes.Text then
                    field:appendMember("maxLen", BYTE, data)
                end
                pos = field:endPos()
                table.insert(fields, field)
            end
            tbl:appendInstanceArray("Field", fields)
            tbl:appendStruct(TableFooter, data, tbl:endPos())
            pos = tbl:endPos()
            table.insert(tables, tbl)
        end
        tableSection:appendInstanceArray("Table", tables)
        return addArea(tableSection)
    end
    local function readSection(sectionId, pos)
        local name = string.format("%d", sectionId)
        if pos == nil then
            pos = currentPos
        end
        local len, dataPos = string.unpack("<I2", data, 1 + pos)
        local actualLen = len & 0x3FFF -- bits 14 and 15 are used for something or other.
        local sectionLen = actualLen + 2
        if actualLen == 0 or pos + sectionLen > #data then
            printf("Warning: Bad section length at %X\n", pos)
            currentPos = #data -- Stop any further attempt at parsing sections
            return nil
        end
        local sectionData = data:sub(dataPos, dataPos + actualLen - 1)
        local section = {
            _pos = pos,
            _size = sectionLen,
            _name = name,
            dump = function()
                printf("Section %s %08X - %08X (%d bytes)\n", name, pos, pos + sectionLen, sectionLen)
                print(hexdump(data, pos, sectionLen))
            end,
        }
        if string.unpack("<I4", data, dataPos) == KDbmsStoreDatabase then
            if actualLen == DbmsStoreDbHeader:sizeof() then
                read(DbmsStoreDbHeader, pos + 2)
            else
                readTableDefinition(pos + 2)
            end
        end

        return addArea(section)
    end
    local function unparsed(pos, endPos)
        printf("--------------------- %08X to 0x%08X UNPARSED ---------------------\n%s%s\n",
            pos, endPos, hexdump(data, pos, endPos - pos), string.rep("-", 75))
    end

    local uids = read(TCheckedUid)
    assert(uids.uid1 == KPermanentFileStoreLayoutUid, "Bad DB UID1 "..tostring(uids.uid1))
    local storeHeader = read(TPermanentStoreHeader)

    local tocpos
    if storeHeader.iHandle == 0 then
        if storeHeader.iRef + 0x14 >= #data then
            printf("TOC ref is out of bounds, using backup")
            tocpos = (storeHeader.iBackup >> 1) + 0x14
        else
            tocpos = storeHeader.iRef + 0x14
        end
    else
        tocpos = #data - (Toc:sizeof() + storeHeader.iHandle * TocEntry:sizeof())
    end

    local toc = read(Toc, tocpos)
    if toc then
        local ok = toc:appendStructArray(toc.count, TocEntry, data)
        if not ok then
            toc = nil
        end
    end

    currentPos = storeHeader._pos + storeHeader._size -- Start of sections
    local sections = {}
    local sectionStarts = {}
    local sectionId = 1
    while currentPos < #data do
        sections[sectionId] = currentPos
        sectionStarts[currentPos] = sectionId
        readSection(sectionId)
        sectionId = sectionId + 1
    end

    local dataOffset = nil
    if toc then
        dataOffset = toc.TocEntry[4].offset
        if sectionStarts[dataOffset + KTocEntryOffset] == nil then
            printf("Warning: TocEntry[4] does not point to the start of a section!\n")
        end

        read(TOplDocRootStream, toc.TocEntry[3].offset + KTocEntryOffset + 2)
    end

    while dataOffset and dataOffset ~= 0 do
        local dataStart = dataOffset + KTocEntryOffset + 2 -- +2 for section length field
        local dataSection = read(TableContentSectionHeader, dataStart)
        -- Now the length table
        for bit = 0, 15 do
            if dataSection.recordBitmask & (1 << bit) ~= 0 then
                dataSection:appendMember(string.format("recordLength[%d]", bit + 1), TCARDINALITY, data)
            end
        end

        local nextSection = dataSection.nextSectionIndex
        if nextSection == 0 then
            dataOffset = nil
        else
            dataOffset = toc.TocEntry[nextSection].offset
            -- printf("Next section is toc entry %d = %X\n", nextSection, dataOffset)
        end
    end

    local pos = 0
    for _, val in ipairs(parsed) do
        local valStart = val._pos
        if valStart > pos then
            unparsed(pos, valStart)
            print("")
        end
        val:dump()
        print("")
        pos = val._pos + val._size
    end
    if pos < #data then
        unparsed(pos, #data)
    end
end

pcallMain()
