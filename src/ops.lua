_ENV = module()

local fns = require("fns")
local fmt = string.format
local Word, Long, Real, String = DataTypes.EWord, DataTypes.ELong, DataTypes.EReal, DataTypes.EString
local WordArray, LongArray, RealArray, StringArray = DataTypes.EWordArray, DataTypes.ELongArray, DataTypes.ERealArray, DataTypes.EStringArray

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
    [0x133] = "dEditCheckbox", -- In 6.0 this opcode has actually been REDEFINED to gSetPenWidth
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
        error(KOplErrIllegal)
    end
end

--[[
xxRightSide<TYPE> means basically push the value onto the stack, the name I
assume coming from the fact that this is what you'd call when the value
appears on the right hand side of an assignment operation.

xxLeftSide<TYPE> means push a reference of some sort to the variable, such
that a subsequent Assign<TYPE> call can assign to it.

We aren't concerned with database fields or type checking so we simplify the
stack usage considerably from what COplRuntime does.
]]

local function leftSide(stack, runtime, type, indirect)
    local index = runtime:IP16()
    if stack then
        local var = runtime:getVar(index, type, indirect)
        if isArrayType(type) then
            local pos = stack:pop()
            var = var()[pos]
        end
        stack:push(var)
    else
        return fmt("0x%04X", index)
    end
end

local function rightSide(stack, runtime, type, indirect)
    if stack then
        leftSide(stack, runtime, type, indirect)
        stack:push(stack:pop()())
    else
        return fmt("0x%04X", runtime:IP16())
    end
end

function SimpleDirectRightSideInt(stack, runtime) -- 0x00
    return rightSide(stack, runtime, Word, false)
end

function SimpleDirectRightSideLong(stack, runtime) -- 0x01
    return rightSide(stack, runtime, Long, false)
end

function SimpleDirectRightSideFloat(stack, runtime) -- 0x02
    return rightSide(stack, runtime, Real, false)
end

function SimpleDirectRightSideString(stack, runtime) -- 0x03
    return rightSide(stack, runtime, String, false)
end

function SimpleDirectLeftSideInt(stack, runtime) -- 0x04
    return leftSide(stack, runtime, Word, false)
end

function SimpleDirectLeftSideLong(stack, runtime) -- 0x05
    return leftSide(stack, runtime, Long, false)
end

function SimpleDirectLeftSideFloat(stack, runtime) -- 0x06
    return leftSide(stack, runtime, Real, false)
end

function SimpleDirectLeftSideString(stack, runtime) -- 0x07
    return leftSide(stack, runtime, String, false)
end

function SimpleInDirectRightSideInt(stack, runtime) -- 0x08
    return rightSide(stack, runtime, Word, true)
end

function SimpleInDirectRightSideLong(stack, runtime) -- 0x09
    return rightSide(stack, runtime, Long, true)
end

function SimpleInDirectRightSideFloat(stack, runtime) -- 0x0A
    return rightSide(stack, runtime, Real, true)
end

function SimpleInDirectRightSideString(stack, runtime) -- 0x0B
    return rightSide(stack, runtime, String, true)
end

function SimpleInDirectLeftSideInt(stack, runtime) -- 0x0C
    return leftSide(stack, runtime, Word, true)
end

function SimpleInDirectLeftSideLong(stack, runtime) -- 0x0D
    return leftSide(stack, runtime, Long, true)
end

function SimpleInDirectLeftSideFloat(stack, runtime) -- 0x0E
    return leftSide(stack, runtime, Real, true)
end

function SimpleInDirectLeftSideString(stack, runtime) -- 0x0F
    return leftSide(stack, runtime, String, true)
end

function ArrayDirectRightSideInt(stack, runtime) -- 0x10
    return rightSide(stack, runtime, WordArray, false)
end

function ArrayDirectRightSideLong(stack, runtime) -- 0x11
    return rightSide(stack, runtime, LongArray, false)
end

