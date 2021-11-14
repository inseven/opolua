_ENV = module()

local fns = require("fns")
local fmt = string.format

codes = {
    [0x00] = "SimpleDirectRightSideInt",
    [0x01] = "SimpleDirectRightSideLong",
    [0x02] = "SimpleDirectRightSideFloat",
    [0x03] = "SimpleDirectRightSideString",
    [0x04] = "SimpleDirectLeftSideInt",
    [0x05] = "SimpleDirectLeftSideLong",
    [0x06] = "SimpleDirectLeftSideFloat",
    [0x07] = "SimpleDirectLeftSideString",
    [0x08] = "SimpleInDirectRightSideInt",
    [0x09] = "SimpleInDirectRightSideLong",
    [0x0A] = "SimpleInDirectRightSideFloat",
    [0x0B] = "SimpleInDirectRightSideString",
    [0x0C] = "SimpleInDirectLeftSideInt",
    [0x0D] = "SimpleInDirectLeftSideLong",
    [0x0E] = "SimpleInDirectLeftSideFloat",
    [0x0F] = "SimpleInDirectLeftSideString",
    [0x10] = "ArrayDirectRightSideInt",
    [0x11] = "ArrayDirectRightSideLong",
    [0x12] = "ArrayDirectRightSideFloat",
    [0x13] = "ArrayDirectRightSideString",
    [0x14] = "ArrayDirectLeftSideInt",
    [0x15] = "ArrayDirectLeftSideLong",
    [0x16] = "ArrayDirectLeftSideFloat",
    [0x17] = "ArrayDirectLeftSideString",
    [0x18] = "ArrayInDirectRightSideInt",
    [0x19] = "ArrayInDirectRightSideLong",
    [0x1A] = "ArrayInDirectRightSideFloat",
    [0x1B] = "ArrayInDirectRightSideString",
    [0X1C] = "ArrayInDirectLeftSideInt",
    [0x1D] = "ArrayInDirectLeftSideLong",
    [0x1E] = "ArrayInDirectLeftSideFloat",
    [0x1F] = "ArrayInDirectLeftSideString",
    [0x20] = "FieldRightSideInt",
    [0x21] = "FieldRightSideLong",
    [0x22] = "FieldRightSideFloat",
    [0x23] = "FieldRightSideString",
    [0x24] = "FieldLeftSide",
    [0x25] = "FieldLeftSide",
    [0x26] = "FieldLeftSide",
    [0x27] = "FieldLeftSide",
    [0x28] = "ConstantInt",
    [0x29] = "ConstantLong",
    [0x2A] = "ConstantFloat",
    [0x2B] = "ConstantString",
    [0x2C] = "IllegalOpCode",
    [0x2D] = "IllegalOpCode",
    [0x2E] = "IllegalOpCode",
    [0x2F] = "IllegalOpCode",
    [0x30] = "CompareLessThanInt",
    [0x31] = "CompareLessThanLong",
    [0x32] = "CompareLessThanFloat",
    [0x33] = "CompareLessThanString",
    [0x34] = "CompareLessOrEqualInt",
    [0x35] = "CompareLessOrEqualLong",
    [0x36] = "CompareLessOrEqualFloat",
    [0x37] = "CompareLessOrEqualString",
    [0x38] = "CompareGreaterThanInt",
    [0x39] = "CompareGreaterThanLong",
    [0x3A] = "CompareGreaterThanFloat",
    [0x3B] = "CompareGreaterThanString",
    [0x3C] = "CompareGreaterOrEqualInt",
    [0x3D] = "CompareGreaterOrEqualLong",
    [0x3E] = "CompareGreaterOrEqualFloat",
    [0x3F] = "CompareGreaterOrEqualString",
    [0x40] = "CompareEqualInt",
    [0x41] = "CompareEqualLong",
    [0x42] = "CompareEqualFloat",
    [0x43] = "CompareEqualString",
    [0x44] = "CompareNotEqualInt",
    [0x45] = "CompareNotEqualLong",
    [0x46] = "CompareNotEqualFloat",
    [0x47] = "CompareNotEqualString",
    [0x48] = "AddInt",
    [0x49] = "AddLong",
    [0x4A] = "AddFloat",
    [0x4B] = "AddString",
    [0x4C] = "SubtractInt",
    [0x4D] = "SubtractLong",
    [0x4E] = "SubtractFloat",
    [0x4F] = "StackByteAsWord",
    [0x50] = "MultiplyInt",
    [0x51] = "MultiplyLong",
    [0x52] = "MultiplyFloat",
    [0x53] = "RunProcedure",
    [0x54] = "DivideInt",
    [0x55] = "DivideLong",
    [0x56] = "DivideFloat",
    [0x57] = "CallFunction",
    [0x58] = "PowerOfInt",
    [0x59] = "PowerOfLong",
    [0x5A] = "PowerOfFloat",
    [0x5B] = "BranchIfFalse",
    [0x5C] = "AndInt",
    [0x5D] = "AndLong",
    [0x5E] = "AndFloat",
    [0x5F] = "StackByteAsLong",
    [0x60] = "OrInt",
    [0x61] = "OrLong",
    [0x62] = "OrFloat",
    [0x63] = "StackWordAsLong",
    [0x64] = "NotInt",
    [0x65] = "NotLong",
    [0x66] = "NotFloat",
    [0x67] = "Statement16",
    [0x68] = "UnaryMinusInt",
    [0x69] = "UnaryMinusLong",
    [0x6A] = "UnaryMinusFloat",
    [0x6B] = "CallProcByStringExpr",
    [0x6C] = "PercentLessThan",
    [0x6D] = "PercentGreaterThan",
    [0x6E] = "PercentAdd",
    [0x6F] = "PercentSubtract",
    [0x70] = "PercentMultiply",
    [0x71] = "PercentDivide",
    [0x72] = "IllegalOpCode",
    [0x73] = "IllegalOpCode",
    [0x74] = "ZeroReturnInt",
    [0x75] = "ZeroReturnLong",
    [0x76] = "ZeroReturnFloat",
    [0x77] = "NullReturnString",
    [0x78] = "LongToInt",
    [0x79] = "FloatToInt",
    [0x7A] = "FloatToLong",
    [0x7B] = "IntToLong",
    [0x7C] = "IntToFloat",
    [0x7D] = "LongToFloat",
    [0x7E] = "LongToUInt",
    [0x7F] = "FloatToUInt",
    [0x80] = "DropInt",
    [0x81] = "DropLong",
    [0x82] = "DropFloat",
    [0x83] = "DropString",
    [0x84] = "AssignInt",
    [0x85] = "AssignLong",
    [0x86] = "AssignFloat",
    [0x87] = "AssignString",
    [0x88] = "PrintInt",
    [0x89] = "PrintLong",
    [0x8A] = "PrintFloat",
    [0x8B] = "PrintString",
    [0x8C] = "LPrintInt",
    [0x8D] = "LPrintLong",
    [0x8E] = "LPrintFloat",
    [0x8F] = "LPrintString",
    [0x90] = "PrintSpace",
    [0x91] = "LPrintSpace",
    [0x92] = "PrintCarriageReturn",
    [0x93] = "LPrintCarriageReturn",
    [0x94] = "InputInt",
    [0x95] = "InputLong",
    [0x96] = "InputFloat",
    [0x97] = "InputString",
    [0x98] = "PokeW",
    [0x99] = "PokeL",
    [0x9A] = "PokeD",
    [0x9B] = "PokeStr",
    [0x9C] = "PokeB",
    [0x9D] = "Append",
    [0x9E] = "At",
    [0x9F] = "Back",
    [0xA0] = "Beep",
    [0xA1] = "Close",
    [0xA2] = "Cls",
    [0xA3] = "IllegalOpCode",
    [0xA4] = "Copy",
    [0xA5] = "Create",
    [0xA6] = "Cursor",
    [0xA7] = "Delete",
    [0xA8] = "Erase",
    [0xA9] = "Escape",
    [0xAA] = "First",
    [0xAB] = "Vector",
    [0xAC] = "Last",
    [0xAD] = "LClose",
    [0xAE] = "LoadM",
    [0xAF] = "LOpen",
    [0xB0] = "Next",
    [0xB1] = "OnErr",
    [0xB2] = "Off",
    [0xB3] = "OffFor",
    [0xB4] = "Open",
    [0xB5] = "Pause",
    [0xB6] = "Position",
    [0xB7] = "IoSignal",
    [0xB8] = "Raise",
    [0xB9] = "Randomize",
    [0xBA] = "Rename",
    [0xBB] = "Stop",
    [0xBC] = "Trap",
    [0xBD] = "Update",
    [0xBE] = "Use",
    [0xBF] = "GoTo",
    [0xC0] = "Return",
    [0xC1] = "UnLoadM",
    [0xC2] = "Edit",
    [0xC3] = "Screen2",
    [0xC4] = "OpenR",
    [0xC5] = "gSaveBit",
    [0xC6] = "gClose",
    [0xC7] = "gUse",
    [0xC8] = "gSetWin",
    [0xC9] = "gVisible",
    [0xCA] = "gFont",
    [0xCB] = "gUnloadFont",
    [0xCC] = "gGMode",
    [0xCD] = "gTMode",
    [0xCE] = "gStyle",
    [0xCF] = "gOrder",
    [0xD0] = "IllegalOpCode",
    [0xD1] = "gCls",
    [0xD2] = "gAt",
    [0xD3] = "gMove",
    [0xD4] = "gPrintWord",
    [0xD5] = "gPrintLong",
    [0xD6] = "gPrintDbl",
    [0xD7] = "gPrintStr",
    [0xD8] = "gPrintSpace",
    [0xD9] = "gPrintBoxText",
    [0xDA] = "gLineBy",
    [0xDB] = "gBox",
    [0xDC] = "gCircle",
    [0xDD] = "gEllipse",
    [0xDE] = "gPoly",
    [0xDF] = "gFill",
    [0xE0] = "gPatt",
    [0xE1] = "gCopy",
    [0xE2] = "gScroll",
    [0xE3] = "gUpdate",
    [0xE4] = "GetEvent",
    [0xE5] = "gLineTo",
    [0xE6] = "gPeekLine",
    [0xE7] = "Screen4",
    [0xE8] = "IoWaitStat",
    [0xE9] = "IoYield",
    [0xEA] = "mInit",
    [0xEB] = "mCard",
    [0xEC] = "dInit",
    [0xED] = "dItem",
    [0xEE] = "IllegalOpCode",
    [0xEF] = "IllegalOpCode",
    [0xF0] = "Busy",
    [0xF1] = "Lock",
    [0xF2] = "gInvert",
    [0xF3] = "gXPrint",
    [0xF4] = "gBorder",
    [0xF5] = "gClock",
    [0xF6] = "IllegalOpCode",
    [0xF7] = "IllegalOpCode",
    [0xF8] = "MkDir",
    [0xF9] = "RmDir",
    [0xFA] = "SetPath",
    [0xFB] = "SecsToDate",
    [0xFC] = "gIPrint",
    [0xFD] = "IllegalOpCode",
    [0xFE] = "IllegalOpCode",
    [0xFF] = "NextOpcodeTable",
    [0x100] = "gGrey",
    [0x101] = "DefaultWin",
    [0x102] = "IllegalOpCode",
    [0x103] = "IllegalOpCode",
    [0x104] = "Font",
    [0x105] = "Style",
    [0x106] = "IllegalOpCode",
    [0x107] = "IllegalOpCode",
    [0x108] = "IllegalOpCode",
    [0x109] = "IllegalOpCode",
    [0x10A] = "IllegalOpCode",
    [0x10B] = "IllegalOpCode",
    [0x10C] = "FreeAlloc",
    [0x10D] = "IllegalOpCode",
    [0x10E] = "IllegalOpCode",
    [0x10F] = "gButton",
    [0x110] = "gXBorder",
    [0x111] = "IllegalOpCode",
    [0x112] = "IllegalOpCode",
    [0x113] = "IllegalOpCode",
    [0x114] = "ScreenInfo",
    [0x115] = "IllegalOpCode",
    [0x116] = "IllegalOpCode",
    [0x117] = "IllegalOpCode",
    [0x118] = "CallOpxFunc",
    [0x119] = "Statement32",
    [0x11A] = "Modify",
    [0x11B] = "Insert",
    [0x11C] = "Cancel",
    [0x11D] = "Put",
    [0x11E] = "DeleteTable",
    [0x11F] = "GotoMark",
    [0x120] = "KillMark",
    [0x121] = "ReturnFromEval",
    [0x122] = "GetEvent32",
    [0x123] = "GetEventA32",
    [0x124] = "gColor",
    [0x125] = "SetFlags",
    [0x126] = "SetDoc",
    [0x127] = "DaysToDate",
    [0x128] = "gInfo32",
    [0x129] = "IoWaitStat32",
    [0x12A] = "Compact",
    [0x12B] = "BeginTrans",
    [0x12C] = "CommitTrans",
    [0x12D] = "Rollback",
    [0x12E] = "ClearFlags",
    [0x12F] = "PointerFilter",
    [0x130] = "mCasc",
    [0x131] = "EvalExternalRightSideRef",
    [0x132] = "EvalExternalLeftSideRef",
    [0x133] = "gSetPenWidth",
    [0x134] = "dEditMulti",
    [0x135] = "gColorInfo",
    [0x136] = "gColorBackground",
    [0x137] = "mCardX",
    [0x138] = "SetHelp",
    [0x139] = "ShowHelp",
    [0x13A] = "SetHelpUid",
    [0x13B] = "gXBorder32",
    [0x13C] = "IllegalOpCode",
    [0x13D] = "IllegalOpCode",
    [0x13E] = "IllegalOpCode",
    [0x13F] = "IllegalOpCode",
    [0x140] = "IllegalOpCode",
    [0x141] = "IllegalOpCode",
    [0x142] = "IllegalOpCode",
    [0x143] = "IllegalOpCode",
    [0x144] = "IllegalOpCode",
    [0x145] = "IllegalOpCode",
    [0x146] = "IllegalOpCode",
    [0x147] = "IllegalOpCode",
    [0x148] = "IllegalOpCode",
    [0x149] = "IllegalOpCode",
    [0x14A] = "IllegalOpCode",
    [0x14B] = "IllegalOpCode",
    [0x14C] = "IllegalOpCode",
    [0x14D] = "IllegalOpCode",
    [0x14E] = "IllegalOpCode",
    [0x14F] = "IllegalOpCode",
    [0x150] = "IllegalOpCode",
    [0x151] = "IllegalOpCode",
    [0x152] = "IllegalOpCode",
    [0x153] = "IllegalOpCode",
    [0x154] = "IllegalOpCode",
    [0x155] = "IllegalOpCode",
    [0x156] = "IllegalOpCode",
    [0x157] = "IllegalOpCode",
    [0x158] = "IllegalOpCode",
    [0x159] = "IllegalOpCode",
    [0x15A] = "IllegalOpCode",
    [0x15B] = "IllegalOpCode",
    [0x15C] = "IllegalOpCode",
    [0x15D] = "IllegalOpCode",
    [0x15E] = "IllegalOpCode",
    [0x15F] = "IllegalOpCode",
    [0x160] = "IllegalOpCode",
    [0x161] = "IllegalOpCode",
    [0x162] = "IllegalOpCode",
    [0x163] = "IllegalOpCode",
    [0x164] = "IllegalOpCode",
    [0x165] = "IllegalOpCode",
    [0x166] = "IllegalOpCode",
    [0x167] = "IllegalOpCode",
    [0x168] = "IllegalOpCode",
    [0x169] = "IllegalOpCode",
    [0x16A] = "IllegalOpCode",
    [0x16B] = "IllegalOpCode",
    [0x16C] = "IllegalOpCode",
    [0x16D] = "IllegalOpCode",
    [0x16E] = "IllegalOpCode",
    [0x16F] = "IllegalOpCode",
    [0x170] = "IllegalOpCode",
    [0x171] = "IllegalOpCode",
    [0x172] = "IllegalOpCode",
    [0x173] = "IllegalOpCode",
    [0x174] = "IllegalOpCode",
    [0x175] = "IllegalOpCode",
    [0x176] = "IllegalOpCode",
    [0x177] = "IllegalOpCode",
    [0x178] = "IllegalOpCode",
    [0x179] = "IllegalOpCode",
    [0x17A] = "IllegalOpCode",
    [0x17B] = "IllegalOpCode",
    [0x17C] = "IllegalOpCode",
    [0x17D] = "IllegalOpCode",
    [0x17E] = "IllegalOpCode",
    [0x17F] = "IllegalOpCode",
    [0x180] = "IllegalOpCode",
    [0x181] = "IllegalOpCode",
    [0x182] = "IllegalOpCode",
    [0x183] = "IllegalOpCode",
    [0x184] = "IllegalOpCode",
    [0x185] = "IllegalOpCode",
    [0x186] = "IllegalOpCode",
    [0x187] = "IllegalOpCode",
    [0x188] = "IllegalOpCode",
    [0x189] = "IllegalOpCode",
    [0x18A] = "IllegalOpCode",
    [0x18B] = "IllegalOpCode",
    [0x18C] = "IllegalOpCode",
    [0x18D] = "IllegalOpCode",
    [0x18E] = "IllegalOpCode",
    [0x18F] = "IllegalOpCode",
    [0x190] = "IllegalOpCode",
    [0x191] = "IllegalOpCode",
    [0x192] = "IllegalOpCode",
    [0x193] = "IllegalOpCode",
    [0x194] = "IllegalOpCode",
    [0x195] = "IllegalOpCode",
    [0x196] = "IllegalOpCode",
    [0x197] = "IllegalOpCode",
    [0x198] = "IllegalOpCode",
    [0x199] = "IllegalOpCode",
    [0x19A] = "IllegalOpCode",
    [0x19B] = "IllegalOpCode",
    [0x19C] = "IllegalOpCode",
    [0x19D] = "IllegalOpCode",
    [0x19E] = "IllegalOpCode",
    [0x19F] = "IllegalOpCode",
    [0x1A0] = "IllegalOpCode",
    [0x1A1] = "IllegalOpCode",
    [0x1A2] = "IllegalOpCode",
    [0x1A3] = "IllegalOpCode",
    [0x1A4] = "IllegalOpCode",
    [0x1A5] = "IllegalOpCode",
    [0x1A6] = "IllegalOpCode",
    [0x1A7] = "IllegalOpCode",
    [0x1A8] = "IllegalOpCode",
    [0x1A9] = "IllegalOpCode",
    [0x1AA] = "IllegalOpCode",
    [0x1AB] = "IllegalOpCode",
    [0x1AC] = "IllegalOpCode",
    [0x1AD] = "IllegalOpCode",
    [0x1AE] = "IllegalOpCode",
    [0x1AF] = "IllegalOpCode",
    [0x1B0] = "IllegalOpCode",
    [0x1B1] = "IllegalOpCode",
    [0x1B2] = "IllegalOpCode",
    [0x1B3] = "IllegalOpCode",
    [0x1B4] = "IllegalOpCode",
    [0x1B5] = "IllegalOpCode",
    [0x1B6] = "IllegalOpCode",
    [0x1B7] = "IllegalOpCode",
    [0x1B8] = "IllegalOpCode",
    [0x1B9] = "IllegalOpCode",
    [0x1BA] = "IllegalOpCode",
    [0x1BB] = "IllegalOpCode",
    [0x1BC] = "IllegalOpCode",
    [0x1BD] = "IllegalOpCode",
    [0x1BE] = "IllegalOpCode",
    [0x1BF] = "IllegalOpCode",
    [0x1C0] = "IllegalOpCode",
    [0x1C1] = "IllegalOpCode",
    [0x1C2] = "IllegalOpCode",
    [0x1C3] = "IllegalOpCode",
    [0x1C4] = "IllegalOpCode",
    [0x1C5] = "IllegalOpCode",
    [0x1C6] = "IllegalOpCode",
    [0x1C7] = "IllegalOpCode",
    [0x1C8] = "IllegalOpCode",
    [0x1C9] = "IllegalOpCode",
    [0x1CA] = "IllegalOpCode",
    [0x1CB] = "IllegalOpCode",
    [0x1CC] = "IllegalOpCode",
    [0x1CD] = "IllegalOpCode",
    [0x1CE] = "IllegalOpCode",
    [0x1CF] = "IllegalOpCode",
    [0x1D0] = "IllegalOpCode",
    [0x1D1] = "IllegalOpCode",
    [0x1D2] = "IllegalOpCode",
    [0x1D3] = "IllegalOpCode",
    [0x1D4] = "IllegalOpCode",
    [0x1D5] = "IllegalOpCode",
    [0x1D6] = "IllegalOpCode",
    [0x1D7] = "IllegalOpCode",
    [0x1D8] = "IllegalOpCode",
    [0x1D9] = "IllegalOpCode",
    [0x1DA] = "IllegalOpCode",
    [0x1DB] = "IllegalOpCode",
    [0x1DC] = "IllegalOpCode",
    [0x1DD] = "IllegalOpCode",
    [0x1DE] = "IllegalOpCode",
    [0x1DF] = "IllegalOpCode",
    [0x1E0] = "IllegalOpCode",
    [0x1E1] = "IllegalOpCode",
    [0x1E2] = "IllegalOpCode",
    [0x1E3] = "IllegalOpCode",
    [0x1E4] = "IllegalOpCode",
    [0x1E5] = "IllegalOpCode",
    [0x1E6] = "IllegalOpCode",
    [0x1E7] = "IllegalOpCode",
    [0x1E8] = "IllegalOpCode",
    [0x1E9] = "IllegalOpCode",
    [0x1EA] = "IllegalOpCode",
    [0x1EB] = "IllegalOpCode",
    [0x1EC] = "IllegalOpCode",
    [0x1ED] = "IllegalOpCode",
    [0x1EE] = "IllegalOpCode",
    [0x1EF] = "IllegalOpCode",
    [0x1F0] = "IllegalOpCode",
    [0x1F1] = "IllegalOpCode",
    [0x1F2] = "IllegalOpCode",
    [0x1F3] = "IllegalOpCode",
    [0x1F4] = "IllegalOpCode",
    [0x1F5] = "IllegalOpCode",
    [0x1F6] = "IllegalOpCode",
    [0x1F7] = "IllegalOpCode",
    [0x1F8] = "IllegalOpCode",
    [0x1F9] = "IllegalOpCode",
    [0x1FA] = "IllegalOpCode",
    [0x1FB] = "IllegalOpCode",
    [0x1FC] = "IllegalOpCode",
    [0x1FD] = "IllegalOpCode",
    [0x1FE] = "IllegalOpCode",
    [0x1FF] = "IllegalOpCode",
}

