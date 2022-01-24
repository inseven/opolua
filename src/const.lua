-- CONST.OPH version 1.10
-- Constants for OPL
-- Last edited on 19 May 1997
-- (C) Copyright Psion PLC 1997
-- General constants

-- 2022-01-18: Formatting and minor modifications by tomsci

KTrue = -1
KFalse = 0

-- Special keys
KKeyEsc = 27
KKeySpace = 32
KKeyDel = 8
KKeyTab = 9
KKeyEnter = 13
KGetMenu = 4150
KKeyUpArrow = 4105
KKeyDownArrow = 4106
KKeyLeftArrow = 4103
KKeyRightArrow = 4104
KKeyPageUp = 4100
KKeyPageDown = 4101
KKeyPageLeft = 4098
KKeyPageRight = 4099

-- Month numbers
KJanuary = 1
KFebruary = 2
KMarch = 3
KApril = 4
KMay = 5
KJune = 6
KJuly = 7
KAugust = 8
KSeptember = 9
KOctober = 10
KNovember = 11
KDecember = 12

-- Graphics
KDefaultWin = 1
KgModeSet = 0
KgModeClear = 1
KgModeInvert = 2
KtModeSet = 0
KtModeClear = 1
KtModeInvert = 2
KtModeReplace = 3

KgStyleNormal = 0
KgStyleBold = 1
KgStyleUnder = 2
KgStyleInverse = 4
KgStyleDoubleHeight = 8
KgStyleMonoFont = 16
KgStyleItalic = 32

-- For 32-bit status words IOWAIT and IOWAITSTAT32
-- Use KErrFilePending (-46) for 16-bit status words
-- KStatusPending32 = 0x80000001

-- Error codes
KErrGenFail = -1
KErrInvalidArgs = -2
KErrOs = -3
KErrNotSupported = -4
KErrUnderflow = -5
KErrOverflow = -6
KErrOutOfRange = -7
KErrDivideByZero = -8
KErrInUse = -9
KErrNoMemory = -10
KErrNoSegments = -11
KErrNoSemaphore = -12
KErrNoProcess = -13
KErrAlreadyOpen = -14
KErrNotOpen = -15
KErrImage = -16
KErrNoReceiver = -17
KErrNoDevices = -18
KErrNoFileSystem = -19
KErrFailedToStart = -20
KErrFontNotLoaded = -21
KErrTooWide = -22
KErrTooManyItems = -23
KErrBatLowSound = -24
KErrBatLowFlash = -25
KErrExists = -32
KErrNotExists = -33
KErrWrite = -34
KErrRead = -35
KErrEof = -36
KErrFull = -37
KErrName = -38
KErrAccess = -39
KErrLocked = -40
KErrDevNotExist = -41
KErrDir = -42
KErrRecord = -43
KErrReadOnly = -44
KErrInvalidIO = -45
KErrFilePending = -46
KErrVolume = -47
KErrIOCancelled = -48
-- OPL specific errors
KErrSyntax = -77
KOplStructure = -85
KErrIllegal = -96
KErrNumArg = -97
KErrUndef = -98
KErrNoProc = -99
KErrNoFld = -100
KErrOpen = -101
KErrClosed = -102
KErrRecSize = -103
KErrModLoad = -104
KErrMaxLoad = -105
KErrNoMod = -106
KErrNewVer = -107
KErrModNotLoaded = -108
KErrBadFileType = -109
KErrTypeViol = -110
KErrSubs = -111
KErrStrTooLong = -112
KErrDevOpen = -113
KErrEsc = -114
KErrMaxDraw = -117
KErrDrawNotOpen = -118
KErrInvalidWindow = -119
KErrScreenDenied = -120
KErrOpxNotFound = -121
KErrOpxVersion = -122
KErrOpxProcNotFound = -123
KErrStopInCallback = -124
KErrIncompUpdateMode = -125
KErrInTransaction = -126

-- For ALERT
KAlertEsc = 1
KAlertEnter = 2
KAlertSpace = 3

 -- For BUSY and GIPRINT
KBusyTopLeft = 0
KBusyBottomLeft = 1
KBusyTopRight = 2
KBusyBottomRight = 3
KBusyMaxText = 80

-- For CMD$
KCmdAppName = 1 -- Full path name used to start program
KCmdUsedFile = 2
KCmdLetter = 3
-- For CMD$(3)
KCmdLetterCreate = "C"
KCmdLetterOpen = "O"
KCmdLetterRun = "R"

-- For CURSOR
KCursorTypeNotFlashing = 2
KCursorTypeGrey = 4

