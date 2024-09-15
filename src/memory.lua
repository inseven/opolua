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

local chunkstride = 4
local strideshift = 2

-- Redeclare a bunch of things local for the (probably minute) performance gain that gives
local EWord = DataTypes.EWord
local ELong = DataTypes.ELong
local EReal = DataTypes.EReal
local EString = DataTypes.EString
local EWordArray = DataTypes.EWordArray
local ELongArray = DataTypes.ELongArray
local ERealArray = DataTypes.ERealArray
local EStringArray = DataTypes.EStringArray
local math_max = math.max
local string_pack = string.pack
local string_unpack = string.unpack
local string_sub = string.sub
local fmt = string.format
local isArrayType = isArrayType
local type = type
local assert = assert

local ValSize = {
    [EWord] = 2,
    [ELong] = 4,
    [EReal] = 8,
}
local FmtForType = {
    [EWord] = "<i2",
    [ELong] = "<i4",
    [EReal] = "<d",
}

Chunk = class {
    -- data is stored as 32-bit ints from self[0] to self[size//4 -1]
    address = 0, -- Note, chunk must start on a chunkstride boundary
    maxIdx = 0, -- A convenience for dump() when using unsized Chunks
    size = nil, -- Must be set to use alloc
}

function Chunk:checkRange(addr)
    local max = self.address + self.size
    if addr < self.address or addr >= max then
        error(fmt("Address 0x%08X out of bounds %08X-%08X", addr, self.address, max), 2)
    end
end

local function word(self, idx)
    local result = string_pack("<I4", self[idx] or 0)
    return result
end

local function setword(self, idx, data, dataPos)
    self[idx] = string_unpack("<I4", data, dataPos)
end

local function hexdump(word)
    return string.format("%02X%02X%02X%02X", string.byte(word, 1, 4))
end

function Chunk:read(offset, len)
    assert(offset >= 0, "Attempt read before start of chunk!")
    local rem = offset % chunkstride
    local idx = offset >> strideshift
    local words = {}
    local i = 1
    if rem ~= 0 then
        local w = word(self, idx)
        w = string_sub(w, 1 + rem, rem + len)
        words[i] = w
        i = i + 1
        len = len - #w
        idx = idx + 1
    end
    while len > 0 do
        local w = word(self, idx)
        if len >= chunkstride then
            words[i] = w
            len = len - chunkstride
        else
            words[i] = string_sub(w, 1, len)
            len = 0
        end
        idx = idx + 1
        i = i + 1
    end
    return table.concat(words)
end

function Chunk:dump(maxLen)
    printf("Dumping chunk...\n")
    local maxIdx = (maxLen and maxLen >> strideshift) or self.size and (self.size >> strideshift) or self.maxIdx
    for i = 0, maxIdx - 1, 4 do
        local str = word(self, i) .. word(self, i + 1) .. word(self, i + 2) .. word(self, i + 3)
        str = str:gsub("[\x00-\x1F\x7F-\xFF]", ".")
        printf("%08X: %s %s %s %s  %s\n", self.address + i * chunkstride,
            hexdump(word(self, i)),
            hexdump(word(self, i + 1)),
            hexdump(word(self, i + 2)),
            hexdump(word(self, i + 3)),
            str)
    end
end

function Chunk:write(offset, data)
    assert(offset >= 0, "Attempt write before start of chunk!")
    local rem = offset % chunkstride
    local idx = offset >> strideshift
    local dataIdx = 0

    if rem ~= 0 then
        local w = word(self, idx)
        local firstPiece = string_sub(data, 1, chunkstride - rem)
        local newVal = string_sub(w, 1, rem) .. firstPiece
        if #newVal < chunkstride then
            -- data does not reach to the end of the word, have to add the original tail
            -- ie must be oNoo oNNo or ooNo (o=orig byte, N = new byte from data)
            newVal = newVal .. string_sub(w, -(chunkstride - #newVal))
        end
        -- print(rem, hexEscape(firstPiece))
        assert(#newVal == chunkstride)
        setword(self, idx, newVal)
        idx = idx + 1
        dataIdx = #firstPiece
    end

    local dataLen = #data
    while dataIdx < dataLen do
        if dataIdx + chunkstride <= dataLen then
            setword(self, idx, data, 1 + dataIdx)
            dataIdx = dataIdx + chunkstride
        else
            local lastPiece = string_sub(data, 1 + dataIdx)
            assert(#lastPiece < chunkstride)
            local newVal = lastPiece .. string_sub(word(self, idx), -(chunkstride - #lastPiece))
            assert(#newVal == chunkstride)
            setword(self, idx, newVal)
            dataIdx = dataLen
        end
        idx = idx + 1
    end

    self.maxIdx = math_max(self.maxIdx, idx)
end

-- Optimised version of Chunk:write(offset, string.rep("\0", length))
function Chunk:clear(offset, length)
    assert(offset % chunkstride == 0, "Cannot zero from a non-aligned address!")
    assert(length % chunkstride == 0, "Cannot zero a non-aligned length!")
    for i = offset >> strideshift, (offset + length - 1) >> strideshift do
        self[i] = 0
    end
end

local prefixSize = {
    [EWord] = 0,
    [ELong] = 0,
    [EReal] = 0,
    [EString] = 1,
    [EWordArray] = 2,
    [ELongArray] = 2,
    [ERealArray] = 2,
    [EStringArray] = 3,
}

function Chunk:getVariableAtOffset(offset, type)
    local var = Variable {
        _type = type,
        _chunk = self,
        _offset = offset,
    }

    return var
end

function Chunk:allocVariable(type, stringMaxLen, arrayLen)
    local valType = type & 0xF
    local prefix = prefixSize[type]
    local sz
    if valType == EString then
        sz = 1 + stringMaxLen
    else
        sz = ValSize[valType]
    end
    if isArrayType(type) then
        sz = sz * arrayLen
    end
    local allocOffset = self:alloc(sz + prefix)
    local result = self:makeNewVariable(allocOffset, type, stringMaxLen, arrayLen)
    result._allocOffset = allocOffset
    return result
end

-- In-place constructs a variable at startOffset
function Chunk:makeNewVariable(startOffset, type, stringMaxLen, arrayLen)
    local offset = startOffset + prefixSize[type]
    local result = self:getVariableAtOffset(offset, type)
    result:fixup(stringMaxLen, arrayLen)
    return result
end

function Chunk:setSize(len)
    assert(self.size == nil and self[0] == nil and self.maxIdx == 0, "Cannot resize chunks!")
    assert(len & 0x3 == 0, "Chunk size must be aligned!")
    self.size = len
    self[0] = 1 -- 0 always points to the first free cell
    self[1] = len -- Cell size of the first (and only) free cell)
    self[2] = 0 -- Next free cell index (ie, no more)
end

function Chunk:alloc(len)
    -- printf("alloc(%d) ", len)
    -- printf("freeCellList before: %s ", self:freeCellListStr())

    len = (len + 3) & ~3
    local freeCellPtrIdx = 0
    local idx, cellLen
    while true do
        idx = self[freeCellPtrIdx] or 0
        if idx == 0 then
            -- No more free cells
            print("OOM!")
            -- printf("Free cells: %s\n", self:freeCellListStr())
            -- self:dump(0x700)
            -- error("OOM DOOM")
            return nil
        end
        cellLen = self[idx] or 0
        if cellLen >= len + 4 then
            -- Found a big enough cell
            break
        end
        freeCellPtrIdx = idx + 1
    end
    -- print("idx", idx)
    local nextFreeCellIdx = self[idx + 1]
    -- print("nextFreeCellIdx", nextFreeCellIdx)
    local remaining = cellLen - (len + 4)
    -- print("remaining", remaining)
    if remaining >= 8 then
        -- There's room to split the cell
        self[idx] = len + 4
        local newCellIdx = idx + 1 + (len >> strideshift)
        -- print("newCellIdx", newCellIdx)
        self[newCellIdx] = remaining
        self[newCellIdx + 1] = nextFreeCellIdx
        nextFreeCellIdx = newCellIdx
    end
    self[freeCellPtrIdx] = nextFreeCellIdx
    local result = (idx + 1) << strideshift
    -- printf("--> 0x%X freeCellList after: %s\n", result, self:freeCellListStr())
    -- self:write(result, string.rep("\xAA", len))
    return result
end

function Chunk:allocz(len)
    -- printf("Chunk:allocz(%d)\n", len)
    local result = self:alloc(len)
    if result then
        self:clear(result, self:getAllocLen(result))
    end
    -- printf("freeCellList after allocz: %s\n", self:freeCellListStr())
    -- printf(" -> 0x%X alloclen=%d\n", result, result or 0 and self:getAllocLen(result) or 0)
    return result
end

function Chunk:freeCellList()
    local result = {}
    local i = 1
    local fc = self[0]
    while fc ~= 0 do
        result[i] = fc
        i = i + 1
        fc = self[fc + 1]
    end
    return result
end

function Chunk:freeCellListStr()
    local list = self:freeCellList()
    local parts = {}
    for i, idx in ipairs(self:freeCellList()) do
        parts[i] = string.format("%d+%d", idx * 4, self:getCellLen(idx))
    end
    return table.concat(parts, ",")
end

-- This isn't a complicated calculation, it's more for clarity
function Chunk:getCellLen(cellIdx)
    return self[cellIdx]
end

function Chunk:getAllocLen(offset)
    return self:getCellLen((offset - 4) >> strideshift) - 4
end

function Chunk:free(offset)
    -- printf("free(0x%X)\n", offset)
    -- printf("freeCellList before: %s\n", self:freeCellListStr())
    assert(offset & 3 == 0, "Bad offset to free!")
    -- self:write(offset, string.rep("\xDD", self:getAllocLen(offset)))
    local cellIdx = (offset >> strideshift) - 1
    local cellLen = self:getCellLen(cellIdx)
    self:declareFreeCell(cellIdx, cellLen)
end

function Chunk:declareFreeCell(cellIdx, cellLen)
    self[cellIdx] = cellLen -- In the case of Chunk:free() this is already set, but do it here anyway to handle realloc

    -- Find the freeCell immediately before where this should go
    local prev = -1
    local fc = self[prev + 1]
    while fc ~= 0 do
        if fc > cellIdx then
            break
        end
        prev = fc
        fc = self[prev + 1]
    end

    local nextCell = self[prev + 1]
    -- printf("free(%X): prev=%X next=%X\n", cellIdx << strideshift, prev << strideshift, nextCell << strideshift)
    self[prev + 1] = cellIdx -- prev->next = cellIdx
    self[cellIdx + 1] = nextCell -- cell->next = nextCell

    -- Now check if we can coelsce cell with either its prev or its next
    if nextCell > 0 and cellIdx + (cellLen >> strideshift) == nextCell then
        -- printf("Merging cell %X len %d with next %X\n", cellIdx << strideshift, cellLen, nextCell << strideshift)
        cellLen = cellLen + self:getCellLen(nextCell)
        nextCell = self[nextCell + 1]
        self[cellIdx] = cellLen
        self[cellIdx + 1] = nextCell
    end
    if prev > 0 and prev + (self:getCellLen(prev) >> strideshift) == cellIdx then
        -- printf("Merging cell %X with prev %X len %d\n", cellIdx << strideshift, prev << strideshift, self:getCellLen(prev))
        self[prev] = self:getCellLen(prev) + cellLen -- set prev cellLen
        self[prev + 1] = nextCell
    end
    -- printf("freeCellList after: %s\n", self:freeCellListStr())
end

function Chunk:realloc(offset, sz)
    if sz == 0 then
        self:free(offset)
        return nil
    end

    -- Alloc lens are always rounded to a word size
    sz = (sz + 3) & ~3

    local allocLen = self:getAllocLen(offset)
    if sz <= allocLen then
        -- Shrink in place
        local cellIdx = (offset - 4) >> strideshift
        if allocLen - sz >= 8 then
            self[cellIdx] = sz
            self:declareFreeCell((offset + sz) >> strideshift, allocLen - sz)
        end
        return offset
    else
        local newOffset = self:alloc(sz)
        local oldIdx = offset >> strideshift
        local newIdx = newOffset >> strideshift
        -- This is a little more optimised than doing a read() followed by a write()
        for i = 0, (allocLen >> strideshift) - 1 do
            self[newIdx + i] = self[oldIdx + i]
        end
        self:free(offset)
        return newOffset
    end
end

Variable = class {
    _type = nil,
    _chunk = nil,
    _offset = nil, -- relative to start of _chunk
    _arrayLen = nil,
    _stringMaxLen = nil,
}

function Variable:__index(k)
    local v = Variable[k]
    if v then
        return v
    end

    -- Support array indexing, for array vars (do away with intermediary
    -- ArrayValue object since that isn't really an OPL concept).
    if type(k) == "number" then
        local t = self:type()
        assert(isArrayType(t), "Cannot array index a non-array Variable!")
        local len = self:arrayLen()
        if not (k > 0 and k <= len) then
            -- error(KErrSubs)
            error(string.format("Out of bounds: %d len=%d", k, len)) -- for %s\n", k, len, self))
        end
        local result = self._chunk:getVariableAtOffset(self._offset + (k - 1) * self:stride(), t & 0xF)
        if t == EStringArray then
            -- It's important to set _stringMaxLen because strings inside arrays
            -- don't have the max len field in the same place and there's no way
            -- for result to know where the correct location is (given how we're
            -- currently structuring the Variable object).
            result._stringMaxLen = self:stringMaxLen()
        end
        rawset(self, k, result) -- Cache for future
        return result
    end

    -- Fallback for accessing a non-existent member
    return nil
end

-- Convenience syntax to allow `foo[3] = bar` as well as `foo[3](bar)`
function Variable:__newindex(k, v)
    if type(k) == "number" then
        local t = self:type()
        assert(isArrayType(t), "Cannot array index assign to a non-array Variable!")
        self[k](v)
    else
        rawset(self, k, v)
    end
end

-- local sets = 0
-- local gets = 0
function Variable:__call(val)
    local t = self._type
    local chunk = self._chunk
    local offset = self._offset
    local offsetAlign = offset & 0x3
    local idx = offset >> strideshift
    if val ~= nil then
        -- Set value
        -- sets = sets + 1
        -- See comment on Addr._bnot() for how this works.
        -- The logic is "if type is EWord or ELong and val is an Addr rather than a number"
        if t < 2 and not ~val then
            -- Assigning an Addr to an integer variable...
            val = val:intValue()
        end

        -- Optmised cases
        if t == EWord and offsetAlign == 0 then
            chunk[idx] = ((chunk[idx] or 0) & 0xFFFF0000) | (val & 0xFFFF)
            return
        elseif t == EWord and offsetAlign == 2 then
            chunk[idx] = ((chunk[idx] or 0) & 0xFFFF) | ((val << 16) & 0xFFFF0000)
            return
        elseif t == ELong and offsetAlign == 0 then
            chunk[idx] = val & 0xFFFFFFFF
        elseif isArrayType(t) then
            error("Cannot assign to an array variable")
        end
        
        -- Slow path
        local data
        if t == EString then
            if type(val) ~= "string" then
                error("Cannot assign a "..type(val).." value to a string variable")
            end
            if #val > self:stringMaxLen() then
                printf("String too long: maxlen=%d val='%s'\n", self:stringMaxLen(), hexEscape(val))
                error(KErrStrTooLong)
            end
            data = string_pack("<B", #val)..val
        else
            data = string_pack(FmtForType[t], val)
        end
        chunk:write(offset, data)
    else
        -- gets = gets + 1
        -- Get value
        if t == EWord and offsetAlign == 0 then
            -- Optimisation
            local ret = (chunk[idx] or 0) & 0xFFFF
            if ret & 0x8000 ~= 0 then
                -- Have to sign extend it
                ret = ret | ~0xFFFF
            end
            return ret
        elseif t == EWord and offsetAlign == 2 then
            local ret = ((chunk[idx] or 0) & 0xFFFF0000) >> 16
            if ret & 0x8000 ~= 0 then
                -- Have to sign extend it
                ret = ret | ~0xFFFF
            end
            return ret
        elseif t == ELong and offsetAlign == 0 then
            local ret = chunk[idx] or 0
            if ret & 0x80000000 ~= 0 then
                -- Have to sign extend it
                ret = ret | ~0xFFFFFFFF
            end
            return ret
        elseif t == EString then
            local len = string_unpack("B", chunk:read(offset, 1))
            return chunk:read(offset + 1, len)
        elseif isArrayType(t) then
            error("Cannot get the value of an array variable")
        else
            -- Fall back to the slow path
            local bytes = chunk:read(offset, ValSize[t])
            local result = string_unpack(assert(FmtForType[t]), bytes)
            return result
        end
    end
end

function Variable:fixup(stringMaxLen, arrayLen)
    if self._type & 0xF == EString then
        assert(stringMaxLen, "Initializing a string variable requires max length to be specified")
        self._chunk:write(self._offset - 1, string_pack("BB", stringMaxLen, 0))
        self._stringMaxLen = stringMaxLen -- might as well set this while we're here
    end
    if isArrayType(self._type) then
        assert(arrayLen, "Initializing an array variable requires the array length to be specified")
        local arrayFixupIndex = (self._type == DataTypes.EStringArray) and self._offset - 3 or self._offset - 2
        self._chunk:write(arrayFixupIndex, string_pack("<I2", arrayLen))
        self._arrayLen = arrayLen -- might as well set this while we're here
    end
end

function Variable:type()
    return rawget(self, "_type")
end

function Variable:addressOf()
    return Addr {
        chunk = self._chunk,
        offset = self._offset,
    }
end

function Variable:stride()
    local valType = self:type() & 0xF
    if valType == EString then
        return 1 + self:stringMaxLen()
    else
        return assert(ValSize[valType])
    end
end

function Variable:free()
    assert(self._allocOffset, "Cannot free a non-alloced variable!")
    self._chunk:free(self._allocOffset)
    self._allocOffset = nil
    self._offset = nil
end

-- We don't have a size API because that would be ambiguous as to whether it
-- should include any array length or string max length bytes that come before
-- Variable._offset.
function Variable:endOffset()
    local valSize = self:stride()
    if isArrayType(self._type) then
        return self._offset + valSize * self:arrayLen()
    else
        return self._offset + valSize
    end
end

-- Note, this definition works fine for both strings and string arrays because
-- they both put the max len byte at the same place relative to self._offset
-- (but not for strings _in_ arrays, see comment below).
function Variable:stringMaxLen()
    assert(self._type & 0xF == EString, "Bad variable type in stringMaxLen!")
    if not self._stringMaxLen then
        -- We ensure _stringMaxLen is always set for array members, so we don't have to worry about that case.
        -- Equally a variable's max length can't change so it's safe to cache this.
        self._stringMaxLen = string_unpack("B", self._chunk:read(self._offset - 1, 1))
    end
    return self._stringMaxLen
end

function Variable:arrayLen()
    assert(isArrayType(self._type), "Bad variable type in arrayLen!")
    if not self._arrayLen then
        local arrayLenIndex = (self._type == DataTypes.EStringArray) and self._offset - 3 or self._offset - 2
        self._arrayLen = string_unpack("<I2", self._chunk:read(arrayLenIndex, 2))
    end
    return self._arrayLen
end

-- Providing Chunk.__tostring isn't defined, this defines a unique string for any chunk and offset combination.
local function uniqueKey(chunk, offset)
    return fmt("%s_%x", tostring(chunk):match("^table: (.*)"), offset)
end

function Variable:uniqueKey()
    return uniqueKey(self._chunk, self._offset)
end

function Variable:isPending()
    local t = self:type()
    if t == DataTypes.EWord then
        return self() == KErrFilePending
    elseif t == DataTypes.ELong then
        return self() == KRequestPending
    else
        error("Bad type for isPending")
    end
end

function Variable:setPending()
    local t = self:type()
    if t == DataTypes.EWord then
        self(KErrFilePending)
    elseif t == DataTypes.ELong then
        self(KRequestPending)
    else
        error("Bad type for isPending")
    end
end

--

Addr = class {
    chunk = nil,
    offset = 0,
}

local function getAddrAndOffset(lhs, rhs)
    -- Either of lhs or rhs could be the Addr, but it's an error if somehow
    -- both are (that would indicate the program has added 2 addresses together,
    -- which never makes sense to do)
    local lt = type(lhs)
    if lt == "table" then
        assert(type(rhs) == "number", "Bad rhs to getAddrAndOffset!")
        return lhs, rhs
    else
        assert(lt == "number", "Bad lhs to getAddrAndOffset!")
        -- Don't need to check rhs in this case, we wouldn't be here if it wasn't a table with a Addr metatable
        return rhs, lhs
    end
end

function Addr.__add(lhs, rhs)
    local addr, offset = getAddrAndOffset(lhs, rhs)
    if offset == 0 then
        -- No change
        return addr
    end

    local newOffset = addr.offset + offset
    return Addr {
        chunk = addr.chunk,
        offset = newOffset,
    }
end

function Addr.__sub(lhs, rhs)
    local addr, offset = getAddrAndOffset(lhs, rhs)
    return Addr.__add(addr, -offset)
end

-- Fast path optimisation hack for when a value is probably an integer in which
-- case no further action is needed, but might be an Addr in which case a slow
-- path is needed. Code can use `not ~val` to test if it's an Addr, because
-- ~val on any number value will always return a truthy value.
--
-- This is measurably faster in microbenchmarks, see:
--     time lua tbench_typenumber.lua
-- versus
--     time lua tbench_bnot.lua
function Addr.__bnot()
    return false
end

function Addr:__tostring()
    return fmt("0x%08X", self.chunk.address + self.offset)
end

-- This is a defense against code accidentally using an Addr as if it were a Variable
function Addr.__newindex()
    error("Cannot declare values in Addr!")
end

-- replacement for dereference
function Addr:asVariable(type)
    return self.chunk:getVariableAtOffset(self.offset, type)
end

function Addr:intValue()
    return self.chunk.address + self.offset
end

function Addr:read(len)
    return self.chunk:read(self.offset, len)
end

function Addr:write(data)
    return self.chunk:write(self.offset, data)
end

function Addr:writeArray(array, valueType)
    local valSz = assert(ValSize[valueType], "Bad type to writeArray")
    local fmt = FmtForType[valueType]
    local parts = {}
    for i, val in ipairs(array) do
        parts[i] = string_pack(fmt, val)
    end
    self.chunk:write(self.offset, table.concat(parts))
end

function Addr:uniqueKey()
    return uniqueKey(self.chunk, self.offset)
end

function printStats()
    -- printf("gets = %d, sets = %d\n", gets, sets)
end

return _ENV
