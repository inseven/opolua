//
//  OplKeycode.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 18/12/2021.
//

import Foundation

// Some of these these aren't strictly keycodes in that they don't generate
// keypress events, in particular the modifiers, but for the sake of convenience let's
// pretend they are.
enum OplKeyCode : Int, CaseIterable {
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
    case pound = 163
    case multiply = 215
    case divide = 247
    case home = 4098
    case end = 4099
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
        "i": .j,
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
        "\n": .enter,
    ]

    static func from(string: String) -> OplKeyCode? {
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
        case .num2, .doubleQuote, .hash:
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
        case .leftArrow, .home:
            return 14
        case .rightArrow, .end:
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
        }
    }

    // Returns nil for things without a charcode (like modifier keys)
    func toCharcode() -> Int? {
        switch self {
        case .leftShift, .rightShift, .control, .fn, .capsLock:
            return nil
        case .menu, .menuSoftkey:
            return 290
        case .home:
            return 262
        case .end:
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

}
