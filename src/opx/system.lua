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

_ENV = module()

fns = {
    [1] = "BackLightOn",
    [2] = "SetBackLightOn",
    [3] = "SetBackLightOnTime",
    [4] = "SetBacklightBehavior",
    [5] = "IsBacklightPresent",
    [6] = "SetAutoSwitchOffBehavior",
    [7] = "SetAutoSwitchOffTime",
    [8] = "SetActive",
    [9] = "ResetAutoSwitchOffTimer",
    [10] = "SwitchOff",
    [11] = "SetSoundEnabled",
    [12] = "SetSoundDriverEnabled",
    [13] = "SetKeyClickEnabled",
    [14] = "SetPointerClickEnabled",
    [15] = "SetDisplayContrast",
    [16] = "MaxDisplayContrast",
    [17] = "IsReadOnly",
    [18] = "IsHidden",
    [19] = "IsSystem",
    [20] = "SetReadOnly",
    [21] = "SetHiddenFile",
    [22] = "SetSystemFile",
    [23] = "VolumeSize",
    [24] = "VolumeSpaceFree",
    [25] = "VolumeUniqueID",
    [26] = "MediaType",
    [27] = "GetFileTime",
    [28] = "SetFileTime",
    [29] = "DisplayTaskList",
    [30] = "SetComputeMode",
    [31] = "RunApp",
    [32] = "RunExe",
    [33] = "LogonToThread",
    [34] = "TerminateCurrentProcess",
    [35] = "TerminateProcess",
    [36] = "KillCurrentProcess",
    [37] = "KillProcess",
    [38] = "PlaySound",
    [39] = "PlaySoundA",
    [40] = "StopSound",
    [41] = "Mod",
    [42] = "XOR",
    [43] = "LoadRsc",
    [44] = "UnLoadRsc",
    [45] = "ReadRsc",
    [46] = "ReadRscLong",
    [47] = "CheckUid",
    [48] = "SetPointerGrabOn",
    [49] = "MachineName",
    [50] = "MachineUniqueId",
    [51] = "EndTask",
    [52] = "KillTask",
    [53] = "GetThreadIdFromOpenDoc",
    [54] = "GetThreadIdFromAppUid",
    [55] = "SetForeground",
    [56] = "SetBackground",
    [57] = "SetForegroundByThread",
    [58] = "SetBackgroundByThread",
    [59] = "GetNextWindowGroupName",
    [60] = "GetNextWindowId",
    [61] = "SendKeyEventToApp",
    [62] = "IrDAConnectToSend",
    [63] = "IrDAConnectToReceive",
    [64] = "IrDAWrite",
    [65] = "IrDARead",
    [66] = "IrDAReadA",
    [67] = "IrDAWaitForDisconnect",
    [68] = "IrDADisconnect",
    [69] = "MainBatteryStatus",
    [70] = "BackupBatteryStatus",
    [71] = "CaptureKey",
    [72] = "CancelCaptureKey",
    [73] = "SetPointerCapture",
    [74] = "ClaimPointerGrab",
    [75] = "OpenFileDialog",
    [76] = "CreateFileDialog",
    [77] = "SaveAsFileDialog",
}

function BackLightOn(stack, runtime) -- 1
    unimplemented("opx.system.BackLightOn")
end

function SetBackLightOn(stack, runtime) -- 2
    unimplemented("opx.system.SetBackLightOn")
end

function SetBackLightOnTime(stack, runtime) -- 3
    unimplemented("opx.system.SetBackLightOnTime")
end

function SetBacklightBehavior(stack, runtime) -- 4
    unimplemented("opx.system.SetBacklightBehavior")
end

function IsBacklightPresent(stack, runtime) -- 5
    unimplemented("opx.system.IsBacklightPresent")
end

function SetAutoSwitchOffBehavior(stack, runtime) -- 6
    unimplemented("opx.system.SetAutoSwitchOffBehavior")
end