-- For DATIM$ - offsets
KDatimOffDayName = 1
KDatimOffDay = 5
KDatimOffMonth = 8
KDatimOffYear = 12
KDatimOffHour = 17
KDatimOffMinute = 20
KDatimOffSecond = 23

-- For dBUTTON
KDButtonNoLabel = 0x100
KDButtonPlainKey = 0x200
KDButtonDel = 8
KDButtonTab = 9
KDButtonEnter = 13
KDButtonEsc = 27
KDButtonSpace = 32

-- For dEDITMULTI and printing
KParagraphDelimiter = 0x06
KLineBreak = 0x07
KPageBreak = 0x08
KTabCharacter = 0x09
KNonBreakingTab = 0x0a
KNonBreakingHyphen = 0x0b
KPotentialHyphen = 0x0c
KNonBreakingSpace = 0x10
KPictureCharacter = 0x0e
KVisibleSpaceCharacter = 0x0f

 -- For DEFAULTWIN
KDefWin4ColourMode = 1
KDefWin16ColourMode = 2

-- For dFILE
KDFileNameLen = 255
-- flags
KDFileEditBox = 0x0001
KDFileAllowFolders = 0x0002
KDFileFoldersOnly = 0x0004
KDFileEditorDisallowExisting = 0x0008
KDFileEditorQueryExisting = 0x0010
KDFileAllowNullStrings = 0x0020
KDFileAllowWildCards = 0x0080
KDFileSelectorWithRom = 0x0100
KDFileSelectorWithSystem = 0x0200

-- Opl-related Uids for dFILE
KUidDirectFileStore = 0x10000037
-- tomsci: conflicts KUidOplInterpreter = 0x10000077
KUidOplApp = 0x10000074
KUidOplDoc = 0x10000075
KUidOPO = 0x10000073
KUidOplFile = 0x1000008A
KUidOpxDll = 0x1000005D

-- For DIALOG
KDlgCancel = 0

-- For dINIT (flags for dialogs)
KDlgButRight = 1
KDlgNoTitle = 2
KDlgFillScreen = 4
KDlgNoDrag = 8
KDlgDensePack = 16

-- For DOW
KMonday = 1
KTuesday = 2
KWednesday = 3
KThursday = 4
KFriday = 5
KSaturday = 6
KSunday = 7

-- For dPOSITION
KDPositionLeft = -1
KDPositionCentre = 0
KDPositionRight = 1

-- For dTEXT
KDTextLeft = 0
KDTextRight = 1
KDTextCentre = 2
KDTextBold = 0x100 -- Ignored in Eikon
KDTextLineBelow = 0x200
KDTextAllowSelection = 0x400
KDTextSeparator = 0x800

-- For dTIME
KDTimeAbsNoSecs = 0
KDTimeAbsWithSecs = 1
KDTimeDurationNoSecs = 2
KDTimeDurationWithSecs = 3
-- Flags for dTIME (for ORing combinations)
KDTimeWithSeconds = 1
KDTimeDuration = 2
KDTimeNoHours = 4
KDTime24Hour = 8

-- For dXINPUT
KDXInputMaxLen = 16

-- For FINDFIELD
KFindCaseDependent = 16
KFindBackwards = 0
KFindForwards = 1
KFindBackwardsFromEnd = 2
KFindForwardsFromStart = 3

-- For FLAGS
KFlagsAppFileBased = 1
KFlagsAppIsHidden = 2

-- For gBORDER and gXBORDER
KBordSglShadow = 1
KBordSglGap = 2
KBordDblShadow = 3
KBordDblGap = 4
KBordGapAllRound = 0x100
KBordRoundCorners = 0x200
KBordLosePixel = 0x400

-- For gBUTTON
KButtS3 = 0
KButtS3Raised = 0
KButtS3Pressed = 1
KButtS3a = 1
KButtS3aRaised = 0
KButtS3aSemiPressed = 1
KButtS3aSunken = 2
KButtS5 = 2
KButtS5Raised = 0
KButtS5SemiPressed = 1
KButtS5Sunken = 2
KButtLayoutTextRightPictureLeft = 0
KButtLayoutTextBottomPictureTop = 1
KButtLayoutTextTopPictureBottom = 2
KButtLayoutTextLeftPictureRight = 3
KButtTextRight = 0
KButtTextBottom = 1
KButtTextTop = 2
KButtTextLeft = 3
KButtExcessShare = 0x00
KButtExcessToText = 0x10
KButtExcessToPicture = 0x20

-- For gCLOCK
KgClockS5System = 6
KgClockS5Analog = 7
KgClockS5Digital = 8
KgClockS5LargeAnalog = 9
KgClockS5Formatted = 11

