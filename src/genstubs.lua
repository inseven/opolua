#!/usr/local/bin/lua-5.3

local fmt = string.format

function fileToLines(path)
    local lines = {}
    local f = assert(io.open(path, "r"))
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

-- Find the lowest key in tbl which is greater than val, and return its val
function lowerBound(tbl, val)
    local curr
    for k, v in pairs(tbl) do
        -- print(k,v)
        if k > val and (curr == nil or k < curr) then
            -- print("Found!", k)
            curr = k
        end
    end
    return tbl[curr]
end

function createStubsFor(modName)
    local mod = require(modName)

    local lines = fileToLines(modName..".lua")

    local lineStarts = {}
    for code, fnName in pairs(mod.codes) do
        local fn = mod[fnName]
        if type(fn) == "function" and fnName ~= "IllegalOpCode" and fnName ~= "IllegalFuncOpCode" then
            lineStarts[code] = debug.getinfo(fn, "S").linedefined
        end
    end
    
    local sortedOps = {}
    for k, v in pairs(mod.codes) do
        table.insert(sortedOps, k)
    end
    table.sort(sortedOps, function(l, r) return l > r end)


    for _, code in ipairs(sortedOps) do
        local fnName = mod.codes[code]
        local fn = mod[fnName]
        if not fn then
            local insertAtLine = lowerBound(lineStarts, code)
            print(string.format("No implementation for %s, insert 0x%02X @ %d", fnName, code, insertAtLine or -1))
            local stub = {
                fmt("function %s(stack, runtime) -- 0x%02X", fnName, code),
                '    error("Unimplemented opcode!")',
                "end",
                ""
            }
            -- print(lines[insertAtLine])
            if insertAtLine == nil then
                insertAtLine = #lines
            end

            for i, line in ipairs(stub) do
                table.insert(lines, insertAtLine + i - 1, line)
            end
        end
    end

    local f = assert(io.open(modName..".lua", "w"))
    f:write(table.concat(lines, "\n"))
    f:write("\n")
    f:close()
end

function main()
    require("init")
    createStubsFor("ops")
    createStubsFor("fns")
end

main()
