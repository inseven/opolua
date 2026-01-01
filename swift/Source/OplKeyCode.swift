// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

// Some of these these aren't strictly keycodes in that they don't generate
// keypress events, in particular the modifiers, but for the sake of convenience let's
// pretend they are.
public enum OplKeyCode: Int, CaseIterable {
    case capsLock = 2
    case backspace = 8
    case tab = 9
    case enter = 13
    case leftShift = 18
    case rightShift = 19
    case control = 22
    case fn = 24
    case escape = 27
    case space = 32
    case exclamationMark = 33
    case doubleQuote = 34
    case hash = 35
    case dollar = 36
    case percent = 37
    case ampersand = 38
    case singleQuote = 39
    case leftParenthesis = 40
    case rightParenthesis = 41
    case asterisk = 42
    case plus = 43
    case comma = 44
    case minus = 45
    case fullStop = 46
    case slash = 47
    case num0 = 48
    case num1 = 49
    case num2 = 50
    case num3 = 51
    case num4 = 52
    case num5 = 53
    case num6 = 54
    case num7 = 55
    case num8 = 56
    case num9 = 57
    case colon = 58
    case semicolon = 59
    case lessThan = 60
    case equals = 61
    case greaterThan = 62
    case questionMark = 63
    case atSign = 64
    case A = 65
    case B = 66
    case C = 67
    case D = 68
    case E = 69
    case F = 70
    case G = 71
    case H = 72
    case I = 73
    case J = 74
    case K = 75
    case L = 76
    case M = 77
    case N = 78
    case O = 79
    case P = 80
    case Q = 81
    case R = 82
    case S = 83
    case T = 84
    case U = 85
    case V = 86
    case W = 87
    case X = 88
    case Y = 89
    case Z = 90
    case leftSquareBracket = 91
    case backslash = 92
    case rightSquareBracket = 93
    case circumflex = 94
    case underscore = 95
    case a = 97
    case b = 98
    case c = 99
    case d = 100
    case e = 101
    case f = 102
    case g = 103
    case h = 104
    case i = 105
    case j = 106
    case k = 107
    case l = 108
    case m = 109
    case n = 110
    case o = 111
    case p = 112
    case q = 113
    case r = 114
    case s = 115
    case t = 116
    case u = 117
    case v = 118
    case w = 119
    case x = 120
    case y = 121
    case z = 122
    case leftCurlyBracket = 123
    case rightCurlyBracket = 125
    case tilde = 126
    case euro = 128
    case pound = 163
    case multiply = 215
    case divide = 247
    case homeKey = 4098
    case endKey = 4099
    case pgUp = 4100
    case pgDn = 4101
    case leftArrow = 4103
    case rightArrow = 4104
    case upArrow = 4105
    case downArrow = 4106
    case menu = 4150
    case dial = 4155
    case menuSoftkey = 10000
    case clipboardSoftkey = 10001
    case irSoftkey = 10002
    case zoomInSoftkey = 10003
    case zoomOutSoftkey = 10004
    case help = 291
    case diamond = 292
}

extension OplKeyCode {
    private static let CharKeycodeMap: [String: OplKeyCode] = [
        "a": .a,
        "b": .b,
        "c": .c,
        "d": .d,
        "e": .e,
        "f": .f,
        "g": .g,
        "h": .h,
        "i": .i,
        "j": .j,
        "k": .k,
        "l": .l,
        "m": .m,
        "n": .n,
        "o": .o,
        "p": .p,
        "q": .q,
        "r": .r,
        "s": .s,
        "t": .t,
        "u": .u,
        "v": .v,
        "w": .w,
        "x": .x,
        "y": .y,
        "z": .z,
        "A": .A,
        "B": .B,
        "C": .C,
        "D": .D,
        "E": .E,
        "F": .F,
        "G": .G,
        "H": .H,
        "I": .I,
        "J": .J,
        "K": .K,
        "L": .L,
        "M": .M,
        "N": .N,
        "O": .O,
        "P": .P,
        "Q": .Q,
        "R": .R,
        "S": .S,
        "T": .T,
        "U": .U,
        "V": .V,
        "W": .W,
        "X": .X,
        "Y": .Y,
        "Z": .Z,
        "0": .num0,
        "1": .num1,
        "2": .num2,
        "3": .num3,
        "4": .num4,
        "5": .num5,
        "6": .num6,
        "7": .num7,
        "8": .num8,
        "9": .num9,
        "!": .exclamationMark,
        "@": .atSign,
        "£": .pound,
        "#": .hash,
        "$": .dollar,
        "%": .percent,
        "^": .circumflex,
        "&": .ampersand,
        "*": .asterisk,
        "(": .leftParenthesis,
        ")": .rightParenthesis,
        "-": .minus,
        "_": .underscore,
        "=": .equals,
        "+": .plus,
        "[": .leftSquareBracket,
        "]": .rightSquareBracket,
        "{": .leftCurlyBracket,
        "}": .rightCurlyBracket,
        ";": .semicolon,
        ":": .colon,
        "'": .singleQuote,
        "\"": .doubleQuote,
        "\\": .backslash,
        "~": .tilde,
        " ": .space,
        ",": .comma,
        ".": .fullStop,
        "<": .lessThan,
        ">": .greaterThan,
        "/": .slash,
        "?": .questionMark,
        "€": .euro,
        "\n": .enter,
    ]