function SetAutoSwitchOffTime(stack, runtime) -- 7
    unimplemented("opx.system.SetAutoSwitchOffTime")
end

function SetActive(stack, runtime) -- 8
    printf("system.SetActive(%d)\n", stack:pop())
    stack:push(0)
end

function ResetAutoSwitchOffTimer(stack, runtime) -- 9
    unimplemented("opx.system.ResetAutoSwitchOffTimer")
end

function SwitchOff(stack, runtime) -- 10
    unimplemented("opx.system.SwitchOff")
end

function SetSoundEnabled(stack, runtime) -- 11
    local state = stack:pop()
    printf("TODO: SetSoundEnabled %d\n", state)
    stack:push(0)
end

function SetSoundDriverEnabled(stack, runtime) -- 12
    unimplemented("opx.system.SetSoundDriverEnabled")
end

function SetKeyClickEnabled(stack, runtime) -- 13
    stack:pop() -- state
    stack:push(0)
end

function SetPointerClickEnabled(stack, runtime) -- 14
    unimplemented("opx.system.SetPointerClickEnabled")
end

function SetDisplayContrast(stack, runtime) -- 15
    unimplemented("opx.system.SetDisplayContrast")
end

function MaxDisplayContrast(stack, runtime) -- 16
    unimplemented("opx.system.MaxDisplayContrast")
end

function IsReadOnly(stack, runtime) -- 17
    unimplemented("opx.system.IsReadOnly")
end

function IsHidden(stack, runtime) -- 18
    unimplemented("opx.system.IsHidden")
end

function IsSystem(stack, runtime) -- 19
    unimplemented("opx.system.IsSystem")
end

function SetReadOnly(stack, runtime) -- 20
    unimplemented("opx.system.SetReadOnly")
end

function SetHiddenFile(stack, runtime) -- 21
    local state = stack:pop()
    local path = stack:pop()
    printf("SetHiddenFile(%s, %d)\n", path, state)
    stack:push(0)
end

function SetSystemFile(stack, runtime) -- 22
    unimplemented("opx.system.SetSystemFile")
end

function VolumeSize(stack, runtime) -- 23
    unimplemented("opx.system.VolumeSize")
end

function VolumeSpaceFree(stack, runtime) -- 24
    unimplemented("opx.system.VolumeSpaceFree")
end

function VolumeUniqueID(stack, runtime) -- 25
    unimplemented("opx.system.VolumeUniqueID")
end

function MediaType(stack, runtime) -- 26
    unimplemented("opx.system.MediaType")
end

function GetFileTime(stack, runtime) -- 27
    local dateh = stack:pop()
    local path = stack:pop()
    local stat, err = runtime:iohandler().fsop("stat", path)
    if stat then
        require("opx.date").setDate(dateh, stat.lastModified)
        stack:push(0)
    else
        error(err)
    end
end

function SetFileTime(stack, runtime) -- 28
    unimplemented("opx.system.SetFileTime")
end

function DisplayTaskList(stack, runtime) -- 29
    runtime:DisplayTaskList()
    stack:push(0)
end

function SetComputeMode(stack, runtime) -- 30
    local state = stack:pop()
    -- We don't care about scheduling
    stack:push(0)
end

