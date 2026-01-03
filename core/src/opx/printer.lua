--[[

Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe

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
    [1] = "SendStringToPrinter",
    [2] = "InsertString",
    [3] = "SendNewParaToPrinter",
    [4] = "InsertNewPara",
    [5] = "SendSpecialCharToPrinter",
    [6] = "InsertSpecialChar",
    [7] = "SetAlignment",
    [8] = "InitialiseParaFormat",
    [9] = "SetLocalParaFormat",
    [10] = "SetGlobalParaFormat",
    [11] = "RemoveSpecificParaFormat",
    [12] = "SetFontName",
    [13] = "SetFontHeight",
    [14] = "SetFontPosition",
    [15] = "SetFontWeight",
    [16] = "SetFontPosture",
    [17] = "SetFontStrikethrough",
    [18] = "SetFontUnderline",
    [19] = "SetGlobalCharFormat",
    [20] = "RemoveSpecificCharFormat",
    [21] = "SendBitmapToPrinter",
    [22] = "InsertBitmap",
    [23] = "SendScaledBitmapToPrinter",
    [24] = "InsertScaledBitmap",
    [25] = "PrinterDocLength",
    [26] = "SendRichTextToPrinter",
    [27] = "ResetPrinting",
    [28] = "PageSetupDialog",
    [29] = "PrintPreviewDialog",
    [30] = "PrintRangeDialog",
    [31] = "PrintDialog",
    [32] = "SendBufferToPrinter",
}

function SendStringToPrinter(stack, runtime) -- 1
    unimplemented("opx.printer.SendStringToPrinter")
end

function InsertString(stack, runtime) -- 2
    unimplemented("opx.printer.InsertString")
end

function SendNewParaToPrinter(stack, runtime) -- 3
    unimplemented("opx.printer.SendNewParaToPrinter")
end

function InsertNewPara(stack, runtime) -- 4
    unimplemented("opx.printer.InsertNewPara")
end

function SendSpecialCharToPrinter(stack, runtime) -- 5
    unimplemented("opx.printer.SendSpecialCharToPrinter")
end

function InsertSpecialChar(stack, runtime) -- 6
    unimplemented("opx.printer.InsertSpecialChar")
end

function SetAlignment(stack, runtime) -- 7
    unimplemented("opx.printer.SetAlignment")
end

function InitialiseParaFormat(stack, runtime) -- 8
    unimplemented("opx.printer.InitialiseParaFormat")
end

function SetLocalParaFormat(stack, runtime) -- 9
    unimplemented("opx.printer.SetLocalParaFormat")
end

function SetGlobalParaFormat(stack, runtime) -- 10
    unimplemented("opx.printer.SetGlobalParaFormat")
end

function RemoveSpecificParaFormat(stack, runtime) -- 11
    unimplemented("opx.printer.RemoveSpecificParaFormat")
end

function SetFontName(stack, runtime) -- 12
    unimplemented("opx.printer.SetFontName")
end

function SetFontHeight(stack, runtime) -- 13
    unimplemented("opx.printer.SetFontHeight")
end

function SetFontPosition(stack, runtime) -- 14
    unimplemented("opx.printer.SetFontPosition")
end

function SetFontWeight(stack, runtime) -- 15
    unimplemented("opx.printer.SetFontWeight")
end

function SetFontPosture(stack, runtime) -- 16
    unimplemented("opx.printer.SetFontPosture")
end

function SetFontStrikethrough(stack, runtime) -- 17
    unimplemented("opx.printer.SetFontStrikethrough")
end

function SetFontUnderline(stack, runtime) -- 18
    unimplemented("opx.printer.SetFontUnderline")
end

function SetGlobalCharFormat(stack, runtime) -- 19
    unimplemented("opx.printer.SetGlobalCharFormat")
end

function RemoveSpecificCharFormat(stack, runtime) -- 20
    unimplemented("opx.printer.RemoveSpecificCharFormat")
end

function SendBitmapToPrinter(stack, runtime) -- 21
    unimplemented("opx.printer.SendBitmapToPrinter")
end

function InsertBitmap(stack, runtime) -- 22
    unimplemented("opx.printer.InsertBitmap")
end

function SendScaledBitmapToPrinter(stack, runtime) -- 23
    unimplemented("opx.printer.SendScaledBitmapToPrinter")
end

function InsertScaledBitmap(stack, runtime) -- 24
    unimplemented("opx.printer.InsertScaledBitmap")
end

function PrinterDocLength(stack, runtime) -- 25
    unimplemented("opx.printer.PrinterDocLength")
end

function SendRichTextToPrinter(stack, runtime) -- 26
    unimplemented("opx.printer.SendRichTextToPrinter")
end

function ResetPrinting(stack, runtime) -- 27
    -- unimplemented("opx.printer.ResetPrinting")
    stack:push(0)
end

function PageSetupDialog(stack, runtime) -- 28
    unimplemented("opx.printer.PageSetupDialog")
end

function PrintPreviewDialog(stack, runtime) -- 29
    unimplemented("opx.printer.PrintPreviewDialog")
end

function PrintRangeDialog(stack, runtime) -- 30
    unimplemented("opx.printer.PrintRangeDialog")
end

function PrintDialog(stack, runtime) -- 31
    unimplemented("opx.printer.PrintDialog")
end

function SendBufferToPrinter(stack, runtime) -- 32
    unimplemented("opx.printer.SendBufferToPrinter")
end


return _ENV
