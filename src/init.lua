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
    return 0xabcd0000 | val
end

KOplErrInvalidArgs = OPLERR(-2)
KOplErrDivideByZero = OPLERR(-8)

-- Give these global names so native code can potentially get to them easily
_Ops = require("ops")
_Fns = require("fns")
