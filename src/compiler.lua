--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

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

do
    local ops = require("ops")
    local fns = require("fns")
    opcodes = {}
    for k, v in pairs(ops.codes_er5) do
        opcodes[v] = k
    end
    fncodes = {}
    for k, v in pairs(fns.codes_er5) do
        fncodes[v] = k
    end
end

local string_find, string_match, string_sub, string_pack = string.find, string.match, string.sub, string.pack
local table_insert, table_unpack = table.insert, table.unpack
local type = type

local idsuffix = {
    [''] = 'identifier',
    [':'] = {
        [''] = 'identifier',
        [':'] = 'label',
    },
    ['[%%&$]:?'] = 'identifier',
}

local statemachine = {
    ['<'] = {
        [''] = 'lt',
        ['>'] = 'neq',
        ['='] = 'le',
    },
    ['>'] = {
        [''] = 'gt',
        ['='] = 'ge',
    },
    ['='] = 'eq',
    ['%+'] = 'add',
    ['%-'] = 'sub',
    ['[0-9]+'] = {
        [''] = 'number', -- int or long
        ['[eE][%+%-]?[0-9]+'] = 'number', -- int or long with exponent
        ['%.[0-9]*'] = {
            [''] = 'number', -- float
            ['[eE][%+%-]?[0-9]+'] = 'number', -- float with exponent
        },
    },
    ['$[0-9A-Fa-f]+'] = 'number', -- hexdecimal int
    ['&[0-9A-Fa-f]+'] = 'number', -- hexdecimal long
    ['%%'] = {
        [''] = 'percent', -- On its own is the percent operator
        ['[a-zA-Z]'] = 'number', -- charcode int
    },
    [':'] = 'colon',
    [';'] = 'semicolon',
    ['*'] = {
        ['*'] = 'pow',
        [''] = 'mul',
    },
    ['/'] = 'div',
    ['"'] = function(text, tokenStart)
        local pos = tokenStart + 1
        while true do
            local delim, nextPos = string_match(text, '(["\r\n])()', pos)
            if delim == '"' then
                if string_sub(text, nextPos, nextPos) == '"' then
                    -- Double-" means an escaped ", keep going
                    pos = nextPos + 1
                else
                    -- End of string
                    return "string", string_sub(text, tokenStart, nextPos - 1)
                end
            else
                error('Unmatched "')
            end
        end
    end,
    [','] = 'comma',
    ['%('] = 'oparen',
    ['%)'] = 'cloparen',
    ['\r?\n'] = 'newline',
    ['[ \t]+'] = 'space',
    ['@[%%&$]?'] = 'dyncall', -- Dynamic procedure call syntax

    -- Bluh ensuring REM isn't interpreted as an identifier is tedious...
    ['[a-qs-zA-QS-Z]%.?[a-zA-Z0-9_]*'] = idsuffix,
    ['_[a-zA-Z0-9_]*'] = idsuffix,
    ['[Rr]'] = function(text, tokenStart, pos)
        local emptyComment = string_match(text, '^([Rr][Ee][Mm])[\r\n]', tokenStart)
        if emptyComment then
            return "comment", emptyComment
        end
        local comment = string_match(text, '^[Rr][Ee][Mm][ \t][^\r\n]*', tokenStart)
        if comment then
            return "comment", comment
        end
        return {
            ['%.?[a-zA-Z0-9_]*'] = idsuffix,
        }
    end,
}

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

identifierTokens = enum {
    "INCLUDE", "CONST", "DECLARE", "EXTERNAL",
    "APP", "CAPTION", "ICON", "FLAGS", "ENDA",
    "OPX", "END", "BYREF", -- For DECLARE OPX ... END DECLARE
    "PROC", "ENDP",
    "LOCAL", "GLOBAL",
    "IF", "ELSEIF", "ELSE", "ENDIF",
    "AND", "OR", "NOT",
    "WHILE", "ENDWH",
    "DO", "UNTIL",
    "BREAK", "CONTINUE", "GOTO",
    "VECTOR", "ENDV",
    "TRAP", "ONERR",
    "ON", "OFF",
    "RETURN",
}

-- symbol is something with a src - either an expression or a token
local function synerror(symbol, fmt, ...)
    local src = symbol.src
    error({msg = string.format(fmt, ...), src = { path = src[1], line = src[2], column = src[3] } }, 0)
end

local function synassert(test, symbol, ...)
    if test then
        return test
    else
        synerror(symbol, ...)
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

