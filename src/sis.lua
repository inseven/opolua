--[[

Copyright (c) 2021 Jason Morley, Tom Sutcliffe

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

Options = enum {
    IsUnicode = 0x1
}

FileRecordType = enum {
    SimpleFileRecord = 0,
    MultiLangRecord = 1,
    OptionsRecord = 2,
    IfRecord = 3,
    ElseIfRecord = 4,
    ElseRecord = 5,
    EndIfRecord = 6,
}

FileType = enum {
    File = 0,
    FileText = 1,
    SisComponent = 2,
    FileRun = 3,
    FileNull = 4,
    FileMime = 5,
}

function parseSisFile(data, verbose)
    local uid1, uid2, uid3, uid4, checksum, nLangs, nFiles, pos = string.unpack("<I4I4I4I4I2I2I2", data)
    if verbose then
        printf("nLangs=%d nFiles=%d\n", nLangs, nFiles)
    end

    local nReq, lang, instFiles, instDrv, nCaps, instVer, pos = string.unpack("<I2I2I2I2I2I4", data, pos)
    if verbose then
        printf("nReq=%d lang=%d instFiles=%d instDrv=%d nCaps=%d instVer=0x%08X\n",
            nReq, lang, instFiles, instDrv, nCaps, instVer)
    end

    assert(instVer == 0x64, "Only ER5 SIS files are supported")

    local options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr, pos =
        string.unpack("<I2I2I2I2I4I4I4I4", data, pos)
    if verbose then
        printf("options=%d type=%d verMaj=%d verMin=%d variant=%d langPtr=0x%08X filesPtr=0x%08X reqPtr=0x%08X\n",
            options, type, verMaj, verMin, variant, langPtr, filesPtr, reqPtr)
    end

    assert(options & Options.IsUnicode == 0, "ER5U not supported!")

    local result = {
        files = {},
    }
    pos = 1 + filesPtr
    for i = 1, nFiles do
        local recordType, file
        recordType, pos = string.unpack("<I4", data, pos)
        if recordType == FileRecordType.SimpleFileRecord then
            file, pos = parseSimpleFileRecord(data, pos, 1, verbose)
        elseif recordType == FileRecordType.MultiLangRecord then
            file, pos = parseSimpleFileRecord(data, pos, nLangs, verbose)
        else
            error("Unknown record type "..tostring(recordType))
        end
        result.files[i] = file
    end
    return result
end

function parseSimpleFileRecord(data, pos, numLangs, verbose)
    assert(numLangs == 1, "Multiple lang support not done yet!")
    local type, details, srcNameLen, srcNamePtr, destNameLen, destNamePtr, pos =
        string.unpack("<I4I4I4I4I4I4", data, pos)

    local contents = {}
    for i = 1, numLangs do
        local len
        len, pos = string.unpack("<I4", data, pos)
        contents[i] = { len = len }
    end
    for i = 1, numLangs do
        local ptr
        ptr, pos = string.unpack("<I4", data, pos)
        contents[i].ptr = ptr
    end

    -- , fileLen, filePtr
    if verbose then
        printf("type=%d details=%d srcNameLen=%d srcNamePtr=0x%08X destNameLen=%d destNamePtr=0x%08X fileLen=%d filePtr=0x%08X\n",
            type, details, srcNameLen, srcNamePtr, destNameLen, destNamePtr, fileLen, filePtr)
    end
    -- local srcName = data:sub(1 + srcNamePtr, srcNamePtr + srcNameLen)
    local destName = data:sub(1 + destNamePtr, destNamePtr + destNameLen)
    local file = {
        type = type,
        -- src = srcName,
        dest = destName,
    }

    if type ~= FileRecordType.FileNull then
        file.data = data:sub(1 + filePtr, filePtr + fileLen)
    end
    if type == FileRecordType.FileText then
        file.details = details
    end

    return file, pos
end

return _ENV
