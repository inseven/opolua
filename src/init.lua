function module()
    return setmetatable({}, {__index=_G})
end

function enum(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = v
        result[v] = k
    end
    return result
end

function printf(...)
    io.stdout:write(string.format(...))
end

DataTypes = enum {
    EWord = 0, -- 2 bytes
    ELong = 1, -- 4 bytes
    EReal = 2, -- 8 bytes
    EString = 3,
    EWordArray = 0x80,
    ELongArray = 0x81,
    ERealArray = 0x82,
    EStringArray = 0x83,
}

local function OPLERR(val)
    -- return 0xabcd0000 | val
    return val
end

-- Since we never have to worry about acual epoc error codes (eg -8 meaning
-- KErrBadHandle) we can just always use the OPL1993 values
Errors = {
    KErrNone = 0,
    KOplErrGenFail = OPLERR(-1),
    KOplErrInvalidArgs = OPLERR(-2),
    KOplErrDivideByZero = OPLERR(-8),
    KOplErrIllegal = OPLERR(-96),
    KOplErrEsc = OPLERR(-114),
}

-- Errors are global for convenience
for k, v in pairs(Errors) do _ENV[k] = v end
-- And allow reverse lookup
Errors = enum(Errors)

-- Give these global names so native code can potentially get to them easily
_Ops = require("ops")
_Fns = require("fns")
