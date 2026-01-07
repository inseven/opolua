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

local function unhandledType(t, outputFormat)
    if outputFormat == "json" then
        local s = tostring(t):gsub("[\"\b\f\n\r\t\\]", {
            ["\b"] = "\\b",
            ["\f"] = "\\f",
            ["\n"] = "\\n",
            ["\r"] = "\\r",
            ["\t"] = "\\t",
            ["\""] = "\\\"",
            ["\\"] = "\\\\",
        })
        -- Anything else non-printable, escape with \u
        s = s:gsub("[\x00-\x1F]", function(m) return string.format("\\u%04X", m:byte()) end)
        return '"'..s..'"'
    else
        return tostring(t)
    end
end

-- Put strings at the top of the order, improves legibility of mixed tables
local typeOrder = {
    string = 1,
    boolean = 2,
    ["function"] = 3,
    ["nil"] = 4,
    number = 5,
    table = 6,
    thread = 7,
    userdata = 8,
}

local function keySorter(a, b)
    local typea, typeb = type(a), type(b)
    if typea == typeb then
        if typea == "userdata" or typea == "table" or typea == "thread" then
            -- not comparable in the general case
            return tostring(a) < tostring(b)
        end
        return a < b
    else
        return typeOrder[typea] < typeOrder[typeb]
    end
end

local reservedWords = {
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
}

function validLuaIdentifier(str)
    if not str:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        return false
    end
    for _, reservedWord in ipairs(reservedWords) do
        if str == reservedWord then
            return false
        end
    end
    return true
end

-- We get into O(N^2) silliness after a certain point - it's guaranteed we'll
-- find a valid escape sequence eventually (ie, we will halt) but it stops being
-- a worthwhile exercise long before that.
local maxLongEscapeEquals = 5

local function quotedString(str, outputFormat, tableKey)
    local changeEscapeIfNicer = outputFormat == "quoted_long"
    if changeEscapeIfNicer and tableKey and validLuaIdentifier(str) then
        return str
    end

    local result = string.format("%q", str)

    if changeEscapeIfNicer then
        local _, nescapes = result:gsub("\\.", "")
        if nescapes > 1 then
            local neqs = 0
            local found = nil
            while not found and neqs <= maxLongEscapeEquals do
                local eqs = string.rep("=", neqs)
                local start = string.format("[%s[", eqs)
                local ending = string.format("]%s]", eqs)
                local longEscape = start .. str .. ending
                if longEscape:find(ending) < #start + #str then
                    -- the ending escape was either found in str, or when str
                    -- had ending concatenated on it, so keep looking
                    neqs = neqs + 1
                else
                    found = longEscape
                end
            end
            if found and #found < #result then
                result = found
            end
        end
    end

    if tableKey then
        if result:match("^%[") then
            return string.format("[ %s ]", result)
        else
            return string.format("[%s]", result)
        end
    end

    return result
end

local jsonDictHintMetatable

function dump(t, outputFormat, indent, indentChars, seenTables)
    if outputFormat == "" then
        outputFormat = "minimal"
    elseif outputFormat ~= "quoted" and outputFormat ~= "minimal" and outputFormat ~= "json" then
        -- quoted_long is now the default, and also what's used if an unrecognized format is requested.
        outputFormat = "quoted_long"
    end

    local outputQuoted = outputFormat == "quoted" or outputFormat == "quoted_long"
    local typet = type(t)
    if typet ~= "table" then
        if outputQuoted and typet == "string" then
            return quotedString(t, outputFormat)
        elseif outputFormat == "json" then
            if typet == "number" or typet == "boolean" then
                return tostring(t)
            elseif t == json.null then
                return "null"
            end
        end
        return unhandledType(t, outputFormat)
    elseif outputFormat == "minimal" then
        local mt = getmetatable(t)
        if mt and mt.__tostring and mt.__name then
            return string.format("%s (%s)", tostring(t), mt.__name)
        end
    end
    if not indent then indent = 0 end
    if not indentChars then indentChars = "  " end
    if seenTables == nil then seenTables = {} end
    if seenTables[t] then
        -- We have a data structure that (possibly indirectly) points back to itself
        return unhandledType(t, outputFormat)
    else
        seenTables[t] = true
    end
    local array = true -- Set to false if we find anything disqualifying this from being an array
    local sortedKeys = {}

    for k in pairs(t) do
        if math.type(k) ~= "integer" then array = false end
        table.insert(sortedKeys, k)
    end
    table.sort(sortedKeys, keySorter)
    local nkeys = #sortedKeys
    local tableStart, tableEnd = "{", "}"
    if nkeys == 0 and outputFormat == "json" then
        -- Check if there's a hint to say that this should be a dict
        if getmetatable(t) == json.dictHintMetatable then
            array = false
        end
    end
    -- We could do better when formatting mixed array/map tables when the array
    -- part is still a sequence, but it doesn't matter that much.
    if array then
        for i, k in ipairs(sortedKeys) do
            if i ~= k then
                array = false
                break
            end
        end
    end
    if array and outputFormat == "json" then
        tableStart, tableEnd = "[", "]"
    end
    if nkeys == 0 then
        -- Special case so it doesn't return {\n}
        return tableStart..tableEnd
    end
    local mt = getmetatable(t)
    if outputFormat == "minimal" and mt and mt.__name then
        tableStart = mt.__name .. " " .. tableStart
    end
    local ret = { tableStart }
    local indentStr = string.rep(indentChars, indent)
    local nextIndent = indentStr..indentChars
    for i, k in ipairs(sortedKeys) do
        local vtext = dump(t[k], outputFormat, indent + 1, indentChars, seenTables)
        local ktext, str
        if outputQuoted then
            if array then
                -- Omit the key
                str = string.format("%s%s,", nextIndent, vtext)
            else
                if type(k) == "string" then
                    ktext = quotedString(k, outputFormat, true)
                else
                    ktext = "["..tostring(k).."]"
                end
                str = string.format("%s%s = %s,", nextIndent, ktext, vtext)
            end
        elseif outputFormat == "json" then
            local suffix = (i == nkeys) and "" or "," -- No trailing commas allowed in JSON
            if array then
                str = string.format("%s%s%s", nextIndent, vtext, suffix)
            else
                -- Keys must be quoted strings in json, so we have to be potentially lossy here and do a tostring(k)
                ktext = string.format("%q", tostring(k))
                str = string.format("%s%s: %s%s", nextIndent, ktext, vtext, suffix)
            end
        else
            ktext = tostring(k)
            str = string.format("%s%s: %s", nextIndent, ktext, vtext)
        end
        table.insert(ret, str)
    end
    table.insert(ret, indentStr..tableEnd)
    return table.concat(ret, "\n")
end