function RunApp(stack, runtime) -- 31
    local cmd = stack:pop()
    local tail = stack:pop()
    local doc = stack:pop()
    local prog = stack:pop()
    if cmd == 0 then
        if doc:lower():match("%.hlp$") then
            local dlg = {
                title = "Not supported",
                flags = 0,
                xpos = 0,
                ypos = 0,
                items = {
                    {
                    type = dItemTypes.dTEXT,
                    align = "center",
                    value = "Viewing help files (*.hlp) is not yet supported by",
                    },
                    {
                    type = dItemTypes.dTEXT,
                    align = "center",
                    value = "OpoLua. See GitHub issue #202 for more details."
                    }
                },
                buttons = {
                    { key = KKeyEsc | KDButtonNoLabel, text = "OK" },
                },
            }
            runtime:DIALOG(dlg)
            stack:push(0)
            return
        end
        local ret = runtime:iohandler().runApp(prog, doc)
        -- Although a non-existent prog _would_ cause an error dialog to appear
        -- on screen, that was posted the system and you'd get a seemingly-valid
        -- but useless thread id returned to the program. We're not going to do
        -- that, and will just error instead.
        assert(ret, KErrGenFail)
        stack:push(ret)
    elseif cmd == 1 then
        unimplemented("opx.system.RunApp.create")
    elseif cmd == 2 then
        unimplemented("opx.system.RunApp.run")
    elseif cmd == 3 then
        unimplemented("opx.system.RunApp.background")
    else
        error(KErrInvalidArgs)
    end
end

function RunExe(stack, runtime) -- 32
    unimplemented("opx.system.RunExe")
end

function LogonToThread(stack, runtime) -- 33
    unimplemented("opx.system.LogonToThread")
end

function TerminateCurrentProcess(stack, runtime) -- 34
    unimplemented("opx.system.TerminateCurrentProcess")
end

function TerminateProcess(stack, runtime) -- 35
    unimplemented("opx.system.TerminateProcess")
end

function KillCurrentProcess(stack, runtime) -- 36
    unimplemented("opx.system.KillCurrentProcess")
end

function KillProcess(stack, runtime) -- 37
    unimplemented("opx.system.KillProcess")
end

function PlaySound(stack, runtime) -- 38
    local var = runtime:makeTemporaryVar(DataTypes.ELong)
    stack:push(var:addressOf())
    PlaySoundA(stack, runtime)
    runtime:waitForRequest(var)
    local val = var()
    if val < 0 then
        error(val)
    end
end

function PlaySoundA(stack, runtime) -- 39
    local var = stack:pop():asVariable(DataTypes.ELong)
    local volume = stack:pop() -- not used atm...
    local path = stack:pop()
    runtime:PlaySoundA(var, path)
    stack:push(0)
end

function StopSound(stack, runtime) -- 40
    local didStop = runtime:StopSound()
    stack:push(didStop and 1 or 0)
end

function Mod(stack, runtime) -- 41
    local right = stack:pop()
    local left = stack:pop()
    -- Oh joy, Lua and C (and by extension, OPL) don't have the same definition of modulus for negative operands
    -- See https://torstencurdt.com/tech/posts/modulo-of-negative-numbers/
    -- So we can't just do left % right
    local sign = left < 0 and -1 or 1
    stack:push(sign * (math.abs(left) % math.abs(right)))
end

function XOR(stack, runtime) -- 42
    local right = stack:pop()
    local left = stack:pop()
    stack:push(left ~ right)
end

function LoadRsc(stack, runtime) -- 43
    local path = stack:pop()
    local handle = runtime:LoadRsc(path)
    stack:push(handle)
end

function UnLoadRsc(stack, runtime) -- 44
    local h = stack:pop()
    runtime:UnLoadRsc(h)
    stack:push(0)
end

function ReadRsc(stack, runtime) -- 45
    local id = stack:pop()
    stack:push(runtime:ReadRsc(id))
end

