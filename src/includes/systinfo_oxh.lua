return [[
rem SYSTINFO.OXH
rem 
rem Copyright (c) 1997-2000 Symbian Ltd. All rights reserved.

CONST KOpxSystinfoUid&=&10000B90
CONST KOpxSystinfoVersion%=$510

CONST KDateFormatAmerican&=0
CONST KDateFormatEuropean&=1
CONST KDateFormatJapanese&=2

CONST KTimeFormat12Hour&=0
CONST KTimeFormat24Hour&=1

CONST KDaylightSavingZoneHome&=0
CONST KDaylightSavingZoneEuropean&=1
CONST KDaylightSavingZoneNorthern&=2
CONST KDaylightSavingZoneSouthern&=4

CONST KUnitsImperial&=0
CONST KUnitsMetric&=1

CONST KSwitchOffDisabled&=0
CONST KSwitchOffEnabledOnBatteries&=1
CONST KSwitchOffEnabledAlways&=2

CONST KBacklightBehaviorTimed&=0
CONST KBacklightBehaviorUntimed&=1

CONST KRemoteLinkDisabled&=0
CONST KRemoteLinkDisconnected&=1 
CONST KRemoteLinkConnected&=2

CONST KLinkTypeUnknown%=0
CONST KLinkTypeCable%=1
CONST KLinkTypeIrDA%=2

CONST KLinkBpsUnknown%=0
CONST KLinkBps9600%=1
CONST KLinkBps19200%=2
CONST KLinkBps38400%=3
CONST KLinkBps57600%=4
CONST KLinkBps115200%=5

DECLARE OPX SYSTINFO,KOpxSystinfoUid&,KOpxSystinfoVersion%
    SISystemVisible&: : 1
    SIHiddenVisible&: : 2
    SICurrencyFormat$:(BYREF aDecimalPlaces&,BYREF aNegativeInBrackets&,BYREF aSpaceBetween&,BYREF aSymbolPosition&,BYREF aTriadsAllowed&) : 3
    SIDateFormat:(BYREF aDateFormat&,BYREF aDateSeparator0%,BYREF aDateSeparator1%,BYREF aDateSeparator2%,BYREF aDateSeparator3%) : 4
    SITimeFormat:(BYREF aTimeFormat&,BYREF aTimeSeparator0%,BYREF aTimeSeparator1%,BYREF aTimeSeparator2%,BYREF aTimeSeparator3%,BYREF aAmPmSpaceBetween&,BYREF aAmPmSymbolPosition&) : 5
    SIUTCOffset&: : 6
    SIWorkday%:(aDayNumber&) : 7
    SIDaylightSaving%:(aDaylightSavingZone&) : 8
    SIHomeCountry$: : 9
    SIUnits:(BYREF aUnitsGeneral&,BYREF aUnitsDistanceShort&,BYREF aUnitsDistanceLong&) : 10
    SIIsDirectory&:(aPath$) : 11
    SIVolumeName$:(aDriveNumber&) : 12
    SIUniqueFilename$:(aFilename$) : 13
    SIBookmark$: : 14
    SIStandardFolder$: : 15
    SIDisplayContrast&: : 16
    SIOwner$: : 17
    SIBatteryVolts:(BYREF aMainBatteryMilliVolts&,BYREF aMainBatteryMaxMilliVolts&,BYREF aBackupBatteryMilliVolts&,BYREF aBackupBatteryMaxMilliVolts&) : 18
    SIBatteryCurrent:(BYREF aCurrentConsumptionMilliAmps&,BYREF aMainBatteryUsedMilliAmpSeconds&,BYREF aMainBatteryInUseSeconds&,BYREF aExternalPowerInUseSeconds&,BYREF aExternalPowerPresent&,aMainBatteryInsertionTime&) : 19
    SIMemory:(BYREF aTotalRamInBytes&,BYREF aTotalRomInBytes&,BYREF aMaxFreeRamInBytes&,BYREF aFreeRamInBytes&,BYREF aInternalRamDiskUsedInBytes&) : 20
    SIKeyClickEnabled%: : 21
    SIKeyClickLoud%: : 22
    SIKeyClickOverridden%: : 23
    SIPointerClickEnabled%: : 24
    SIPointerClickLoud%: : 25
    SIBeepEnabled%: : 26
    SIBeepLoud%: : 27
    SISoundDriverEnabled%: : 28
    SISoundDriverLoud%: : 29
    SISoundEnabled%: : 30
    SIAutoSwitchOffBehaviour&: : 31
    SIAutoSwitchOffTime&: : 32
    SIBacklightBehaviour&: : 33
    SIBacklightOnTime&: : 34
    SIDisplaySize:(BYREF aDisplayWidthInPixels&,BYREF aDisplayHeightInPixels&,BYREF aXYInputWidthInPixels&,BYREF aXYInputHeightInPixels&,BYREF aPhysicalScreenWidth&,BYREF aPhysicalScreenHeight&) : 35
    SIKeyboardIndex&: : 36
    SILanguageIndex&: : 37
    SIXYInputPresent%: : 38
    SIKeyboardPresent%: : 39
    SIMaximumColors&: : 40
    SIProcessorClock&: : 41
    SISpeedFactor&: : 42
    SIMachine$: : 43
    SIRemoteLinkStatus&: : 44
    SIRemoteLinkDisable: : 45
    SIIsPathVisible&:(aPath$) : 46
    SIRemoteLinkEnable: : 47
    SIPWIsEnabled%: : 48
    SIPWSetEnabled:(aPassword$,aEnable%) : 49
    SIPWIsValid%:(aPassword$) : 50
    SIPWSet:(aOldPassword$,aNewPassword$) : 51
    SILedSet:(aState%) : 52
    SIRemoteLinkEnableWithOptions:(aLinkType%,aBaudRate%) : 53
    SIRemoteLinkConfig:(BYREF aLinkType%, BYREF aBaudRate%) : 54
END DECLARE
]]