-- For gCREATE
KgCreateInvisible = 0
KgCreateVisible = 1
KgCreateHasShadow = 0x0010
-- tomsci: updated
-- Color mode constants
KgCreate2GrayMode = 0x0000
KgCreate4GrayMode = 0x0001
KgCreate16GrayMode = 0x0002
KgCreate256GrayMode = 0x0003
KgCreate16ColorMode = 0x0004
KgCreate256ColorMode = 0x0005
KgCreate64KColorMode = 0x0006
KgCreate16MColorMode = 0x0007
KgCreateRGBColorMode = 0x0008
KgCreate4KColorMode = 0x0009

-- For GETCMD$
KGetCmdLetterCreate = "C"
KGetCmdLetterOpen = "O"
KGetCmdLetterExit = "X"
KGetCmdLetterUnknown = "U"

-- For gLOADBIT
KgLoadBitReadOnly = 0
KgLoadBitWriteable = 1

-- For gRANK
KgRankForeground = 1
KgRankBackGround = 32767

-- For gPOLY - array subscripts
KgPolyAStartX = 1
KgPolyAStartY = 2
KgPolyANumPairs = 3
KgPolyANumDx1 = 4
KgPolyANumDy1 = 5

 -- For gPRINTB
KgPrintBRightAligned = 1
KgPrintBLeftAligned = 2
KgPrintBCentredAligned = 3
-- The defaults
KgPrintBDefAligned = KgPrintBLeftAligned
KgPrintBDefTop = 0
KgPrintBDefBottom = 0
KgPrintBDefMargin = 0

-- For gXBORDER
KgXBorderS3Type = 0
KgXBorderS3aType = 1
KgXBorderS5Type = 2
-- For gXPRINT
KgXPrintNormal = 0
KgXPrintInverse = 1
KgXPrintInverseRound = 2
KgXPrintThinInverse = 3
KgXPrintThinInverseRound = 4
KgXPrintUnderlined = 5
KgXPrintThinUnderlined = 6

-- For KMOD
KKmodShift = 2
KKmodControl = 4
KKmodPsion = 8
KKmodCaps = 16
KKmodFn = 32

-- For mCARD and mCASC
KMenuDimmed = 0x1000
KMenuSymbolOn = 0x2000
KMenuSymbolIndeterminate = 0x4000
KMenuCheckBox = 0x0800
KMenuOptionStart = 0x0900
KMenuOptionMiddle = 0x0A00
KMenuOptionEnd = 0x0B00

-- For mPOPUP position type
-- Specifies which corner of the popup is given by the coordinates
KMPopupPosTopLeft = 0
KMPopupPosTopRight = 1
KMPopupPosBottomLeft = 2
KMPopupPosBottomRight = 3

-- For PARSE$ - array subscripts
KParseAOffFSys = 1
KParseAOffDev = 2
KParseAOffPath = 3
KParseAOffFilename = 4
KParseAOffExt = 5
KParseAOffWild = 6
-- Wild-card flags
KParseWildNone = 0
KParseWildFilename = 1
KParseWildExt = 2
KParseWildBoth = 3

-- For SCREENINFO - array subscripts
KSInfoALeft = 1
KSInfoATop = 2
KSInfoAScrW = 3
KSInfoAScrH = 4
KSInfoAReserved1 = 5
KSInfoAFont = 6
KSInfoAPixW = 7
KSInfoAPixH = 8
KSInfoAReserved2 = 9
KSInfoAReserved3 = 10

-- For SETFLAGS
KRestrictTo64K = 0x0001
KAutoCompact = 0x0002
KTwoDigitExponent = 0x0004
KSendSwitchOnMessage = 0x010000

-- For GetEvent32
-- Array indexes
KEvAType = 1
KEvATime = 2

-- Event array keypress subscripts
KEvAKMod = 4
KEvAKRep = 5

-- Pointer event array subscripts
KEvAPtrOplWindowId = 3
KEvAPtrWindowId = 3
KEvAPtrType = 4
KEvAPtrModifiers = 5
KEvAPtrPositionX = 6
KEvAPtrPositionY = 7
KEvAPtrScreenPosX = 8
KEvAPtrScreenPosY = 9

-- Event types
KEvNotKeyMask = 0x400
KEvFocusGained = 0x401
KEvFocusLost = 0x402
KEvSwitchOn = 0x403
KEvCommand = 0x404
KEvDateChanged = 0x405
KEvKeyDown = 0x406
KEvKeyUp = 0x407
KEvPtr = 0x408
KEvPtrEnter = 0x409
KEvPtrExit = 0x40A

