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

fns = {
    [1] = "DbAddField",
    [2] = "DbAddFieldTrunc",
    [3] = "DbCreateIndex",
    [4] = "DbDeleteKey",
    [5] = "DbDropIndex",
    [6] = "DbGetFieldCount",
    [7] = "DbGetFieldName",
    [8] = "DbGetFieldType",
    [9] = "DbIsDamaged",
    [10] = "DbIsUnique",
    [11] = "DbMakeUnique",
    [12] = "DbNewKey",
    [13] = "DbRecover",
    [14] = "DbSetComparison",
}

keys = {}

function DbAddField(stack, runtime) -- 1
    local k, field, order = stack:pop(3)
    printf("DbAddField k=%d field=%s order=%d\n", k, field, order)
    stack:push(0)
end

function DbAddFieldTrunc(stack, runtime) -- 2
    local k, field, order, trunc = stack:pop(4)
    printf("DbAddFieldTrunc k=%d field=%s order=%d trunc=%d\n", k, field, order, trunc)
    stack:push(0)
end

function DbCreateIndex(stack, runtime) -- 3
    local index, key, path, tableName = stack:pop(4)
    printf("DbCreateIndex(%s, %s, %s)\n", index, path, tableName)
    stack:push(0)
end

function DbDeleteKey(stack, runtime) -- 4
    keys[stack:pop()] = nil
    stack:push(0)
end

function DbDropIndex(stack, runtime) -- 5
    local index, path, tableName = stack:pop(3)
    printf("DbDropIndex(%s, %s, %s)\n", index, path, tableName)
    stack:push(0)
end

function DbGetFieldCount(stack, runtime) -- 6
    local path, tblName = stack:pop(2)
    local db = runtime:newDb(path, nil)
    local tbl = db.tables[tblName]
    assert(tbl, KErrInvalidArgs) -- Probably?
    stack:push(#tbl.fields)
end

function DbGetFieldName(stack, runtime) -- 7
    local path, tblName, fieldNum = stack:pop(3)
    local db = runtime:newDb(path, nil)
    local tbl = db.tables[tblName]
    assert(tbl, KErrInvalidArgs) -- Probably?
    local field = tbl[fieldNum] -- fieldNum is 1 based
    assert(field, KErrInvalidArgs) -- Probably?
    stack:push(field.name)
end

function DbGetFieldType(stack, runtime) -- 8
    local path, tblName, fieldNum = stack:pop(3)
    local db = runtime:newDb(path, nil)
    local tbl = db.tables[tblName]
    assert(tbl, KErrInvalidArgs) -- Probably?
    local field = tbl[fieldNum]
    assert(field, KErrInvalidArgs) -- Probably?
    stack:push(field.rawType)
end

function DbIsDamaged(stack, runtime) -- 9
    stack:pop() -- path
    -- Since we don't read indexes anyway, let's just say... no?
    stack:push(0)
end

function DbIsUnique(stack, runtime) -- 10
    unimplemented("opx.dbase.DbIsUnique")
end

function DbMakeUnique(stack, runtime) -- 11
    unimplemented("opx.dbase.DbMakeUnique")
end

function DbNewKey(stack, runtime) -- 12
    local k = #keys + 1
    keys[k] = {}
    stack:push(k)
end

function DbRecover(stack, runtime) -- 13
    local path = stack:pop(1)
    printf("DbRecover(%s)\n", path)
    stack:push(0)
end

function DbSetComparison(stack, runtime) -- 14
    -- unimplemented("opx.dbase.DbSetComparison")
    local key, order = stack:pop(2)
    stack:push(0)
end

return _ENV