function lex(prog, source, language)
    if language == nil then
        language = {
            statemachine = statemachine,
            identifierTokens = identifierTokens,
            precedences = precedences,
            unaryOperators = unaryOperators,
            rightAssociativeOperators = rightAssociativeOperators,
        }
    end
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
        idx = idx + #val
        if tok == "newline" then
            table.insert(tokens, Token { type="eos", src={source, line, col} })
            line = line + 1
            col = 1
        elseif tok == "space" or tok == "comment" then
            col = col + #val            
        else
            if tok == "identifier" or tok == "label" then
                val = val:upper()
                if language.identifierTokens[val] then
                    tok = val
                end
            end
            table.insert(tokens, Token { type=tok, val=val, src={source, line, col} })
            col = col + #val
        end
    end

    -- Add a trailing end of statement marker, for convenience
    if (tokens[#tokens] or {}).type ~= "eos" then
        table.insert(tokens, Token { type="eos", src={source, line, col} })
    end

    if idx <= #prog then
        -- Means we hit something we couldn't parse
        synerror({src={source, line, col}}, "Parse error")
    end
    return tokens
end

Int = "%"
Long = "&"
Float = ""
String = "$"
IntPtr = Long -- Like intptr_t - would be Int on the 16-bit sibo, if we ever support that in the compiler

-- Only used by args in Callables. Values are arbitrary as these should be considered opaque.
VariablePrefix = "_Var_"
AnyVariable = "_Var_Any"
IntVariable = "_Var_Int"
LongVariable = "_Var_Long"
FloatVariable = "_Var_Float"
StringVariable = "_Var_String"
IntArrayVariable = "_Var_IntArray"
LongArrayVariable = "_Var_LongArray"
FloatArrayVariable = "_Var_FloatArray"

TypeToDataType = enum {
    [Int] = DataTypes.EWord,
    [Long] = DataTypes.ELong,
    [Float] = DataTypes.EReal,
    [String] = DataTypes.EString,
}

TypeToStr = {
    [Int] = "Int",
    [Long] = "Long",
    [Float] = "Float",
    [String] = "String",
}

-- gPrint doesn't use the same convention as print and lprint...
GPrintTypeToStr = {
    [Int] = "gPrintWord",
    [Long] = "gPrintLong",
    [Float] = "gPrintDbl",
    [String] = "gPrintStr",
}

DefaultReturnOpcode = {
    [Int] = "ZeroReturnInt",
    [Long] = "ZeroReturnLong",
    [Float] = "ZeroReturnFloat",
    [String] = "NullReturnString",
}

TrappableCommands = enum {
    "APPEND", "UPDATE", "BACK", "NEXT", "LAST", "FIRST", "POSITION", "USE", "CREATE", "OPEN", "OPENR", "CLOSE",
    "DELETE", "MODIFY", "INSERT", "PUT", "CANCEL",
    "COPY", "ERASE", "RENAME", "LOPEN", "LCLOSE", "LOADM", "UNLOADM", "MKDIR", "RMDIR",
    "EDIT", "INPUT",
    "GSAVEBIT", "GCLOSE", "GUSE", "GUNLOADFONT", "GFONT", "GPATT", "GCOPY",
    "RAISE",
}

local function Fn(name, args, ret) return { type = "fn", name = name, args = args, valType = ret } end
local function Op(name, args) return { type = "op", name = name, args = args } end
local function SpecialFn(args, ret) return { type = "fn", args = args, valType = ret } end
local function SpecialOp(optArgs) return { type = "op", args = optArgs } end

-- Includes CallFunction functions, and commands that correspond to a single opcode and have a fixed number of
-- arguments. Cmds which have variadic arguments using the standard numParams calling convention can use
-- numParams={...} which is an array of acceptable argument counts. Non-Special Ops with numParams MUST also specify
-- numFixedParams because Ops are not consistent in how variable number of args are implemented (unlike Fns which are).
-- numFixedParams=2 means the first two args are not counted in numParams.
--
-- One way to figure out what numFixedParams should be is by looking at the source of opl/oplt/stran/OT_KYWRD.CPP for
-- how `qualifier` is set.
Callables = {
    ABS = Fn("Abs", {Float}, Float),
    ACOS = Fn("ACos", {Float}, Float),
    ADDR = SpecialFn(nil, IntPtr),
    ADJUSTALLOC = Fn("AdjustAlloc", {IntPtr, IntPtr, IntPtr}, IntPtr),
    ALERT = Fn("Alert", {String, String, String, String, String, numParams = {1, 2, 3, 4, 5}}, Int),
    ALLOC = Fn("Alloc", {IntPtr}, IntPtr),
    APPEND = Op("Append", {}),
    ASC = Fn("Asc", {String}, Int),
    ASIN = Fn("ASin", {Float}, Float),
    AT = Op("At", {Int, Int}),
    ATAN = Fn("ATan", {Float}, Float),
    BACK = Op("Back", {}),
    BEEP = Op("Beep", {Int, Int}),
    BEGINTRANS = Op("BeginTrans", {}),
    BOOKMARK = Fn("Bookmark", {}, Int),
    BUSY = SpecialOp(),
    CANCEL = Op("Cancel", {}),
    ["CHR$"] = Fn("ChrStr", {Int}, String),
    CLOSE = Op("Close", {}),
    CLEARFLAGS = Op("ClearFlags", {Long}),
    CLS = Op("Cls", {}),
    ["CMD$"] = Fn("CmdStr", {Int}, String),
    COMMITTRANS = Op("CommitTrans", {}),
    COMPACT = Op("Compact", {String}),
    COPY = Op("Copy", {String, String}),
    COS = Fn("Cos", {Float}, Float),
    COUNT = Fn("Count", {}, Int),
    CREATE = SpecialOp(),
    CURSOR = SpecialOp(),
    DATETOSECS = Fn("DateToSecs", {Int, Int, Int, Int, Int, Int}, Long),
    ["DATIM$"] = Fn("DatimStr", {}, String),
    DAY = Fn("Day", {}, Int),
    ["DAYNAME$"] = Fn("DayNameStr", {Int}, String),
    DAYS = Fn("Days", {Int, Int, Int}, Long),
    DAYSTODATE = Op("DaysToDate", {Long, IntVariable, IntVariable, IntVariable}),
    DBUTTONS = SpecialOp(),
    DCHECKBOX = SpecialOp({IntVariable, String}),
    DCHOICE = SpecialOp({IntVariable, String, String}),
    DDATE = SpecialOp({LongVariable, String, Long, Long}),
    DEDIT = SpecialOp({StringVariable, String, Int, numParams = {2, 3}}),
    DEDITMULTI = Op("dEditMulti", {IntPtr, String, Int, Int, Long}), -- last param IS a long no matter what docs say
    DEFAULTWIN = Op("DefaultWin", {Int}),
    DEG = Fn("Deg", {Float}, Float),
    DELETE = SpecialOp({String, String, numParams = {1, 2}}),
    DFILE = SpecialOp({StringVariable, String, Int, Long, Long, Long, numParams = {3, 6}}),
    DFLOAT = SpecialOp({FloatVariable, String, Float, Float}),
    DIALOG = Fn("Dialog", {}, Int),
    DINIT = Op("dInit", {String, Int, numParams = {0, 1, 2}, numFixedParams = 0}),
    ["DIR$"] = Fn("DirStr", {String}, String),
    DLONG = SpecialOp({LongVariable, String, Long, Long}),
    DOW = Fn("Dow", {Int, Int, Int}, Int),
    DPOSITION = SpecialOp({Int, Int}),
    DTEXT = SpecialOp({String, String, Int, numParams = {2, 3}}),
    DTIME = SpecialOp({LongVariable, String, Int, Long, Long}),
    DXINPUT = SpecialOp({StringVariable, String}),
    EDIT = SpecialOp(),
    EOF = Fn("Eof", {}, Int),
    ERASE = Op("Erase", {}),
    ERR = Fn("Err", {}, Int),
    ["ERR$"] = Fn("ErrStr", {Int}, String),
    ["ERRX$"] = Fn("ErrxStr", {}, String),
    ESCAPE = SpecialOp(),
    EVAL = Fn("Eval", {String}, Float),
    EXIST = Fn("Exist", {String}, Int),
    EXP = Fn("Exp", {Float}, Float),
    FIND = Fn("Find", {String}, Int),
    FINDFIELD = Fn("FindField", {String, Int, Int, Int}, Int),
    FIRST = Op("First", {}),
    ["FIX$"] = Fn("FixStr", {Float, Int, Int}, String),
    FONT = Op("Font", {IntPtr, Int}),
    FLT = Fn("Flt", {Long}, Float),
    FREEALLOC = Op("FreeAlloc", {IntPtr}),
    GAT = Op("gAt", {Int, Int}),
    GBORDER = Op("gBorder", {Int, Int, Int, numParams = {1, 3}, numFixedParams = 0}),
    GBOX = Op("gBox", {Int, Int}),
    GBUTTON = Op("gButton", {String, Int, Int, Int, Int, Long, Long, Int, numParams = {5, 6, 7, 8}, numFixedParams = 5}),
    GCIRCLE = Op("gCircle", {Int, Int, numParams = {1, 2}, numFixedParams = 1}),
    GCLOCK = SpecialOp(),
    GCLOSE = Op("gClose", {Int}),
    GCLS = Op("gCls", {}),
    GCOLOR = Op("gColor", {Int, Int, Int}),
    GCOLORBACKGROUND = Op("gColorBackground", {Int, Int, Int}),
    GCOLORINFO = Op("gColorInfo", {LongArrayVariable}),
    GCOPY = Op("gCopy", {Int, Int, Int, Int, Int, Int}),
    GCREATE = SpecialFn({Int, Int, Int, Int, Int, Int, numParams = {5, 6}}, Int),
    GCREATEBIT = Fn("gCreateBit", {Int, Int, Int, numParams = {2, 3}}, Int),
    GELLIPSE = Op("gEllipse", {Int, Int, Int, numParams = {2, 3}, numFixedParams = 2}),
    ["GEN$"] = Fn("GenStr", {Float, Int}, String),
    GET = Fn("Get", {}, Int),
    ["GETCMD$"] = Fn("WCmd", {}, String),
    ["GETDOC$"] = Fn("GetDocStr", {}, String),
    GETEVENT = Op("GetEvent", {IntArrayVariable}),
    GETEVENTA32 = Op("GetEventA32", {IntVariable, LongArrayVariable}),
    GETEVENT32 = Op("GetEvent32", {LongArrayVariable}),
    GETEVENTC = Fn("GetEventC", {IntVariable}, Int),
    ["GET$"] = Fn("GetStr", {}, String),
    GFILL = Op("gFill", {Int, Int, Int}),
    GFONT = Op("gFont", {IntPtr}),
    GGMODE = Op("gGMode", {Int}),
    GGREY = Op("gGrey_epoc", {Int}),
    GHEIGHT = Fn("gHeight", {}, Int),
    GIDENTITY = Fn("gIdentity", {}, Int),
    GINFO32 = Op("gInfo32", {LongArrayVariable}),
    GINVERT = Op("gInvert", {Int, Int}),
    GIPRINT = Op("gIPrint", {String, Int, numParams = {1, 2}, numFixedParams = 1}),
    GLINEBY = Op("gLineBy", {Int, Int}),
    GLINETO = Op("gLineTo", {Int, Int}),
    GLOADBIT = Fn("gLoadBit", {String, Int, Int, numParams = {1, 2, 3}}, Int),
    GLOADFONT = Fn("gLoadFont", {String}, Int),
    GMOVE = Op("gMove", {Int, Int}),
    GORDER = Op("gOrder", {Int, Int}),
    GORIGINX = Fn("gOriginX", {}, Int),
    GORIGINY = Fn("gOriginY", {}, Int),
    GOTOMARK = Op("GotoMark", {Int}),
    GPATT = Op("gPatt", {Int, Int, Int, Int}),
    GPEEKLINE = SpecialOp({Int, Int, Int, IntArrayVariable, Int, Int, numParams = {5, 6}}),
    GPOLY = Op("gPoly", {IntArrayVariable}),
    GPRINT = SpecialOp(),
    GPRINTB = Op("gPrintBoxText", {String, Int, Int, Int, Int, Int, numParams = {2, 3, 4, 5, 6}, numFixedParams = 1}),
    GPRINTCLIP = Fn("gPrintClip", {String, Int}, Int),
    GRANK = Fn("gRank", {}, Int),
    GSAVEBIT = Op("gSaveBit", {String, Int, Int, numParams = {1, 3}, numFixedParams = 1}),
    GSCROLL = Op("gScroll", {Int, Int, Int, Int, Int, Int, numParams = {2, 6}, numFixedParams = 0}),
    GSETPENWIDTH = Op("gSetPenWidth", {Int}),
    GSETWIN = Op("gSetWin", {Int, Int, Int, Int, numParams = {2, 4}, numFixedParams = 0}),
    GSTYLE = Op("gStyle", {Int}),
    GTMODE = Op("gTMode", {Int}),
    GTWIDTH = Fn("gTWidth", {String}, Int),
    GUNLOADFONT = Op("gUnloadFont", {Int}),
    GUPDATE = SpecialOp(),
    GUSE = Op("gUse", {Int}),
    GVISIBLE = SpecialOp(),
    GWIDTH = Fn("gWidth", {}, Int),
    GX = Fn("gX", {}, Int),
    GXBORDER = Op("gXBorder", {Int, Int, Int, Int, numParams = {2, 4}, numFixedParams = 0}),
    GXPRINT = Op("gXPrint", {String, Int}),
    GY = Fn("gY", {}, Int),
    ["HEX$"] = Fn("HexStr", {Long}, String),
    HOUR = Fn("Hour", {}, Int),
    IABS = Fn("IAbs", {Long}, Long),
    INPUT = SpecialOp(),
    INSERT = Op("Insert", {}),
    INT = Fn("IntLong", {Float}, Long),
    INTF = Fn("Intf", {Float}, Float),
    INTRANS = Fn("InTrans", {}, Int),
    IOA = Fn("Ioa", {Int, Int, IntVariable, AnyVariable, AnyVariable}, Int),
    IOC = Fn("Ioc", {Int, Int, IntVariable, AnyVariable, AnyVariable, numParams = {3, 4, 5}}, Int),
    IOCANCEL = Fn("IoCancel", {Int}, Int),
    IOCLOSE = Fn("IoClose", {Int}, Int),
    IOOPEN = SpecialFn(nil, Int),
    IOREAD = Fn("IoRead", {Int, IntPtr, Int}, Int),
    IOSEEK = Fn("IoSeek", {Int, Int, LongVariable}, Int),
    IOSIGNAL = Op("IoSignal", {}),
    IOW = Fn("Iow", {Int, Int, AnyVariable, AnyVariable}, Int),
    IOWAIT = Fn("IoWait", {}, Int),
    IOWAITSTAT = Op("IoWaitStat", {IntVariable}),
    IOWAITSTAT32 = Op("IoWaitStat32", {LongVariable}),
    IOWRITE = Fn("IoWrite", {Int, IntPtr, Int}, Int),
    IOYIELD = Op("IoYield", {}),
    KEY = Fn("Key", {}, Int),
    KEYA = Fn("KeyA", {IntVariable, IntArrayVariable}, Int),
    KEYC = Fn("KeyC", {IntVariable}, Int),
    ["KEY$"] = Fn("KeyStr", {}, String),
    KILLMARK = Op("KillMark", {Int}),
    KMOD = Fn("Kmod", {}, Int),
    LAST = Op("Last", {}),
    LCLOSE = Op("LClose", {}),
    ["LEFT$"] = Fn("LeftStr", {String, Int}, String),
    LEN = Fn("Len", {String}, Int),
    LENALLOC = Fn("LenAlloc", {IntPtr}, IntPtr),
    LN = Fn("Ln", {Float}, Float),
    LOADM = Op("LoadM", {String}),
    LOC = Fn("Loc", {String, String}, Int),
    LOCK = SpecialOp(),
    LOG = Fn("Log", {Float}, Float),
    LOPEN = Op("LOpen", {String}),
    ["LOWER$"] = Fn("LowerStr", {String}, String),
    LPRINT = SpecialOp(),
    MAX = SpecialFn(nil, Float),
    MCARD = SpecialOp(),
    MCASC = SpecialOp(),
    MEAN = SpecialFn(nil, Float),
    MENU = SpecialFn({IntVariable, numParams = {0, 1}}, Int),
    ["MID$"] = Fn("MidStr", {String, Int, Int}, String),
    MIN = SpecialFn(nil, Float),
    MINIT = Op("mInit", {}),
    MINUTE = Fn("Minute", {}, Int),
    MKDIR = Op("MkDir", {String}),
    MODIFY = Op("Modify", {}),
    MONTH = Fn("Month", {}, Int),
    ["MONTH$"] = Fn("MonthStr", {Int}, String),
    MPOPUP = SpecialFn(nil, Int),
    NEXT = Op("Next", {}),
    ["NUM$"] = Fn("NumStr", {Float, Int}, String),
    OPEN = SpecialOp(),
    OPENR = SpecialOp(),
    ["PARSE$"] = Fn("ParseStr", {String, String, IntArrayVariable}, String),
    PAUSE = Op("Pause", {Int}),
    PEEKB = Fn("PeekB", {IntPtr}, Int),
    PEEKF = Fn("PeekF", {IntPtr}, Float),
    PEEKL = Fn("PeekL", {IntPtr}, Long),
    ["PEEK$"] = Fn("PeekStr", {IntPtr}, String),
    PEEKW = Fn("PeekW", {IntPtr}, Int),
    PI = Fn("Pi", {}, Float),
    POINTERFILTER = Op("PointerFilter", {Int, Int}),
    POKEB = Op("PokeB", {IntPtr, Int}),
    POKEF = Op("PokeD", {IntPtr, Float}),
    POKEL = Op("PokeL", {IntPtr, Long}),
    ["POKE$"] = Op("PokeStr", {IntPtr, String}),
    POKEW = Op("PokeW", {IntPtr, Int}),
    POS = Fn("Pos", {}, Int),
    POSITION = Op("Position", {Int}),
    PRINT = SpecialOp(),
    PUT = Op("Put", {}),
    RAD = Fn("Rad", {Float}, Float),
    RANDOMIZE = Op("Randomize", {Long}),
    RAISE = Op("Raise", {Int}),
    REALLOC = Fn("ReAlloc", {IntPtr, IntPtr}, IntPtr),
    RENAME = Op("Rename", {String, String}),
    ["REPT$"] = Fn("ReptStr", {String, Int}, String),
    ["RIGHT$"] = Fn("RightStr", {String, Int}, String),
    ROLLBACK = Op("Rollback", {}),
    RMDIR = Op("RmDir", {String}),
    RND = Fn("Rnd", {}, Float),
    ["SCI$"] = Fn("SciStr", {Float, Int, Int}, String),
    SCREEN = SpecialOp({Int, Int, Int, Int, numParams = {2, 4}}),
    SCREENINFO = Op("ScreenInfo", {IntArrayVariable}),
    SECOND = Fn("Second", {}, Int),
    SECSTODATE = Op("SecsToDate", {Long, IntVariable, IntVariable, IntVariable, IntVariable, IntVariable, IntVariable, IntVariable}),
    SETDOC = Op("SetDoc", {String}),
    SETFLAGS = Op("SetFlags", {Long}),
    SETPATH = Op("SetPath", {String}),
    SIN = Fn("Sin", {Float}, Float),
    SPACE = Fn("Space", {}, Long),
    SQR = Fn("Sqr", {Float}, Float),
    STOP = Op("Stop", {}),
    STD = SpecialFn(nil, Float),
    STYLE = Op("Style", {Int}),
    SUM = SpecialFn(nil, Float),
    TAN = Fn("Tan", {Float}, Float),
    TESTEVENT = Fn("TestEvent", {}, Int),
    UADD = Fn("Uadd", {Int, Int}, Int),
    UNLOADM = Op("UnLoadM", {String}),
    UPDATE = Op("Update", {}),
    ["UPPER$"] = Fn("UpperStr", {String}, String),
    USE = SpecialOp(),
    USUB = Fn("Usub", {Int, Int}, Int),
    VAL = Fn("Val", {String}, Float),
    VAR = SpecialFn(nil, Float),
    WEEK = Fn("Week", {Int, Int, Int}, Int),
    YEAR = Fn("Year", {}, Int),
}

precedences = enum {
    noop = 0, -- Special placeholder operator for root node used during parseExpression only
    AND = 1,
    OR = 1,
    eq = 2,
    lt = 2,
    le = 2,
    gt = 2,
    ge = 2,
    neq = 2,
    add = 3,
    sub = 3,
    mul = 4,
    div = 4,
    NOT = 5,
    unm = 6, -- Not actually a token, special cased
    pow = 7,
}

operatorOpcodes = {
    AND = "And",
    OR = "Or",
    eq = "CompareEqual",
    lt = "CompareLessThan",
    le = "CompareLessOrEqual",
    gt = "CompareGreaterThan",
    ge = "CompareGreaterOrEqual",
    neq = "CompareNotEqual",
    add = "Add",
    sub = "Subtract",
    mul = "Multiply",
    div = "Divide",
    NOT = "Not",
    unm = "UnaryMinus",
    pow = "PowerOf",
}

percentOpcodes = {
    add = "PercentAdd",
    sub = "PercentSubtract",
    mul = "PercentMultiply",
    div = "PercentDivide",
    lt = "PercentLessThan",
    gt = "PercentGreaterThan",
}

unaryOperators = {
    NOT = true,
    unm = true,
}

-- The ones that return a boolean (ie Int) regardless of what type the operands are.
-- All other operators are assumed to return a value of the same type as the expression operandType.
booleanOperators = {
    eq = true,
    lt = true,
    le = true,
    gt = true,
    ge = true,
    neq = true,
    NOT = true,
}

rightAssociativeOperators = {
    pow = true,
}

function parseExpression(tokens)
    local result = parseUntypedExpression(tokens)
    setExpressionType(result)
    return result
end

function parseUntypedExpression(tokens)
    local precedences = tokens.language.precedences
    local unaryOperators = tokens.language.unaryOperators
    local rightAssociativeOperators = tokens.language.rightAssociativeOperators
    local root = { {}, op="noop" }
    local expression = root
    local prec = 0
    local function addOperand(val)
        synassert(#expression == 1, val, "Too many operands (missing operator?)")
        table.insert(expression, val)
    end
    while not tokens:endOfExpression() do
        local token = tokens:current()
        local operatorPrecedence = precedences[token.type]
        if token.type == "oparen" then
            tokens:advance()
            addOperand(parseUntypedExpression(tokens))
            tokens:expect("cloparen")
        elseif operatorPrecedence then
            -- Token is an operator
            local op = token.type

            if op == "sub" and #expression == 1 then
                -- Must be unary minus
                op = "unm"
                operatorPrecedence = precedences[op] -- unm has different precedence to sub
            end

            if unaryOperators[op] then
                -- A unary operator like NOT A is treated like a binary operator <nil> NOT A
                addOperand({})
            end

            -- There should always be two operands at this point (ie at the point of encountering opb in the below
            -- comments, the current expression should always have A and B), otherwise we have multiple operators in a
            -- row.
            synassert(#expression == 2, token, "Expected operand")

            local prec = precedences[expression.op]
            -- Since unary operators are treated like <nil> <operator> <val>, all unary operators are considered
            -- right-associative.
            local isRightAssociative = rightAssociativeOperators[op] or unaryOperators[op]
            if operatorPrecedence > prec or (operatorPrecedence == prec and isRightAssociative) then
                -- A opa (B opb C)
                --
                --   [opa]         [opa]
                --   /   \    ->   /   \
                --  A     B       A   [opb]
                --                    /   \
                --                   B     C
                --
                local rhs = expression[2]
                local newRhs = { op = op, parent = expression, src = token.src, rhs }
                expression[2] = newRhs
                expression = newRhs
            else
                -- ([...] A opa B) opb C
                --
                --  [...]            [...]
                --    \                \
                --   [opa]            [opb]
                --   /   \    ->     /     \
                --  A     B        [opa]    C
                --                 /   \
                --                A     B
                --
                -- Walk back up the expression to find how far this new precedence means we have to unwind
                local expressionToReplaceRhsOf = expression.parent
                while precedences[expressionToReplaceRhsOf.op] >= operatorPrecedence do
                    expressionToReplaceRhsOf = expressionToReplaceRhsOf.parent
                end

                local newExpression = { op = op, parent = expressionToReplaceRhsOf, src = token.src, expressionToReplaceRhsOf[2] }
                expressionToReplaceRhsOf[2] = newExpression
                expression = newExpression
            end
        elseif token.type == "percent" then
            -- Ugh this is a horrible special case
            local exp = synassert(expression[2], tokens:current(), "Percent operator only valid on RHS of expression")
            exp.isPercentage = true
        else
            -- Operand. See if it's a callable with parameters. At this stage of the parse a zero-args function call
            -- is indistinguishable from an identifier, but if it has arguments we'll change it to a "call" type.
            local nextToken = tokens:peekNext()
            if nextToken and nextToken.type == "oparen" then
                assert(token.type == "identifier" or token.type == "dyncall", "Unexpected bracket after "..token.type)                
                tokens:advance()
                tokens:advance() -- Skip over the bracket
                if token.type == "identifier" then
                    token.type = "call"
                end
                token.args = parseExpressionList(tokens)
                tokens:expect("cloparen")
                if token.type == "dyncall" then
                    assert(#token.args == 1, "Wrong number of args to @()")
                    assert(token.args[1].valType == String, "Expected string argument to @()")
                    -- We've consumed @%(fnname) tokens should now be :(args...)
                    tokens:expectNext("colon")
                    if tokens:peekNext().type == "oparen" then
                        tokens:advance() -- onto the bracket
                        tokens:advance() -- past the bracket
                        local args = parseExpressionList(tokens)
                        tokens:expect("cloparen")
                        -- Treat args as just more args to $(fnName)
                        for _, arg in ipairs(args) do
                            table.insert(token.args, arg)
                        end
                    end
                end
            end

            assert(token.type == "identifier" or token.type == "call" or token.type == "dyncall" or token.type == "string" or token.type == "number",
                "Unexpected token type "..token.type)
            addOperand(token)
        end
        tokens:advance()
    end
    local result = synassert(root[2], tokens:current(), "Expected expression")
    return result
end

-- For parsing comma-separated expressions. Returns on any end-of-expression that isn't a comma.
function parseExpressionList(tokens)
    local result = {}
    if tokens:endOfExpression() then
        return result
    end
    while true do
        table.insert(result, parseExpression(tokens))
        if tokens:current().type ~= "comma" then
            break
        else
            -- Consume the comma
            tokens:advance()
            -- And go round loop again
        end
    end
    return result
end

function setExpressionType(exp)
    local op = exp.op
    if exp.valType then
        -- Already set
    elseif op and exp[2].isPercentage then
        -- Percentage expressions always promote to Float
        setExpressionType(exp[1])
        setExpressionType(exp[2])
        exp.operandType = Float
        exp.valType = exp.operandType
    elseif op then
        local lhs = unaryOperators[op] and exp[2] or exp[1]
        local lhsType = TypeToDataType[setExpressionType(lhs)]
        local rhsType = TypeToDataType[setExpressionType(exp[2])]
        local result = math.max(lhsType, rhsType) -- Works thanks to DataTypes being defined in type promotion order
        if result == DataTypes.EString and lhsType ~= rhsType then
            synerror(exp, "Cannot combine string and non-string data types")
        end
        exp.operandType = TypeToDataType[result]
        if booleanOperators[op] then
            exp.valType = Int
        else
            exp.valType = exp.operandType
        end
    elseif exp.type == "string" then
        exp.valType = String
    elseif exp.type == "number" then
        exp.valType = literalToNumber(exp.val)
    elseif exp.type == "identifier" or exp.type == "call" or exp.type == "dyncall" then
        -- Check if it's a zero-args callable that doesn't obey the suffix convention
        local callable = Callables[exp.val]
        if callable then
            exp.valType = callable.valType
        else
            exp.valType = valTypeFromName(exp.val)
        end
    else
        error("Unhandled expression type "..tostring(exp.type))
    end
    return assert(exp.valType)
end

function valTypeFromName(name)
    local suffix = name:match("([%%&$]):?$")
    return suffix or Float
end

function procNameFromName(name)
    local result = name:match("(.+):$")
    return result
end

function fieldFromIdentifier(name)
    local log, field = name:match("^([A-Z])%.([a-zA-Z_][a-zA-Z0-9_]*[%%&$]?)$")
    if log then
        return string.byte(log) - string.byte("A"), field
    else
        return nil
    end
end

function literalToNumber(str)
    local longhex = string_match(str, "&(.*)")
    if longhex then
        return Long, toint32(tonumber(longhex, 16))
    end
    local wordhex = string_match(str, "$(.*)")
    if wordhex then
        return Int, toint16(tonumber(wordhex, 16))
    end
    local charcode = string_match(str, "%%([a-zA-Z])")
    if charcode then
        return Int, charcode:byte()
    end
    local val = assert(tonumber(str))
    -- Fortunately Lua and OPL seem to agree on the distinctions of tonumber("1.0") vs tonumber("1") etc, including the
    -- fact that any exponent even on an integer value within bounds makes it a float.
    local intval = math.type(val) == "integer"
    if intval then
        if val >= -65536 and val <= 65535 then
            return Int, val
        elseif val >= KMinLong and val <= KMaxLong then
            return Long, val
        else
            -- A bigger-than-long integer literal without a floating point dot is treated as a float, so drop through.
        end
    end

    return Float, val
end

function literalToString(val)
    local result = assert(val:match('^"(.*)"$')):gsub('""', '"')
    return result
end

function numberCast(exp, to)
    local fromType = TypeToStr[exp.valType]
    local toType = TypeToStr[to]
    return synassert(opcodes[string.format("%sTo%s", fromType, toType)], exp, "Cannot cast from %s to %s", fromType, toType)
end

function evalConstExpr(requiredType, exp, consts)
    local t, val
    if exp.type == "number" then
        t, val = literalToNumber(exp.val)
    elseif exp.type == "string" then
        t = String
        val = literalToString(exp.val)
    elseif exp.type == "identifier" and consts[exp.val] then
        return evalConstExpr(requiredType, consts[exp.val])
    else
        error("Expression is not constant")
    end

    if requiredType == Long and t == Int then
        -- Type promotion is allowed here
        t = Long
    end
    synassert(t == requiredType, exp, "Bad type in constexpr")
    return val
end

function parseApp(tokens, consts)
    local aif = {
        captions = {},
        icons = {},
    }
    tokens:advance() -- Past the APP
    local exps = parseExpressionList(tokens)
    synassert(#exps == 2, token, "Expected APP name, uid")
    local defaultCaption = exps[1].val
    aif.uid3 = evalConstExpr(Long, exps[2], consts)

    while tokens:expect("CAPTION", "ICON", "FLAGS", "ENDA", "eos").type ~= "ENDA" do
        local token = tokens:current()
        if token.type == "eos" then
            tokens:advance()
        elseif token.type == "CAPTION" then
            tokens:advance()
            local exps = parseExpressionList(tokens)
            synassert(#exps == 2, token, "Expected CAPTION name, lang")
            table.insert(aif.captions, { evalConstExpr(Int, exps[2], consts), evalConstExpr(String, exps[1], consts) })
        elseif token.type == "ICON" then
            tokens:advance()
            local iconToken = tokens:current()
            table.insert(aif.icons, {
                token = iconToken,
                path = evalConstExpr(String, parseExpression(tokens), consts)
            })
        elseif token.type == "FLAGS" then
            tokens:advance()
            synassert(aif.flags == nil, token, "Duplicate FLAGS")
            aif.flags = evalConstExpr(Int, parseExpression(tokens), consts)
        else
            synerror(token, "Unhandled")
        end
    end
    tokens:advance()
    if next(aif.captions) == nil then
        aif.captions[0] = defaultCaption
    end
    return aif
end

function parseOpx(tokens, consts)
    tokens:expect("OPX")
    tokens:advance()
    local exps = parseExpressionList(tokens)
    synassert(#exps == 3, token, "Expected DECLARE OPX name, uid, version")
    tokens:expect("eos")
    local opx = {
        name =  exps[1].val,
        uid = evalConstExpr(Long, exps[2], consts),
        version = evalConstExpr(Int, exps[3], consts),
        procDecls = {}
    }
    while true do
        local token = tokens:current()
        if not token then
            synerror(tokens:last(), "Missing END to DECLARE OPX")
        elseif token.type == "eos" then
            tokens:advance()
        elseif token.type == "END" then
            tokens:expectNext("DECLARE")
            tokens:advance()
            break
        elseif token.type == "identifier" then
            local decl = parseProcDeclaration("OPX", tokens, opx.procDecls)
            table.insert(opx.procDecls, decl)
            tokens:expect("colon")
            tokens:advance()
            local fnIndex = evalConstExpr(Int, parseExpression(tokens), {})
            decl.fnIndex = fnIndex
            decl.opx = opx
            assert(fnIndex == #opx.procDecls, "Bad function index in OPX")
        else
            synerror(token, "Expected OPX function declaration")
        end
    end
    return opx
end

-- Either PROC foo:(...)
-- or EXTERNAL foo:(...)
-- or within a DECLARE OPX foo:(...)
function parseProcDeclaration(declType, tokens, procDecls)
    -- Proc names don't include the trailing colon from the identifier
    local nameToken = tokens:expect("identifier")
    local name = synassert(procNameFromName(nameToken.val), nameToken, "Expected 'procname:'")
    local argValTypes = {}
    local argExps = {}
    if tokens:expectNext("eos", "colon", "oparen").type == "oparen" then
        tokens:advance()

        -- Do our own parsing here because parseExpressionList won't handle BYREF

        local done = tokens:current().type == "cloparen"
        if done then
            tokens:advance()
        end
        while not done do
            local argToken = tokens:current()
            local byref = false
            if argToken.type == "BYREF" then
                synassert(declType == "OPX", argToken, "BYREF only valid in OPX declarations")
                byref = true
                tokens:advance()
                argToken = tokens:current()
            end
            synassert(argToken.type == "identifier", argToken, "Expected identifier in arg %d of %s", #argExps + 1, name)
            argToken.valType = valTypeFromName(argToken.val)
            if byref then
                -- Don't think OPX API supports array var type
                argToken.valType = VariablePrefix .. TypeToStr[argToken.valType]
            end
            table.insert(argExps, argToken)
            table.insert(argValTypes, argToken.valType)
            done = tokens:expectNext("comma", "cloparen").type == "cloparen"
            tokens:advance()
        end
    end
    local decl = {
        name = name,
        args = argValTypes,
        declType = declType,
        valType = valTypeFromName(name),
        src = nameToken.src,
    }

    local priorDecl = procDecls and procDecls[name]
    if priorDecl then
        if priorDecl.declType == "EXTERNAL" then
            synassert(procDeclsMatch(decl, priorDecl), decl, "Signature does not match previous EXTERNAL declaration")
        else
            synerror(decl, "Duplicate declaration of %s", name)
        end
    elseif procDecls then
        procDecls[name] = decl
    end

    return decl, argExps
end

function procDeclsMatch(a, b)
    if a.name ~= b.name or #a.args ~= #b.args then
        return false
    end
    for i, arg in ipairs(a.args) do
        if arg ~= b.args[i] then
            return false
        end
    end
    return true
end

function checkExpressionArguments(args, declArgs, token)
    local numParams = args and #args or 0
    if declArgs.numParams then
        -- numParams must be one of the numbers in declArgs.numParams
        local allowed = false
        for _, allowedNum in ipairs(declArgs.numParams) do
            if numParams == allowedNum then
                allowed = true
                break
            end
        end
        synassert(allowed, token, "Wrong number of arguments to %s", token.val)
    else
        synassert(numParams == #declArgs, token, "Expected %d args to %s, not %d", #declArgs, token.val, numParams)
    end
    for i, arg in ipairs(args or {}) do
        if declArgs[i] == AnyVariable then
            synassert(arg.type == "identifier" or (arg.type == "call" and arg.args and #arg.args == 0), arg, "Expected variable")
        elseif declArgs[i] == IntArrayVariable then
            synassert(arg.type == "call" and arg.valType == Int and arg.args and #arg.args == 0, arg, "Expected Int array var")
        elseif declArgs[i] == LongArrayVariable then
            synassert(arg.type == "call" and arg.valType == Long and arg.args and #arg.args == 0, arg, "Expected Long array var")
        elseif declArgs[i] == FloatArrayVariable then
            synassert(arg.type == "call" and arg.valType == Float and arg.args and #arg.args == 0, arg, "Expected Float array var")
        elseif declArgs[i] == IntVariable then
            synassert(arg.type == "identifier" and arg.valType == Int, arg, "Expected Int var")
        elseif declArgs[i] == LongVariable then
            synassert(arg.type == "identifier" and arg.valType == Long, arg, "Expected Long var")
        elseif declArgs[i] == FloatVariable then
            synassert(arg.type == "identifier" and arg.valType == Float, arg, "Expected Float var")
        elseif declArgs[i] == StringVariable then
            synassert(arg.type == "identifier" and arg.valType == String, arg, "Expected String var")
        else
            local expType = TypeToDataType[arg.valType]
            local declType = TypeToDataType[declArgs[i]]
            -- Have to allow for permissable type promotions
            local maxType = math.max(declType, expType) -- Works thanks to DataTypes being defined in type promotion order
            if maxType == DataTypes.EString and expType ~= declType then
                synerror(token, "Argument %d type %s not compatible with declaration type %s", i,
                    TypeToStr[arg.valType], TypeToStr[declArgs[i]])
            end
        end
    end
end

ProcState = class {}

function ProcState:emit(fmt, ...)
    local bytes
    if select("#", ...) == 0 then
        bytes = fmt
    else
        bytes = string_pack("<"..fmt, ...)
    end
    table_insert(self.code, bytes)
    self.code.sz = self.code.sz + #bytes
end

function ProcState:addPendingOffset(type, name, token, codeSz)
    -- codeSz should be nil for anything other than VECTOR, where the offsets need to be relative
    -- to a specific location
    self:emit("h", 0x7FFF) -- Temporary dummy value, will be fixed up in resolveOffsets()
    table_insert(self.pendingOffsets, { codeIdx = #self.code, codeSz = codeSz or self.code.sz, type = type, name = name, token = token })
end

function ProcState:pushStack(...)
    for i = 1, select("#", ...) do
        local val = select(i, ...)
        local sz
        if val:match("^"..VariablePrefix) then
            sz = 6 -- Apparently...
        elseif val == String then
            sz = 0 -- Apparently...
        else
            sz = SizeofType[TypeToDataType[val]]
        end
        self.stackSz.sz = self.stackSz.sz + sz
        self.stackSz.max = math.max(self.stackSz.max, self.stackSz.sz)
        table.insert(self.stackSz, sz)
        -- printf("Push %s (%d)\n", TypeToStr[val], sz)
    end
end

function ProcState:popStack(n)
    local sz = 0
    -- printf("popStack(%d)\n", n)
    synassert(n <= #self.stackSz, self.tokens:current(), "Too many items popped")
    while n > 0 do
        sz = sz + self.stackSz[#self.stackSz]
        self.stackSz[#self.stackSz] = nil
        -- printf("Pop %d bytes\n", sz)
        n = n - 1
    end
    self.stackSz.sz = self.stackSz.sz - sz
    assert(self.stackSz.sz >= 0, "Stack size cannot be negative")
end

function ProcState:getVar(token, isArray)
    synassert(token.type == "identifier" or token.type == "call", token, "Expected identifier")
    synassert(fieldFromIdentifier(token.val) == nil, token, "Expected non-field identifier")

    local localVar = self.locals[token.val]
    if localVar then
        return localVar
    end

    -- It must be an external
    synassert(#token.val <= 32, token, "Variable name is too long")
    local valType = valTypeFromName(token.val)
    local dataType = TypeToDataType[valType]
    if isArray then
        dataType = dataType | 0x80
    end

    local external = self.externals[token.val]
    if external == nil then
        -- Do we have an externalDecl for it?
        local decl = self.externalDecls[token.val]
        synassert(decl or not self.strictExternals, token,
            "External used without being declared when DECLARE EXTERNAL is in effect")
        if decl then
            synassert(dataType == decl.type, token,
                "Type %d does not match EXTERNAL declaration type %d", dataType, decl.type)
        end

        external = {
            name = token.val,
            type = dataType,
            array = isArray, -- Convenience so externals can be treated the same as local/global decls
            valType = valType,
            external = true,
        }
        self.externals[external.name] = external
        table.insert(self.externals, external)
    else
        -- In case of array vs non-array, check types
        synassert(external.type == dataType, token, "Mismatch in arrayness of %s", external.name)
    end
    return external
end

function ProcState:emitNumberLiteral(valType, val)
    if valType == Int then
        if val >= -128 and val <= 127 then
            self:emit("Bb", opcodes.StackByteAsWord, val)
        else
            self:emit("Bh", opcodes.ConstantInt, val)
        end
    elseif valType == Long then
        if val >= -128 and val <= 127 then
            self:emit("Bb", opcodes.StackByteAsLong, val)
        elseif val >= -32768 and val <= 32767 then
            self:emit("Bh", opcodes.StackWordAsLong, val)
        else
            self:emit("Bi4", opcodes.ConstantLong, val)
        end
    else
        self:emit("Bd", opcodes.ConstantFloat, val)
    end
    self:pushStack(valType)
end

--[[
The rule for number type coercion in OPL is:
* All literals have a single inherent type, based on their value. Integers that fit in 16 bits are Int/EWord,
  literals with a decimal point are Float/EReal, etc. Literals are never type promoted at compile time and keep that
  original type in the compiled output.
* When applying a type constraint to an expression, for eg `CHR$(foo)` where foo is a Long literal and CHR$ expects
  an Int, the literal is runtime cast by emitting a IntToLong opcode, rather than it being a compile-time error.
  Same goes for something like `a% = &7` which will use a LongToInt.
* The above applies to narrowing as well as widening conversions.
]]
function ProcState:emitExpression(exp, requiredType)
    assert(requiredType)

    if requiredType:match("^"..VariablePrefix) then
        -- Special case, only used by ops which take the address of a variable
        local isArray = exp.args ~= nil
        local var = self:getVar(exp, isArray)
        self:emitAddressOfVar(var, exp)
        return
    end

    local op = exp.op
    if op then
        self:emitExpression(exp[1], exp.operandType)
        self:emitExpression(exp[2], exp.operandType)
        local opcode
        synassert(not exp[1].isPercentage, exp[1],
            "Percentage operator cannot appear on the left hand side of an expression")
        if exp[2].isPercentage then
            opcode = opcodes[percentOpcodes[op]]
            synassert(opcode, op, "Cannot use a percentage expression with operator %s", op)
        else
            opcode = opcodes[operatorOpcodes[op] .. TypeToStr[exp.operandType]]
            synassert(opcode, op, "Cannot apply operator %s to values of type %s", op, TypeToStr[exp.operandType])
        end
        self:emit("B", opcode)
        self:popStack(unaryOperators[op] and 1 or 2)
        self:pushStack(exp.operandType)
    elseif exp.type == "number" then
        local valType, val = literalToNumber(exp.val)
        self:emitNumberLiteral(valType, val)
    elseif exp.type == "string" then
        self:emit("Bs1", opcodes.ConstantString, literalToString(exp.val))
        self:pushStack(String)
    elseif exp.type == "identifier" or exp.type == "call" then

        -- `callable()` is not valid syntax for a zero-args callable, but parseExpression accepts it to allow its use
        -- in parsing extern array declarations and such
        synassert(exp.args == nil or #exp.args > 0, exp, "Zero-argument calls should not have ()")

        local procName = procNameFromName(exp.val)
        local callable = Callables[exp.val]
        local const = self.consts[exp.val]
        local log, field = fieldFromIdentifier(exp.val)
        if field then
            self:emit("Bs1", opcodes.ConstantString, field)
            self:pushStack(String)
            local typeStr = TypeToStr[exp.valType]
            self:emit("BB", opcodes["FieldRightSide" .. typeStr], log)
            self:popStack(1)
            self:pushStack(exp.valType)
        elseif const then
            -- Unlike when if a literal is emitted directly, a const follows the variable's type and not the inherent
            -- type of the literal. Ie if `const kLong& = 3` then we need to emit StackByteAsLong(3) not
            -- StackByteAsWord(3) followed by IntToLong.
            if exp.valType == String then
                self:emit("Bs1", opcodes.ConstantString, literalToString(const.val))
                self:pushStack(String)
            else
                local _, val = literalToNumber(const.val)
                self:emitNumberLiteral(exp.valType, val)
            end
        elseif procName then
            -- Its a proc call
            local decl = self.procDecls[procName]
            if self.strictExternals then
                synassert(decl, exp, "Undefined external")
            end
            if decl then
                checkExpressionArguments(exp.args, decl.args, exp)
            end
            local numParams = exp.args and #exp.args or 0

            local opxIndex, opxFnIndex
            if decl and decl.declType == "OPX" then
                if decl.opx.opxIndex == nil then
                    -- First use of this OPX, add to OPX table
                    table.insert(self.opxTable, decl.opx)
                    decl.opx.opxIndex = #self.opxTable - 1
                end
                opxIndex = decl.opx.opxIndex
                opxFnIndex = decl.fnIndex
            else
                local subproc = self.subprocs[procName]
                if subproc == nil then
                    subproc = {
                        name = procName,
                        numParams = numParams,
                    }
                    self.subprocs[procName] = subproc
                    table.insert(self.subprocs, subproc)
                else
                    synassert(subproc.numParams == numParams, exp,
                        "Expected %d params, got %d", subproc.numParams, numParams)
                end
            end

            local numStackSlots = opxIndex and numParams or (numParams * 2)
            for i, arg in ipairs(exp.args or {}) do
                -- If there is a proc decl for this proc, we have to coerce the argument expression type. But if there
                -- isn't, we just assume the expression type.
                local argType = decl and decl.args[i] or arg.valType
                self:emitExpression(arg, argType)
                -- Opx calling convention does _not_ push types onto stack
                if not opxIndex then
                    self:emit("BB", opcodes.StackByteAsWord, TypeToDataType[argType])
                    self:pushStack(Int)
                end
            end

            if opxIndex then
                self:emit("BBBH", opcodes.NextOpcodeTable, opcodes.CallOpxFunc - 256, opxIndex, opxFnIndex)
            else
                -- Technically, we could figure out the offset here (since it depends only on globals) but for simplicity
                -- we'll do all the offset calculations in one place, and fix up all offsets at that point.
                self:emit("B", opcodes.RunProcedure)
                self:addPendingOffset("subproc", procName, exp)
            end
            self:popStack(numStackSlots)
            self:pushStack(exp.valType)
        elseif callable then
            assert(callable.type == "fn") -- If we're in an expression it must be a function...
            local expArgs = exp.args or {}
            if callable.args then
                checkExpressionArguments(exp.args, callable.args, exp)
            end
            if callable.name then
                for i, arg in ipairs(expArgs) do
                    self:emitExpression(arg, callable.args[i])
                end
                self:emit("BB", opcodes.CallFunction, fncodes[callable.name])
                if callable.args.numParams then
                    self:emit("B", #expArgs)
                end
                self:popStack(#expArgs)
                self:pushStack(callable.valType)
            else
                -- It's a special fn that has a dedicated handler fn for whatever weirdness it has with its arguments
                local handler = _ENV["handleFn_"..exp.val]
                handler(exp, self)
            end
        else
            -- A variable of some sort
            local isArray = exp.args ~= nil
            synassert(not isArray or #exp.args == 1, exp, "Bad array index expression")
            local var = self:getVar(exp, isArray)
            local typeStr = TypeToStr[var.valType]
            if var.external then
                if isArray then
                    self:emitExpression(exp.args[1], Int)
                    self:emit("B", opcodes["ArrayInDirectRightSide" .. typeStr])
                    self:popStack(1)
                else
                    self:emit("B", opcodes["SimpleInDirectRightSide" .. typeStr])
                end
                self:addPendingOffset("external", exp.val, exp)
            else -- local
                if isArray then
                    self:emitExpression(exp.args[1], Int)
                    self:emit("B", opcodes["ArrayDirectRightSide" .. typeStr])
                    self:popStack(1)
                else
                    self:emit("B", opcodes["SimpleDirectRightSide" .. typeStr])
                end
                self:addPendingOffset("local", exp.val, exp)
            end
            self:pushStack(exp.valType)
        end
    elseif exp.type == "dyncall" then
        self:emitExpression(exp.args[1], String) -- The function name
        for i = 2, #exp.args do
            local arg = exp.args[i]
            self:emitExpression(arg, arg.valType)
            -- After each arg, push the type
            self:emit("BB", opcodes.StackByteAsWord, TypeToDataType[arg.valType])
            self:pushStack(Int)
        end
        -- Huh the return type param is '%', '&', '$' or '\0' rather than using DataType. Sigh.
        local type = exp.valType
        if type == "" then
            type = "\0"
        end
        self:emit("BBc1", opcodes.CallProcByStringExpr, #exp.args - 1, type)
        self:popStack(1 + (#exp.args - 1) * 2)
    elseif op == nil and exp.type == nil then
        -- LHS of a unary operator expression, meaning we don't emit anything
        return
    else
        error("Can't handle "..dump(exp))
    end

    if exp.valType ~= requiredType then
        self:emit("B", numberCast(exp, requiredType))
        self:popStack(1)
        self:pushStack(requiredType)
    end
end

function ProcState:emitVarLhs(var, token)
    -- If var is an array, assumes the array index has already been emitted
    local typeStr = TypeToStr[var.valType]
    if var.external then
        if var.array then
            self:emit("B", opcodes["ArrayInDirectLeftSide"..typeStr])
        else
            self:emit("B", opcodes["SimpleInDirectLeftSide"..typeStr])
        end
        self:addPendingOffset("external", token.val, token)
    else
        if var.array then
            self:emit("B", opcodes["ArrayDirectLeftSide"..typeStr])
        else
            self:emit("B", opcodes["SimpleDirectLeftSide"..typeStr])
        end
        self:addPendingOffset("local", token.val, token)
    end
    if var.array then
        self:popStack(1) -- The array index
    end
    self:pushStack(VariablePrefix)
end

function ProcState:emitAddressOfVar(var, token, arraySubscriptExpression)
    if var.array then
        if arraySubscriptExpression == nil then
            -- The addressof(<array>) op is implemented as addressof(<array>[1])
            self:emit("BB", opcodes.StackByteAsWord, 1)
            self:pushStack(Int)
        else
            self:emitExpression(arraySubscriptExpression, Int)
        end
    else
        assert(arraySubscriptExpression == nil)
    end
    self:emitVarLhs(var, token)
    if var.valType == String then
        self:emit("BB", opcodes.CallFunction, fncodes.SAddr)
    else
        self:emit("BB", opcodes.CallFunction, fncodes.Addr)
    end
end

--[[
The ability to allocate local and global offsets, and indirectIndexes, is dependent on iTotalTableSize thus on
knowing in advance all the subprocs in the procedure (as well as all the global decls, but that's easier since they
must precede all code that might want to use an offset or indirectIdx). Given that we have to have a concept of
deferred calculation of offsets to handle labels and gotos, we use that for locals, globals, externals, and subprocs
as well.

The logic for mapping variables to the offsets used by Simple[In]DirectRightSideXyz and friends is there's a common
counter which increments according to the following rules (which are the way they are due to SIBO taking shortcuts
with data structures that have become baked into the bytecode API):

* Starts at 18 (0x12)
* For each global declared *in this proc*, increments by the size of the declaration in the OPO file format globals
  table (name of global including type suffix, plus string len byte, plus type byte, plus offset word). Note the
  global's offset is *not* allocated yet.
* For each subproc *referenced* in this proc, increments by the size of declaration in the OPO file format subproc
  table (name of proc with type suffix but without trailing colon, plus string size byte, plus numParameters byte). The
  location of this 'entry' is the value used in RunProcedure to refer to this proc.
* For each argument to the proc, increments by 2. The indirectIdx for the argument is this location.
* For each external referenced *in this proc* (which is not shadowed by a LOCAL or GLOBAL decl), increments by 2. The
  external's indirectIdx is this value.
* For each of the globals mentioned earlier, increment by the size in bytes of the variable. The global's offset is this
  value.
* For each local declared in this proc, increment by the size in bytes of the variable. The local's offset is this
  value.
* The final value is this proc's iDataSize.
]]
function ProcState:resolveOffsets(argExps)
    local function sizeofDecl(decl)
        -- baseSz doesn't include max len byte, for strings (but does include len byte)
        local baseSz = decl.valType == String and (1 + decl.maxLen) or SizeofType[TypeToDataType[decl.valType]]
        local sz
        if decl.array then
            sz = 2 + (baseSz * decl.arrayLen)
        else
            sz = baseSz
        end

        if decl.valType == String then
            return sz + 1 -- For the maxlen byte
        else
            return sz
        end
    end

    -- How much the offset is offset by in a local/global data val, relative to the actual start of the data
    local function declDataPos(decl)
        local result = 0
        if decl.array then
            result = result + 2 -- The array size word
        end
        if decl.valType == String then
            result = result + 1 -- The max len byte
        end
        return result
    end

    local variableIdx = 0x12

    local function checkSz(tok)
        if variableIdx > 65535 then
            synerror(tok or self, "Procedure variables exceed maximum size")
        end
    end

    for _, globalDecl in ipairs(self.globalDecls) do
        variableIdx = variableIdx + 1 + #globalDecl.val + 1 + 2
        checkSz(globalDecl)
    end
    for _, subproc in ipairs(self.subprocs) do
        subproc.offset = variableIdx
        variableIdx = variableIdx + (1 + #subproc.name) + 1
        checkSz()
    end
    self.iTotalTableSize = variableIdx - 0x12 -- size of globalDecls plus subprocs
    for _, arg in ipairs(argExps) do
        self.externals[arg.val].indirectIdx = variableIdx
        variableIdx = variableIdx + 2
        checkSz(arg)
    end
    for _, external in ipairs(self.externals) do
        external.indirectIdx = variableIdx
        variableIdx = variableIdx + 2
        checkSz()
    end
    for i, globalDecl in ipairs(self.globalDecls) do
        globalDecl.offset = variableIdx + declDataPos(globalDecl)
        variableIdx = variableIdx + sizeofDecl(globalDecl)
        checkSz(globalDecl)
    end
    for _, localDecl in ipairs(self.localDecls) do
        localDecl.offset = variableIdx + declDataPos(localDecl)
        variableIdx = variableIdx + sizeofDecl(localDecl)
        checkSz(localDecl)
    end
    self.iDataSize = variableIdx

    -- Now everything has been laid out, fix up code

    for _, p in ipairs(self.pendingOffsets) do
        local result
        local packFmt = "<H" -- everything except labels use unsigned 16-bit offsets
        if p.type == "label" then
            local offset = self.labels[p.name]
            synassert(offset, p.token, "No label found for %s", p.name)
            -- The desired value is an offset relative the location of the jump instruction...
            result = offset - p.codeSz + 3
            packFmt = "<h" -- label offsets are signed 16-bit
        elseif p.type == "local" then
            local var = assert(self.locals[p.name])
            result = var.offset
        elseif p.type == "external" then
            local external = assert(self.externals[p.name])
            result = external.indirectIdx
        elseif p.type == "subproc" then
            local subproc = assert(self.subprocs[p.name])
            result = subproc.offset
        else
            error("Unhandled pending offset type "..p.type)
        end
        self.code[p.codeIdx] = string_pack(packFmt, result)
    end
end

function handleFn_ADDR(exp, procState)
    synassert(exp.args and #exp.args == 1 and (exp.args[1].type == "identifier" or exp.args[1].type == "call") , exp,
        "Expected 1 variable argument")
    local varExp = exp.args[1]
    local isArray = varExp.args ~= nil
    local arraySubscriptExpression = nil
    if isArray then
        synassert(#varExp.args <= 1, exp, "Bad array subscript expression")
        arraySubscriptExpression = varExp.args[1]
    end
    local var = procState:getVar(varExp, isArray)
    procState:emitAddressOfVar(var, varExp, arraySubscriptExpression)
end

function handleFn_GCREATE(exp, procState)
    for i, arg in ipairs(exp.args) do
        procState:emitExpression(arg, Callables.GCREATE.args[i])
    end
    if #exp.args == 6 then
        procState:emit("BB", opcodes.CallFunction, fncodes.gCreateEnhanced)
    else
        procState:emit("BB", opcodes.CallFunction, fncodes.gCreate)
    end
    procState:popStack(#exp.args)
    procState:pushStack(Int)
end

local function handleFloatOp(exp, procState, fncode)
    -- MIN(a, b, c, ...) or MIN(a(), count%)
    if exp.args and #exp.args == 2 and exp.args[1].type == "call" and #exp.args[1].args == 0 then
        local declArgs = {FloatArrayVariable, Int}
        checkExpressionArguments(exp.args, declArgs, exp)
        local var = procState:getVar(exp.args[1], true)
        procState:emit("BB", opcodes.StackByteAsWord, 1)
        procState:pushStack(Int)
        procState:emitVarLhs(var, exp.args[1])
        procState:emitExpression(exp.args[2], Int)
        procState:emit("BBB", opcodes.CallFunction, fncode, 0)
    else
        synassert(exp.args and #exp.args > 0, exp, "Wrong number of arguments to %s", exp.val)
        for i, arg in ipairs(exp.args) do
            procState:emitExpression(arg, Float)
        end
        procState:emit("BBB", opcodes.CallFunction, fncode, #exp.args)
    end
    procState:popStack(#exp.args)
    procState:pushStack(Float)
end

function handleFn_MAX(exp, procState)
    handleFloatOp(exp, procState, fncodes.Max)
end

function handleFn_MEAN(exp, procState)
    handleFloatOp(exp, procState, fncodes.Mean)
end

function handleFn_MENU(exp, procState)
    if exp.args and #exp.args > 0 then
        for i, arg in ipairs(exp.args) do
            procState:emitExpression(arg, Callables.MENU.args[i])
        end
        procState:emit("BB", opcodes.CallFunction, fncodes.MenuWithMemory)
        procState:popStack(#exp.args)
    else
        procState:emit("BB", opcodes.CallFunction, fncodes.Menu)
    end
    procState:pushStack(Int)
end

function handleFn_MIN(exp, procState)
    handleFloatOp(exp, procState, fncodes.Min)
end

function handleFn_MPOPUP(exp, procState)
    -- (x%,y%,posType%,item1$,key1%,item2$,key2%,...)
    synassert(exp.args and #exp.args >= 5 and (#exp.args & 1) == 1, exp, "Wrong number of arguments to mPOPUP")
    local declArgs = { Int, Int, Int }
    while #declArgs < #exp.args do
        table.insert(declArgs, String)
        table.insert(declArgs, Int)
    end
    checkExpressionArguments(exp.args, declArgs, exp)
    for i, decl in ipairs(declArgs) do
        procState:emitExpression(exp.args[i], decl)
    end
    procState:emit("BBB", opcodes.CallFunction, fncodes.mPopup, #exp.args)
    procState:popStack(#exp.args)
    procState:pushStack(Int)
end

function handleFn_IOOPEN(exp, procState)
    synassert(exp.args and #exp.args == 3, exp, "Expected 3 arguments")
    if exp.args[2].valType == IntPtr then
        checkExpressionArguments(exp.args, {IntVariable, IntPtr, Int}, exp)
        procState:emitExpression(exp.args[1], IntVariable)
        procState:emitExpression(exp.args[2], IntPtr)
        procState:emitExpression(exp.args[3], Int)
        procState:emit("BB", opcodes.CallFunction, fncodes.IoOpenUnique)
    else
        checkExpressionArguments(exp.args, {IntVariable, String, Int}, exp)
        procState:emitExpression(exp.args[1], IntVariable)
        procState:emitExpression(exp.args[2], String)
        procState:emitExpression(exp.args[3], Int)
        procState:emit("BB", opcodes.CallFunction, fncodes.IoOpen)
    end
    procState:popStack(3)
    procState:pushStack(Int)
end

function handleFn_STD(exp, procState)
    handleFloatOp(exp, procState, fncodes.Std)
end

function handleFn_SUM(exp, procState)
    handleFloatOp(exp, procState, fncodes.Sum)
end

function handleFn_VAR(exp, procState)
    handleFloatOp(exp, procState, fncodes.Var)
end

function parseProc(tokens, consts, procDecls, opxTable, strictExternals)
    -- tokens should be pointing to the PROC
    assert(tokens:current().type == "PROC")

    local procState = ProcState {
        tokens = tokens,
        consts = consts,
        procDecls = procDecls,
        opxTable = opxTable,
        subprocs = {}, -- Array, in order, and also keyed by name
        strictExternals = strictExternals,
        externals = {}, -- Array, in order, and also keyed by name (by name also includes args)
        externalDecls = {}, -- variables declared with `external foo%`, keyed by name
        -- Something can appear in externalDecls without appearing in `externals`, if it was declared with `external foo%`
        -- but never actually used.
        localDecls = {}, -- Array, in order
        globalDecls = {}, -- Array, in order
        locals = {}, -- Contains both localDecls and globalDecls, map keyed by variable name
        code = { sz = 0 },
        pendingOffsets = {},
        labels = {},
        stackSz = { sz = 0, max = 0 },
    }

    local result = procState:parse()
    return result
end

function ProcState:parse()
    local tokens = self.tokens
    tokens:expect("PROC")
    self.src = tokens:current().src
    local lineNumber = self.src[2]
    tokens:advance()
    local decl, argExps = parseProcDeclaration("PROC", self.tokens, self.procDecls)

    local params = {}
    for i, arg in ipairs(decl.args) do
        params[i] = TypeToDataType[arg]
    end

    for _, arg in ipairs(argExps) do
        self.externals[arg.val] = {
            name = arg.val,
            type = TypeToDataType[arg.valType], -- Proc args can never be arrays, so this is ok
            valType = arg.valType,
            external = true,
        }
        -- Note, don't insert into the array part because args shouldn't appear in the resulting proc's externals
    end

    local result = {
        name = decl.name,
        lineNumber = lineNumber,
        params = params,
    }

    local function parseAndEmitConditionalExpression()
        local exp = parseExpression(tokens)
        self:emitExpression(exp, exp.valType)
        if exp.valType == Long then
            -- `if &1` really means `if &1 <> 0`
            self:emit("BBB", opcodes.StackByteAsLong, 0, opcodes.CompareNotEqualLong)
            self:popStack()
            self:pushStack(Int)
        elseif exp.valType == Float then
            -- Similar
            self:emit("Bd", opcodes.ConstantFloat, 0, opcodes.CompareNotEqualFloat)
            self:popStack()
            self:pushStack(Int)
        elseif exp.valType == String then
            synerror(exp, "Type mismatch, cannot cast string to int")
        end
    end

    local lastStatement = nil
    local scope = { type = "PROC", prev = nil }

    -- The main parse loop. Once through this for every statement, broadly.
    while true do
        local token = tokens:current()
        if self.stackSz.sz ~= 0 then
            error("stack balance doom at "..dump(token))
        end
        -- print("Stack @ Zero")
        synassert(token, tokens:last(), "Missing ENDP")
        local tokenType = token.type
        if tokenType == "ENDP" then
            synassert(scope.type == "PROC", token, "Expected end for %s", scope.type)
            tokens:advance()
            if lastStatement ~= "RETURN" then
                self:emit("B", opcodes[DefaultReturnOpcode[decl.valType]])
            end
            break
        elseif tokenType == "eos" or tokenType == "colon" then
            tokens:advance()
        elseif tokenType == "LOCAL" or tokenType == "GLOBAL" then
            synassert(self.code.sz == 0, token, "LOCAL/GLOBAL/EXTERNAL must come before any other statements")
            tokens:advance()
            local exps = parseExpressionList(tokens)
            local declArray = tokenType == "LOCAL" and self.localDecls or self.globalDecls
            -- Lazy, a string or array decl will look like a callable with 'arguments' being the size(s)
            for i, exp in ipairs(exps) do
                exp.type = "identifier"
                if exp.args then
                    -- String or array declaration
                    assert(#exp.args == 1 or (#exp.args == 2 and exp.valType == String))
                    local arrayLenExp = exp.args[1]
                    local maxLenExp = nil
                    if #exp.args == 2 then
                        maxLenExp = exp.args[2]
                    elseif #exp.args == 1 and exp.valType == String then
                        maxLenExp = arrayLenExp
                        arrayLenExp = nil
                    end
                    exp.args = nil

                    if arrayLenExp then
                        exp.array = true
                        exp.arrayLen = evalConstExpr(Int, arrayLenExp, self.consts)
                        -- Max array size is in practice constrained lower than this by the
                        -- procedure variables overall size limit.
                        synassert(exp.arrayLen > 0 and exp.arrayLen < 32768, maxLenExp, "Bad array size")
                    end
                    if maxLenExp then
                        exp.maxLen = evalConstExpr(Int, maxLenExp, self.consts)
                        synassert(exp.maxLen > 0 and exp.maxLen < 256, maxLenExp, "String is too long")
                    end
                end
                synassert(#exp.val <= 32, exp, "Variable name is too long")
                synassert(self.locals[exp.val] == nil and self.externalDecls[exp.val] == nil, exp,
                    "Duplicate definition of %s", exp.val)
                self.locals[exp.val] = exp
                table.insert(declArray, exp)
            end
        elseif tokenType == "EXTERNAL" then
            synassert(self.code.sz == 0, token, "LOCAL/GLOBAL/EXTERNAL must come before any other statements")
            tokens:advance()
            local exps = parseExpressionList(tokens)
            for _, exp in ipairs(exps) do
                synassert(exp.type == "identifier" or exp.type == "call", exp, "Expected identifier")
                local t = TypeToDataType[exp.valType]
                if exp.type == "call" then
                    synassert(#exp.args == 0, exp, "Bad external array declaration")
                    -- `identifier()` means the external is an array
                    t = t | 0x80
                end
                synassert(self.locals[exp.val] == nil and self.externalDecls[exp.val] == nil, exp,
                    "Duplicate definition of %s", exp.val)
                self.externalDecls[exp.val] = {
                    name = exp.val,
                    type = t,
                    valType = exp.valType,
                }
            end
        elseif tokenType == "identifier" then
            local callable = Callables[token.val]
            local nextToken = tokens:peekNext()
            if (callable and callable.type == "fn") or procNameFromName(token.val) then
                -- It's a fn call used as an statement, so reuse the parseExpression logic then remember to drop the
                -- result
                local exp = parseExpression(tokens)
                local valType = (callable and callable.valType) or valTypeFromName(token.val)
                self:emitExpression(exp, valType)
                self:emit("B", opcodes["Drop"..TypeToStr[valType]])
                self:popStack(1)
            elseif callable then
                -- Must be an op (that's the only other non-fn thing in Callables)
                assert(callable.type == "op")
                assert(callable.valType == nil) -- There are no op Callables with a return type
                local args
                if callable.args then
                    -- We can parse args now
                    tokens:advance()
                    args = parseExpressionList(tokens)
                    checkExpressionArguments(args, callable.args, token)
                end
                if callable.name then
                    assert(callable.args)
                    for i, argExp in ipairs(args) do
                        self:emitExpression(argExp, callable.args[i])
                    end

                    local opcode = assert(opcodes[callable.name])
                    if opcode >= 256 then
                        self:emit("BB", opcodes.NextOpcodeTable, opcode - 256)
                    else
                        self:emit("B", opcode)
                    end
                    if callable.args.numParams then
                        local numParams = #args - callable.args.numFixedParams
                        self:emit("B", numParams)
                    end
                    self:popStack(#args)
                else
                    -- It's a special op that has a dedicated handler fn for whatever weirdness it has with its arguments
                    local handler = _ENV["handleOp_"..token.val]
                    handler(self, args)
                end

                tokens:expect("eos", "colon")
                tokens:advance()
            elseif nextToken.type == "eq" or nextToken.type == "oparen" then
                tokens:advance() -- to the eq or oparen
                -- Assignment (maybe?)
                local log, field = fieldFromIdentifier(token.val)
                local valType = valTypeFromName(token.val)
                if field then
                    self:emit("Bs1", opcodes.ConstantString, field)
                    self:pushStack(String)
                    local typeStr = TypeToStr[valType]
                    self:emit("BB", opcodes["FieldLeftSide" .. typeStr], log)
                    self:popStack(1)
                    self:pushStack(VariablePrefix)
                else
                    local isArray = nextToken.type == "oparen"
                    local var = self:getVar(token, isArray)
                    
                    if isArray then
                        tokens:advance() -- past the oparen
                        local exp = parseExpression(tokens)
                        self:emitExpression(exp, Int)
                        tokens:expect("cloparen")
                        tokens:expectNext("eq")
                    end

                    self:emitVarLhs(var, token)
                end
                tokens:advance() -- past the eq
                local exp = parseExpression(tokens)
                self:emitExpression(exp, valType)
                self:emit("B", opcodes["Assign"..TypeToStr[valType]])
                self:popStack(2) -- the LHS and the RHS
            else
                synerror(token, "Unknown command %s", token.val)
            end
        elseif tokenType == "dyncall" then
            -- dyncall used as a statement
            local exp = parseExpression(tokens)
            self:emitExpression(exp, exp.valType)
            self:emit("B", opcodes["Drop"..TypeToStr[exp.valType]])
        elseif tokenType == "RETURN" then
            tokens:advance()
            if tokens:eos() then
                self:emit("B", opcodes[DefaultReturnOpcode[decl.valType]])
            else
                local exp = parseExpression(tokens)
                self:emitExpression(exp, decl.valType)
                self:emit("B", opcodes.Return)
                self:popStack(1)
            end
        elseif tokenType == "IF" then
            local ifTokenIndex = tokens.index
            tokens:advance()
            parseAndEmitConditionalExpression()
            scope = {
                type = "IF",
                endLabel = string.format("#end-if-%d", ifTokenIndex),
                nextCondLabel = string.format("#else-%d", ifTokenIndex),
                prev = scope
            }
            self:emit("B", opcodes.BranchIfFalse)
            self:popStack(1)
            self:addPendingOffset("label", scope.nextCondLabel, token)
        elseif tokenType == "ELSEIF" then
            synassert(scope.type == "IF", token, "Expected end of %s block", scope.type)
            local tokenIndex = tokens.index
            tokens:advance()
            -- Ensure the previous block goes to the right place
            self:emit("B", opcodes.GoTo)
            self:addPendingOffset("label", scope.endLabel)
            -- Define nextCondLabel, declare new nextCondLabel for our conditional
            self.labels[scope.nextCondLabel] = self.code.sz
            scope.nextCondLabel = string.format("#else-%d", tokenIndex)
            parseAndEmitConditionalExpression()
            self:emit("B", opcodes.BranchIfFalse)
            self:popStack(1)
            self:addPendingOffset("label", scope.nextCondLabel, token)
        elseif tokenType == "ELSE" then
            synassert(scope.type == "IF", token, "Expected end of %s block", scope.type)
            tokens:advance()
            -- Ensure the previous block goes to the right place
            self:emit("B", opcodes.GoTo)
            self:addPendingOffset("label", scope.endLabel)
            -- Define nextCondLabel, no need for a new nextCondLabel (since ELSE is unconditional)
            self.labels[scope.nextCondLabel] = self.code.sz
            scope.nextCondLabel = nil
        elseif tokenType == "ENDIF" then
            synassert(scope.type == "IF", token, "Expected end of %s block", scope.type)
            tokens:advance()
            -- Last block doesn't need a goto (?)
            -- Define endLabel and nextCondLabel if necessary
            if scope.nextCondLabel then
                self.labels[scope.nextCondLabel] = self.code.sz
            end
            self.labels[scope.endLabel] = self.code.sz
            -- End the scope
            scope = scope.prev
            -- And we're done
        elseif tokenType == "WHILE" then
            local tokenIndex = tokens.index
            tokens:advance()
            local condLabel = string.format("#while-%d", tokenIndex)
            local endLabel = string.format("#end-while-%d", tokenIndex)
            self.labels[condLabel] = self.code.sz
            parseAndEmitConditionalExpression()
            scope = {
                type = "WHILE",
                condLabel = condLabel,
                endLabel = endLabel,
                prev = scope,
            }
            self:emit("B", opcodes.BranchIfFalse)
            self:popStack(1)
            self:addPendingOffset("label", endLabel, token)
        elseif tokenType == "ENDWH" then
            synassert(scope.type == "WHILE", token, "Expected end of %s block", scope.type)
            tokens:advance()
            self:emit("B", opcodes.GoTo)
            self:addPendingOffset("label", scope.condLabel, token)
            self.labels[scope.endLabel] = self.code.sz
            scope = scope.prev
        elseif tokenType == "DO" then
            local tokenIndex = tokens.index
            tokens:advance()
            local startLabel = string.format("#do-%d", tokenIndex)
            local condLabel = string.format("#until-%d", tokenIndex)
            local endLabel = string.format("#end-do-%d", tokenIndex)
            self.labels[startLabel] = self.code.sz
            scope = {
                type = "DO",
                startLabel = startLabel,
                condLabel = condLabel,
                endLabel = endLabel,
                prev = scope,
            }
        elseif tokenType == "UNTIL" then
            synassert(scope.type == "DO", token, "Expected end of %s block", scope.type)
            tokens:advance()
            self.labels[scope.condLabel] = self.code.sz
            parseAndEmitConditionalExpression()
            self:emit("B", opcodes.BranchIfFalse)
            self:popStack(1)
            self:addPendingOffset("label", scope.startLabel, token)
            self.labels[scope.endLabel] = self.code.sz
            scope = scope.prev
        elseif tokenType == "BREAK" or tokenType == "CONTINUE" then
            -- Find innermost DO or WHILE scope
            local breakableScope = scope
            while breakableScope.type == "IF" do
                breakableScope = breakableScope.prev
            end
            synassert(breakableScope.type == "WHILE" or breakableScope.type == "DO", token,
                "Cannot %s from a %s scope", tokenType, breakableScope.type)
            self:emit("B", opcodes.GoTo)
            if tokenType == "BREAK" then
                self:addPendingOffset("label", breakableScope.endLabel, token)
            else
                self:addPendingOffset("label", breakableScope.condLabel, token)
            end
            tokens:advance()
        elseif tokenType == "label" then
            local labelName = assert(token.val:match("(.+)::"))
            synassert(#labelName <= 32, token, "Label name is too long")
            self.labels[labelName] = self.code.sz
            tokens:advance()
        elseif tokenType == "GOTO" then
            local labelToken = tokens:expectNext("identifier", "label")
            local labelName = labelToken.val:match("(.+)::") or labelToken.val
            self:emit("B", opcodes.GoTo)
            self:addPendingOffset("label", labelName, labelToken)
            tokens:advance()
        elseif tokenType == "ONERR" then
            tokens:advance()
            self:emit("B", opcodes.OnErr)
            if tokens:current().type == "OFF" then
                self:emit("h", 0)
            else
                local labelToken = tokens:expect("identifier", "label")
                local labelName = labelToken.val:match("(.+)::") or labelToken.val
                self:addPendingOffset("label", labelName, labelToken)
            end
            tokens:advance()
        elseif tokenType == "TRAP" then
            local next = tokens:peekNext().val
            synassert(TrappableCommands[next], token, "%s is not a trappable command", next)
            self:emit("B", opcodes.Trap)
            tokens:advance()
            -- And go round the loop to process next command
        elseif tokenType == "VECTOR" then
            tokens:advance()
            local exp = parseExpression(tokens)
            self:emitExpression(exp, Int)
            local labels = {}
            while true do
                local tok = tokens:expect("identifier", "ENDV", "colon", "eos")
                tokens:advance()
                if tok.type == "ENDV" then
                    break
                elseif tok.type == "identifier" then
                    table.insert(labels, tok)
                end
                if tokens:current().type == "comma" then
                    tokens:advance()
                end
            end
            self:emit("Bh", opcodes.Vector, #labels)
            local vectorLoc = self.code.sz
            for _, labelToken in ipairs(labels) do
                self:addPendingOffset("label", labelToken.val, labelToken, vectorLoc)
            end
            self:popStack(1)
        else
            synerror(token, "Unhandled token %s", tokenType)
        end

        if tokenType ~= "eos" then
            lastStatement = tokenType
        end
    end

    self:resolveOffsets(argExps)

    result.code = table.concat(self.code)
    assert(#result.code == self.code.sz, "Mismatch in code size!")
    result.maxStack = self.stackSz.max
    result.subprocs = self.subprocs
    result.externals = self.externals
    result.iDataSize = self.iDataSize
    result.iTotalTableSize = self.iTotalTableSize

    result.globals = {}
    local allVars = {}
    for i, var in ipairs(self.globalDecls) do
        local dataType = TypeToDataType[var.valType]
        if var.array then
            dataType = dataType | 0x80
        end
        result.globals[i] = {
            name = var.val,
            type = dataType,
            offset = var.offset,
        }
        table.insert(allVars, var)
    end
    for _, var in ipairs(self.localDecls) do
        table.insert(allVars, var)
    end

    local strings = {}
    local arrays = {}
    -- The offsets for strings table are to the maxlen byte, not the string itself, hence -1
    for _, var in ipairs(allVars) do
        if var.valType == String then
            table.insert(strings, { offset = var.offset - 1, maxLen = var.maxLen })
        end
        if var.arrayLen then
            local arrOffset = var.offset - ((var.valType == String) and 3 or 2)
            table.insert(arrays, { offset = arrOffset, len = var.arrayLen })
        end
    end
    result.strings = strings
    result.arrays = arrays

    return result
end

function handleOp_BUSY(procState)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    local numParams
    if procState.tokens:current().type == "OFF" then
        numParams = 0
        procState.tokens:advance()
    else
        local args = parseExpressionList(procState.tokens)
        local declArgs = {String, Int, Int, numParams = {1, 2, 3}}
        checkExpressionArguments(args, declArgs, cmdToken)
        for i, arg in ipairs(args) do
            procState:emitExpression(arg, declArgs[i])
        end
        numParams = #args
    end
    procState:emit("BB", opcodes.Busy, numParams)
    procState:popStack(numParams)
end

local function handleOpenOrCreate(procState, opcode)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    local args = parseExpressionList(procState.tokens)
    synassert(#args >= 2, cmdToken, "Expected %s name, logicalName, ...", cmdToken.val)
    procState:emitExpression(args[1], String)
    local logicalName = args[2].val
    synassert(logicalName:match("^[A-Z]$"), args[2], "Bad logical name for database handle")
    local log = string.byte(logicalName) - string.byte("A")
    local fields = {}
    for i = 3, #args do
        local t = TypeToDataType[args[i].valType]
        table.insert(fields, string.pack("<Bs1", t, args[i].val))
    end
    table.insert(fields, "\xFF") -- End of types marker
    procState:emit("BB", opcode, log)
    procState:emit(table.concat(fields))
    procState:popStack(1)
end

function handleOp_CREATE(procState)
    handleOpenOrCreate(procState, opcodes.Create)
end

function handleOp_CURSOR(procState)
    local tokens = procState.tokens
    local cmdToken = tokens:current()
    tokens:advance()
    local qualifier, args
    local firstArgType = tokens:current().type

    if firstArgType == "OFF" then
        qualifier = 0
        tokens:advance()
    elseif firstArgType == "ON" then
        qualifier = 1
        tokens:advance()
    else
        args = parseExpressionList(tokens)
        local declArgs = {Int, Int, Int, Int, Int, numParams = {1, 4, 5}}
        checkExpressionArguments(args, declArgs, cmdToken)
        for i, arg in ipairs(args) do
            procState:emitExpression(arg, declArgs[i])
        end
        -- This command is unusual in how qualifier is used...
        if #args == 1 then
            qualifier = 2
        else
            qualifier = #args - 1 -- ie 3 or 4
        end
    end
    procState:emit("BB", opcodes.Cursor, qualifier)
    if args then
        procState:popStack(#args)
    end
end

function handleOp_DBUTTONS(procState)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    -- Is there any actual limit on number of args?
    local args = parseExpressionList(procState.tokens)
    synassert(#args % 2 == 0, cmdToken, "Expected even number of arguments to dBUTTONS")
    -- Not sure what the button count limit is on series 5...
    for i = 1, #args, 2 do
        procState:emitExpression(args[i], String)
        procState:emitExpression(args[i + 1], Int)
    end
    procState:emit("BBB", opcodes.dItem, dItemTypes.dBUTTONS, #args // 2)
    procState:popStack(#args)
end

function handleOp_DCHECKBOX(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emit("BB", opcodes.NextOpcodeTable, opcodes.dEditCheckbox - 256)
    procState:popStack(#args)
end

function handleOp_DCHOICE(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], String)
    procState:emit("BB", opcodes.dItem, dItemTypes.dCHOICE)
    procState:popStack(#args)
end

function handleOp_DDATE(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], Long)
    procState:emitExpression(args[4], Long)
    procState:emit("BB", opcodes.dItem, dItemTypes.dDATE)
    procState:popStack(#args)
end

function handleOp_DELETE(procState, args)
    if #args == 1 then
        procState:emitExpression(args[1], String)
        procState:emit("B", opcodes.Delete)
    else
        assert(#args == 2)
        procState:emitExpression(args[1], String)
        procState:emitExpression(args[2], String)
        procState:emit("BB", opcodes.NextOpcodeTable, opcodes.DeleteTable - 256)
    end
    procState:popStack(#args)
end

function handleOp_DEDIT(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    if #args == 2 then
        procState:emit("BB", opcodes.dItem, dItemTypes.dEDIT)
    else
        procState:emitExpression(args[3], Int)
        procState:emit("BB", opcodes.dItem, dItemTypes.dEDITlen)
    end
    procState:popStack(#args)
end

function handleOp_DFILE(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], Int)
    if #args == 6 then
        procState:emitExpression(args[4], Long)
        procState:emitExpression(args[5], Long)
        procState:emitExpression(args[6], Long)
    else
        procState:emit("BBBBBB", opcodes.StackByteAsLong, 0, opcodes.StackByteAsLong, 0, opcodes.StackByteAsLong, 0)
        procState:pushStack(Long, Long, Long)
    end
    procState:emit("BB", opcodes.dItem, dItemTypes.dFILE)
    procState:popStack(6)
end

function handleOp_DFLOAT(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], Float)
    procState:emitExpression(args[4], Float)
    procState:emit("BB", opcodes.dItem, dItemTypes.dFLOAT)
    procState:popStack(#args)
end

function handleOp_DLONG(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], Long)
    procState:emitExpression(args[4], Long)
    procState:emit("BB", opcodes.dItem, dItemTypes.dLONG)
    procState:popStack(#args)
end

function handleOp_DPOSITION(procState, args)
    procState:emitExpression(args[1], Int)
    procState:emitExpression(args[2], Int)
    procState:emit("BB", opcodes.dItem, dItemTypes.dPOSITION)
    procState:popStack(2)
end

function handleOp_DTEXT(procState, args)
    procState:emitExpression(args[1], String)
    procState:emitExpression(args[2], String)
    local hasFlags = args[3] ~= nil
    if hasFlags then
        procState:emitExpression(args[3], Int)
    end
    procState:emit("BBB", opcodes.dItem, dItemTypes.dTEXT, hasFlags and 1 or 0)
    procState:popStack(#args)
end

function handleOp_DTIME(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emitExpression(args[3], Int)
    procState:emitExpression(args[4], Long)
    procState:emitExpression(args[5], Long)
    procState:emit("BB", opcodes.dItem, dItemTypes.dTIME)
    procState:popStack(#args)
end

function handleOp_DXINPUT(procState, args)
    local var = procState:getVar(args[1], false)
    procState:emitVarLhs(var, args[1])
    procState:emitExpression(args[2], String)
    procState:emit("BB", opcodes.dItem, dItemTypes.dXINPUT)
    procState:popStack(#args)
end

function handleOp_EDIT(procState)
    local tokens = procState.tokens
    tokens:advance()
    local varToken = tokens:current()
    local var = procState:getVar(varToken, false)
    synassert(var.valType == String, varToken, "Expected String variable")
    procState:emitVarLhs(var, varToken)
    procState:emit("B", opcodes.Edit)
    tokens:advance()
    procState:popStack(1)
end

function handleOp_ESCAPE(procState)
    local val = procState.tokens:expectNext("ON", "OFF").val
    procState:emit("BB", opcodes.Escape, val == "ON" and 1 or 0)
    procState.tokens:advance()
end

function handleOp_GCLOCK(procState)
    local tokens = procState.tokens
    local cmdToken = tokens:current()
    tokens:advance()
    local qualifier, args
    local firstArgType = tokens:expect("ON", "OFF").type

    if firstArgType == "OFF" then
        qualifier = 0
        tokens:advance()
    else
        qualifier = 1
        tokens:advance()
        if tokens:current().type == "comma" then
            tokens:advance()
            args = parseExpressionList(tokens)
            local declArgs = {Int, IntPtr, String, IntPtr, Int, numParams = {1, 2, 3, 4, 5}}
            checkExpressionArguments(args, declArgs, cmdToken)
            for i, arg in ipairs(args) do
                procState:emitExpression(arg, declArgs[i])
            end
            qualifier = 1 + #args
        end
    end
    procState:emit("BB", opcodes.gClock, qualifier)
    if args then
        procState:popStack(#args)
    end
end

local function handlePrint(procState)
    local tokens = procState.tokens
    local cmdToken = tokens:current().val
    local gprint = cmdToken == "GPRINT"
    local opPrefix = gprint and "gPrint" or cmdToken == "LPRINT" and "LPrint" or "Print"
    local endedWithSeparator = false
    tokens:advance()
    while not tokens:eos() do
        local exp = parseExpression(tokens)
        procState:emitExpression(exp, exp.valType)
        local opName = gprint and GPrintTypeToStr[exp.valType] or opPrefix..TypeToStr[exp.valType]
        procState:emit("B", opcodes[opName])
        procState:popStack(1)

        local nextToken = tokens:expect("comma", "semicolon", "colon", "eos").type
        if nextToken == "comma" then
            procState:emit("B", opcodes[opPrefix.."Space"])
        end
        endedWithSeparator = nextToken == "comma" or nextToken == "semicolon"
        if endedWithSeparator then
            tokens:advance()
        end
    end
    if not endedWithSeparator and not gprint then
        procState:emit("B", opcodes[opPrefix.."CarriageReturn"])
    end
end

function handleOp_GPEEKLINE(procState, args)
    procState:emitExpression(args[1], Int)
    procState:emitExpression(args[2], Int)
    procState:emitExpression(args[3], Int)
    local var = procState:getVar(args[4], true)
    procState:emitAddressOfVar(var, args[4])
    procState:emitExpression(args[5], Int)
    if #args == 6 then
        procState:emitExpression(args[6], Int)
    else
        procState:emit("BB", opcodes.StackByteAsWord, 0xFF)
        procState:pushStack(Int)
    end
    procState:emit("B", opcodes.gPeekLine)
    procState:popStack(6)
end

function handleOp_GPRINT(procState)
    handlePrint(procState)
end

function handleOp_GUPDATE(procState)
    local tokens = procState.tokens
    tokens:advance()
    local what = tokens:current().type
    local flag
    if what == "ON" then
        tokens:advance()
        flag = 1
    elseif what == "OFF" then
        tokens:advance()
        flag = 0
    else
        flag = 255
        -- The end of statement check in the main parser will catch anything else that's not eos
    end
    procState:emit("BB", opcodes.gUpdate, flag)
end

function handleOp_GVISIBLE(procState)
    local val = procState.tokens:expectNext("ON", "OFF").val
    procState:emit("BB", opcodes.gVisible, val == "ON" and 1 or 0)
    procState.tokens:advance()
end

function handleOp_INPUT(procState)
    local tokens = procState.tokens
    tokens:advance()
    local varToken = tokens:current()
    local var = procState:getVar(varToken, false)
    procState:emitVarLhs(var, varToken)
    if var.valType == Int then
        procState:emit("B", opcodes.InputInt)
    elseif var.valType == Long then
        procState:emit("B", opcodes.InputLong)
    elseif var.valType == Float then
        procState:emit("B", opcodes.InputFloat)
    elseif var.valType == String then
        procState:emit("B", opcodes.InputString)
    end

    tokens:advance()
    procState:popStack(1)
end

function handleOp_LOCK(procState)
    local val = procState.tokens:expectNext("ON", "OFF").val
    procState:emit("BB", opcodes.Lock, val == "ON" and 1 or 0)
    procState.tokens:advance()
end

function handleOp_LPRINT(procState)
    handlePrint(procState)
end

function handleOp_MCARD(procState)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    local args = parseExpressionList(procState.tokens)
    synassert(#args % 2 == 1, cmdToken, "Expected odd number of arguments to mCARD")
    procState:emitExpression(args[1], String)
    for i = 2, #args, 2 do
        procState:emitExpression(args[i], String)
        procState:emitExpression(args[i + 1], Int)
    end
    procState:emit("BB", opcodes.mCard, (#args - 1) // 2)
    procState:popStack(#args)
end

function handleOp_MCASC(procState)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    local args = parseExpressionList(procState.tokens)
    synassert(#args % 2 == 1, cmdToken, "Expected odd number of arguments to mCASC")
    procState:emitExpression(args[1], String)
    for i = 2, #args, 2 do
        procState:emitExpression(args[i], String)
        procState:emitExpression(args[i + 1], Int)
    end
    procState:emit("BBB", opcodes.NextOpcodeTable, opcodes.mCasc - 256, (#args - 1) // 2)
    procState:popStack(#args)
end

function handleOp_OPEN(procState)
    handleOpenOrCreate(procState, opcodes.Open)
end

function handleOp_OPENR(procState)
    handleOpenOrCreate(procState, opcodes.OpenR)
end

function handleOp_PRINT(procState)
    handlePrint(procState)
end

function handleOp_SCREEN(procState, args)
    procState:emitExpression(args[1], Int)
    procState:emitExpression(args[2], Int)
    if args[3] then
        procState:emitExpression(args[3], Int)
        procState:emitExpression(args[4], Int)
        procState:emit("B", opcodes.Screen4)
    else
        procState:emit("B", opcodes.Screen2)
    end
    procState:popStack(#args)
end

function handleOp_USE(procState)
    local cmdToken = procState.tokens:current()
    procState.tokens:advance()
    local logExp = parseExpression(procState.tokens)
    local logicalName = logExp.val
    synassert(logicalName:match("^[A-Z]$"), logExp, "Bad logical name for database handle")
    local log = string.byte(logicalName) - string.byte("A")
    procState:emit("BB", opcodes.Use, log)
end


function readFile(filename, text)
    local f = io.open(filename, text and "r" or "rb")
    if not f then
        return nil
    end
    local data = f:read("a")
    f:close()
    return data
end

function docompile(path, realPath, programText, includePaths)
    local tokens = lex(programText, realPath or path)
    local procTable = {}
    local opxTable = {}
    local consts = {}
    local procDecls = {}
    local aif = nil
    local strictExternals = false
    local isInclude = includePaths == nil
    while true do
        local token = tokens:current()
        if token == nil then
            break
        elseif tokens:eos() then
            tokens:advance()
        elseif token.type == "INCLUDE" then
            -- Don't think includes can have other includes?
            synassert(not isInclude, token, "Cannot use includes in include files")

            tokens:advance()
            local includeTok = tokens:expect("string")
            local includeName = literalToString(includeTok.val)
            tokens:advance()

            local includeText, foundIncludePath
            for _, includePath in ipairs(includePaths) do
                local path = includePath .. includeName
                includeText = readFile(path, true)
                if includeText then
                    foundIncludePath = path
                    break
                end
            end
            if includeText == nil then
                -- Try built-ins
                local modName = "includes." .. includeName:lower():gsub("%.", "_")
                local ok, inc = pcall(require, modName)
                if ok then
                    includeText = inc
                end
            end
            synassert(includeText, includeTok, 'Include not found "%s"', includeName)
            local prog = docompile(includeName, foundIncludePath, includeText, nil)
            for name, exp in pairs(prog.consts) do
                synassert(consts[name] == nil, token, "Duplicate definition of const %s", name)
                consts[name] = exp
            end
            for name, decl in pairs(prog.procDecls) do
                synassert(procDecls[decl.name] == nil, decl, "Procedure %s in OPX already defined", decl.name)
                procDecls[name] = decl
            end
        elseif token.type == "CONST" then
            local idtoken = tokens:expectNext("identifier")
            tokens:expectNext("eq")
            tokens:advance()
            local exp = parseExpression(tokens)
            if exp.op == "unm" then
                -- This is the only "expression" we allow which should be folded into the value
                exp = {
                    type = exp[2].type,
                    valType = exp.valType,
                    operandType = exp.operandType,
                    src = exp.src,
                    val = "-" .. exp[2].val
                }
            end
            if exp.type == "identifier" then
                -- The only allowed identifiers are other already-declared constants
                local const = consts[exp.val]
                assert(const, exp.val.." not found in existing CONSTs")
                exp = const
            end
            synassert(exp.type == "number" or exp.type == "string", exp, "Expected literal in CONST")
            synassert(consts[idtoken.val] == nil, exp, "Duplicate definition of const %s", idtoken.val)
            consts[idtoken.val] = exp
        elseif token.type == "APP" then
            synassert(aif == nil, token, "Multiple APP definitions")
            synassert(not isInclude, token, "Cannot define APPs in include files")
            aif = parseApp(tokens, consts)
        elseif token.type == "DECLARE" then
            token = tokens:expectNext("EXTERNAL", "OPX")
            if token.type == "EXTERNAL" then
                strictExternals = true
                tokens:advance()
            else
                local opx = parseOpx(tokens, consts)
                -- Add all the opx fns to our procDecls
                for _, decl in ipairs(opx.procDecls) do
                    synassert(procDecls[decl.name] == nil, decl, "Procedure %s in OPX already defined", decl.name)
                    procDecls[decl.name] = decl
                end
            end
        elseif token.type == "EXTERNAL" then
            tokens:advance()
            parseProcDeclaration("EXTERNAL", tokens, procDecls)
        elseif token.type == "PROC" then
            synassert(not isInclude, token, "Cannot define procedures in include files")
            table.insert(procTable, parseProc(tokens, consts, procDecls, opxTable, strictExternals))
        else
            synerror(token, "Unhandled top-level token")
        end
    end

    if isInclude then
        return {
            consts = consts,
            procDecls = procDecls,
        }
    else
        return {
            path = path,
            procTable = procTable,
            opxTable = opxTable,
            aif = aif,
        }
    end
end

function compile(path, realPath, programText, includePaths, shouldMakeAif)
    local compileResult = docompile(path, realPath, programText, includePaths)
    local opo = require("opofile").makeOpo(compileResult)
    local aifData = nil
    if shouldMakeAif and compileResult.aif then
        if compileResult.aif.icons then
            -- compileResult.aif.icons is list of mbm paths, convert to list of actual bitmaps
            local mbm = require("mbm")
            local iconBitmaps = {}
            for _, icon in ipairs(compileResult.aif.icons) do
                if icon.path:match("%.bmp$") then
                    error("TODO")
                else
                    local mbmData = readFile(icon.path)
                    synassert(mbmData, icon.token, "Could not read file '%s'", icon.path)
                    local bitmaps = mbm.parseMbmHeader(mbmData)
                    for _, bmp in ipairs(bitmaps) do
                        table.insert(iconBitmaps, bmp)
                    end
                end
            end
            synassert(#iconBitmaps % 2 == 0, compileResult.aif.icons[#compileResult.aif.icons].token,
                "ICONs must have an even number of bitmaps in total")

            for i = 1, #iconBitmaps, 2 do
                synassert(iconBitmaps[i].width == iconBitmaps[i+1].width,
                    compileResult.aif.icons[(i + 1) // 2],
                    "Icon and mask sizes must match")
            end

            -- Convert icons to format expected by makeAif
            compileResult.aif.icons = iconBitmaps
        end

        aifData = require("aif").makeAif(compileResult.aif)
    end
    return opo, aifData
end

return _ENV
