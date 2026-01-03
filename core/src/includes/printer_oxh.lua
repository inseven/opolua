return [[
rem Printer.oxh
rem
rem Copyright (c) 1997-2002 Symbian Ltd. All rights reserved.
rem

CONST KUidOpxPrinter&=&1000025D
CONST KOpxPrinterVersion%=$600

rem Font Posture
CONST KPostureUpright% = 0
CONST KPostureItalic% = 1

rem Font Stroke Weights
CONST KStrokeWeightNormal% = 0
CONST KStrokeWeightBold% = 1    

rem Font Print Position
CONST KPrintPosNormal% = 0
CONST KPrintPosSuperscript% = 1
CONST KPrintPosSubscript% = 2

rem Font Underline
CONST KUnderlineOff% = 0
CONST KUnderlineOn% = 1

rem Strikethrough
CONST KStrikethroughOff% = 0
CONST KStrikethroughOn% = 1
        
rem LineSpacingControl
CONST KLineSpacingAtLeastInTwips% = 0
CONST KLineSpacingExactlyInTwips% = 1
rem CONST KLineSpacingAtLeastInPixels% = 2
rem CONST KLineSpacingExactlyInPixels% = 3

rem Alignment
CONST KPrintLeftAlign% = 0  
CONST KPrintTopAlign% = 0
CONST KPrintCenterAlign% = 1
CONST KPrintRightAlign% = 2
CONST KPrintBottomAlign% = 2
CONST KPrintJustifiedAlign% = 3
CONST KPrintUnspecifiedAlign% = 4
rem CONST KPrintCustomAlign% = 5

DECLARE OPX PRINTER,KUidOpxPrinter&,KOpxPrinterVersion%
    SendStringToPrinter:(string$) :1
    InsertString:(string$,pos&) :2
    SendNewParaToPrinter: :3
    InsertNewPara:(pos&) :4
    SendSpecialCharToPrinter:(character%) :5
    InsertSpecialChar:(character%, pos&) :6
    SetAlignment:(alignment%) :7
    InitialiseParaFormat:(Red%, Green%, Blue%,  LeftMarginInTwips&, RightMarginInTwips&,    IndentInTwips&, HorizontalAlignment%,   VerticalAlignment%, LineSpacingInTwips&,    LineSpacingControl%,            SpaceBeforeInTwips&,    SpaceAfterInTwips&, KeepTogether%,  KeepWithNext%,  StartNewPage%,  WidowOrphan%,   Wrap%,  BorderMarginInTwips&,   DefaultTabWidthInTwips&) :8
    SetLocalParaFormat: :9
    SetGlobalParaFormat: :10
    RemoveSpecificParaFormat: :11
    SetFontName:(name$) :12
    SetFontHeight:(height%) :13
    SetFontPosition:(pos%) :14
    SetFontWeight:(weight%) :15
    SetFontPosture:(posture%) :16
    SetFontStrikethrough:(strikethrough%) :17
    SetFontUnderline:(underline%) :18
    SetGlobalCharFormat: :19
    RemoveSpecificCharFormat: :20
    SendBitmapToPrinter:(bitmapHandle&) :21
    InsertBitmap:(bitmapHandle&, pos&) :22
    SendScaledBitmapToPrinter:(bitmapHandle&, xScale&, yScale&) :23
    InsertScaledBitmap:(bitmapHandle&, pos&, xScale&, yScale&) :24
    PrinterDocLength&: :25
    SendRichTextToPrinter:(richTextAddress&) :26
    ResetPrinting: :27
    PageSetupDialog: :28
    PrintPreviewDialog: :29
    PrintRangeDialog: :30
    PrintDialog: :31
    SendBufferToPrinter:(addr&) :32
END DECLARE
]]