function IllegalOpCode(stack)
    if stack then
        error("IllegalOpCode")
    end
end

function SimpleDirectRightSideInt(stack, runtime)
    local index = runtime:ipWord()
    if stack then
        -- TODO
    else
        return fmt("0x%04X", index)
    end
end

function SimpleDirectLeftSideInt(stack, runtime)
    local index = runtime:ipWord()
    if stack then
        -- TODO
    else
        return fmt("0x%04X", index)
    end
end

function SimpleInDirectRightSideInt(stack, runtime)
    local index = runtime:ipWord()
    if stack then
        -- TODO
    else
        return fmt("0x%04X", index)
    end
end

function SimpleInDirectRightSideLong(stack, runtime)
    local index = runtime:ipWord()
    if stack then
        -- TODO
    else
        return fmt("0x%04X", index)
    end
end

function SimpleInDirectRightSideString(stack, runtime)
    local index = runtime:ipWord()
    if stack then
        -- TODO
    else
        return fmt("0x%04X", index)
    end
end

function ConstantString(stack, runtime)
    local str = runtime:ipString()
    if stack then
        stack:push(str)
    else
        return fmt("'%s'", str)
    end
end

function CompareGreaterThanLong(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left > right)
    end
end

function AddInt(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left + right)
    end
end

