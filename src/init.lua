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

function isArrayType(t)
    return t & 0x80 > 0
end

DefaultSimpleTypes = {
    [DataTypes.EWord] = 0,
    [DataTypes.ELong] = 0,
    [DataTypes.EReal] = 0.0,
    [DataTypes.EString] = "",
}

local function OPLERR(val)
    -- return 0xabcd0000 | val
    return val
end

-- Since we never have to worry about actual epoc error codes (eg -8 meaning
-- KErrBadHandle) we can just always use the OPL1993 values
Errors = {
    KErrNone = 0,
    KOplErrGenFail = OPLERR(-1),
    KOplErrInvalidArgs = OPLERR(-2),
    KOplErrDivideByZero = OPLERR(-8),
    KOplStructure = OPLERR(-85),
    KOplErrIllegal = OPLERR(-96),
    KOplErrNoMod = OPLERR(-106),
    KOplErrSubs = OPLERR(-111),
    KOplErrEsc = OPLERR(-114),
    KStopErr = -999, -- Made this one up
}

dItemTypes = enum {
    dTEXT = 0,
    dCHOICE = 1,
    dLONG = 2,
    dFLOAT = 3,
    dTIME = 4,
    dDATE = 5,
    dEDIT = 6,
    dEDITlen = 7,
    dXINPUT = 8,
    dFILE = 9,
    dBUTTONS = 10,
    dPOSITION = 11,
    dCHECKBOX = 12,
    -- simulated types, not actually used by OPL
    dSEPARATOR = 13,
}

-- Errors are global for convenience
for k, v in pairs(Errors) do _ENV[k] = v end
-- And allow reverse lookup
Errors = enum(Errors)

function sortedKeys(tbl)
    local result = {}
    for k in pairs(tbl) do
        table.insert(result, k)
    end
    table.sort(result)
    return result
end

function splitpath(path)
    local dir, sep, name = path:match([[(.*)([/\])(.*)$]])
    if not dir then
        return "", path
    else
        local dirLen = #dir
        if dirLen == 0 or (dirLen == 2 and dir:match("[a-zA-Z]:")) then
            -- Roots always have have a trailing slash
            dir = dir..sep
        end
        return dir, name
    end
end

function dirname(path)
    local dir, file = splitpath(path)
    return dir
end

function basename(path)
    local dir, file = splitpath(path)
    return file
end

function splitext(path)
    local base, ext = path:match("(.+)(%.[^%.]*)")
    if not base then
        return path, ""
    else
        return base, ext
    end
end