function ArrayDirectRightSideFloat(stack, runtime) -- 0x12
    return rightSide(stack, runtime, RealArray, false)
end

function ArrayDirectRightSideString(stack, runtime) -- 0x13
    return rightSide(stack, runtime, StringArray, false)
end

function ArrayDirectLeftSideInt(stack, runtime) -- 0x14
    return leftSide(stack, runtime, WordArray, false)
end

function ArrayDirectLeftSideLong(stack, runtime) -- 0x15
    return leftSide(stack, runtime, LongArray, false)
end

function ArrayDirectLeftSideFloat(stack, runtime) -- 0x16
    return leftSide(stack, runtime, RealArray, false)
end

function ArrayDirectLeftSideString(stack, runtime) -- 0x17
    return leftSide(stack, runtime, StringArray, false)
end

function ArrayInDirectRightSideInt(stack, runtime) -- 0x18
    return rightSide(stack, runtime, WordArray, true)
end

function ArrayInDirectRightSideLong(stack, runtime) -- 0x19
    return rightSide(stack, runtime, LongArray, true)
end

function ArrayInDirectRightSideFloat(stack, runtime) -- 0x1A
    return rightSide(stack, runtime, RealArray, true)
end

function ArrayInDirectRightSideString(stack, runtime) -- 0x1B
    return rightSide(stack, runtime, StringArray, true)
end

function ArrayInDirectLeftSideInt(stack, runtime) -- 0x1C
    return leftSide(stack, runtime, WordArray, true)
end

function ArrayInDirectLeftSideLong(stack, runtime) -- 0x1D
    return leftSide(stack, runtime, LongArray, true)
end

function ArrayInDirectLeftSideFloat(stack, runtime) -- 0x1E
    return leftSide(stack, runtime, RealArray, true)
end

function ArrayInDirectLeftSideString(stack, runtime) -- 0x1F
    return leftSide(stack, runtime, StringArray, true)
end

function ConstantInt(stack, runtime) -- 0x28
    local val = runtime:IPs16()
    if stack then
        stack:push(val)
    else
        return fmt("%d", val)
    end
end

function ConstantLong(stack, runtime) -- 0x29
    local val = runtime:IPs32()
    if stack then
        stack:push(val)
    else
        return fmt("%d", val)
    end
end

function ConstantFloat(stack, runtime) -- 0x2A
    local val = runtime:IPReal()
    if stack then
        stack:push(val)
    else
        return fmt("%g", val)
    end
end

function ConstantString(stack, runtime) -- 0x2B
    local str = runtime:ipString()
    if stack then
        stack:push(str)
    else
        return fmt('"%s"', str)
    end
end

function CompareLessThanUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left < right)
    end
end

CompareLessThanInt = CompareLessThanUntyped -- 0x30
CompareLessThanLong = CompareLessThanUntyped -- 0x31
CompareLessThanFloat = CompareLessThanUntyped -- 0x32
CompareLessThanString = CompareLessThanUntyped -- 0x33

function CompareLessOrEqualUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left <= right)
    end
end

CompareLessOrEqualInt = CompareLessOrEqualUntyped -- 0x34
CompareLessOrEqualLong = CompareLessOrEqualUntyped -- 0x35
CompareLessOrEqualFloat = CompareLessOrEqualUntyped -- 0x36
CompareLessOrEqualString = CompareLessOrEqualUntyped -- 0x37

function CompareGreaterThanUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left > right)
    end
end

CompareGreaterThanInt = CompareGreaterThanUntyped -- 0x38
CompareGreaterThanLong = CompareGreaterThanUntyped -- 0x39
CompareGreaterThanFloat = CompareGreaterThanUntyped -- 0x3A
CompareGreaterThanString = CompareGreaterThanUntyped -- 0x3B

function CompareGreaterOrEqualUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left >= right)
    end
end

