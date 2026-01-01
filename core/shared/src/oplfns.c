// Copyright (c) 2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "opldefs.h"
#include "oplfns.h"

int32_t oplScancodeForKeycode(int32_t keycode, bool sibo)
{
    if (sibo) {
        // These aren't scancodes per se, these are the indexes into the keyboard bitfield, translated from the OPL
        // manual description. But because we implement the SIBO input APIs in terms of GETEVENT32, we have to make up
        // a scancode for that to return, and we might as well use the same values. Although it's possible these _are_
        // the scancodes and the OPL manual doesn't explain them because the bitfield is the only way to retrieve them
        // on SIBO. See HwGetScanCodes in https://www.davros.org/psion/psionics/syscalls.3 for the X:Y references.
        switch (keycode) {
        case enter:
            return 0;
        case rightArrow:
        case endKey:
            return 1;
        case tab:
            return 2;
        case Y:
        case y:
            return 3;
        case leftArrow:
        case homeKey:
            return 4;
        case downArrow:
        case pgDn:
            return 5;
        case N:
        case n:
            return 6;
        // case Psion:
        //     return 7;
        // case Sheet:
        //     return 8; // 1:0
        // case Time:
        //     return 9; // 1:1
        case slash:
        case semicolon:
            return 17; // 2:1
        case minus:
        case underscore:
            return 18; // 2:2
        case plus:
        case equals:
            return 19; // 2:3
        case num0:
        case rightParenthesis:
        case rightSquareBracket:
            return 20; // 2:4
        case P:
        case p:
            return 21; // 2:5
        case asterisk:
        case colon:
            return 22; // 2:6
        case leftShift:
            return 23; // 2:7
        // case Calc:
        //     return 24; // 3:0
        // case Agenda:
        //     return 25; // 3:1
        case backspace:
            return 32; // 4:0
        case K:
        case k:
            return 33; // 4:1
        case I:
        case i:
            return 34; // 4:2
        case num8:
        case questionMark:
        case rightCurlyBracket:
            return 35; // 4:3
        case num9:
        case leftParenthesis:
        case leftSquareBracket:
            return 36; // 4:4
        case O:
        case o:
            return 37; // 4:5
        case L:
        case l:
            return 38; // 4:6
        case control:
            return 39; // 4:7
        // case World:
        //     return 41; // 5:1
        case comma:
        case lessThan:
            return 49; // 6:1
        case help:
            return 50; // 6:2
        case M:
        case m:
            return 51; // 6:3
        case J:
        case j:
            return 52; // 6:4
        case U:
        case u:
            return 53; // 6:5
        case num7:
        case ampersand:
        case leftCurlyBracket:
            return 54; // 6:6
        case rightShift:
            return 55; // 6:7
        // case Data:
        //     return 57; // 7:1
        case space:
            return 64; // 8:0
        case R:
        case r:
            return 65; // 8:1
        case num4:
        case dollar:
        case tilde:
            return 66; // 8:2
        case num5:
        case percent:
        case singleQuote:
            return 67; // 8:3
        case T:
        case t:
            return 68; // 8:4
        case G:
        case g:
            return 69; // 8:5
        case B:
        case b:
            return 70; // 8:6
        case diamond:
        case capsLock:
            return 71; // 8:7
        // case System:
        //     return 73; // 9:1
        case F:
        case f:
            return 81; // 10:1
        case V:
        case v:
            return 82; // 10:2
        case C:
        case c:
            return 83; // 10:3
        case D:
        case d:
            return 84; // 10:4
        case E:
        case e:
            return 85; // 10:5
        case num3:
        case pound:
        case backslash:
            return 86; // 10:6
        case menu:
            return 87; // 10:7
        // case Word:
        //     return 89; // 11:1
        case Q:
        case q:
            return 97; // 12:1
        case A:
        case a:
            return 98; // 12:2
        case Z:
        case z:
            return 99; // 12:3
        case S:
        case s:
            return 100; // 12:4
        case W:
        case w:
            return 101; // 12:5
        case X:
        case x:
            return 102; // 12:6
        case num1:
        case exclamationMark:
            return 113; // 14:1
        case num2:
        case doubleQuote:
        case hash:
            return 114; // 14:2
        case num6:
        case circumflex:
            return 115; // 14:3
        case fullStop:
        case greaterThan:
            return 116; // 14:4
        case upArrow:
        case pgUp:
            return 117; // 14:5
        case H:
        case h:
            return 118; // 14:6
        case escape:
            return 120; // 15:0
        default:
            // qWarning("unhandled sibo keycode %d", keycode);
            return -1;
        }
    } else {
        if (keycode >= A && keycode <= Z) {
            return keycode;
        } else if (keycode >= a && keycode <= z) {
            return keycode - 32;
        } else if (keycode >= num0 && keycode <= num9) {
            return keycode;
        } else {
            switch (keycode) {
            case leftShift:
            case rightShift:
            case control:
            case fn:
                return keycode;
            case exclamationMark:
            case underscore:
                return num1;
            case doubleQuote:
            case hash:
            case euro:
                return num2;
            case pound:
            case backslash:
                return num3;
            case dollar:
            case atSign:
                return num4;
            case percent:
            case lessThan:
                return num5;
            case circumflex:
            case greaterThan:
                return num6;
            case ampersand:
            case leftSquareBracket:
                return num7;
            case asterisk:
            case rightSquareBracket:
                return num8;
            case leftParenthesis:
            case leftCurlyBracket:
                return num9;
            case rightParenthesis:
            case rightCurlyBracket:
                return num0;
            case backspace:
                return 1;
            case capsLock:
            case tab:
                return 2;
            case enter:
                return 3;
            case escape:
                return 4;
            case space:
                return 5;
            case singleQuote:
            case tilde:
            case colon:
            case verticalBar: // This is made up so we can input it; there's no actual key for this character
                return 126;
            case comma:
            case slash:
                return 121;
            case fullStop:
            case questionMark:
                return 122;
            case leftArrow:
            case homeKey:
                return 14;
            case rightArrow:
            case endKey:
                return 15;
            case upArrow:
            case pgUp:
                return 16;
            case downArrow:
            case pgDn:
                return 17;
            case menu:
            case dial:
                return 148;
            case menuSoftkey:
            case clipboardSoftkey:
            case irSoftkey:
            case zoomInSoftkey:
            case zoomOutSoftkey:
                return keycode;
            case multiply:
                return Y;
            case divide:
                return U;
            case plus:
                return I;
            case minus:
                return O;
            case semicolon:
                return L;
            case equals:
                return P;
            default:
                // qWarning("unhandled keycode %d", keycode);
                return -1;
            }
        }
    }
}

