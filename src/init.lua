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

-- Since we never have to worry about actual epoc error codes (eg -8 meaning
-- KErrBadHandle) we can just always use the OPL1993 values
Errors = {
    KErrNone = 0,
    KOplErrGenFail = -1,
    KOplErrInvalidArgs = -2,
    KOplErrDivideByZero = -8,
    KOplErrInUse = -9,
    KOplErrFontNotLoaded = -21,
    KOplErrExists = -32,
    KOplErrNotExists = -33,
    KOplErrWrite = -34,
    KOplErrName = -38,
    KOplErrAccess = -39,
    KOplErrFilePending = -46,
    KOplErrIOCancelled = -48,
    KOplErrNotReady = -62,
    KOplStructure = -85,
    KOplErrIllegal = -96,
    KOplErrNoFld = -100,
    KOplErrOpen = -101,
    KOplErrClosed = -102,
    KOplErrNoMod = -106,
    KOplErrSubs = -111,
    KOplErrEsc = -114,
    KOplErrDrawNotOpen = -118,
    KOplErrInvalidWindow = -119,
    KOplErrIncompatibleUpdateMode = -125,
    KStopErr = -999, -- Made this one up
}

-- Some misc uids used for file formats
KUidDirectFileStore = 0x10000037 -- OPO file uid1
-- KUidAppDllDoc8 = 0x1000006D
KUidOPO = 0x10000073 -- pre-unicode OPO uid2
KUidMultiBitmapFileImage = 0x10000042
KUidOplInterpreter = 0x10000168

KPermanentFileStoreLayoutUid = 0x10000050 -- DB file uid1
KUidExternalOplFile = 0x1000008A -- DB file UID2

KUidSoundData = 0x10000052 -- Not sure what this uid is officially called, can't find a reference...

KDefaultFontUid = 268435957 -- ie Arial 15

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

FontIds = {
    [4] = { face = "courier", size = 8 },
    [5] = { face = "times", size = 8 },
    [6] = { face = "times", size = 11 },
    [7] = { face = "times", size = 13 },
    [8] = { face = "times", size = 15 },
    [9] = { face = "arial", size = 8 },
    [10] = { face = "arial", size = 11 },
    [11] = { face = "arial", size = 13 },
    [12] = { face = "arial", size = 15 },
    [13] = { face = "tiny", size = 4 },
    [0x9A] = { face = "arial", size = 15 },
    [268435504] = { face = "tiny", size = 4 },
    [268435951] = { face = "arial", size = 8, bold = true },
    [268435952] = { face = "arial", size = 11, bold = true },
    [268435953] = { face = "arial", size = 13, bold = true },
    [268435954] = { face = "arial", size = 8 },
    [268435955] = { face = "arial", size = 11 },
    [268435956] = { face = "arial", size = 13 },
    [268435957] = { face = "arial", size = 15 },
    [268435958] = { face = "arial", size = 18 },
    [268435959] = { face = "arial", size = 22 },
    [268435960] = { face = "arial", size = 27 },
    [268435961] = { face = "arial", size = 32 },
    [268435962] = { face = "times", size = 8, bold = true },
    [268435963] = { face = "times", size = 11, bold = true },
    [268435964] = { face = "times", size = 13, bold = true },
    [268435965] = { face = "times", size = 8 },
    [268435966] = { face = "times", size = 11 },
    [268435967] = { face = "times", size = 13 },
    [268435968] = { face = "times", size = 15 },
    [268435969] = { face = "times", size = 18 },
    [268435970] = { face = "times", size = 22 },
    [268435971] = { face = "times", size = 27 },
    [268435972] = { face = "times", size = 32 },
    [268436062] = { face = "courier", size = 8, bold = true },
    [268436063] = { face = "courier", size = 11, bold = true },
    [268436064] = { face = "courier", size = 13, bold = true },
    [268436065] = { face = "courier", size = 8 },
    [268436066] = { face = "courier", size = 11 },
    [268436067] = { face = "courier", size = 13 },
    [268436068] = { face = "courier", size = 15 },
    [268436069] = { face = "courier", size = 18 },
    [268436070] = { face = "courier", size = 22 },
    [268436071] = { face = "courier", size = 27 },
    [268436072] = { face = "courier", size = 32 },
}

GraphicsMode = enum {
    Set = 0,
    Clear = 1,
    Invert = 2,
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

-- For whenever you need to compare paths for equality - not to be used for anything else
function canonPath(path)
    return path:upper():gsub("[\\/]+", "/")
end

-- Simplest most unambiguous escaping you can get - anything that's not
-- printable ascii is converted to \xNN, including newlines and (to avoid
-- ambiguity) backslash.
function hexEscape(str)
    local pattern = "[\x00-\x1F\x7F-\xFF\\]"
    return str:gsub(pattern, function(ch) return string.format("\\x%02X", ch:byte()) end)
end

function hexUnescape(str)
    return str:gsub("\\x(%x%x)", function(hexcode) return string.char(tonumber(hexcode, 16)) end)
end