CompareGreaterOrEqualInt = CompareGreaterOrEqualUntyped -- 0x3C
CompareGreaterOrEqualLong = CompareGreaterOrEqualUntyped -- 0x3D
CompareGreaterOrEqualFloat = CompareGreaterOrEqualUntyped -- 0x3E
CompareGreaterOrEqualString = CompareGreaterOrEqualUntyped -- 0x3F

function CompareEqualUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left == right)
    end
end

CompareEqualInt = CompareEqualUntyped -- 0x40
CompareEqualLong = CompareEqualUntyped -- 0x41
CompareEqualFloat = CompareEqualUntyped -- 0x42
CompareEqualString = CompareEqualUntyped -- 0x43

function CompareNotEqualUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left ~= right)
    end
end

CompareNotEqualInt = CompareNotEqualUntyped -- 0x44
CompareNotEqualLong = CompareNotEqualUntyped -- 0x45
CompareNotEqualFloat = CompareNotEqualUntyped -- 0x46
CompareNotEqualString = CompareNotEqualUntyped -- 0x47

function AddUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left + right)
    end
end

AddInt = AddUntyped -- 0x48
AddLong = AddUntyped -- 0x49
AddFloat = AddUntyped -- 0x4A

function AddString(stack) -- 0x4B
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left .. right)
    end
end

function SubtractUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left - right)
    end
end

SubtractInt = SubtractUntyped -- 0x4C
SubtractLong = SubtractUntyped -- 0x4D
SubtractFloat = SubtractUntyped -- 0x4E

function StackByteAsWord(stack, runtime) -- 0x4F
    local val = runtime:IPs8()
    if stack then
        stack:push(val)
    else
        return fmt("%d (0x%02X)", val, val)
    end
end

function MultiplyUntyped(stack)
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left * right)
    end
end

MultiplyInt = MultiplyUntyped -- 0x50
MultiplyLong = MultiplyUntyped -- 0x51
MultiplyFloat = MultiplyUntyped -- 0x52

