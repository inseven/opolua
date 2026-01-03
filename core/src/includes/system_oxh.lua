return [[
rem System.OXH version 1.01
rem Header File for System.OPX
rem Copyright (c) 1997-1998 Symbian Ltd. All rights reserved.

rem Added in v1.01:
rem     IsExternalPowerPresent&:

const KUidOpxSystem&=&1000025C
const KOpxSystemVersion%=$101

const KComputeModeOn&=1
const KComputeModeOff&=2
const KComputeModeDisabled&=0

const KBatteryZero&=0
const KBatteryVeryLow&=1
const KBatteryLow&=2
const KBatteryGood&=3

rem For MediaType&:
const KMediaNotPresent&=0
const KMediaUnknown&=1
const KMediaFloppy&=2
const KMediaHardDisk&=3
const KMediaCdRom&=4
const KMediaRam&=5
const KMediaFlash&=6
const KMediaRom&=7
const KMediaRemote&=8

rem For IrDA protocols
const KIrmux$="Irmux"
const KIrTinyTP$="IrTinyTP"

rem For CaptureKey&:
const KModifierAutorepeatable&=&00000001
const KModifierKeypad&=&00000002
const KModifierLeftAlt&=&00000004
const KModifierRightAlt&=&00000008
const KModifierAlt&=&00000010
const KModifierLeftCtrl&=&00000020
const KModifierRightCtrl&=&00000040
const KModifierCtrl&=&00000080
const KModifierLeftShift&=&00000100
const KModifierRightShift&=&00000200
const KModifierShift&=&00000400
const KModifierLeftFunc&=&00000800
const KModifierRightFunc&=&00001000
const KModifierFunc&=&00002000
const KModifierCapsLock&=&00004000
const KModifierNumLock&=&00008000
const KModifierScrollLock&=&00010000
const KModifierKeyUp&=&00020000
const KModifierSpecial&=&00040000
const KModifierDoubleClick&=&00080000
const KModifierPureKeycode&=&00100000
const KAllModifiers&=&001fffff

DECLARE OPX SYSTEM,KUidOpxSystem&,KOpxSystemVersion%
	BackLightOn&: : 1
	SetBackLightOn:(state&) : 2
	SetBackLightOnTime:(seconds&) : 3
	SetBacklightBehavior:(behaviour&) : 4
	IsBacklightPresent&: : 5
	SetAutoSwitchOffBehavior:(behaviour&) : 6
	SetAutoSwitchOffTime:(seconds&) : 7
	SetActive:(state&) : 8
	ResetAutoSwitchOffTimer: : 9
	SwitchOff: : 10
	SetSoundEnabled:(state&) : 11
	SetSoundDriverEnabled:(state&) : 12
	SetKeyClickEnabled:(state&) : 13
	SetPointerClickEnabled:(state&) : 14
	SetDisplayContrast:(value&) : 15
	MaxDisplayContrast&: : 16
	IsReadOnly&:(file$) : 17
	IsHidden&:(file$) : 18
	IsSystem&:(file$) : 19
	SetReadOnly:(file$,state&) : 20
	SetHiddenFile:(file$,state&) : 21
	SetSystemFile:(file$,state&) : 22
	VolumeSize&:(drive&) : 23
	VolumeSpaceFree&:(drive&) : 24
	VolumeUniqueID&:(drive&) : 25
	MediaType&:(drive&) : 26
	GetFileTime:(file$,DateTimeId&) : 27
	SetFileTime:(file$,DateTimeId&) : 28
	DisplayTaskList: : 29
	SetComputeMode:(State&) : 30
	RunApp&:(lib$,doc$,tail$,cmd&) : 31
	RunExe&:(name$) : 32
	LogonToThread:(threadId&, BYREF statusWord&) : 33
	TerminateCurrentProcess:(reason&) : 34
	TerminateProcess:(proc$,reason&) : 35
	KillCurrentProcess:(reason&) : 36
	KillProcess:(proc$,reason&) : 37
	PlaySound:(file$,volume&) : 38
	PlaySoundA:(file$,volume&, BYREF statusWord&) : 39
	StopSound&: : 40
	Mod&:(left&,right&) : 41
	XOR&:(left&,right&) : 42
	LoadRsc&:(file$) : 43
	UnLoadRsc:(id&) : 44
	ReadRsc$:(id&) : 45
	ReadRscLong&:(id&) : 46
	CheckUid$:(Uid1&,Uid2&,Uid3&) : 47
	SetPointerGrabOn:(WinId&,state&) : 48
	MachineName$: : 49
	MachineUniqueId:(BYREF high&,BYREF low&) : 50
	EndTask&:(threadId&,previous&)  : 51
	KillTask&:(threadId&,previous&) : 52
	GetThreadIdFromOpenDoc&:(doc$,BYREF previous&) : 53
	GetThreadIdFromAppUid&:(uid&,BYREF previous&) : 54
	SetForeground: : 55
	SetBackground: : 56
	SetForegroundByThread&:(threadId&,previous&) : 57
	SetBackgroundByThread&:(threadId&,previous&) : 58
	GetNextWindowGroupName$:(threadId&,BYREF previous&) : 59
	GetNextWindowId&:(threadId&,previous&) : 60
	SendKeyEventToApp&:(threadId&,previous&,code&,scanCode&,modifiers&,repeats&) : 61
    IrDAConnectToSend&:(protocol$, port&) : 62
	IrDAConnectToReceive:(protocol$, port&, BYREF statusW&) : 63
	IrDAWrite:(chunk$, BYREF statusW&) : 64
	IrDARead$: : 65
	IrDAReadA:(stringAddr&, BYREF statusW&): 66
	IrDAWaitForDisconnect: : 67
	IrDADisconnect: : 68
	MainBatteryStatus&: :69
	BackupBatteryStatus&: :70
	CaptureKey&:(keyCode&, mask&, modifier&) :71
	CancelCaptureKey:(handle&) :72
	SetPointerCapture:(winId&, flags&) :73
	ClaimPointerGrab:(winId&, state&) :74
	OpenFileDialog$:(seedFile$,uid1&,uid2&,uid3&) : 75
	CreateFileDialog$:(seedPath$) : 76
	SaveAsFileDialog$:(seedPath$,BYREF useNewFile%) : 77
	IsExternalPowerPresent&: : 78
END DECLARE
]]