function ReadRscLong(stack, runtime) -- 46
    local id = stack:pop()
    local result = runtime:ReadRsc(id)
    assert(#result == 4, "Bad resource length for ReadRscLong!")
    result = string.unpack("<i4", result)
    stack:push(result)
end

function CheckUid(stack, runtime) -- 47
    local uid3 = touint32(stack:pop())
    local uid2 = touint32(stack:pop())
    local uid1 = touint32(stack:pop())
    local checksum = require("crc").getUidsChecksum(uid1, uid2, uid3)
    local result = string.pack("<I4I4I4I4", uid1, uid2, uid3, checksum)
    stack:push(result)
end

function SetPointerGrabOn(stack, runtime) -- 48
    unimplemented("opx.system.SetPointerGrabOn")
end

function MachineName(stack, runtime) -- 49
    stack:push("OpoLua")
end

function MachineUniqueId(stack, runtime) -- 50
    local loWord = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    local hiWord = runtime:addrAsVariable(stack:pop(), DataTypes.ELong)
    hiWord(0x090700A)
    loWord(toint32(0xFACE4ACE))
    stack:push(0)
end

function EndTask(stack, runtime) -- 51
    local prev = stack:pop()
    local id = stack:pop()
    printf("TODO: EndTask id=%d prev=%d\n", id, prev)
    stack:push(0)
end

function KillTask(stack, runtime) -- 52
    unimplemented("opx.system.KillTask")
end

function GetThreadIdFromOpenDoc(stack, runtime) -- 53
    unimplemented("opx.system.GetThreadIdFromOpenDoc")
end

function GetThreadIdFromAppUid(stack, runtime) -- 54
    unimplemented("opx.system.GetThreadIdFromAppUid")
end

function SetForeground(stack, runtime) -- 55
    runtime:SetForeground()
    stack:push(0)
end

function SetBackground(stack, runtime) -- 56
    runtime:SetBackground()
    stack:push(0)
end

function SetForegroundByThread(stack, runtime) -- 57
    unimplemented("opx.system.SetForegroundByThread")
end

function SetBackgroundByThread(stack, runtime) -- 58
    unimplemented("opx.system.SetBackgroundByThread")
end

function GetNextWindowGroupName(stack, runtime) -- 59
    unimplemented("opx.system.GetNextWindowGroupName")
end

function GetNextWindowId(stack, runtime) -- 60
    unimplemented("opx.system.GetNextWindowId")
end

function SendKeyEventToApp(stack, runtime) -- 61
    unimplemented("opx.system.SendKeyEventToApp")
end

function IrDAConnectToSend(stack, runtime) -- 62
    unimplemented("opx.system.IrDAConnectToSend")
end

function IrDAConnectToReceive(stack, runtime) -- 63
    unimplemented("opx.system.IrDAConnectToReceive")
end

function IrDAWrite(stack, runtime) -- 64
    unimplemented("opx.system.IrDAWrite")
end

function IrDARead(stack, runtime) -- 65
    unimplemented("opx.system.IrDARead")
end

function IrDAReadA(stack, runtime) -- 66
    unimplemented("opx.system.IrDAReadA")
end

function IrDAWaitForDisconnect(stack, runtime) -- 67
    unimplemented("opx.system.IrDAWaitForDisconnect")
end

function IrDADisconnect(stack, runtime) -- 68
    unimplemented("opx.system.IrDADisconnect")
end

function MainBatteryStatus(stack, runtime) -- 69
    stack:push(3) -- Good
end

function BackupBatteryStatus(stack, runtime) -- 70
    unimplemented("opx.system.BackupBatteryStatus")
end

function CaptureKey(stack, runtime) -- 71
    local mod = stack:pop()
    local mask = stack:pop()
    local key = stack:pop()
    printf("system.CaptureKey(%d, %d, %d)\n", key, mask, mod)
    stack:push(0)
end

function CancelCaptureKey(stack, runtime) -- 72
    unimplemented("opx.system.CancelCaptureKey")
end

function SetPointerCapture(stack, runtime) -- 73
    unimplemented("opx.system.SetPointerCapture")
end

function ClaimPointerGrab(stack, runtime) -- 74
    unimplemented("opx.system.ClaimPointerGrab")
end

function OpenFileDialog(stack, runtime) -- 75
    unimplemented("opx.system.OpenFileDialog")
end

function CreateFileDialog(stack, runtime) -- 76
    unimplemented("opx.system.CreateFileDialog")
end

function SaveAsFileDialog(stack, runtime) -- 77
    unimplemented("opx.system.SaveAsFileDialog")
end

return _ENV
