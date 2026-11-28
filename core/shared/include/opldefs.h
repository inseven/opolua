// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#pragma once

#include "opldevicetype.h"

#ifdef __cplusplus
namespace opl {
#endif

// Some of these these aren't strictly keycodes in that they don't generate
// keypress events, in particular the modifiers, but for the sake of convenience let's
// pretend they are.
enum OplKeyCode {
    capsLock = 2,
    backspace = 8,
    tab = 9,
    enter = 13,
    leftShift = 18,
    rightShift = 19,
    control = 22,
    fn = 24,
    escape = 27,
    space = 32,
    exclamationMark = 33,
    doubleQuote = 34,
    hash = 35,
    dollar = 36,
    percent = 37,
    ampersand = 38,
    singleQuote = 39,
    leftParenthesis = 40,
    rightParenthesis = 41,
    asterisk = 42,
    plus = 43,
    comma = 44,
    minus = 45,
    fullStop = 46,
    slash = 47,
    num0 = 48,
    num1 = 49,
    num2 = 50,
    num3 = 51,
    num4 = 52,
    num5 = 53,
    num6 = 54,
    num7 = 55,
    num8 = 56,
    num9 = 57,
    colon = 58,
    semicolon = 59,
    lessThan = 60,
    equals = 61,
    greaterThan = 62,
    questionMark = 63,
    atSign = 64,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    leftSquareBracket = 91,
    backslash = 92,
    rightSquareBracket = 93,
    circumflex = 94,
    underscore = 95,
    a = 97,
    b = 98,
    c = 99,
    d = 100,
    e = 101,
    f = 102,
    g = 103,
    h = 104,
    i = 105,
    j = 106,
    k = 107,
    l = 108,
    m = 109,
    n = 110,
    o = 111,
    p = 112,
    q = 113,
    r = 114,
    s = 115,
    t = 116,
    u = 117,
    v = 118,
    w = 119,
    x = 120,
    y = 121,
    z = 122,
    leftCurlyBracket = 123,
    verticalBar = 124,
    rightCurlyBracket = 125,
    tilde = 126,
    euro = 128,
    pound = 163,
    multiply = 215,
    divide = 247,
    help = 291, // sibo only
    diamond = 292, // sibo only
    homeKey = 4098,
    endKey = 4099,
    pgUp = 4100,
    pgDn = 4101,
    leftArrow = 4103,
    rightArrow = 4104,
    upArrow = 4105,
    downArrow = 4106,
    menu = 4150,
    dial = 4155,
    menuSoftkey = 10000,
    clipboardSoftkey = 10001,
    irSoftkey = 10002,
    zoomInSoftkey = 10003,
    zoomOutSoftkey = 10004,
} CLOSED_ENUM;

enum OplModifier {
    shiftModifier = 2,
    controlModifier = 4,
    psionModifier = 8, // sibo only
    capsLockModifier = 16,
    fnModifier = 32,
} CLOSED_ENUM;

enum EventId {
    foregrounded = 0x401,
    backgrounded = 0x402,
    switchon = 0x403,
    command = 0x404,
    keydown = 0x406,
    keyup = 0x407,
    pen = 0x408,
    pendown = 0x409,
    penup = 0x40A,
} CLOSED_ENUM;

enum PointerType {
    pointerDown = 0,
    pointerUp = 1,
    pointerDrag = 6,
} CLOSED_ENUM;

enum TEventModifiers {
    teventShift = 0x500, // EModifierLeftShift | EModifierShift
    teventControl = 0xA0, // EModifierLeftCtrl | EModifierCtrl
    teventCapsLock = 0x4000, // EModifierCapsLock
    teventFn = 0x2800, // EModifierLeftFunc | EModifierFunc
    teventDoubleClick = 0x80000,
} CLOSED_ENUM;

#ifdef __cplusplus
} // end namespace opl
#endif

// The following are deliberately not in the opl:: namespace

enum TranslatorVersion {
    oplS3 = 0x110F,
    opl1993 = 0x111F,
    opler1 = 0x200A,
} CLOSED_ENUM;

enum OplError {
    KErrNone = 0,
    KErrGenFail = -1,
    KErrInvalidArgs = -2,
    KErrFilePending = -46,
    KErrIOCancelled = -48,
    KErrDrawNotOpen = -118,
} CLOSED_ENUM;

typedef struct OplClockMetrics {
    const char* name; // name of clock png, NULL means digital
    unsigned int timeFont; // 0 means analog
    unsigned int dateFont;
    int hourHandLen;
    int minuteHandLen;
} OplClockMetrics;

enum OplDateFormat {
    EuropeanFormat,
    AmericanFormat,
    JapaneseFormat,
} CLOSED_ENUM;

typedef enum OplDateFormat OplDateFormat;

enum OplClockType {
    invalidClock = -1,
    digitalSmall, // type 1
    analogSmall, // type 3
    digitalMedium, // type 4
    analogMediumBlack, // type 5
    analogMediumS3a, // type 7 (S3a)
    analogMediumS5, // type 7 (S5)
    analogMediumColor, // type 7 (color)
    digitalFont, // Type 8, using KFontDigital35 (S5 and later)
    digitalFontShadowed, // Type 8, using shadowed KFontDigital35 (S3a only)
    analogLargeS3a, // type 9 (S3a)
    analogLargeS5, // type 9 (S5)
    analogLargeColor, // type 9 (color)
    customFormatS3a, // type 10
    customFormatS5, // type 11
} CLOSED_ENUM;

typedef enum OplClockType OplClockType;

typedef struct OplClockFormatSettings {
    OplClockType type;
    OplDateFormat dateFormat;
    const char* timeSeparator;
    const char* dateSeparator;
    const char* amText; // Can be null to use strftime
    const char* pmText; // Can be null to use strftime
    int system24hour;
} OplClockFormatSettings;

static const unsigned int KFontSysNorm = 1;
static const unsigned int KFontSwiss11 = 10;
static const unsigned int KFontDigital35 = 0x10000128;
static const unsigned int KFontArialNormal15 = 0x100001F5;

static const int KgCreate2ColourMode = 0x0000;
static const int KColorgCreate4GrayMode = 0x0001;
static const int KColorgCreate16GrayMode = 0x0002;
static const int KColorgCreate256ColorMode = 0x0005;
