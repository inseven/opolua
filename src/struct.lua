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

BYTE = "B"
UINT = "I4"
USHORT = "I2"
LONG = "i4"
BSTRING = "s1"
-- These two are our extensions to pack format
TCARDINALITY = "^"
SSTRING = "&"

Struct = class {}
Instance = class {}

function Struct:sizeof()
    local sz = 0
    for _, member in ipairs(self) do
        sz = sz + string.packsize(member[2])
    end
    return sz
end

-- pos and result are zero-based indexes
function Struct.unpackMember(fmt, data, pos)
    if fmt == TCARDINALITY then
        local val, nextPos = readCardinality(data, 1 + pos)
        return val, nextPos - 1
    elseif fmt == SSTRING then
        local sz, nextPos = readSpecialEncoding(data, 1 + pos)
        return string.sub(data, nextPos, nextPos + sz - 1), nextPos - 1 + sz
    else
        local val, nextPos = string.unpack("<"..fmt, data, 1 + pos)
        return val, nextPos - 1
    end
end

function Struct:unpack(data, pos)
    if pos == nil then
        pos = 0
    end
    -- TODO reinstate this check
    -- local sz = self:sizeof()
    -- if pos + sz > #data then
    --     printf("Warning: struct %s (size 0x%X) at 0x%X extends beyond the data\n", self.name, sz, pos)
    --     return nil
    -- end

    local result = Instance {
        _type = self,
        _pos = pos,
        _size = 0,
    }
    for i, memberDef in ipairs(self) do
        local memberName, memberType = table.unpack(memberDef)
        result:appendMember(memberName, memberType, data)
    end
    return result
end

function Instance:appendMember(memberName, memberType, data)
    -- printf("appendMember %s @ %X\n", memberName, self:endPos())
    local pos = self:endPos()
    local val, nextPos = Struct.unpackMember(memberType, data, pos)
    local memberSize = nextPos - pos
    local printfmt
    if memberType == TCARDINALITY then
        printfmt = "%X"
    elseif math.type(val) == "integer" then
        printfmt = string.format("%%0%dX", string.packsize(memberType) * 2)
    else
        printfmt = "%s"
    end
    table.insert(self, {
        name = memberName,
        pos = pos,
        size = memberSize,
        printfmt = printfmt,
        value = val,
    })
    self[memberName] = val
    self._size = self._size + memberSize
end

function Instance:appendInstanceArray(memberName, instanceArray)
    local arr = {}
    for arrayIndex, instance in ipairs(instanceArray) do
        assert(instance._pos == self:endPos(), "mindthegap")
        local newInstance = {} -- well, not really an instance. Just a container for use by arr when array indexing
        arr[arrayIndex] = newInstance
        for _, member in ipairs(instance) do
            local newMember = {
                name = string.format("%s[%d].%s", memberName, arrayIndex, member.name),
                pos = member.pos,
                size = member.size,
                printfmt = member.printfmt,
                value = member.value,
                annotation = member.annotation,
            }
            table.insert(self, newMember)
            newInstance[member.name] = newMember
            self._size = self._size + member.size
        end
    end
    self[memberName] = arr
end

function Instance:dump()
    for _, member in ipairs(self) do
        local annotation = ""
        if member.annotation then
            annotation = string.format(" (%s)", member.annotation)
        end
        printf("%08X %s.%s "..member.printfmt.."%s\n", member.pos, self._type.name, member.name, member.value, annotation)
    end
end

function Instance:endPos()
    return self._pos + self._size
end

function Instance:appendStructArray(count, structType, data)
    local pos = self._pos + self._size
    local sz = structType:sizeof() * count
    if pos + sz > #data then
        printf("warning: Array data for %s extends beyond the data\n", structType.name)
        return false
    end
    local arr = {}
    self[structType.name] = arr
    for i = 1, count do
        local entry = structType:unpack(data, pos)
        arr[i] = entry
        for _, entryMember in ipairs(entry) do
            entryMember.name = string.format("%s[%d].%s", structType.name, i, entryMember.name)
            table.insert(self, entryMember)
        end
        pos = pos + entry._size
        self._size = self._size + entry._size
    end
    return true
end

function Instance:appendStruct(structType, data, pos, namePrefix)
    assert(pos == self:endPos(), "Gap in members!")
    local instance = structType:unpack(data, pos)
    if namePrefix == nil then
        namePrefix = ""
    end
    for _, member in ipairs(instance) do
        member.name = namePrefix .. member.name
        assert(self[member.name] == nil, "Duplicate member in Instance being concatenated")
        table.insert(self, member)
        self[member.name] = member.value
    end
    self._size = instance._pos + instance._size - self._pos
end

function Instance:annotate(name, annotation)
    local found
    for i, member in ipairs(self) do
        if member.name == name then
            found = i
            break
        end
    end
    assert(found, "Field not found!")
    self[found].annotation = annotation
end

function import(env)
    for k, v in pairs(_ENV) do
        env[k] = v
    end
end

return _ENV