function RunProcedure(stack, runtime) -- 0x53
    local procIdx = runtime:IP16()
    local name, numParams
    local proc = runtime:currentProc()
    for _, subproc in ipairs(proc.subprocs) do
        if subproc.offset == procIdx then
            name = subproc.name
            numParams = subproc.numParams
            break
        end
    end

    if stack then
        assert(name, "Subproc not found for index "..tostring(procIdx))
        local proc = runtime:findProc(name)
        assert(#proc.params == numParams, "Wrong number of arguments for proc "..name)
        runtime:pushNewFrame(stack, proc)
    else
        return fmt('0x%04X (name="%s" nargs=%s)', procIdx, name or "?", tostring(numParams or "?"))
    end
end

function DivideInt(stack) -- 0x54
    if stack then
        local denominator = stack:pop()
        if denominator == 0 then
            error(KOplErrDivideByZero)
        end
        stack:push(stack:pop() // denominator)
    end
end

DivideLong = DivideInt -- 0x55

function DivideFloat(stack) -- 0x56
    if stack then
        local denominator = stack:pop()
        if denominator == 0 then
            error(KOplErrDivideByZero)
        end
        stack:push(stack:pop() / denominator)
    end
end

function CallFunction(stack, runtime) -- 0x57
    local fnIdx = runtime:IP8()
    local fnName = fns.codes[fnIdx]
    local fn = assert(fns[fnName], "Function "..fnName.. " not implemented!")
    if stack then
        fn(stack, runtime)
    else
        return fmt("0x%02X (%s)%s", fnIdx, fnName, fn(nil, runtime) or "")
    end
end

function PowerOfUntyped(stack)
    if stack then
        local powerOf = stack:pop()
        local number = stack:pop()
        if powerOf <= 0 and number == 0 then
            -- No infs here thank you very much
            error(KOplErrInvalidArgs)
        end
        stack:push(number ^ powerOf)
    end
end

PowerOfInt = PowerOfUntyped -- 0x58
PowerOfLong = PowerOfUntyped -- 0x59
PowerOfFloat = PowerOfUntyped -- 0x5A

function BranchIfFalse(stack, runtime) -- 0x5B
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    if stack then
        if stack:pop() == 0 then
            runtime:setIp(ip + relJmp)
        end
    else
        return fmt("%d (->0x%08X)", relJmp, ip + relJmp)
    end
end

function AndInt(stack) -- 0x5C
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left & right)
    end
end

AndLong = AndInt -- 0x5D

function AndFloat(stack) -- 0x5E
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        -- Weird one, this
        stack:push((left ~= 0) and (right ~= 0))
    end
end

StackByteAsLong = StackByteAsWord -- 0x5F

function OrInt(stack) -- 0x60
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push(left | right)
    end
end

OrLong = OrInt -- 0x61

function OrFloat(stack) -- 0x62
    if stack then
        local right = stack:pop()
        local left = stack:pop()
        stack:push((left ~= 0) or (right ~= 0))
    end
end

function StackWordAsLong(stack, runtime) -- 0x63
    local val = runtime:IPs16()
    if stack then
        stack:push(val)
    else
        return fmt("%d (0x%04X)", val, val)
    end
end

function NotInt(stack) -- 0x64
    if stack then
        stack:push(~stack:pop())
    end
end

NotLong = NotInt -- 0x65

function NotFloat(stack) -- 0x66
    if stack then
        stack:push(stack:pop() ~= 0)
    end
end

function OplDebug(pos)
    printf("Statement number %d\n", pos)
end

function Statement16(stack, runtime) -- 0x67
    local pos = runtime:IP16()
    if stack then
        OplDebug(pos)
    else
        return fmt("%d", pos)
    end
end

function UnaryMinusUntyped(stack)
    if stack then
        stack:push(-stack:pop())
    end
end

UnaryMinusInt = UnaryMinusUntyped -- 0x68
UnaryMinusLong = UnaryMinusUntyped -- 0x69
UnaryMinusFloat = UnaryMinusUntyped -- 0x6A

function CallProcByStringExpr(stack, runtime) -- 0x6B
    local numParams = runtime:IP8()
    local type = runtime:IP8()
    if stack then
        local procName = stack:remove(stack:getSize() - numParams*2)
        local proc = runtime:findProc(procName:upper())
        assert(#proc.params == numParams, "Wrong number of arguments for proc "..procName)
        runtime:pushNewFrame(stack, proc)
    else
        return fmt("nargs=%d type=%s", numParams, type)
    end
end

function ZeroReturn(stack, runtime)
    if stack then
        runtime:returnFromFrame(stack, 0)
    end
end

ZeroReturnInt = ZeroReturn -- 0x74
ZeroReturnLong = ZeroReturn -- 0x75
ZeroReturnFloat = ZeroReturn -- 0x76

function NullReturnString(stack, runtime) -- 0x77
    if stack then
        runtime:returnFromFrame(stack, "")
    end
end

function NoOp()
end

LongToInt = NoOp -- 0x78

function FloatToInt(stack, runtime) -- 0x79
    return fns.IntLong(stack, runtime) -- no idea why these are duplicated
end

FloatToLong = FloatToInt -- 0x7A

IntToLong = NoOp -- 0x7B
IntToFloat = NoOp -- 0x7C
LongToFloat = NoOp -- 0x7D
LongToUInt = NoOp -- 0x7E
FloatToUInt = NoOp -- 0x7F

function DropUntyped(stack)
    if stack then
        stack:pop()
    end
end

DropInt = DropUntyped -- 0x80
DropLong = DropUntyped -- 0x81
DropFloat = DropUntyped -- 0x82
DropString = DropUntyped -- 0x83

function AssignUntyped(stack, runtime)
    if stack then
        local val = stack:pop()
        local var = stack:pop()
        var(val)
    end
end

AssignInt = AssignUntyped -- 0x84
AssignLong = AssignUntyped -- 0x85
AssignFloat = AssignUntyped -- 0x86
AssignString = AssignUntyped -- 0x87

function PrintUntyped(stack, runtime)
    if stack then
        runtime:iohandler().print(stack:pop())
    end
end

PrintInt = PrintUntyped -- 0x88
PrintLong = PrintUntyped -- 0x89
PrintFloat = PrintUntyped -- 0x8A
PrintString = PrintUntyped -- 0x8B

function PrintSpace(stack, runtime) -- 0x90
    if stack then
        runtime:iohandler().print(" ")
    end
end

function PrintCarriageReturn(stack, runtime) -- 0x92
    if stack then
        runtime:iohandler().print("\n")
    end
end

function InputInt(stack, runtime) -- 0x94
    if stack then
        local var = stack:pop()
        local trapped = runtime:getTrap()
        local result
        while result == nil do
            local line = runtime:iohandler().readLine(trapped)
            result = tonumber(line)
            if result == nil then
                if trapped then
                    -- We can error and the trap check in runtime will deal with it
                    error(KOplErrGenFail)
                else
                    -- iohandler is responsible for outputting a linefeed after reading the line
                    runtime:iohandler().print("?")
                    -- And go round again
                end
            end
        end
        var(result)
        runtime:setTrap(false)
    end
end

InputLong = InputInt -- 0x95
InputFloat = InputInt -- 0x96

function InputString(stack, runtime) -- 0x97
    if stack then
        local var = stack:pop()
        local trapped = runtime:getTrap()
        local line = runtime:iohandler().readLine(trapped)
        var(line)
        runtime:setTrap(false)
    end
end

function Beep(stack, runtime) -- 0xA0
    if stack then
        local pitch = stack:pop()
        local freq = 512 / (pitch + 1) -- in Khz
        local duration = stack:pop() * 1/32 -- in seconds
        runtime:iohandler().beep(freq, duration)
    end
end

function OnErr(stack, runtime) -- 0xB1
    local offset = runtime:IP16()
    local newIp
    if offset ~= 0 then
        newIp = runtime:getIp() + offset - 3
    end
    if stack then
        runtime:setFrameErrIp(newIp)
    else
        return newIp and fmt("%d (->0x%08X)", offset, newIp) or "OFF"
    end
end

function Raise(stack, runtime) -- 0xB8
    if stack then
        error(stack:pop())
    end
end

function Stop(stack, runtime) -- 0xBB
    if stack then
        -- OPL uses User::Leave(0) for this (and for returning from the main fn)
        -- but we use setting ip to nil for both instead.
        runtime:setIp(nil)
    end
end

function Trap(stack, runtime) -- 0xBC
    if stack then
        runtime:setTrap(true)
    end
end

function GoTo(stack, runtime) -- 0xBF
    local ip = runtime:getIp() - 1 -- Because ip points to just after us
    local relJmp = runtime:IPs16()
    if stack then
        runtime:setIp(ip + relJmp)
    else
        return fmt("%d (->0x%08X)", relJmp, ip + relJmp)
    end
end

function Return(stack, runtime) -- 0xC0
    if stack then
        local val = stack:pop()
        runtime:returnFromFrame(stack, val)
    end
end

function gCls(stack, runtime) -- 0xD1
    if stack then
        local graphics = runtime:getGraphics()
        local context = graphics.current
        context.pos = { x = 0, y = 0 }
        runtime:graphicsOp("cls")
    end
end

function gAt(stack, runtime) -- 0xD2
    if stack then
        runtime:getGraphics().current.pos = stack:popPoint()
    end
end

function gLineBy(stack, runtime) -- 0xDA
    if stack then
        local graphics = runtime:getGraphics()
        local context = graphics.current
        local endPoint = stack:popPoint()
        -- relative pos; make abs
        endPoint.x = context.pos.x + endPoint.x
        endPoint.y = context.pos.y + endPoint.y
        runtime:graphicsOp("line", { x2 = endPoint.x, y2 = endPoint.y })
        context.pos = endPoint
    end
end

function gCircle(stack, runtime) -- 0xDC
    local hasFill = runtime:IP8()
    if stack then
        local graphics = runtime:getGraphics()
        local context = graphics.current
        local fill = 0
        if hasFill ~= 0 then
            fill = stack:pop()
        end
        local radius = stack:pop()
        runtime:graphicsOp("circle", { r = radius, fill = fill })
    else
        return fmt("hasfill=%d", hasFill)
    end
end

function gUpdate(stack, runtime) -- 0xE3
    local flag = runtime:IP8()
    if stack then
        local graphics = runtime:getGraphics()
        local context = graphics.current
        if flag == 255 then -- gUPDATE
            -- Flush now
            if graphics.buffer and graphics.buffer[1] then
                runtime:iohandler().graphics(graphics.buffer)
                graphics.buffer = {}
            end
            return
        end
        if flag == 0 then -- gUPDATE OFF
            if not graphics.buffer then
                graphics.buffer = {}
            end
        else -- gUPDATE ON
            if graphics.buffer and graphics.buffer[1] then
                runtime:iohandler().graphics(graphics.buffer)
            end
            graphics.buffer = nil
        end
    else
        return fmt("flag=%d", flag)
    end
end

function gLineTo(stack, runtime) -- 0xE5
    if stack then
        local graphics = runtime:getGraphics()
        local context = graphics.current
        local endPoint = stack:popPoint()
        runtime:graphicsOp("line", { x2 = endPoint.x, y2 = endPoint.y })
        context.pos = endPoint
    end
end

function mInit(stack, runtime) -- 0xEA
    if stack then
        runtime:setMenu({
            cascades = {},
        })
    end
end

function mCard(stack, runtime) -- 0xEB
    local numParams = runtime:IP8()
    if stack then
        local menu = runtime:getMenu()
        local card = {}
        for i = 1, numParams do
            local item = {}
            item.keycode = stack:pop()
            item.text = stack:pop()
            if item.text:match(">$") then
                -- It's a cascade
                local cascade = menu.cascades[item.text]
                if cascade then
                    item.text = item.text:sub(1, -2)
                    item.submenu = cascade
                else
                    -- We're suppose to just ignore its cascadiness
                    print("CASCADE NOT FOUND")
                end
            end
            -- Last item is popped first
            table.insert(card, 1, item)
        end
        card.title = stack:pop()
        table.insert(menu, card)
    else
        return fmt("%d", numParams)
    end
end

function dInit(stack, runtime) -- 0xEC
    local numParams = runtime:IP8()
    if stack then
        local dialog = {
            flags = 0,
            items = {}
        }
        if numParams == 2 then
            dialog.flags = stack:pop()
        end
        if numParams >= 1 then
            dialog.title = stack:pop()
        end
        runtime:setDialog(dialog)
    else
        return fmt("%d", numParams)
    end        
end

function dItem(stack, runtime) -- 0xED
    local itemType = runtime:IP8()
    if stack then
        local dialog = runtime:getDialog()
        local item = { type = itemType }
        if itemType == dItemTypes.dTEXT then
            local flagToAlign = { [0] = "left", [1] = "right", [2] = "center" }
            local flags = 0
            if runtime:IP8() ~= 0 then
                flags = stack:pop()
            end
            item.align = flagToAlign[flags & 3]
            item.value = stack:pop()
            item.prompt = stack:pop()
            if item.prompt == "" and item.value == "" and (flags & 0x800) > 0 then
                item = { type = dItemTypes.dSEPARATOR }
            end
            -- Ignoring the other flags for now
        elseif itemType == dItemTypes.dCHOICE then
            local commaList = stack:pop()
            item.choices = {}
            for choice in commaList:gmatch("[^,]+") do
                table.insert(item.choices, choice)
            end
            item.prompt = stack:pop()
            item.variable = stack:pop()
            -- Have to resolve default choice here, and _not_ at the point of the DIALOG call!
            item.value = tostring(item.variable())
        elseif itemType == dItemTypes.dLONG or itemType == dItemTypes.dFLOAT or itemType == dItemTypes.dDATE or itemType == dItemTypes.dTIME then
            item.max = stack:pop()
            item.min = stack:pop()
            assert(item.max >= item.min, KOplErrInvalidArgs)
            local timeFlags
            if itemType == dItemTypes.dTIME then
                timeFlags = stack:pop()
                -- TODO something with timeFlags
            end
            item.prompt = stack:pop()
            item.variable = stack:pop()
            item.value = tostring(item.variable())
        elseif itemType == dItemTypes.dEDIT or itemType == dItemTypes.dEDITlen then
            item.max = 0
            if itemType == dItemTypes.dEDITlen then
                max = stack:pop()
            end
            item.prompt = stack:pop()
            item.variable = stack:pop()
            item.value = tostring(item.variable())
            item.type = dItemTypes.dEDIT -- No need to distinguish in higher layers
        elseif itemType == dItemTypes.dXINPUT then
            item.prompt = stack:pop()
            item.variable = stack:pop()
        elseif itemType == dItemTypes.dBUTTONS then
            assert(dialog.buttons == nil, KOplStructure)
            local numButtons = runtime:IP8()
            assert(numButtons <= 4, KOplStructure)
            dialog.buttons = {}
            for i = 1, numButtons do
                local key = stack:pop()
                local text = stack:pop()
                table.insert(dialog.buttons, 1, { key = key, text = text })
            end
        else
            error("Unsupported dItem type "..itemType)
        end
        if itemType ~= dItemTypes.dBUTTONS then
            table.insert(dialog.items, item)
        end
    else
        local extra = ""
        if itemType == dItemTypes.dBUTTONS then
            extra = fmt(" numButtons=%d", runtime:IP8())
        elseif itemType == dItemTypes.dTEXT then
            extra = fmt(" hasFlags=%d", runtime:IP8())
        end
        return fmt("%d (%s)%s", itemType, dItemTypes[itemType] or "?", extra)
    end
end

function NextOpcodeTable(stack, runtime) -- 0xFF
    local extendedCode = runtime:IP8()
    local realOpcode = 256 + extendedCode
    local fnName = codes[realOpcode]
    local realFn = _ENV[fnName]
    assert(realFn, "No function for "..fnName)
    if stack then
        realFn(stack, runtime)
    else
        return fmt("%02X %s %s", extendedCode, fnName, realFn(stack, runtime) or "")
    end
end

function gGrey(stack, runtime) -- 0x100
    if stack then
        local mode = stack:pop()
        local val = mode == 1 and 0xAA or 0
        runtime:getGraphics().current.color = val
    end
end

function gColor(stack, runtime) -- 0x124
    if stack then
        local blue = stack:pop()
        local green = stack:pop()
        local red = stack:pop()
        -- Not gonna bother too much about exact luminosity right now
        local val = (red + green + blue) // 3
        runtime:getGraphics().current.color = val
    end
end

function mCasc(stack, runtime) -- 0x130
    local numParams = runtime:IP8()
    if stack then
        local card = {}
        for i = 1, numParams do
            local keycode = stack:pop()
            local text = stack:pop()
            -- Last item is popped first
            table.insert(card, 1, { keycode = keycode, text = text })
        end
        local title = stack:pop()
        card.title = title
        runtime:getMenu().cascades[title..">"] = card
    else
        return fmt("%d", numParams)
    end

end

function dEditCheckbox(stack, runtime) -- 0x133
    if stack then
        local dialog = runtime:getDialog()
        local item = { type = dItemTypes.dCHECKBOX }
        item.prompt = stack:pop()
        item.variable = stack:pop()
        item.value = tostring(item.variable())
        table.insert(dialog.items, item)
    end
end

return _ENV
