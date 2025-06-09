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

require("const")

KLineBreakStr = string.char(KLineBreak)
KParagraphDelimiterStr = string.char(KParagraphDelimiter)

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

json = {
    dictHintMetatable = {},
    null = function() error("json.null should never actually be called") end,
    encode = function(val) return dump(val, "json") end,
    Dict = function(tbl) return setmetatable(tbl, json.dictHintMetatable) end,
}

function printf(...)
    io.stdout:write(string.format(...))
end

function toint32(val)
    if val >= 0x80000000 then
        val = string.unpack("<i4", string.pack("<I4", val))
    end
    return val
end

function toint16(val)
    if val >= 0x8000 then
        val = string.unpack("<i2", string.pack("<I2", val))
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
KUidAppDllDoc8 = 0x1000006D -- generic uid2 for various apps (check uid3)
-- KUidOPO = 0x10000073 -- pre-unicode OPO uid2
KMultiBitmapRomImageUid = 0x10000041 -- uid1
KUidMultiBitmapFileImage = 0x10000042
KUidOplInterpreter = 0x10000168
KUidDirectFileStore = 0x10000037

KUidSisFileEr6 = 0x10003A12 -- ER6 SIS uid2, allegedly
KUidInstallApp = 0x10000419 -- SIS file uid3 (all versions)

KPermanentFileStoreLayoutUid = 0x10000050 -- DB file uid1
KUidOplFile = 0x1000008A -- DB file UID2
KUidTextEdApp = 0x10000085 -- OPL file UID3
KUidRecordApp = 0x1000007E -- WAV file UID3
KEikUidWordApp = 0x1000007F

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
    -- internal types, not actually used by OPL
    dSEPARATOR = 257,
    dEDITMULTI = 258,
    dFILECHOOSER = 259,
    dFILEEDIT = 260,
    dFILEFOLDER = 261,
    dFILEDISK = 262,
}

KDefaultFontUid = KFontArialNormal15

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

-- These aren't defined in the const.oph version we're using as our baseline
KColorgCreate64KColorMode = 0x0006
KColorgCreate16MColorMode = 0x0007
KColorgCreateRGBColorMode = 0x0008
KColorgCreate4KColorMode = 0x0009

local GrayBppToMode = {
    [1] = KColorgCreate2GrayMode,
    [2] = KColorgCreate4GrayMode,
    [4] = KColorgCreate16GrayMode,
    [8] = KColorgCreate256GrayMode,
}

local ColorBppToMode = {
    [4] = KColorgCreate16ColorMode,
    [8] = KColorgCreate256ColorMode,
    [12] = KColorgCreate4KColorMode,
    [16] = KColorgCreate64KColorMode,
    [24] = KColorgCreate16MColorMode,
    [32] = KColorgCreateRGBColorMode,
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
    local result = str:gsub(pattern, function(ch) return string.format("\\x%02X", ch:byte()) end)
    return result
end

function hexUnescape(str)
    return str:gsub("\\x(%x%x)", function(hexcode) return string.char(tonumber(hexcode, 16)) end)
end

local charCodeMap = {
    [KKeyPageLeft32] = KKeyPageLeft, -- Home
    [KKeyPageRight32] = KKeyPageRight, -- End
    [KKeyPageUp32] = KKeyPageUp, -- PgUp
    [KKeyPageDown32] = KKeyPageDown, -- PgDn
    [KKeyLeftArrow32] = KKeyLeftArrow, -- LeftArrow
    [KKeyRightArrow32] = KKeyRightArrow, -- RightArrow
    [KKeyUpArrow32] = KKeyUpArrow, -- UpArrow
    [KKeyDownArrow32] = KKeyDownArrow, -- DownArrow
    [KKeyMenu32] = KGetMenu, -- Menu (note different naming convention on charcode)
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

-- What https://frodo.looijaard.name/psifiles/Basic_Elements refers to as
-- "Special encoding"
function readSpecialEncoding(data, pos)
    local b, pos = string.unpack("B", data, pos)
    if b & 3 == 2 then
        -- Single byte
        return b >> 2, pos
    else
        assert(b & 7 == 6, "Bad variable length encoding!")
        local b2, pos = string.unpack("B", data, pos)
        return ((b >> 3) + (b2 << 8)) >> 3, pos
    end
end

function unimplemented(opName)
    error({ msg = "Unimplemented operation "..opName, unimplemented = opName })
end

function dump(...)
    require("init_dump")
    -- Will replace dump fn, so re-call the new fn
    return dump(...)
end

textReplacementsMatch = "[\x06\x07\x0a\x0b\x10]"

textReplacements = {
    [KParagraphDelimiterStr] = "\n\n",
    [KLineBreakStr] = "\n",
    [string.char(KNonBreakingSpace)] = " ", -- Close enough
    [string.char(KNonBreakingTab)] = "\t", -- Close enough
    [string.char(KNonBreakingHyphen)] = "-", -- Close enough
}
