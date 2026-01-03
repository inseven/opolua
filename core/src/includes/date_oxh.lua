return [[
rem DATE.OXH version 1.01
rem Header File for DATE.OPX
rem Copyright (c) 1997-1998 Symbian Ltd. All rights reserved.
rem Changes in 1.01:
rem  Fixed day range bug in DtNewDateTime: and DtSetDay:
rem  Corrected ranges in DtNewDateTime:, DtSetHour:, DtSetMinute:,
rem  DtSetSecond: and DtSetMicro

CONST KLCAnalogClock&=0
CONST KLCDigitalClock&=1

CONST KUidOpxDate&=&1000025A
CONST KOpxDateVersion%=$101

DECLARE OPX DATE,KUidOpxDate&,KOpxDateVersion%
	DTNewDateTime&:(year&,month&,day&,hour&,minute&,second&,micro&) : 1
	DTDeleteDateTime:(id&) : 2
	DTYear&:(id&) : 3
	DTMonth&:(id&) : 4
	DTDay&:(id&) : 5
	DTHour&:(id&) : 6
	DTMinute&:(id&) : 7
	DTSecond&:(id&) : 8
	DTMicro&:(id&) : 9
	DTSetYear:(id&,year&) : 10
	DTSetMonth:(id&,month&) : 11
	DTSetDay:(id&,day&) : 12
	DTSetHour:(id&,hour&) : 13
	DTSetMinute:(id&,minute&) : 14
	DTSetSecond:(id&,second&) : 15
	DTSetMicro:(id&,micro&) : 16
	DTNow&: : 17
	DTDateTimeDiff:(start&,end&,BYREF year&,BYREF month&,BYREF day&,BYREF hour&,BYREF minute&,BYREF second&,BYREF micro&) : 18
	DTYearsDiff&:(start&,end&) : 19
	DTMonthsDiff&:(start&,end&) : 20
	DTDaysDiff&:(start&,end&) : 21
	DTHoursDiff&:(start&,end&) : 22
	DTMinutesDiff&:(start&,end&) : 23
	DTSecsDiff&:(start&,end&) : 24
	DTMicrosDiff&:(start&,end&) : 25
	DTWeekNoInYear&:(id&,yearstart&,rule&) : 26
	DTDayNoInYear&:(id&,yearstart&) : 27
	DTDayNoInWeek&:(id&) : 28
	DTDaysInMonth&:(id&) : 29
	DTSetHomeTime:(id&) : 30
	LCCountryCode&: : 31
	LCDecimalSeparator$: : 32
	LCSetClockFormat:(format&) : 33
	LCClockFormat&: : 34
	LCStartOfWeek&: : 35
	LCThousandsSeparator$: : 36
END DECLARE
]]