function AddLong(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left + right)
    end
end

function AddFloat(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left + right)
    end
end

function StackByteAsWord(stack, runtime)
    local val = runtime:ipByte()
    if stack then
        stack:push(val)
    else
        return fmt("%d (0x%02X)", val, val)
    end
end

function RunProcedure(stack, runtime, frame)
    local procIdx = runtime:ipWord()
    local name, numParams
    for _, subproc in ipairs(frame.proc.subprocs) do
        if subproc.offset == procIdx then
            name = subproc.name
            numParams = subproc.numParams
            break
        end
    end

    if stack then
        assert(name, "Subproc not found for index "..tostring(procIdx))
        local proc = runtime:findProc(name)
        runtime:newFrame(stack, proc)
    else
        return fmt("idx=0x%04X name=%s nargs=%s", procIdx, name or "?", tostring(numParams or "?"))
    end
end

function CallFunction(stack, runtime, frame)
    local fnIdx = runtime:ipByte()
    local fnName = fns.codes[fnIdx]
    if stack then
        local fn = assert(fns[fnName], "Function "..fnName.. " not implemented!")
        fn(stack, runtime, frame)
    else
        return fmt("idx=0x%02X %s()", fnIdx, fnName or "?")
    end
end

function BranchIfFalse(stack, runtime)
    local ip = runtime.ip - 1 -- Because ip points to just after us
    local relJmp = runtime:ipWord()
    if stack then
        if not stack:popBoolean() then
            runtime:relJmp(relJmp)
        end
    else
        return fmt("%d (->0x%08X)", relJmp, ip + relJmp)
    end
end

function StackByteAsLong(stack, runtime)
    local val = runtime:ipByte()
    if stack then
        stack:push(val)
    else
        return fmt("%d (0x%02X)", val, val)
    end
end

function ZeroReturnFloat(stack, runtime, frame)
    if stack then
        runtime:returnFromFrame(stack, 0.0)
    end
end

function IntToLong()
    -- Nothing needed
end

function DropInt(stack)
    if stack then
        stack:pop()
    end
end

function DropFloat(stack)
    if stack then
        stack:pop()
    end
end

function DropString(stack)
    if stack then
        stack:popString()
    end
end

function AssignInt(stack, runtime)
    if stack then
        --TODO
    end
end

function PrintInt(stack)
    if stack then
        printf("%d", stack:pop())
    end
end

function PrintLong(stack)
    if stack then
        printf("%d", stack:pop())
    end
end

function PrintString(stack)
    if stack then
        printf("%s", stack:popString())
    end
end

function PrintSpace(stack)
    if stack then
        printf(" ")
    end
end

function PrintCarriageReturn(stack)
    if stack then
        printf("\n")
    end
end

function Return(stack, runtime, frame)
    if stack then
        local val = stack:pop()
        runtime:returnFromFrame(val)
    end
end

return _ENV
