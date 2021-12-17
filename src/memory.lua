_ENV = module()

-- To get the var at the given (1-based) pos, do arrayVar()[pos]. This will do
-- the bounds check and create a var if necessary. It is an error to assign
-- directly to the array, do arrayVar()[pos](newVal) instead - ie get the val,
-- then assign to it using the function syntax.
ArrayValue = class {
    _type = nil,
    _len = nil,
    _stringMaxLen = nil,
}

function ArrayValue:__index(k)
    if ArrayValue[k] then
        return ArrayValue[k]
    end
    local len = rawget(self, "_len")
    assert(len, "Array length has not been set!")
    assert(type(k) == "number", "Attempt to index "..tostring(k))
    if not (k > 0 and k <= len) then
        error(string.format("Out of bounds: %d len=%d for %s\n", k, len, ArrayValue.__tostring(self)))
    end
    assert(k > 0 and k <= len, KOplErrSubs)
    local valType = rawget(self, "_type")
    local maxLen = rawget(self, "_stringMaxLen")
    local result = makeVar(valType, maxLen)
    result:setParent(self, k)
    rawset(self, k, result)
    -- And default initialize the array value
    result(DefaultSimpleTypes[valType])
    return result
end

function ArrayValue:__newindex(k, v)
    error("Runtime should never be assigning to a array var index!")
end

function ArrayValue:arrayLen()
    return rawget(self, "_len")
end

function ArrayValue:valueType()
    return rawget(self, "_type")
end

function ArrayValue:__tostring()
    local result = {}
    local len = self:arrayLen()
    for i = 1, len do
        result[i] = tostring(self[i])
    end
    return string.format("[t=%d, %s]", self:valueType(), table.concat(result, ", "))
end

function newArrayVal(valueType, len, stringMaxLen)
    return ArrayValue {
        _type = valueType,
        _len = len,
        _stringMaxLen = stringMaxLen
    }
end

--

Variable = class {
    _type = nil,
    _parent = nil,
    _idx = nil,
    _maxLen = nil,
    _val = nil,
}

function Variable:__call(val)
    if val ~= nil then
        -- TODO should probably assert that val's type is correct for our type
        if self._len then
            self:updateStringData(0, val)
            self._len = #val
        else
            self._val = val
        end
    else
        if self._len then
            return self._val:sub(1, self._len)
        else
            return self._val
        end
    end
end

function Variable:__tostring()
    if self._type == DataTypes.EString then
        return string.format('"%s"', hexEscape(self()))
    else
        return tostring(self())
    end
end

function Variable:type()
    return self._type
end

function Variable:addressOf()
    -- For array items, addressOf yields an AddrSlice that is allows access to
    -- all the values in the array, kinda like how & operator in C technically
    -- doesn't allow you to index that pointer beyond the array bounds (even
    -- though most people ignore that, undefined behaviour oh well).
    local parentArrayVal = self:getParent()
    if parentArrayVal then
        local valSz = self:stride()
        local arrayVar = makeVar(parentArrayVal:valueType() | 0x80)
        arrayVar(parentArrayVal)
        return AddrSlice {
            offset = (self:getIndexInArray() - 1) * valSz,
            len = parentArrayVal:arrayLen() * valSz,
            var = arrayVar,
        }
    else
        return AddrSlice {
            offset = 0,
            len = self:stride(),
            var = self,
        }
    end
end

function Variable:setParent(parentArrayVal, parentIdx)
    self._parent = parentArrayVal
    self._idx = parentIdx
end

function Variable:getParent()
    return self._parent
end

function Variable:getIndexInArray()
    assert(self._idx, "Cannot call getIndexInArray on a variable not in an array!")
    return self._idx
end

function Variable:setMaxLen(maxLen)
    assert(self:type() == DataTypes.EString, "Can't set maxLen for non-string variables!")
    self._maxLen = maxLen or 255
end

function Variable:getMaxLen()
    assert(self:type() == DataTypes.EString, "Can't get maxLen for non-string variables!")
    assert(self._maxLen, "Missing maxLen!")
    return self._maxLen
end

function Variable:stride()
    if isArrayType(self._type) then
        return self._val[1]:stride()
    elseif self._type == DataTypes.EString then
        return 1 + self:getMaxLen()
    else
        return assert(SizeofType[self._type], "Bad type in stride!")
    end
end

function Variable:getBytes()
    local t = self._type
    if t == DataTypes.EWord then
        return string.pack("<i2", self._val)
    elseif t == DataTypes.ELong then
        return string.pack("<i4", self._val)
    elseif t == DataTypes.EReal then
        return string.pack("<d", self._val)
    elseif t == DataTypes.EString then
        return string.pack("s1", self:getAllStringData())
    else
        error("Bad type in getBytes!")
    end
end

function Variable:getAllStringData()
    if self._len then
        -- Already expanded
        return self._val, self._len
    else
        local realLen = #self._val
        return self._val .. string.rep("\0", self:getMaxLen() - realLen), realLen
    end
end

function Variable:ensureStringExpanded()
    if not self._len then
        self._val, self._len = self:getAllStringData()
    end
end

