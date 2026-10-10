-- Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
-- See LICENSE file for license information.

_ENV = module()

local string_find, string_match = string.find, string.match
local table_insert, table_unpack = table.insert, table.unpack

-- symbol is something with a src - either an expression or a token
function synerror(symbol, fmt, ...)
    local src = symbol.src
    error({msg = string.format(fmt, ...), src = { path = src[1], line = src[2], column = src[3] } }, 0)
end

function synassert(test, symbol, ...)
    if test then
        return test
    else
        synerror(symbol, ...)
    end
end

local synerror, synassert = synerror, synassert

local function lexmatch(text, tokenStart, pos, sm)
    local tsm = type(sm)
    if tsm == "string" then
        return sm, text:sub(tokenStart, pos - 1)
    elseif tsm == "function" then
        local toktype, tokval = sm(text, tokenStart, pos)
        if type(toktype) == "string" then
            return toktype, tokval
        else
            sm = toktype
            -- And drop through
        end
    end
    for k, v in pairs(sm) do
        if k ~= '' then
            local tstart, tend = string_find(text, '^'..k, pos)
            if tstart then
                return lexmatch(text, tokenStart, tend + 1, v)
            end
        end
    end
    local noMoreCharsOpt = sm['']
    if noMoreCharsOpt then
        return lexmatch(text, tokenStart, pos, noMoreCharsOpt)
    else
        return nil
    end
end

Tokens = class {}
Token = class {}

function Tokens:current()
    return self[self.index]
end

function Tokens:peekNext()
    return self[self.index + 1]
end

function Tokens:advance()
    self.index = self.index + 1
end

function Tokens:last()
    return self[#self]
end

function Tokens:eos()
    local current = self[self.index]
    -- In every case where we call eos(), colon can be treated the same as eos. The only place it can't, is in
    -- parseExpression when token.type is dyncall, and that makes sure not to call eos().
    return current == nil or current.type == "eos" or current.type == "colon"
end

function Tokens:expectNext(...)
    self:advance()
    return self:expect(...)
end

function Tokens:expect(...)
    local allowed = {...}
    return self:expectTokens(allowed)
end

function Tokens:expectTokens(allowed)
    local token = self:current()
    for _, val in ipairs(allowed) do
        allowed[val] = true
    end
    if allowed[token.type] then
        return token
    else
        synerror(token, "Expected token %s", table.concat(allowed, "|"))
    end
end

function Tokens:endOfExpression()
    if self:eos() then
        return true
    end
    local curr = self:current().type
    -- The way subexpression parsing is done, a close bracket always means the end of the subexpression. Semicolon is
    -- only valid in the context of print but there's no real need to distinguish here.
    return curr == "comma" or curr == "cloparen" or curr == "semicolon"
end

function Token:__tostring()
    local desc
    if self.type == "identifier" or self.type == "call" or self.type == "dyncall" or self.type == "number" or self.type == "string" then
        desc = self.val
    else
        desc = self.type
    end
    return string.format("%s:%d:%d: %s", self.src[1], self.src[2], self.src[3], desc)
end

function Token:context()
    return self.src[4]
end

function lex(prog, source, language, tokenContext)
    assert(language, "language parameter must be specified")
    local idx = 1
    local tokens = Tokens { index = 1, language = language }
    local line = 1
    local col = 1
    if source == nil then
        source = "<input>"
    end
    while true do
        local tok, val = lexmatch(prog, idx, idx, language.statemachine)
        if not tok then
            break
        end
        if tok == "error" then
            synerror({src={source, line, col}}, val)
        end
        idx = idx + #val
        if tok == "newline" then
            table_insert(tokens, Token { type="eos", src={source, line, col} })
            line = line + 1
            col = 1
        elseif tok == "space" or tok == "comment" then
            col = col + #val            
        else
            local tokenSource = val
            if tok == "identifier" or tok == "label" then
                val = val:upper()
                if language.identifierTokens[val] then
                    tok = val
                end
            end
            local src = {source, line, col, tokenContext}
            table_insert(tokens, Token { type=tok, val=val, src=src, tokenSource = tokenSource })
            col = col + #val
        end
    end

    -- Add a trailing end of statement marker, for convenience
    if (tokens[#tokens] or {}).type ~= "eos" then
        table_insert(tokens, Token { type="eos", src={source, line, col} })
    end

    if idx <= #prog then
        -- Means we hit something we couldn't parse
        synerror({src={source, line, col}}, "Parse error")
    end
    return tokens
end

return _ENV
