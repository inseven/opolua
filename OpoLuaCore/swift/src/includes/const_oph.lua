-- From EPOC Release 5 v1.05(254)

return [[
rem CONST.OPH version 1.02
rem Constants for OPL
rem Copyright (c) 1997-1999 Symbian Ltd. All rights reserved.

rem Changes in 1.02:
rem   Added subscripts for gCOLORINFO keyword
rem   Added new colour modes for DEFAULTWIN and gCREATE
rem   Added MIME priority values.
rem Changes in 1.01:
rem - some language codes added
rem - consts for KKeyUpArrow%,KKeyDownArrow%,... apply to 16-bit
rem   keywords GET, GETEVENT, KEY
rem   KKeyUpArrow32%,KKeyDownArrow32%,... added for 32-bit
rem   keywords GETEVENT32 etc. 
 
rem General constants
const KTrue%=-1
const KFalse%=0

rem Data type ranges
const KMaxStringLen%=255
const KMaxFloat=1.7976931348623157E+308
const KMinFloat=2.2250738585072015E-308 rem Minimum with full precision in mantissa
const KMinFloatDenorm=5e-324  rem Denormalised (just one bit of precision left)
const KMinInt%=$8000 rem -32768 (translator needs hex for maximum ints)
const KMaxInt%=32767
const KMinLong&=&80000000 rem -2147483648 (hex for translator)
const KMaxLong&=2147483647

rem Special keys
const KKeyEsc%=27
const KKeySpace%=32
const KKeyDel%=8
const KKeyTab%=9
const KKeyEnter%=13
rem Key constants for 16-bit keywords GETEVENT etc.
const KGetMenu%=290    rem unfortunately must be named KGetMenu% because KKeyMenu% clashes with badly-named other constant which cannot be changed for compatibility reasons
const KKeyUpArrow%=256
const KKeyDownArrow%=257
const KKeyLeftArrow%=259
const KKeyRightArrow%=258
const KKeyPageUp%=260
const KKeyPageDown%=261
const KKeyPageLeft%=262
const KKeyPageRight%=263

const KKeyMenu%=4150         rem const kept for compatibility
const KKeySidebarMenu%=10000 rem const kept for compatibility

rem Key constants for 32-bit keywords GETEVENT32 etc.
const KKeyMenu32%=4150
const KKeySidebarMenu32%=10000
const KKeyPageLeft32%=4098
const KKeyPageRight32%=4099
const KKeyPageUp32%=4100
const KKeyPageDown32%=4101
const KKeyLeftArrow32%=4103
const KKeyRightArrow32%=4104
const KKeyUpArrow32%=4105
const KKeyDownArrow32%=4106



rem Month numbers
const KJanuary%=1
const KFebruary%=2
const KMarch%=3
const KApril%=4
const KMay%=5
const KJune%=6
const KJuly%=7
const KAugust%=8
const KSeptember%=9
const KOctober%=10
const KNovember%=11
const KDecember%=12

rem Graphics
const KDefaultWin%=1
const KgModeSet%=0
const KgModeClear%=1
const KgModeInvert%=2
const KtModeSet%=0
const KtModeClear%=1
const KtModeInvert%=2
const KtModeReplace%=3

const KgStyleNormal%=0
const KgStyleBold%=1
const KgStyleUnder%=2
const KgStyleInverse%=4
const KgStyleDoubleHeight%=8
const KgStyleMonoFont%=16
const KgStyleItalic%=32

rem For 32-bit status words IOWAIT and IOWAITSTAT32
rem Use KErrFilePending% (-46) for 16-bit status words
const KStatusPending32&=&80000001

rem Error codes
const KErrGenFail%=-1
const KErrInvalidArgs%=-2
const KErrOs%=-3
const KErrNotSupported%=-4
const KErrUnderflow%=-5
const KErrOverflow%=-6
const KErrOutOfRange%=-7
const KErrDivideByZero%=-8
const KErrInUse%=-9
const KErrNoMemory%=-10
const KErrNoSegments%=-11
const KErrNoSemaphore%=-12
const KErrNoProcess%=-13
const KErrAlreadyOpen%=-14
const KErrNotOpen%=-15
const KErrImage%=-16
const KErrNoReceiver%=-17
const KErrNoDevices%=-18
const KErrNoFileSystem%=-19
const KErrFailedToStart%=-20
const KErrFontNotLoaded%=-21
const KErrTooWide%=-22
const KErrTooManyItems%=-23
const KErrBatLowSound%=-24
const KErrBatLowFlash%=-25
const KErrExists%=-32
const KErrNotExists%=-33
const KErrWrite%=-34
const KErrRead%=-35
const KErrEof%=-36
const KErrFull%=-37
const KErrName%=-38
const KErrAccess%=-39
const KErrLocked%=-40
const KErrDevNotExist%=-41
const KErrDir%=-42
const KErrRecord%=-43
const KErrReadOnly%=-44
const KErrInvalidIO%=-45
const KErrFilePending%=-46
const KErrVolume%=-47
const KErrIOCancelled%=-48
rem OPL specific error
const KErrSyntax%=-77
const KOplStructure%=-85
const KErrIllegal%=-96
const KErrNumArg%=-97
const KErrUndef%=-98
const KErrNoProc%=-99
const KErrNoFld%=-100
const KErrOpen%=-101
const KErrClosed%=-102
const KErrRecSize%=-103
const KErrModLoad%=-104
const KErrMaxLoad%=-105
const KErrNoMod%=-106
const KErrNewVer%=-107
const KErrModNotLoaded%=-108
const KErrBadFileType%=-109
const KErrTypeViol%=-110
const KErrSubs%=-111
const KErrStrTooLong%=-112
const KErrDevOpen%=-113
const KErrEsc%=-114
const KErrMaxDraw%=-117
const KErrDrawNotOpen%=-118
const KErrInvalidWindow%=-119
const KErrScreenDenied%=-120
const KErrOpxNotFound%=-121
const KErrOpxVersion%=-122
const KErrOpxProcNotFound%=-123
const KErrStopInCallback%=-124
const KErrIncompUpdateMode%=-125
const KErrInTransaction%=-126

rem For ALERT
const KAlertEsc%=1
const KAlertEnter%=2
const KAlertSpace%=3

rem For BUSY and GIPRINT
const KBusyTopLeft%=0
const KBusyBottomLeft%=1
const KBusyTopRight%=2
const KBusyBottomRight%=3
const KBusyMaxText%=80

rem For CMD$
const KCmdAppName%=1   rem Full path name used to start program
const KCmdUsedFile%=2
const KCmdLetter%=3
rem For CMD$(3)
const KCmdLetterCreate$="C"
const KCmdLetterOpen$="O"
const KCmdLetterRun$="R"

rem For CURSOR
const KCursorTypeNotFlashing%=2
const KCursorTypeGrey%=4

rem For DATIM$ - offsets
const KDatimOffDayName%=1
const KDatimOffDay%=5
const KDatimOffMonth%=8
const KDatimOffYear%=12
const KDatimOffHour%=17
const KDatimOffMinute%=20
const KDatimOffSecond%=23

rem For dBUTTON
const KDButtonNoLabel%=$100
const KDButtonPlainKey%=$200
const KDButtonDel%=8
const KDButtonTab%=9
const KDButtonEnter%=13
const KDButtonEsc%=27
const KDButtonSpace%=32

rem For dEDITMULTI and printing
const KParagraphDelimiter%=$06
const KLineBreak%=$07
const KPageBreak%=$08
const KTabCharacter%=$09
const KNonBreakingTab%=$0a
const KNonBreakingHyphen%=$0b
const KPotentialHyphen%=$0c
const KNonBreakingSpace%=$10
const KPictureCharacter%=$0e
const KVisibleSpaceCharacter%=$0f

rem For DEFAULTWIN
rem Old consts retained for compatibility:
const KDefWin4ColourMode%=1
const KDefWin16ColourMode%=2
rem New color mode constants:
const KColorDefWin2GrayMode%=0
const KColorDefWin4GrayMode%=1
const KColorDefWin16GrayMode%=2
const KColorDefWin256GrayMode%=3
const KColorDefWin16ColorMode%=4
const KColorDefWin256ColorMode%=5

rem For dFILE
const KDFileNameLen%=255
      rem flags
const KDFileEditBox%=$0001
const KDFileAllowFolders%=$0002
const KDFileFoldersOnly%=$0004
const KDFileEditorDisallowExisting%=$0008
const KDFileEditorQueryExisting%=$0010
const KDFileAllowNullStrings%=$0020
const KDFileAllowWildCards%=$0080
const KDFileSelectorWithRom%=$0100
const KDFileSelectorWithSystem%=$0200

rem Opl-related Uids for dFILE
const KUidOplInterpreter&=268435575
const KUidOplApp&=268435572
const KUidOplDoc&=268435573
const KUidOPO&=268435571
const KUidOplFile&=268435594
const KUidOpxDll&=268435549

rem For DIALOG
const KDlgCancel%=0

rem For dINIT (flags for dialogs)
const KDlgButRight%=1
const KDlgNoTitle%=2
const KDlgFillScreen%=4
const KDlgNoDrag%=8
const KDlgDensePack%=16

rem For DOW
const KMonday%=1
const KTuesday%=2
const KWednesday%=3
const KThursday%=4
const KFriday%=5
const KSaturday%=6
const KSunday%=7

rem For dPOSITION
const KDPositionLeft%=-1
const KDPositionCentre%=0
const KDPositionRight%=1

rem For dTEXT
const KDTextLeft%=0
const KDTextRight%=1
const KDTextCentre%=2
const KDTextBold%=$100       rem Ignored in Eikon
const KDTextLineBelow%=$200
const KDTextAllowSelection%=$400
const KDTextSeparator%=$800

rem For dTIME
const KDTimeAbsNoSecs%=0
const KDTimeAbsWithSecs%=1
const KDTimeDurationNoSecs%=2
const KDTimeDurationWithSecs%=3
rem Flags for dTIME (for ORing combinations)
const KDTimeWithSeconds%=1
const KDTimeDuration%=2
const KDTimeNoHours%=4
const KDTime24Hour%=8

rem For dXINPUT
const KDXInputMaxLen%=16

rem For FINDFIELD
const KFindCaseDependent%=16
const KFindBackwards%=0
const KFindForwards%=1
const KFindBackwardsFromEnd%=2
const KFindForwardsFromStart%=3

rem For FLAGS
const KFlagsAppFileBased%=1
const KFlagsAppIsHidden%=2


rem For gBORDER and gXBORDER
const KBordSglShadow%=1
const KBordSglGap%=2
const KBordDblShadow%=3
const KBordDblGap%=4
const KBordGapAllRound%=$100
const KBordRoundCorners%=$200
const KBordLosePixel%=$400

rem For gBUTTON
const KButtS3%=0
const KButtS3Raised%=0
const KButtS3Pressed%=1
const KButtS3a%=1
const KButtS3aRaised%=0
const KButtS3aSemiPressed%=1
const KButtS3aSunken%=2
const KButtS5%=2
const KButtS5Raised%=0
const KButtS5SemiPressed%=1
const KButtS5Sunken%=2

const KButtLayoutTextRightPictureLeft%=0
const KButtLayoutTextBottomPictureTop%=1
const KButtLayoutTextTopPictureBottom%=2
const KButtLayoutTextLeftPictureRight%=3
const KButtTextRight%=0
const KButtTextBottom%=1
const KButtTextTop%=2
const KButtTextLeft%=3
const KButtExcessShare%=$00
const KButtExcessToText%=$10
const KButtExcessToPicture%=$20

rem For gCLOCK
const KgClockS5System%=6
const KgClockS5Analog%=7
const KgClockS5Digital%=8
const KgClockS5LargeAnalog%=9
const KgClockS5Formatted%=11

rem For gCREATE
const KgCreateInvisible%=0
const KgCreateVisible%=1
const KgCreateHasShadow%=$0010
rem Old constants retained for compatibility:
const KgCreate2ColourMode%=$0000
const KgCreate4ColourMode%=$0001
const KgCreate16ColourMode%=$0002
rem Color mode constants:
const KColorgCreate2GrayMode%=$0000
const KColorgCreate4GrayMode%=$0001
const KColorgCreate16GrayMode%=$0002
const KColorgCreate256GrayMode%=$0003
const KColorgCreate16ColorMode%=$0004
const KColorgCreate256ColorMode%=$0005

rem For gCOLORINFO - array subscripts
const gColorInfoADisplayMode%=1
const gColorInfoANumColors%=2
const gColorInfoANumGreys%=3
rem DisplayMode constants:
const KDisplayModeNone%=0
const KDisplayModeGray2%=1
const KDisplayModeGray4%=2
const KDisplayModeGray16%=3
const KDisplayModeGray256%=4
const KDisplayModeColor16%=5
const KDisplayModeColor256%=6
const KDisplayModeColor64K%=7
const KDisplayModeColor16M%=8
const KDisplayModeRGB%=9
const KDisplayModeColor4K%=10

rem For GETCMD$
const KGetCmdLetterCreate$="C"
const KGetCmdLetterOpen$="O"
const KGetCmdLetterExit$="X"
const KGetCmdLetterUnknown$="U"
const KGetCmdLetterBackup$="S"
const KGetCmdLetterRestart$="R"

rem For gLOADBIT
const KgLoadBitReadOnly%=0
const KgLoadBitWriteable%=1

rem For gRANK
const KgRankForeground%=1
const KgRankBackGround%=32767

rem For gPOLY - array subscripts
const KgPolyAStartX%=1
const KgPolyAStartY%=2
const KgPolyANumPairs%=3
const KgPolyANumDx1%=4
const KgPolyANumDy1%=5

rem For gPRINTB
const KgPrintBRightAligned%=1
const KgPrintBLeftAligned%=2
const KgPrintBCentredAligned%=3
rem The defaults
const KgPrintBDefAligned%=KgPrintBLeftAligned%
const KgPrintBDefTop%=0
const KgPrintBDefBottom%=0
const KgPrintBDefMargin%=0

rem For gXBORDER
const KgXBorderS3Type%=0
const KgXBorderS3aType%=1
const KgXBorderS5Type%=2

rem For gXPRINT
const KgXPrintNormal%=0
const KgXPrintInverse%=1
const KgXPrintInverseRound%=2
const KgXPrintThinInverse%=3
const KgXPrintThinInverseRound%=4
const KgXPrintUnderlined%=5
const KgXPrintThinUnderlined%=6

rem For KMOD
const KKmodShift%=2
const KKmodControl%=4
const KKmodPsion%=8
const KKmodCaps%=16
const KKmodFn%=32

rem For mCARD and mCASC
const KMenuDimmed%=$1000
const KMenuSymbolOn%=$2000
const KMenuSymbolIndeterminate%=$4000
const KMenuCheckBox%=$0800
const KMenuOptionStart%=$0900
const KMenuOptionMiddle%=$0A00
const KMenuOptionEnd%=$0B00

rem For mPOPUP position type
rem Specifies which corner of the popup is given by the coordinates
const KMPopupPosTopLeft%=0
const KMPopupPosTopRight%=1
const KMPopupPosBottomLeft%=2
const KMPopupPosBottomRight%=3

rem For PARSE$ - array subscripts
const KParseAOffFSys%=1
const KParseAOffDev%=2
const KParseAOffPath%=3
const KParseAOffFilename%=4
const KParseAOffExt%=5
const KParseAOffWild%=6
rem Wild-card flags
const KParseWildNone%=0
const KParseWildFilename%=1
const KParseWildExt%=2
const KParseWildBoth%=3

rem For SCREENINFO - array subscripts
const KSInfoALeft%=1
const KSInfoATop%=2
const KSInfoAScrW%=3
const KSInfoAScrH%=4
const KSInfoAReserved1%=5
const KSInfoAFont%=6
const KSInfoAPixW%=7
const KSInfoAPixH%=8
const KSInfoAReserved2%=9
const KSInfoAReserved3%=10

rem For SETFLAGS
const KRestrictTo64K&=&0001
const KAutoCompact&=&0002
const KTwoDigitExponent&=&0004
const KSendSwitchOnMessage&=&010000

rem For GetEvent32
rem Array indexes
const KEvAType%=1
const KEvATime%=2

rem event array keypress subscripts
const KEvAKMod%=4
const KEvAKRep%=5

rem Pointer event array subscripts
const KEvAPtrOplWindowId%=3
const KEvAPtrWindowId%=3
const KEvAPtrType%=4
const KEvAPtrModifiers%=5
const KEvAPtrPositionX%=6
const KEvAPtrPositionY%=7
const KEvAPtrScreenPosX%=8
const KEvAPtrScreenPosY%=9

rem Event types
const KEvNotKeyMask&=&400
const KEvFocusGained&=&401
const KEvFocusLost&=&402
const KEvSwitchOn&=&403
const KEvCommand&=&404
const KEvDateChanged&=&405
const KEvKeyDown&=&406
const KEvKeyUp&=&407
const KEvPtr&=&408
const KEvPtrEnter&=&409
const KEvPtrExit&=&40A

rem Pointer event types
const KEvPtrPenDown&=0
const KEvPtrPenUp&=1
const KEvPtrButton1Down&=KEvPtrPenDown&
const KEvPtrButton1Up&=KEvPtrPenUp&
const KEvPtrButton2Down&=2
const KEvPtrButton2Up&=3
const KEvPtrButton3Down&=4
const KEvPtrButton3Up&=5
const KEvPtrDrag&=6
const KEvPtrMove&=7
const KEvPtrButtonRepeat&=8
const KEvPtrSwitchOn&=9

rem For PointerFilter
const KPointerFilterEnterExit%=$1
const KPointerFilterMove%=$2
const KPointerFilterDrag%=$4

rem code page 1252 ellipsis ("windows latin 1")
const KScreenEllipsis%=133
const KScreenLineFeed%=10

rem For gCLOCK
const KClockLocaleConformant%=6
const KClockSystemSetting%=KClockLocaleConformant%
const KClockAnalog%=7
const KClockDigital%=8
const KClockLargeAnalog%=9
rem gClock 10 no longer supported (use slightly changed gCLOCK 11)
const KClockFormattedDigital%=11

rem For gFONT

const KFontArialBold8&=       268435951
const KFontArialBold11&=      268435952
const KFontArialBold13&=      268435953
const KFontArialNormal8&=     268435954
const KFontArialNormal11&=    268435955
const KFontArialNormal13&=    268435956
const KFontArialNormal15&=    268435957
const KFontArialNormal18&=    268435958
const KFontArialNormal22&=    268435959
const KFontArialNormal27&=    268435960
const KFontArialNormal32&=    268435961

const KFontTimesBold8&=       268435962
const KFontTimesBold11&=      268435963
const KFontTimesBold13&=      268435964
const KFontTimesNormal8&=     268435965
const KFontTimesNormal11&=    268435966
const KFontTimesNormal13&=    268435967
const KFontTimesNormal15&=    268435968
const KFontTimesNormal18&=    268435969
const KFontTimesNormal22&=    268435970
const KFontTimesNormal27&=    268435971
const KFontTimesNormal32&=    268435972

const KFontCourierBold8&=      268436062
const KFontCourierBold11&=     268436063
const KFontCourierBold13&=     268436064
const KFontCourierNormal8&=    268436065
const KFontCourierNormal11&=   268436066
const KFontCourierNormal13&=   268436067
const KFontCourierNormal15&=   268436068
const KFontCourierNormal18&=   268436069
const KFontCourierNormal22&=   268436070
const KFontCourierNormal27&=   268436071
const KFontCourierNormal32&=   268436072

const KFontCalc13n&=   268435493
const KFontCalc18n&=   268435494
const KFontCalc24n&=   268435495

const KFontMon18n&=    268435497
const KFontMon18b&=    268435498
const KFontMon9n&=     268435499
const KFontMon9b&=     268435500

const KFontTiny1&=     268435501
const KFontTiny2&=     268435502
const KFontTiny3&=     268435503
const KFontTiny4&=     268435504

const KFontEiksym15&=  268435661

const KFontSquashed&=  268435701
const KFontDigital35&= 268435752


rem For IOOPEN
rem Mode category 1
const KIoOpenModeOpen%=$0000
const KIoOpenModeCreate%=$0001
const KIoOpenModeReplace%=$0002
const KIoOpenModeAppend%=$0003
const KIoOpenModeUnique%=$0004

rem Mode category 2
const KIoOpenFormatBinary%=$0000
const KIoOpenFormatText%=$0020

rem Mode category 3
const KIoOpenAccessUpdate%=$0100
const KIoOpenAccessRandom%=$0200
const KIoOpenAccessShare%=$0400

rem Language code for CAPTION
const KLangEnglish%=1
const KLangFrench%=2
const KLangGerman%=3
const KLangSpanish%=4
const KLangItalian%=5
const KLangSwedish%=6
const KLangDanish%=7
const KLangNorwegian%=8
const KLangFinnish%=9
const KLangAmerican%=10
const KLangSwissFrench%=11
const KLangSwissGerman%=12
const KLangPortuguese%=13
const KLangTurkish%=14
const KLangIcelandic%=15
const KLangRussian%=16
const KLangHungarian%=17
const KLangDutch%=18
const KLangBelgianFlemish%=19
const KLangAustralian%=20
const KLangBelgianFrench%=21
const KLangAustrian%=22
const KLangNewZealand%=23
const KLangInternationalFrench%=24

REM RGB color masking:
const kRgbRedPosition&=&10000
const kRgbGreenPosition&=$100
const kRgbBluePosition&=$1
const kRgbColorMask&=$ff

REM RGB color values:
const KRgbBlack&=&000000
const KRgbDarkGray&=&555555
const KRgbDarkRed&=&800000
const KRgbDarkGreen&=&008000
const KRgbDarkYellow&=&808000
const KRgbDarkBlue&=&000080
const KRgbDarkMagenta&=&800080
const KRgbDarkCyan&=&008080
const KRgbRed&=&ff0000
const KRgbGreen&=&00ff00
const KRgbYellow&=&ffff00
const KRgbBlue&=&0000ff
const KRgbMagenta&=&ff00ff
const KRgbCyan&=&00ffff
const KRgbGray&=&aaaaaa
const KRgbDitheredLightGray&=&cccccc
const KRgb1in4DitheredGray&=&ededed
const KRgbWhite&=&ffffff

REM MIME priority values:
const KDataTypePriorityUserSpecified%=KMaxInt%
const KDataTypePriorityHigh%=10000
const KDataTypePriorityNormal%=0
const KDataTypePriorityLow%=-10000
const KDataTypePriorityLastResort%=-20000
const KDataTypePriorityNotSupported%=KMinInt%

rem End of Const.oph

]]