function Variable:updateStringData(idx, data)
    assert(self:type() == DataTypes.EString, "Can't updateStringData for non-string variables!")
    assert(idx + #data <= self:getMaxLen(), "Attempt to updateStringData beyond max length!")
    self:ensureStringExpanded()
    self._val = self._val:sub(1, idx)..data..self._val:sub(idx + 1 + #data)
    assert(#self._val == self:getMaxLen(), "Oh dear I've messed up the maths")
end

function Variable:setStringLength(len)
    assert(len <= self:getMaxLen(), "Attempt to setStringLength beyond maxLen")
    self:ensureStringExpanded()
   self._len = len
end

function makeVar(type, maxLen)
    local result = Variable { _type = type }
    if type == DataTypes.EString then
        result:setMaxLen(maxLen)
    end
    return result
end

--

AddrSlice = class {
    offset = 0,
    len = 0,
    var = nil,
}

local function getAddrAndOffset(lhs, rhs)
    -- Either of lhs or rhs could be the AddrSlice, but it's an error if somehow
    -- both are (that would indicate the program has added 2 addresses together,
    -- which never makes sense to do)
    local lt = type(lhs)
    if lt == "table" then
        assert(type(rhs) == "number", "Bad rhs to getAddrAndOffset!")
        return lhs, rhs
    else
        assert(lt == "number", "Bad lhs to getAddrAndOffset!")
        -- Don't need to check rhs in this case, we wouldn't be here if it wasn't a table with a AddrSlice metatable
        return rhs, lhs
    end
end

function AddrSlice.__add(lhs, rhs)
    local addr, offset = getAddrAndOffset(lhs, rhs)
    local newOffset = addr.offset + offset
    if newOffset < 0 or newOffset > addr.len then
        printf("Warning: 0x%08X + %d outside of 0-%08X for var %s\n", addr.offset, offset, addr.len, addr.var)
        -- error("Address calculation out of bounds!")
        -- Strictly speaking it's not an error until you try and dereference it
    end
    return AddrSlice {
        offset = newOffset,
        len = addr.len,
        var = addr.var,
    }
end

function AddrSlice.__sub(lhs, rhs)
    local addr, offset = getAddrAndOffset(lhs, rhs)
    return AddrSlice.__add(addr, -offset)
end

function AddrSlice:dereference()
    assert(self.offset == 0, "Addr not pointing to start of value!")
    if isArrayType(self.var:type()) then
        return self.var()[1]
    else
        return self.var
    end
end

function AddrSlice:getVarForOffset(offset)
    local offset = self.offset + offset
    local stride = self.var:stride()
    if isArrayType(self.var:type()) then
        local idx = offset // stride
        local remainder = offset - (idx * stride)
        local pos = idx + 1
        assert(pos > 0 and pos <= self.var():arrayLen(), "Out of bounds!")
        return self.var()[pos], remainder
    else
        assert(offset < stride, "Out of bounds!")
        return self.var, offset
    end
end

function AddrSlice:getValidLength()
    return self.len - self.offset
end

function AddrSlice:read(len)
    local varData
    if isArrayType(self.var:type()) then
        -- Have to potentially span data from across multiple vars, fun....
        -- For simplicity just flatten everything then sub it. Super inefficient, but easy to code
        local arrayVal = self.var()
        local allData = {}
        for i = 1, arrayVal:arrayLen() do
            allData[i] = arrayVal[i]:getBytes()
        end
        varData = table.concat(allData)
    else
        varData = self.var:getBytes()
    end
    assert(#varData == self.len, "getBytes didn't return the expected len!")
    local result = varData:sub(1 + self.offset, self.offset + len)
    assert(#result == len, "Not enough data in var to satisfy read!")
    return result
end

local FmtForType = {
    [DataTypes.EWord] = "<i2",
    [DataTypes.ELong] = "<i4",
    [DataTypes.EReal] = "<d",
}

local function applyDataToSimpleVar(data, var, offset)
    assert(offset + #data <= var:stride(), "Too much data for this var!")
    local vart = var:type()
    -- printf("applyDataToSimpleVar datalen=%d offset=%d vartype=%d stride=%d\n", #data, offset, vart, var:stride())
    if vart == DataTypes.EString then
        local newLen
        if offset == 0 then
            -- Updating the length
            newLen = string.unpack("B", data)
            offset = 1
            data = data:sub(2)
        end
        if #data > 0 then
            var:updateStringData(offset - 1, data)
        end
        if newLen then
            var:setStringLength(newLen)
        end
    elseif offset == 0 and #data == SizeofType[vart] then
        -- We can simply assign
        local fmt = FmtForType[vart]
        var(string.unpack(fmt, data))
    else
        local fmt = FmtForType[vart]
        local stringVar = makeVar(DataTypes.EString, string.packsize(fmt))
        stringVar(string.pack(fmt, var()))
        applyDataToSimpleVar(data, stringVar, offset + 1)
        var(string.unpack(fmt, stringVar()))
    end
end 

function AddrSlice:write(data)
    if #data == 0 then
        return
    end

    -- printf("WRITE: offset %d len=%d stride=%d to '%s'\n", self.offset, #data, self.var:stride(), self.var())

    local dataIdx = 0
    local stride = self.var:stride()
    while dataIdx < #data do
        local var, varOffset = self:getVarForOffset(dataIdx)
        local dataPiece = data:sub(1 + dataIdx, dataIdx + stride)
        -- assert(#dataPiece == stride, "Oh dear maths fail")
        applyDataToSimpleVar(dataPiece, var, varOffset)
        dataIdx = dataIdx + stride
    end
end


function AddrSlice:writeArray(array, valueType)
    -- Most of the time the underlying var will probably be of the same type so
    -- we could save some complexity here and just set the underlying var's
    -- array values directly, but this way handles all the corner cases
    local valSz = assert(SizeofType[valueType], "Bad type to writeArray")
    local fmt = FmtForType[valueType]
    local offset = self.offset
    for i, val in ipairs(array) do
        local data = string.pack(fmt, val)
        self:write(data)
        self.offset = self.offset + valSz
    end
    -- Restore offset
    self.offset = offset
end

return _ENV