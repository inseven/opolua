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
        return string.pack("<I2", self._val)
    elseif t == DataTypes.ELong then
        return string.pack("<I4", self._val)
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
        return self._val
    else
        return self._val .. string.rep("\0", self:getMaxLen() - #self._val)
    end
end

function Variable:updateStringData(idx, data)
    assert(self:type() == DataTypes.EString, "Can't updateStringData for non-string variables!")
    assert(idx + #data <= self:getMaxLen(), "Attempt to updateStringData beyond max length!")
    if self._len == nil then
        -- Extend the string to the max len to make the maths easier (__call knows to sub() it)
        local len = #self.val
        self._val = self:getAllStringData()
        self._len = len
    end
    self._val = self._val:sub(1, idx)..data..self._val:sub(idx + 1 + #data)
    assert(#self._val == self:getMaxLen(), "Oh dear I've messed up the maths")
end

function Variable:setStringLength(len)
    assert(len <= self:getMaxLen(), "Attempt to setStringLength beyond maxLen")
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
    assert(newOffset >= 0 and newOffset <= addr.len, "Address calculation out of bounds!")
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

function AddrSlice:getOffsetAsArrayPosition()
    local valSz = self.var:stride()
    assert(self.offset < self.len and self.offset % valSz == 0, "Addr is not pointing to an array entry!")
    return 1 + (self.offset // valSz)
end

function AddrSlice:dereference(arrayPos)
    if not arrayPos then
        arrayPos = 1
    end
    assert(arrayPos > 0, "Cannot dereference backwards") -- just no.
    if isArrayType(self.var:type()) then
        local arrayVal = self.var()
        local pos = self:getOffsetAsArrayPosition() + (arrayPos - 1)
        return arrayVal[pos]
    else
        assert(self.offset == 0, "Addr not pointing to start of value!")
        assert(arrayPos == 1, "dereference beyond slice bounds!")
        return self.var
    end
end

function AddrSlice:getLength()
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
    [DataTypes.EWord] = "<I2",
    [DataTypes.ELong] = "<I4",
    [DataTypes.EReal] = "<d",
}

local function applyDataToSimpleVar(data, var, offset)
    assert(offset + #data <= var:stride(), "Too much data for this var!")
    local vart = var:type()
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
    else
        assert(offset == 0 and #data == SizeofType[vart], "Setting a primitive type with data not of the same size?!")
        local fmt = FmtForType[vart]
        var(string.unpack(fmt, data))
    end
end 

function AddrSlice:write(data)
    if #data == 0 then
        return
    end

    local dataIdx = 0
    local varIdx = 0
    local stride = self.var:stride()
    while dataIdx + stride <= #data do
        local var = self:dereference(1 + varIdx)
        local dataPiece = data:sub(1 + dataIdx, dataIdx + stride)
        -- assert(#dataPiece == stride, "Oh dear maths fail")
        applyDataToSimpleVar(dataPiece, var, dataIdx % stride)
        dataIdx = dataIdx + stride
        varIdx = varIdx + 1
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
