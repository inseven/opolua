return [[
rem SYSRAM1.TXH version 5.20
rem Header File for SYSRAM1.OPX
rem Copyright (c) 1997-2000 Symbian Ltd. All rights reserved.

CONST KUidOpxSysram1&=&10000405
CONST KOpxSysram1Version%=$520

DECLARE OPX SYSRAM1,KUidOpxSysram1&,KOpxSysram1Version%
    DBFind&:(aString$) :1
    DBFindField&:(aString$,aStart&,aNum&,aFlags&) :2
    GetThreadIdFromCaption&:(aCaption$,BYREF aPrevious&) :3
    ExternalPower&: :4
    LCNearestLanguageFile$:(aFile$) :5
    LCLanguage&: :6
    OSVersionMajor&: :7 
    OSVersionMinor&: :8
    OSVersionBuild&: :9
    ROMVersionMajor&: :10
    ROMVersionMinor&: :11
    ROMVersionBuild&: :12
    GetFileSize&:(aFile$) :13
    DTDayNameFull$:(aDay&) :14
    DTMonthNameFull$:(aMonth&) :15
    DTIsLeapYear&:(aYear&) :16
    LCDateSeparator$:(aIndex&) :17
    LCTimeSeparator$:(aIndex&) :18
    LCAmPmSpaceBetween&: :19
    RunExeWithCmd&:(aExeName$,aCommandLine$) :20
    SendSwitchFilesMessageToApp&:(aThreadID&,aPrevious&,aFile$,aCreateNotOpen%) : 21
    RunDocument&:(aDocumentName$,aSwitchToIfRunning%) : 22
    GetOPXVersion&:(aOPXName$) : 23
END DECLARE
]]
