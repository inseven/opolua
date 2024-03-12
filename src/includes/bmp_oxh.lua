return [[
rem BMP.OXH version 1.00
rem Header File for BMP.OPX
rem Copyright (c) 1997-1998 Symbian Ltd. All rights reserved.

DECLARE OPX BMP,&10000258,$100
	BITMAPLOAD&:(name$,index&) : 1
	BITMAPUNLOAD:(id&) : 2
	BITMAPDISPLAYMODE&:(id&) : 3
	SPRITECREATE&:(winId%,x&,y&,flags&) : 4
	SPRITEAPPEND:(time&,bitmap&,maskBitmap&,invertMask&,dx&,dy&) : 5
	SPRITECHANGE:(index&,time&,bitmap&,maskBitmap&,invertMask&,dx&,dy&) : 6
	SPRITEDRAW:() : 7
	SPRITEPOS:(x&,y&) : 8
	SPRITEDELETE:(id&) : 9
	SPRITEUSE:(id&) : 10
END DECLARE
]]