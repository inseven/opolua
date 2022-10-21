---
title: Release Notes
---

# Release Notes

## 1.1.0

**Changes**

- Rudimentary series 3 (SIBO) support
- New memory model
- Support alloc on new memory model
- Add support to FileSystem for adding shared drives
- Support gGREY on Series 3
- Support Series 3 .WVE files
- Support correct SIBO default string encoding (CP850)
- Start supporting OS() and CALL() syscalls properly (SIBO only)
- (partially) support SIBO sprite syscalls

**Fixes**

- Support for reading Series 3 format .PIC files and some 1BPP fixes
- Support --noget arg in runopo.lua
- dEdit dialog items in new memory model
- Implement opx.alarm.AlmAlarmState()
- Implement some systinfo.opx fns
- LoadResource should abs its path
- Don't return "X" from GETCMD$ unless there's really been a quit event
- Implement MODIFY, INSERT, PUT, CANCEL, BEGINTRANS, COMMITTRANS, ROLLBACK, INTRANS
- stub SETDOC()
- Implement DOW()
- Stub CaptureKey
- Add some Z: drive resources
- Broken DTNow
- Correct the capitalisation in 'Psion Series 3c'
- Save screenshots as PNG files and include the timestamp in the filename
- Nicer failure mode when launching help files
- 1BPP masks
- Preserve bitmap mode when resizing CanvasView
- Cache composited CanvasView image, for performance
- misc SIBO syscalls wFree, wInquireWindow, wDisableKeyClick, HwGetScanCodes (stubbed)
- crash when recognizing awkward files
- Support for gPATT -1
- Make SIBO non-OPL apps error the same way as ER5 ones
- Support SIBO HwGetScanCodes syscall
- Show the application name in the about screen (#231)
- crash in iOS 16 (#238)
- Crash when adding large directories (#239)
- Correct the color of the about view commit link (#240)

## 1.0.1

**Fixes**

- GEN$() with negative width was broken
- HexStr shouldn't sign extend negative numbers
- PrintFloat shouldn't add .0 to integral values
- don't write the full 16 items in getevent array
- don't flush in gLOADBIT or gSETWIN
- passing a filename without path to runopo.lua was broken

## 1.0.0

**Changes**

- Initial release
- Support raising a GitHub issue from the error view controller
- Bump the version to 1.0.0

**Fixes**

- actually support RMDIR
- Implement system.SetHiddenFile()
- NumStr with negative width was always returning an empty string
- Reuse drawableIds once the win/bmp has been closed
- MachineUniqueId shouldn't rely on dereference
- Max(array, numVals) was completely broken
- support STYLE()
- PRINT() should always use gTMODE replace
- Support gXPRINT
- Support tight line spacing and fullscreen flags in DIALOG
- gINVERT was inverting the wrong coordinates
- Ensure the correct library section is selected when switching program
- Remove search as it causes program layout issues on first run Unfortunately having a search controller in `AllProgramsViewController` was causing our `UISplitViewController` to get into a weird intiial state which was then leading to an overly large navigation bar when pushing `ProgramViewController`. That navigation bar was then occluding the top of the program's `RootView` meaning it wasn't possible to interact with the menu. This change removes search until we can find the issue with our use of `UISplitViewController`. THere's a longer discussion on the issue tracking this: https://github.com/inseven/opolua/issues/206
- Implement sysram1.GetFileSize
- Ensure the source viewer respects safe areas
- TBarInit() is supposed to call gUPDATE OFF
- Offset menu bar by an extra pixel
- Rename the app to 'OpoLua'
- Update Welcome app for new naming and first screen
- Update the color icons for the Welcome program
