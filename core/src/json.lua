-- Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

local lex = require("lex")
local synerror, synassert = lex.synerror, lex.synassert

local string_find, string_match, string_sub, string_pack = string.find, string.match, string.sub, string.pack
local table_insert = table.insert

local jsonLang = {
    statemachine = {
        ['%['] = 'obracket',
        ['%]'] = 'clobracket',
        ['%{'] = 'ocurly',
        ['%}'] = 'clocurly',
        [','] = 'comma',
        [':'] = 'colon',
        ['[ \t\r\n]+'] = 'space',
        -- Leading zeros not allowed in JSON
        ['%-?0'] = 'number',
        ['%-?[1-9]+[0-9]*'] = {
            [''] = 'number',
            ['[eE][%+%-]?[0-9]+'] = 'number', -- integer with exponent
            ['%.[0-9]*'] = {
                [''] = 'number', -- float
                ['[eE][%+%-]?[0-9]+'] = 'number', -- float with exponent
            },
        },
        ['null'] = 'null',
        ['true'] = 'bool',
        ['false'] = 'bool',
        ['"'] = function(text, tokenStart)
            local pos = tokenStart + 1
            while true do
                local delim, nextPos = string_match(text, '(["\r\n])()', pos)
                if delim == '"' then
                    if string_sub(text, nextPos - 2, nextPos - 2) == '\\' then
                        -- Escaped quote, keep going
                        pos = nextPos
                    else
                        -- End of string
                        return "string", string_sub(text, tokenStart, nextPos - 1)
                    end
                else
                    return "error", 'Unmatched "'
                end
            end
        end,
    },
}

-- JSON strings are complicated enough thanks to unicode surrogates that it's worth invoking the lexer again to parse
-- them.
local stringLang = {
    statemachine = {
        ['\\'] = {
            ['"'] = 'quote',
            ['\\'] = 'backslash',
            ['/'] = 'slash',
            ['b'] = 'backspace',
            ['f'] = 'formfeed',
            ['n'] = 'lf',
            ['r'] = 'cr',
            ['t'] = 'tab',
            ['u'] = {
                ['[dD]'] = {
                    ['[0-7][0-9A-Fa-f][0-9A-Fa-f]'] = 'unicode',
                    ['[89aAbB][0-9A-Fa-f][0-9A-Fa-f]'] = { -- Opening surrogate pair
                        ['\\u[dD][cCdDeEfF][0-9A-Fa-f][0-9A-Fa-f]'] = 'surrogatepair',
                        [''] = 'baresurrogate'
                    },
                    ['[cCdDeEfF][0-9A-Fa-f][0-9A-Fa-f]'] = 'baresurrogate',
                },
                ['[0-9a-cA-Ce-fE-F][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'] = 'unicode',
            },
        },
        ['[\x00-\x1F]'] = 'control',
        ['[^\x00-\x1F\\]+'] = 'text',
    }
}

function parseLiteral(tok)
    if tok.type == "string" then
        -- See https://www.rfc-editor.org/info/rfc4627/#section-2.5
        local strdata = assert(tok.val:match('^"(.*)"$'))
        local parts = lex.lex(strdata, nil, stringLang)
        local result = {}
        while parts:current().type ~= "eos" do
            local part = parts:current()
            local partsrc = { tok.src[1], tok.src[2], tok.src[3] + part.src[3] - 1 }
            local t = part.type
            if t == "text" then
                table_insert(result, part.val)
            elseif t == "quote" then
                table_insert(result, '"')
            elseif t == "backslash" then
                table_insert(result, '\\')
            elseif t == "slash" then
                table_insert(result, '/')
            elseif t == "backspace" then
                table_insert(result, '\b')
            elseif t == "formfeed" then
                table_insert(result, '\f')
            elseif t == "lf" then
                table_insert(result, '\n')
            elseif t == "cr" then
                table_insert(result, '\r')
            elseif t == "tab" then
                table_insert(result, '\t')
            elseif t == "unicode" then
                table_insert(result, utf8.char(assert(tonumber(part.val:sub(3), 16)))) -- 3 skips over the \u
            elseif t == "surrogatepair" then
                local hi, lo = string_match(part.val, "\\u(....)\\u(....)")
                local hicode = assert(tonumber(hi, 16))
                local locode = assert(tonumber(lo, 16))
                local code = ((hicode - 0xD800) << 10) + (locode - 0xDC00)
                table_insert(result, utf8.char(code))
            elseif t == "baresurrogate" then
                synerror({src = partsrc}, "Illegal bare surrogate")
            elseif t == "control" then
                synerror({src = partsrc}, "Illegal control character")
            else
                synerror({src = partsrc}, "Unhandled token type %s", t)
            end
            parts:advance()
        end
        return table.concat(result)
    elseif tok.type == "number" then
        local result = tonumber(tok.val) -- Lua number format basically supports everything JSON allows
        synassert(result, tok, "Expected number")
        return result
    elseif tok.type == "bool" then
        return tok.val == "true"
    else
        synerror(tok, "Expected literal")
    end
end

local function parseString(tok)
    synassert(tok.type == "string", tok, "Expected string")
    return parseLiteral(tok)
end

-- parseValue should always leave tokens pointing at the next token after the parsed value
local function parseValue(tokens, nullValue, dictHintMetatable)
    local tok = tokens:current()
    tokens:advance()
    if tok.type == "string" or tok.type == "number" or tok.type == "bool" then
        return parseLiteral(tok)
    elseif tok.type == "ocurly" then
        local dict = {}
        setmetatable(dict, dictHintMetatable)
        while true do
            local current = tokens:current()
            if current.type == "clocurly" then
                tokens:advance()
                return dict
            else
                local k = parseString(current)
                tokens:expectNext("colon")
                tokens:advance()
                dict[k] = parseValue(tokens, nullValue, dictHintMetatable)
                if tokens:expect("comma", "clocurly").type == "comma" then
                    tokens:advance()
                end
                -- And continue
            end
        end
    elseif tok.type == "obracket" then
        local array = {}
        while true do
            local next = tokens:current()
            if next.type == "clobracket" then
                tokens:advance()
                return array
            elseif next.type == "eos" then
                synerror(next, "Missing ]")
            else
                local val = parseValue(tokens, nullValue, dictHintMetatable)
                if val == nullValue and nullValue == nil then
                    synerror(next, "Cannot add a JSON null to an array unless nullValue is set")
                end
                table.insert(array, val)
                if tokens:expect("comma", "clobracket").type == "comma" then
                    tokens:advance()
                end
                -- And continue
            end
        end
        return array
    elseif tok.type == "null" then
        return nullValue
    else
        synerror(tok, "Expected value")
    end
end

function parse(str, src, nullValue, dictHintMetatable)
    local tokens = lex.lex(str, src, jsonLang)
    local result = parseValue(tokens, nullValue, dictHintMetatable)
    synassert(tokens:current().type == "eos", tokens:current(), "Unparsed trailing data")
    return result
end

return _ENV