    public static func from(string: String) -> OplKeyCode? {
        return CharKeycodeMap[string]
    }

    func toScancode() -> Int {
        switch self {
        case .A, .B, .C, .D, .E, .F, .G, .H, .I, .J, .K, .L, .M, .N, .O, .P, .Q, .R, .S, .T, .U, .V, .W, .X, .Y, .Z:
            return self.rawValue
        case .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z:
            return self.rawValue - 32
        case .leftShift, .rightShift, .control, .fn:
            return self.rawValue
        case .num1, .exclamationMark, .underscore:
            return OplKeyCode.num1.rawValue
        case .num2, .doubleQuote, .hash, .euro:
            return OplKeyCode.num2.rawValue
        case .num3, .pound, .backslash:
            return OplKeyCode.num3.rawValue
        case .num4, .dollar, .atSign:
            return OplKeyCode.num4.rawValue
        case .num5, .percent, .lessThan:
            return OplKeyCode.num5.rawValue
        case .num6, .circumflex, .greaterThan:
            return OplKeyCode.num6.rawValue
        case .num7, .ampersand, .leftSquareBracket:
            return OplKeyCode.num7.rawValue
        case .num8, .asterisk, .rightSquareBracket:
            return OplKeyCode.num8.rawValue
        case .num9, .leftParenthesis, .leftCurlyBracket:
            return OplKeyCode.num9.rawValue
        case .num0, .rightParenthesis, .rightCurlyBracket:
            return OplKeyCode.num0.rawValue
        case .backspace:
            return 1
        case .capsLock, .tab:
            return 2
        case .enter:
            return 3
        case .escape:
            return 4
        case .space:
            return 5
        case .singleQuote, .tilde, .colon:
            return 126
        case .comma, .slash:
            return 121
        case .fullStop, .questionMark:
            return 122
        case .leftArrow, .homeKey:
            return 14
        case .rightArrow, .endKey:
            return 15
        case .upArrow, .pgUp:
            return 16
        case .downArrow, .pgDn:
            return 17
        case .menu, .dial:
            return 148
        case .menuSoftkey, .clipboardSoftkey, .irSoftkey, .zoomInSoftkey, .zoomOutSoftkey:
            return self.rawValue
        case .multiply:
            return OplKeyCode.Y.rawValue
        case .divide:
            return OplKeyCode.U.rawValue
        case .plus:
            return OplKeyCode.I.rawValue
        case .minus:
            return OplKeyCode.O.rawValue
        case .semicolon:
            return OplKeyCode.L.rawValue
        case .equals:
            return OplKeyCode.P.rawValue
        case .help, .diamond:
            // Don't exist on Series 5
            return self.rawValue
        }
    }