-- Pointer event types
KEvPtrPenDown = 0
KEvPtrPenUp = 1
KEvPtrButton1Down = KEvPtrPenDown
KEvPtrButton1Up = KEvPtrPenUp
KEvPtrButton2Down = 2
KEvPtrButton2Up = 3
KEvPtrButton3Down = 4
KEvPtrButton3Up = 5
KEvPtrDrag = 6
KEvPtrMove = 7
KEvPtrButtonRepeat = 8
KEvPtrSwitchOn = 9
KKeyMenu = 4150
KKeySidebarMenu = 10000

-- For PointerFilter
KPointerFilterEnterExit = 0x1
KPointerFilterMove = 0x2
KPointerFilterDrag = 0x4

-- Code page 1252 ellipsis (“windows latin 1")
KScreenEllipsis = 133
KScreenLineFeed = 10

-- For gCLOCK
KClockLocaleConformant = 6
KClockSystemSetting = KClockLocaleConformant
KClockAnalog = 7
KClockDigital = 8
KClockLargeAnalog = 9
-- GClock 10 no longer supported (use slightly changed gCLOCK 11)
KClockFormattedDigital = 11

-- For gFONT
-- tomsci: UIDs converted with lua -e "for line in io.lines() do print((line:gsub('(%s+)([0-9]+)%s*', function(s, m) return string.format('%s0x%08X', s, tonumber(m)) end))) end"
KFontArialBold8 = 0x100001EF
KFontArialBold11 = 0x100001F0
KFontArialBold13 = 0x100001F1
KFontArialNormal8 = 0x100001F2
KFontArialNormal11 = 0x100001F3
KFontArialNormal13 = 0x100001F4
KFontArialNormal15 = 0x100001F5
KFontArialNormal18 = 0x100001F6
KFontArialNormal22 = 0x100001F7
KFontArialNormal27 = 0x100001F8
KFontArialNormal32 = 0x100001F9
KFontTimesBold8 = 0x100001FA
KFontTimesBold11 = 0x100001FB
KFontTimesBold13 = 0x100001FC
KFontTimesNormal8 = 0x100001FD
KFontTimesNormal11 = 0x100001FE
KFontTimesNormal13 = 0x100001FF
KFontTimesNormal15 = 0x10000200
KFontTimesNormal18 = 0x10000201
KFontTimesNormal22 = 0x10000202
KFontTimesNormal27 = 0x10000203
KFontTimesNormal32 = 0x10000204
KFontCourierBold8 = 0x1000025E
KFontCourierBold11 = 0x1000025F
KFontCourierBold13 = 0x10000260
KFontCourierNormal8 = 0x10000261
KFontCourierNormal11 = 0x10000262
KFontCourierNormal13 = 0x10000263
KFontCourierNormal15 = 0x10000264
KFontCourierNormal18 = 0x10000265
KFontCourierNormal22 = 0x10000266
KFontCourierNormal27 = 0x10000267
KFontCourierNormal32 = 0x10000268
KFontTiny4 = 0x10000030
KFontEiksym15 = 0x100000CD
KFontSquashed = 0x100000F5
KFontDigital35 = 0x10000128

-- For IOOPEN
-- Mode category 1
KIoOpenModeOpen = 0x0000
KIoOpenModeCreate = 0x0001
KIoOpenModeReplace = 0x0002
KIoOpenModeAppend = 0x0003
KIoOpenModeUnique = 0x0004
-- Mode category 2
KIoOpenFormatBinary = 0x0000
KIoOpenFormatText = 0x0020
-- Mode category 3
KIoOpenAccessUpdate = 0x0100
KIoOpenAccessRandom = 0x0200
KIoOpenAccessShare = 0x0400

-- tomsci: added
-- For IOSEEK
KIoSeekFromStart = 1
KIoSeekFromEnd = 2
KIoSeekFromCurrent = 3
KIoSeekFirstRecord = 6

-- Language code for CAPTION
KLangEnglish = 1
KLangFrench = 2
KLangGerman = 3
KLangSpanish = 4
KLangItalian = 5
KLangSwedish = 6
KLangDanish = 7
KLangNorwegian = 8
KLangFinnish = 9
KLangAmerican = 10
KLangSwissFrench = 11
KLangSwissGerman = 12
KLangPortuguese = 13
KLangTurkish = 14
KLangIcelandic = 15
KLangRussian = 16
KLangHungarian = 17
KLangDutch = 18
KLangBelgianFlemish = 19
KLangAustralian = 20
KLangBelgianFrench = 21
KLangAustrian = 22
KLangNewZealand = 23
KLangInternationalFrench = 24
