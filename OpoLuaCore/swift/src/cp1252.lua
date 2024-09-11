--[[

Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe

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

-- From https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt
local map = {
    ['\x80'] = "\u{20AC}", -- Euro Sign
    ['\x81'] = "\u{0081}", 
    ['\x82'] = "\u{201A}", -- Single Low-9 Quotation Mark
    ['\x83'] = "\u{0192}", -- Latin Small Letter F With Hook
    ['\x84'] = "\u{201E}", -- Double Low-9 Quotation Mark
    ['\x85'] = "\u{2026}", -- Horizontal Ellipsis
    ['\x86'] = "\u{2020}", -- Dagger
    ['\x87'] = "\u{2021}", -- Double Dagger
    ['\x88'] = "\u{02C6}", -- Modifier Letter Circumflex Accent
    ['\x89'] = "\u{2030}", -- Per Mille Sign
    ['\x8A'] = "\u{0160}", -- Latin Capital Letter S With Caron
    ['\x8B'] = "\u{2039}", -- Single Left-Pointing Angle Quotation Mark
    ['\x8C'] = "\u{0152}", -- Latin Capital Ligature Oe
    ['\x8D'] = "\u{008D}", 
    ['\x8E'] = "\u{017D}", -- Latin Capital Letter Z With Caron
    ['\x8F'] = "\u{008F}", 
    ['\x90'] = "\u{0090}", 
    ['\x91'] = "\u{2018}", -- Left Single Quotation Mark
    ['\x92'] = "\u{2019}", -- Right Single Quotation Mark
    ['\x93'] = "\u{201C}", -- Left Double Quotation Mark
    ['\x94'] = "\u{201D}", -- Right Double Quotation Mark
    ['\x95'] = "\u{2022}", -- Bullet
    ['\x96'] = "\u{2013}", -- En Dash
    ['\x97'] = "\u{2014}", -- Em Dash
    ['\x98'] = "\u{02DC}", -- Small Tilde
    ['\x99'] = "\u{2122}", -- Trade Mark Sign
    ['\x9A'] = "\u{0161}", -- Latin Small Letter S With Caron
    ['\x9B'] = "\u{203A}", -- Single Right-Pointing Angle Quotation Mark
    ['\x9C'] = "\u{0153}", -- Latin Small Ligature Oe
    ['\x9D'] = "\u{009D}", 
    ['\x9E'] = "\u{017E}", -- Latin Small Letter Z With Caron
    ['\x9F'] = "\u{0178}", -- Latin Capital Letter Y With Diaeresis
    ['\xA0'] = "\u{00A0}", -- No-Break Space
    ['\xA1'] = "\u{00A1}", -- Inverted Exclamation Mark
    ['\xA2'] = "\u{00A2}", -- Cent Sign
    ['\xA3'] = "\u{00A3}", -- Pound Sign
    ['\xA4'] = "\u{00A4}", -- Currency Sign
    ['\xA5'] = "\u{00A5}", -- Yen Sign
    ['\xA6'] = "\u{00A6}", -- Broken Bar
    ['\xA7'] = "\u{00A7}", -- Section Sign
    ['\xA8'] = "\u{00A8}", -- Diaeresis
    ['\xA9'] = "\u{00A9}", -- Copyright Sign
    ['\xAA'] = "\u{00AA}", -- Feminine Ordinal Indicator
    ['\xAB'] = "\u{00AB}", -- Left-Pointing Double Angle Quotation Mark
    ['\xAC'] = "\u{00AC}", -- Not Sign
    ['\xAD'] = "\u{00AD}", -- Soft Hyphen
    ['\xAE'] = "\u{00AE}", -- Registered Sign
    ['\xAF'] = "\u{00AF}", -- Macron
    ['\xB0'] = "\u{00B0}", -- Degree Sign
    ['\xB1'] = "\u{00B1}", -- Plus-Minus Sign
    ['\xB2'] = "\u{00B2}", -- Superscript Two
    ['\xB3'] = "\u{00B3}", -- Superscript Three
    ['\xB4'] = "\u{00B4}", -- Acute Accent
    ['\xB5'] = "\u{00B5}", -- Micro Sign
    ['\xB6'] = "\u{00B6}", -- Pilcrow Sign
    ['\xB7'] = "\u{00B7}", -- Middle Dot
    ['\xB8'] = "\u{00B8}", -- Cedilla
    ['\xB9'] = "\u{00B9}", -- Superscript One
    ['\xBA'] = "\u{00BA}", -- Masculine Ordinal Indicator
    ['\xBB'] = "\u{00BB}", -- Right-Pointing Double Angle Quotation Mark
    ['\xBC'] = "\u{00BC}", -- Vulgar Fraction One Quarter
    ['\xBD'] = "\u{00BD}", -- Vulgar Fraction One Half
    ['\xBE'] = "\u{00BE}", -- Vulgar Fraction Three Quarters
    ['\xBF'] = "\u{00BF}", -- Inverted Question Mark
    ['\xC0'] = "\u{00C0}", -- Latin Capital Letter A With Grave
    ['\xC1'] = "\u{00C1}", -- Latin Capital Letter A With Acute
    ['\xC2'] = "\u{00C2}", -- Latin Capital Letter A With Circumflex
    ['\xC3'] = "\u{00C3}", -- Latin Capital Letter A With Tilde
    ['\xC4'] = "\u{00C4}", -- Latin Capital Letter A With Diaeresis
    ['\xC5'] = "\u{00C5}", -- Latin Capital Letter A With Ring Above
    ['\xC6'] = "\u{00C6}", -- Latin Capital Ligature Ae
    ['\xC7'] = "\u{00C7}", -- Latin Capital Letter C With Cedilla
    ['\xC8'] = "\u{00C8}", -- Latin Capital Letter E With Grave
    ['\xC9'] = "\u{00C9}", -- Latin Capital Letter E With Acute
    ['\xCA'] = "\u{00CA}", -- Latin Capital Letter E With Circumflex
    ['\xCB'] = "\u{00CB}", -- Latin Capital Letter E With Diaeresis
    ['\xCC'] = "\u{00CC}", -- Latin Capital Letter I With Grave
    ['\xCD'] = "\u{00CD}", -- Latin Capital Letter I With Acute
    ['\xCE'] = "\u{00CE}", -- Latin Capital Letter I With Circumflex
    ['\xCF'] = "\u{00CF}", -- Latin Capital Letter I With Diaeresis
    ['\xD0'] = "\u{00D0}", -- Latin Capital Letter Eth
    ['\xD1'] = "\u{00D1}", -- Latin Capital Letter N With Tilde
    ['\xD2'] = "\u{00D2}", -- Latin Capital Letter O With Grave
    ['\xD3'] = "\u{00D3}", -- Latin Capital Letter O With Acute
    ['\xD4'] = "\u{00D4}", -- Latin Capital Letter O With Circumflex
    ['\xD5'] = "\u{00D5}", -- Latin Capital Letter O With Tilde
    ['\xD6'] = "\u{00D6}", -- Latin Capital Letter O With Diaeresis
    ['\xD7'] = "\u{00D7}", -- Multiplication Sign
    ['\xD8'] = "\u{00D8}", -- Latin Capital Letter O With Stroke
    ['\xD9'] = "\u{00D9}", -- Latin Capital Letter U With Grave
    ['\xDA'] = "\u{00DA}", -- Latin Capital Letter U With Acute
    ['\xDB'] = "\u{00DB}", -- Latin Capital Letter U With Circumflex
    ['\xDC'] = "\u{00DC}", -- Latin Capital Letter U With Diaeresis
    ['\xDD'] = "\u{00DD}", -- Latin Capital Letter Y With Acute
    ['\xDE'] = "\u{00DE}", -- Latin Capital Letter Thorn
    ['\xDF'] = "\u{00DF}", -- Latin Small Letter Sharp S
    ['\xE0'] = "\u{00E0}", -- Latin Small Letter A With Grave
    ['\xE1'] = "\u{00E1}", -- Latin Small Letter A With Acute
    ['\xE2'] = "\u{00E2}", -- Latin Small Letter A With Circumflex
    ['\xE3'] = "\u{00E3}", -- Latin Small Letter A With Tilde
    ['\xE4'] = "\u{00E4}", -- Latin Small Letter A With Diaeresis
    ['\xE5'] = "\u{00E5}", -- Latin Small Letter A With Ring Above
    ['\xE6'] = "\u{00E6}", -- Latin Small Ligature Ae
    ['\xE7'] = "\u{00E7}", -- Latin Small Letter C With Cedilla
    ['\xE8'] = "\u{00E8}", -- Latin Small Letter E With Grave
    ['\xE9'] = "\u{00E9}", -- Latin Small Letter E With Acute
    ['\xEA'] = "\u{00EA}", -- Latin Small Letter E With Circumflex
    ['\xEB'] = "\u{00EB}", -- Latin Small Letter E With Diaeresis
    ['\xEC'] = "\u{00EC}", -- Latin Small Letter I With Grave
    ['\xED'] = "\u{00ED}", -- Latin Small Letter I With Acute
    ['\xEE'] = "\u{00EE}", -- Latin Small Letter I With Circumflex
    ['\xEF'] = "\u{00EF}", -- Latin Small Letter I With Diaeresis
    ['\xF0'] = "\u{00F0}", -- Latin Small Letter Eth
    ['\xF1'] = "\u{00F1}", -- Latin Small Letter N With Tilde
    ['\xF2'] = "\u{00F2}", -- Latin Small Letter O With Grave
    ['\xF3'] = "\u{00F3}", -- Latin Small Letter O With Acute
    ['\xF4'] = "\u{00F4}", -- Latin Small Letter O With Circumflex
    ['\xF5'] = "\u{00F5}", -- Latin Small Letter O With Tilde
    ['\xF6'] = "\u{00F6}", -- Latin Small Letter O With Diaeresis
    ['\xF7'] = "\u{00F7}", -- Division Sign
    ['\xF8'] = "\u{00F8}", -- Latin Small Letter O With Stroke
    ['\xF9'] = "\u{00F9}", -- Latin Small Letter U With Grave
    ['\xFA'] = "\u{00FA}", -- Latin Small Letter U With Acute
    ['\xFB'] = "\u{00FB}", -- Latin Small Letter U With Circumflex
    ['\xFC'] = "\u{00FC}", -- Latin Small Letter U With Diaeresis
    ['\xFD'] = "\u{00FD}", -- Latin Small Letter Y With Acute
    ['\xFE'] = "\u{00FE}", -- Latin Small Letter Thorn
    ['\xFF'] = "\u{00FF}", -- Latin Small Letter Y With Diaeresis
}

local function toUtf8(data)
    return (string.gsub(data, "[\x80-\xFF]", map))
end

return {
    toUtf8 = toUtf8
}