    func toSiboScancode() -> Int {
        switch self {
        case .enter:
            return 0
        case .rightArrow, .endKey:
            return 1
        case .tab:
            return 2
        case .Y, .y:
            return 3
        case .leftArrow, .homeKey:
            return 4
        case .downArrow, .pgDn:
            return 5
        case .N, .n:
            return 6
        // case Psion:
        //     return 7
        // case Sheet:
        //     return 8 // 1:0
        // case Time:
        //     return 9 // 1:1
        case .slash, .semicolon:
            return 17 // 2:1
        case .minus, .underscore:
            return 18 // 2:2
        case .plus, .equals:
            return 19 // 2:3
        case .num0, .rightParenthesis, .rightSquareBracket:
            return 20 // 2:4
        case .P, .p:
            return 21 // 2:5
        case .asterisk, .colon:
            return 22 // 2:6
        case .leftShift:
            return 23 // 2:7
        // case Calc:
        //     return 24 // 3:0
        // case Agenda:
        //     return 25 // 3:1
        case .backspace:
            return 32 // 4:0
        case .K, .k:
            return 33 // 4:1
        case .I, .i:
            return 34 // 4:2
        case .num8, .questionMark, .rightCurlyBracket:
            return 35 // 4:3
        case .num9, .leftParenthesis, .leftSquareBracket:
            return 36 // 4:4
        case .O, .o:
            return 37 // 4:5
        case .L, .l:
            return 38 // 4:6
        case .control:
            return 39 // 4:7
        // case World:
        //     return 41 // 5:1
        case .comma, .lessThan:
            return 49 // 6:1
        case .help:
            return 50 // 6:2
        case .M, .m:
            return 51 // 6:3
        case .J, .j:
            return 52 // 6:4
        case .U, .u:
            return 53 // 6:5
        case .num7, .ampersand, .leftCurlyBracket:
            return 54 // 6:6
        case .rightShift:
            return 55 // 6:7
        // case Data:
        //     return 57 // 7:1
        case .space:
            return 64 // 8:0
        case .R, .r:
            return 65 // 8:1
        case .num4, .dollar, .tilde:
            return 66 // 8:2
        case .num5, .percent, .singleQuote:
            return 67 // 8:3
        case .T, .t:
            return 68 // 8:4
        case .G, .g:
            return 69 // 8:5
        case .B, .b:
            return 70 // 8:6
        case .diamond, .capsLock:
            return 71 // 8:7
        // case System:
        //     return 73 // 9:1
        case .F, .f:
            return 81 // 10:1
        case .V, .v:
            return 82 // 10:2
        case .C, .c:
            return 83 // 10:3
        case .D, .d:
            return 84 // 10:4
        case .E, .e:
            return 85 // 10:5
        case .num3, .pound, .backslash:
            return 86 // 10:6
        case .menu:
            return 87 // 10:7
        // case Word:
        //     return 89 // 11:1
        case .Q, .q:
            return 97 // 12:1
        case .A, .a:
            return 98 // 12:2
        case .Z, .z:
            return 99 // 12:3
        case .S, .s:
            return 100 // 12:4
        case .W, .w:
            return 101 // 12:5
        case .X, .x:
            return 102 // 12:6
        case .num1, .exclamationMark:
            return 113 // 14:1
        case .num2, .doubleQuote, .hash:
            return 114 // 14:2
        case .num6, .circumflex:
            return 115 // 14:3
        case .fullStop, .greaterThan:
            return 116 // 14:4
        case .upArrow, .pgUp:
            return 117 // 14:5
        case .H, .h:
            return 118 // 14:6
        case .escape:
            return 120 // 15:0
        default:
            print("unhandled sibo keycode \(self)");
            return self.rawValue
        }
    }

    // Returns nil for things without a charcode (like modifier keys)
    public func toCharcode() -> Int? {
        switch self {
        case .leftShift, .rightShift, .control, .fn, .capsLock:
            return nil
        case .menu, .menuSoftkey:
            return 290
        case .homeKey:
            return 262
        case .endKey:
            return 263
        case .pgUp:
            return 260
        case .pgDn:
            return 261
        case .leftArrow:
            return 259
        case .rightArrow:
            return 258
        case .upArrow:
            return 256
        case .downArrow:
            return 257
        default:
            // Everything else has the same charcode as keycode
            return self.rawValue
        }
    }

    public func isAlpha() -> Bool {
        return (self.rawValue >= OplKeyCode.a.rawValue && self.rawValue <= OplKeyCode.z.rawValue) ||
        (self.rawValue >= OplKeyCode.A.rawValue && self.rawValue <= OplKeyCode.Z.rawValue)
    }

    public func isNum() -> Bool {
        return self.rawValue >= OplKeyCode.num0.rawValue && self.rawValue <= OplKeyCode.num9.rawValue
    }

    public func lowercase() -> OplKeyCode {
        if self.rawValue >= OplKeyCode.A.rawValue && self.rawValue <= OplKeyCode.Z.rawValue {
            return OplKeyCode(rawValue: self.rawValue + 32)!
        } else {
            return self
        }
    }

    // Returns true for keys that add 0x200 to the keycode when the psion key is pressed. This is broadly all
    // ASCII-producing keys that don't have an alternate usage printed on them.
    public func addsPsionBit() -> Bool {
        return isAlpha() || self == .asterisk || self == .slash || self == .minus || self == .plus
    }
}