int32_t oplCharcodeForKeycode(int32_t keycode)
{
    switch (keycode) {
    case leftShift:
    case rightShift:
    case control:
    case fn:
    case capsLock:
        return 0;
    case menu:
    case menuSoftkey:
        return 290;
    case homeKey:
        return 262;
    case endKey:
        return 263;
    case pgUp:
        return 260;
    case pgDn:
        return 261;
    case leftArrow:
        return 259;
    case rightArrow:
        return 258;
    case upArrow:
        return 256;
    case downArrow:
        return 257;
    default:
        // Everything else has the same charcode as keycode
        return keycode;
    }
}

// Pen events actually use TEventModifers not TOplModifiers (despite what the documentation says)
uint32_t oplModifiersToTEventModifiers(uint32_t modifiers)
{
    uint32_t result = 0;
    if (modifiers & shiftModifier) {
        result |= teventShift;
    }
    if (modifiers & controlModifier) {
        result |= teventControl;
    }
    if (modifiers & capsLockModifier) {
        result |= teventCapsLock;
    }
    if (modifiers & fnModifier) {
        result |= teventFn;
    }
    return result;
}

static bool isAlpha(int32_t keycode)
{
    return (keycode >= A && keycode <= Z) || (keycode >= a && keycode <= z);
}

// Returns true for keys that add 0x200 to the keycode when the psion key is pressed. This is broadly all
// ASCII-producing keys that don't have an alternate usage printed on them.
static bool oplKeycodeAddsPsionBit(int32_t keycode)
{
    return isAlpha(keycode) || keycode == asterisk || keycode == slash || keycode == minus || keycode == plus;
}

int32_t oplModifiedKeycode(int32_t keycode, uint32_t modifiers)
{
    // If it doesn't have a charcode, we shouldn't generate a keypress for it
    if (oplCharcodeForKeycode(keycode)) {
        // Psion-key and CTRL-[shift-]letter have special codes
        if ((modifiers & psionModifier) && oplKeycodeAddsPsionBit(keycode)) {
            // Psion key adds 0x200 to the keycode, and they are always sent lowercase, hence the 0x20.
            // The psion key being pressed supersedes the control key logic below.
            return keycode | 0x220;
        } else if ((modifiers & controlModifier) && isAlpha(keycode)) {
            return (keycode & ~0x20) - A + 1;
        } else if ((modifiers & controlModifier) && keycode >= num0 && keycode <= num9) {
            // Ctrl-0 thru Ctrl-9 don't send keypress events at all because CTRL-x,y,z... is used
            // for inputting a key with code xyz.
            // But eg Ctrl-Fn-1 (for underscore) does.
            return 0;
        } else {
            return keycode;
        }
    } else {
        return 0;
    }
}

int32_t oplUnicodeToKeycode(uint32_t ch)
{
    if (ch >= 0x20 && ch <= 0x7E && ch != '`') {
        // All the printable ascii block except backtick have the same codes in OPL
        return (int32_t)ch;
    } else if (ch == 0xA3) {
        return pound;
    } else if (ch == 0x20AC) {
        return euro;
    } else {
        return 0;
    }
}
