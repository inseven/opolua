--[[

Copyright (c) 2021-2022 Jason Morley, Tom Sutcliffe

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

require("const")

function module()
    return setmetatable({}, {__index=_G})
end

local classMt = {
    __call = function(classObj, obj)
        return setmetatable(obj or {}, classObj)
    end,
    __index = function(classObj, name)
        local super = rawget(classObj, "_super")
        if super then
            return super[name]
        end
    end,
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

function toint32(val)
    if val >= 0x80000000 then
        val = string.unpack("<i4", string.pack("<I4", val))
    end
    return val
end

function touint16(val)
    return string.unpack("<I2", string.pack("<i2", val))
end

function touint32(val)
    return string.unpack("<I4", string.pack("<i4", val))
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

KErrNone = 0
KErrNotReady = -62
KStopErr = -999 -- Made this one up

Errors = enum {
    KErrNone = KErrNone,
    KErrNotReady = KErrNotReady,
    KStopErr = KStopErr,

    -- redefinitions from const.lua follow
    KErrGenFail = KErrGenFail,
    KErrInvalidArgs = KErrInvalidArgs,
    KErrOs = KErrOs,
    KErrNotSupported = KErrNotSupported,
    KErrUnderflow = KErrUnderflow,
    KErrOverflow = KErrOverflow,
    KErrOutOfRange = KErrOutOfRange,
    KErrDivideByZero = KErrDivideByZero,
    KErrInUse = KErrInUse,
    KErrNoMemory = KErrNoMemory,
    KErrNoSegments = KErrNoSegments,
    KErrNoSemaphore = KErrNoSemaphore,
    KErrNoProcess = KErrNoProcess,
    KErrAlreadyOpen = KErrAlreadyOpen,
    KErrNotOpen = KErrNotOpen,
    KErrImage = KErrImage,
    KErrNoReceiver = KErrNoReceiver,
    KErrNoDevices = KErrNoDevices,
    KErrNoFileSystem = KErrNoFileSystem,
    KErrFailedToStart = KErrFailedToStart,
    KErrFontNotLoaded = KErrFontNotLoaded,
    KErrTooWide = KErrTooWide,
    KErrTooManyItems = KErrTooManyItems,
    KErrBatLowSound = KErrBatLowSound,
    KErrBatLowFlash = KErrBatLowFlash,
    KErrExists = KErrExists,
    KErrNotExists = KErrNotExists,
    KErrWrite = KErrWrite,
    KErrRead = KErrRead,
    KErrEof = KErrEof,
    KErrFull = KErrFull,
    KErrName = KErrName,
    KErrAccess = KErrAccess,
    KErrLocked = KErrLocked,
    KErrDevNotExist = KErrDevNotExist,
    KErrDir = KErrDir,
    KErrRecord = KErrRecord,
    KErrReadOnly = KErrReadOnly,
    KErrInvalidIO = KErrInvalidIO,
    KErrFilePending = KErrFilePending,
    KErrVolume = KErrVolume,
    KErrIOCancelled = KErrIOCancelled,
    KErrSyntax = KErrSyntax,
    KOplStructure = KOplStructure,
    KErrIllegal = KErrIllegal,
    KErrNumArg = KErrNumArg,
    KErrUndef = KErrUndef,
    KErrNoProc = KErrNoProc,
    KErrNoFld = KErrNoFld,
    KErrOpen = KErrOpen,
    KErrClosed = KErrClosed,
    KErrRecSize = KErrRecSize,
    KErrModLoad = KErrModLoad,
    KErrMaxLoad = KErrMaxLoad,
    KErrNoMod = KErrNoMod,
    KErrNewVer = KErrNewVer,
    KErrModNotLoaded = KErrModNotLoaded,
    KErrBadFileType = KErrBadFileType,
    KErrTypeViol = KErrTypeViol,
    KErrSubs = KErrSubs,
    KErrStrTooLong = KErrStrTooLong,
    KErrDevOpen = KErrDevOpen,
    KErrEsc = KErrEsc,
    KErrMaxDraw = KErrMaxDraw,
    KErrDrawNotOpen = KErrDrawNotOpen,
    KErrInvalidWindow = KErrInvalidWindow,
    KErrScreenDenied = KErrScreenDenied,
    KErrOpxNotFound = KErrOpxNotFound,
    KErrOpxVersion = KErrOpxVersion,
    KErrOpxProcNotFound = KErrOpxProcNotFound,
    KErrStopInCallback = KErrStopInCallback,
    KErrIncompUpdateMode = KErrIncompUpdateMode,
    KErrInTransaction = KErrInTransaction,
}

-- Except when we do :-(
KRequestPending = toint32(0x80000001)
assert(KRequestPending == -2147483647)

-- Some misc uids used for file formats
-- OPL/OPO/AIF/MBM uid1 is KUidDirectFileStore
KDynamicLibraryUid = 0x10000079 -- ie a native app
KUidAppInfoFile8 = 0x1000006A -- AIF file uid2
-- KUidAppDllDoc8 = 0x1000006D
-- KUidOPO = 0x10000073 -- pre-unicode OPO uid2
KMultiBitmapRomImageUid = 0x10000041 -- uid1
KUidMultiBitmapFileImage = 0x10000042
KUidOplInterpreter = 0x10000168

KPermanentFileStoreLayoutUid = 0x10000050 -- DB file uid1
-- KUidOplFile = 0x1000008A -- DB file UID2

KUidSoundData = 0x10000052 -- Not sure what this uid is officially called, can't find a reference...
KUidTextEdSection = 0x10000085 -- ditto

KIoOpenModeMask = 0xF

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

KDefaultFontUid = KFontArialNormal15

FontIds = {
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
    [KFontEiksym15] = { face = "eiksym", size = 15 },
    [KFontSquashed] = { face = "squashed", size = 11, bold = true },
    [KFontDigital35] = { face = "digit", size = 35 },
}

for uid, font in pairs(FontIds) do font.uid = uid end

FontAliases = {
    [4] = KFontCourierNormal8,
    [5] = KFontTimesNormal8,
    [6] = KFontTimesNormal11,
    [7] = KFontTimesNormal13,
    [8] = KFontTimesNormal15,
    [9] = KFontArialNormal8,
    [10] = KFontArialNormal11,
    [11] = KFontArialNormal13,
    [12] = KFontArialNormal15,
    [13] = KFontTiny4,
    [0x9A] = KFontArialNormal15,
}

local GrayBppToMode = {
    [1] = KgCreate2GrayMode,
    [2] = KgCreate4GrayMode,
    [4] = KgCreate16GrayMode,
    [8] = KgCreate256GrayMode,
}

local ColorBppToMode = {
    [4] = KgCreate16ColorMode,
    [8] = KgCreate256ColorMode,
}    

function bppColorToMode(bpp, color)
    local result = (color and ColorBppToMode or GrayBppToMode)[bpp]
    if not result then
        error(string.format("Invalid bpp=%d color=%s combination", bpp, color))
    end
    return result
end

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
    local dir, name = path:match([[(.*[/\])(.*)$]])
    if not dir then
        return "", path
    else
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

local function abs(path, relativeTo)
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

function oplpath.abs(path, relativeTo)
    local result = abs(path, relativeTo)
    -- printf("ABS(%s, %s)->%s\n", path, relativeTo, result)
    return result
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

function readCardinality(data, pos)
    local val, pos = string.unpack("B", data, pos)
    if val & 1 == 0 then
        return val >> 1, pos
    elseif val & 2 == 0 then
        val = (val + (string.unpack("B", data, pos) << 8)) >> 2
        pos = pos + 1
    elseif val & 4 == 0 then
        local n = string.unpack("I3", data, pos)
        val = (val + (n << 8)) >> 3
        pos = pos + 3
    else
        error("Invalid TCardinality!")
    end
    return val, pos
end

function unimplemented(opName)
    error({ msg = "Unimplemented operation "..opName, unimplemented = opName })
end
