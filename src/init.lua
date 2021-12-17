function module()
    return setmetatable({}, {__index=_G})
end

local classMt = {
    __call = function(classObj, obj)
        return setmetatable(obj or {}, classObj)
    end
}

function class(classObj)
    classObj.__index = classObj
    return setmetatable(classObj, classMt)
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

SizeofType = {
    [DataTypes.EWord] = 2,
    [DataTypes.ELong] = 4,
    [DataTypes.EReal] = 8,
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
    KOplErrEof = -36,
    KOplErrName = -38,
    KOplErrAccess = -39,
    KOplErrRecord = -43, -- Specifically can mean "record too large"
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

-- Except when we do :-(
KRequestPending = 0x80000001

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

KPenDown = 0
KPenUp = 1
KPenDrag = 6

-- UIDs converted with
-- lua -e "for line in io.lines() do print((line:gsub('(%s+)([0-9]+)%s*', function(s, m) return string.format('%s0x%08X', s, tonumber(m)) end))) end"
KFontArialBold8 = 0x100001EF
KFontArialBold11 = 0x100001F0
KFontArialBold13 = 0x100001F1
KFontArialNormal8 = 0x100001F2
KFontArialNormal11 = 0x100001F3
KFontArialNormal13 = 0x100001F4
KFontArialNormal15 = 0x100001F5
KFontArialNormal18 = 0x100001F6
KFontArialNormal22 = 0x100001F7
KFontArialNormal27 = 0x100001F8
KFontArialNormal32 = 0x100001F9
KFontTimesBold8 = 0x100001FA
KFontTimesBold11 = 0x100001FB
KFontTimesBold13 = 0x100001FC
KFontTimesNormal8 = 0x100001FD
KFontTimesNormal11 = 0x100001FE
KFontTimesNormal13 = 0x100001FF
KFontTimesNormal15 = 0x10000200
KFontTimesNormal18 = 0x10000201
KFontTimesNormal22 = 0x10000202
KFontTimesNormal27 = 0x10000203
KFontTimesNormal32 = 0x10000204
KFontCourierBold8 = 0x1000025E
KFontCourierBold11 = 0x1000025F
KFontCourierBold13 = 0x10000260
KFontCourierNormal8 = 0x10000261
KFontCourierNormal11 = 0x10000262
KFontCourierNormal13 = 0x10000263
KFontCourierNormal15 = 0x10000264
KFontCourierNormal18 = 0x10000265
KFontCourierNormal22 = 0x10000266
KFontCourierNormal27 = 0x10000267
KFontCourierNormal32 = 0x10000268
KFontTiny4 = 0x10000030
KFontSquashed = 0x100000F5

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
    [KFontTiny4] = { face = "tiny", size = 4 },
    [KFontArialBold8] = { face = "arial", size = 8, bold = true },
    [KFontArialBold11] = { face = "arial", size = 11, bold = true },
    [KFontArialBold13] = { face = "arial", size = 13, bold = true },
    [KFontArialNormal8] = { face = "arial", size = 8 },
    [KFontArialNormal11] = { face = "arial", size = 11 },
    [KFontArialNormal13] = { face = "arial", size = 13 },
    [KFontArialNormal15] = { face = "arial", size = 15 },
    [KFontArialNormal18] = { face = "arial", size = 18 },
    [KFontArialNormal22] = { face = "arial", size = 22 },
    [KFontArialNormal27] = { face = "arial", size = 27 },
    [KFontArialNormal32] = { face = "arial", size = 32 },
    [KFontTimesBold8] = { face = "times", size = 8, bold = true },
    [KFontTimesBold11] = { face = "times", size = 11, bold = true },
    [KFontTimesBold13] = { face = "times", size = 13, bold = true },
    [KFontTimesNormal8] = { face = "times", size = 8 },
    [KFontTimesNormal11] = { face = "times", size = 11 },
    [KFontTimesNormal13] = { face = "times", size = 13 },
    [KFontTimesNormal15] = { face = "times", size = 15 },
    [KFontTimesNormal18] = { face = "times", size = 18 },
    [KFontTimesNormal22] = { face = "times", size = 22 },
    [KFontTimesNormal27] = { face = "times", size = 27 },
    [KFontTimesNormal32] = { face = "times", size = 32 },
    [KFontCourierBold8] = { face = "courier", size = 8, bold = true },
    [KFontCourierBold11] = { face = "courier", size = 11, bold = true },
    [KFontCourierBold13] = { face = "courier", size = 13, bold = true },
    [KFontCourierNormal8] = { face = "courier", size = 8 },
    [KFontCourierNormal11] = { face = "courier", size = 11 },
    [KFontCourierNormal13] = { face = "courier", size = 13 },
    [KFontCourierNormal15] = { face = "courier", size = 15 },
    [KFontCourierNormal18] = { face = "courier", size = 18 },
    [KFontCourierNormal22] = { face = "courier", size = 22 },
    [KFontCourierNormal27] = { face = "courier", size = 27 },
    [KFontCourierNormal32] = { face = "courier", size = 32 },
    [KFontSquashed] = { face = "squashed", size = 11, bold = true },
}

GraphicsMode = enum {
    Set = 0,
    Clear = 1,
    Invert = 2,
}

Align = enum {
    Left = 2,
    Right = 1,
    Center = 3,
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

oplpath = {}

function oplpath.isabs(path)
    return path:match("^[a-zA-Z]:\\") ~= nil
end

function oplpath.split(path)
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

function oplpath.dirname(path)
    local dir, file = oplpath.split(path)
    return dir
end

function oplpath.basename(path)
    local dir, file = oplpath.split(path)
    return file
end

function oplpath.splitext(path)
    local base, ext = path:match("(.+)(%.[^%.]*)")
    if not base then
        return path, ""
    else
        return base, ext
    end
end

function oplpath.join(path, component)
    if not path:match("\\$") then
        path = path.."\\"
    end
    return path..component
end

function oplpath.abs(path, relativeTo)
    if path == "" then
        return relativeTo
    elseif oplpath.isabs(path) then
        return path
    elseif path:match("^\\") then
        -- Just take drive letter from relativeTo
        return relativeTo:sub(1, 2) .. path
    else
        local dir, name = oplpath.split(relativeTo)
        -- Check if relativeTo has a wildcarded name (ugh)
        if name:match("%*") then
            path = name:gsub("%*", path, 1)
        end
        return oplpath.join(dir, path)
    end
end

-- For whenever you need to compare paths for equality - not to be used for anything else
function oplpath.canon(path)
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

local charCodeMap = {
    [4098] = 262, -- Home
    [4099] = 263, -- End
    [4100] = 260, -- PgUp
    [4101] = 261, -- PgDn
    [4103] = 259, -- LeftArrow
    [4104] = 258, -- RightArrow
    [4105] = 256, -- UpArrow
    [4106] = 257, -- DownArrow
    [4150] = 290, -- Menu
}

function keycodeToCharacterCode(keycode)
    local ch = charCodeMap[keycode]
    if ch then
        return ch
    elseif keycode < 256 then
        return keycode
    else
        error("Unknown keycode "..tostring(keycode))
    end
end
