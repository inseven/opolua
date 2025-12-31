// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplkeycode.h"
#include <Qt>

int qtKeyToOpl(int qtKey)
{
    switch(qtKey) {
    case Qt::Key_Escape: return opl::escape;
    case Qt::Key_Tab: return opl::tab;
    case Qt::Key_Backtab: return opl::tab;
    case Qt::Key_Backspace: return opl::backspace;
    case Qt::Key_Return: return opl::enter; // close enough?
    case Qt::Key_Enter: return opl::enter;
    // case Qt::Key_Insert:
    case Qt::Key_Delete: return opl::backspace;
    // case Qt::Key_Pause:
    // case Qt::Key_Print:
    // case Qt::Key_SysReq:
    // case Qt::Key_Clear:
    case Qt::Key_Home: return opl::homeKey;
    case Qt::Key_End: return opl::endKey;
    case Qt::Key_Left: return opl::leftArrow;
    case Qt::Key_Up: return opl::upArrow;
    case Qt::Key_Right: return opl::rightArrow;
    case Qt::Key_Down: return opl::downArrow;
    case Qt::Key_PageUp: return opl::pgUp;
    case Qt::Key_PageDown: return opl::pgDn;
    case Qt::Key_Shift: return opl::leftShift;
#ifdef Q_OS_MAC
    // case Qt::Key_Control: return opl::menu;
    case Qt::Key_Meta: return opl::control;
#else
    case Qt::Key_Control: return opl::control;
    // case Qt::Key_Meta: return opl::menu;
#endif
    // case Qt::Key_Alt:
    // case Qt::Key_CapsLock:
    // case Qt::Key_NumLock:
    // case Qt::Key_ScrollLock:
    case Qt::Key_F1: return opl::menu;
    case Qt::Key_F2: return opl::diamond;
    // case Qt::Key_Super_L:
    // case Qt::Key_Super_R:
    case Qt::Key_Menu: return opl::menu;
    // case Qt::Key_Hyper_L:
    // case Qt::Key_Hyper_R:
    // case Qt::Key_Help:
    // case Qt::Key_Direction_L:
    // case Qt::Key_Direction_R:
    case Qt::Key_Space: return opl::space;
    // case Qt::Key_Any:
    case Qt::Key_Exclam: return opl::exclamationMark;
    case Qt::Key_QuoteDbl: return opl::doubleQuote;
    case Qt::Key_NumberSign: return opl::hash;
    case Qt::Key_Dollar: return opl::dollar;
    case Qt::Key_Percent: return opl::percent;
    case Qt::Key_Ampersand: return opl::ampersand;
    case Qt::Key_Apostrophe: return opl::singleQuote;
    case Qt::Key_ParenLeft: return opl::leftParenthesis;
    case Qt::Key_ParenRight: return opl::rightParenthesis;
    case Qt::Key_Asterisk: return opl::asterisk;
    case Qt::Key_Plus: return opl::plus;
    case Qt::Key_Comma: return opl::comma;
    case Qt::Key_Minus: return opl::minus;
    case Qt::Key_Period: return opl::fullStop;
    case Qt::Key_Slash: return opl::slash;
    case Qt::Key_0: return opl::num0;
    case Qt::Key_1: return opl::num1;
    case Qt::Key_2: return opl::num2;
    case Qt::Key_3: return opl::num3;
    case Qt::Key_4: return opl::num4;
    case Qt::Key_5: return opl::num5;
    case Qt::Key_6: return opl::num6;
    case Qt::Key_7: return opl::num7;
    case Qt::Key_8: return opl::num8;
    case Qt::Key_9: return opl::num9;
    case Qt::Key_Colon: return opl::colon;
    case Qt::Key_Semicolon: return opl::semicolon;
    case Qt::Key_Less: return opl::lessThan;
    case Qt::Key_Equal: return opl::equals;
    case Qt::Key_Greater: return opl::greaterThan;
    case Qt::Key_Question: return opl::questionMark;
    case Qt::Key_At: return opl::atSign;
    case Qt::Key_A: return opl::A;
    case Qt::Key_B: return opl::B;
    case Qt::Key_C: return opl::C;
    case Qt::Key_D: return opl::D;
    case Qt::Key_E: return opl::E;
    case Qt::Key_F: return opl::F;
    case Qt::Key_G: return opl::G;
    case Qt::Key_H: return opl::H;
    case Qt::Key_I: return opl::I;
    case Qt::Key_J: return opl::J;
    case Qt::Key_K: return opl::K;
    case Qt::Key_L: return opl::L;
    case Qt::Key_M: return opl::M;
    case Qt::Key_N: return opl::N;
    case Qt::Key_O: return opl::O;
    case Qt::Key_P: return opl::P;
    case Qt::Key_Q: return opl::Q;
    case Qt::Key_R: return opl::R;
    case Qt::Key_S: return opl::S;
    case Qt::Key_T: return opl::T;
    case Qt::Key_U: return opl::U;
    case Qt::Key_V: return opl::V;
    case Qt::Key_W: return opl::W;
    case Qt::Key_X: return opl::X;
    case Qt::Key_Y: return opl::Y;
    case Qt::Key_Z: return opl::Z;
    case Qt::Key_BracketLeft: return opl::leftSquareBracket;
    case Qt::Key_Backslash: return opl::backslash;
    case Qt::Key_BracketRight: return opl::rightSquareBracket;
    case Qt::Key_AsciiCircum: return opl::circumflex;
    case Qt::Key_Underscore: return opl::underscore;
    // case Qt::Key_QuoteLeft: return opl::
    case Qt::Key_BraceLeft: return opl::leftCurlyBracket;
    // case Qt::Key_Bar: return opl::
    case Qt::Key_BraceRight: return opl::rightCurlyBracket;
    case Qt::Key_AsciiTilde: return opl::tilde;
    default: return 0;
    }
}

int32_t modifiersToTEventModifiers(opl::Modifiers modifiers)
{
    int32_t result = 0;
    if (modifiers & opl::shiftModifier) {
        result |= opl::teventShift;
    }
    if (modifiers & opl::controlModifier) {
        result |= opl::teventControl;
    }
    if (modifiers & opl::capsLockModifier) {
        result |= opl::teventCapsLock;
    }
    if (modifiers & opl::fnModifier) {
        result |= opl::teventFn;
    }
    return result;
}

#ifdef Q_OS_MAC
static const int kRealControlModifer = Qt::MetaModifier;
#else
static const int kRealControlModifer = Qt::ControlModifier;
#endif

opl::Modifiers getOplModifiers(Qt::KeyboardModifiers modifiers)
{
    opl::Modifiers result;
    if (modifiers & Qt::ShiftModifier) {
        result = result | opl::shiftModifier;
    }
    if (modifiers & kRealControlModifer) {
        result = result | opl::controlModifier;
    }
    if (modifiers & Qt::AltModifier) {
        result = result | opl::psionModifier;
    }
    return result;
}

int32_t scancodeForKeycode(int32_t keycode)
{
    if (keycode >= opl::A && keycode <= opl::Z) {
        return keycode;
    } else if (keycode >= opl::a && keycode <= opl::z) {
        return keycode - 32;
    } else if (keycode >= opl::num0 && keycode <= opl::num9) {
        return keycode;
    } else {
        switch (keycode) {
        case opl::leftShift:
        case opl::rightShift:
        case opl::control:
        case opl::fn:
            return keycode;
        case opl::exclamationMark:
        case opl::underscore:
            return opl::num1;
        case opl::doubleQuote:
        case opl::hash:
        case opl::euro:
            return opl::num2;
        case opl::pound:
        case opl::backslash:
            return opl::num3;
        case opl::dollar:
        case opl::atSign:
            return opl::num4;
        case opl::percent:
        case opl::lessThan:
            return opl::num5;
        case opl::circumflex:
        case opl::greaterThan:
            return opl::num6;
        case opl::ampersand:
        case opl::leftSquareBracket:
            return opl::num7;
        case opl::asterisk:
        case opl::rightSquareBracket:
            return opl::num8;
        case opl::leftParenthesis:
        case opl::leftCurlyBracket:
            return opl::num9;
        case opl::rightParenthesis:
        case opl::rightCurlyBracket:
            return opl::num0;
        case opl::backspace:
            return 1;
        case opl::capsLock:
        case opl::tab:
            return 2;
        case opl::enter:
            return 3;
        case opl::escape:
            return 4;
        case opl::space:
            return 5;
        case opl::singleQuote:
        case opl::tilde:
        case opl::colon:
            return 126;
        case opl::comma:
        case opl::slash:
            return 121;
        case opl::fullStop:
        case opl::questionMark:
            return 122;
        case opl::leftArrow:
        case opl::homeKey:
            return 14;
        case opl::rightArrow:
        case opl::endKey:
            return 15;
        case opl::upArrow:
        case opl::pgUp:
            return 16;
        case opl::downArrow:
        case opl::pgDn:
            return 17;
        case opl::menu:
        case opl::dial:
            return 148;
        case opl::menuSoftkey:
        case opl::clipboardSoftkey:
        case opl::irSoftkey:
        case opl::zoomInSoftkey:
        case opl::zoomOutSoftkey:
            return keycode;
        case opl::multiply:
            return opl::Y;
        case opl::divide:
            return opl::U;
        case opl::plus:
            return opl::I;
        case opl::minus:
            return opl::O;
        case opl::semicolon:
            return opl::L;
        case opl::equals:
            return opl::P;
        default:
            qWarning("unhandled keycode %d", keycode);
            return -1;
        }
    }
}

// These aren't scancodes per se, these are the indexes into the keyboard bitfield, translated from the OPL manual
// description. But because we implement the SIBO input APIs in terms of GETEVENT32, we have to make up a scancode for
// that to return, and we might as well use the same values. Although it's possible these _are_ the scancodes and the
// OPL manual doesn't explain them because the bitfield is the only way to retrieve them on SIBO.
// See HwGetScanCodes in https://www.davros.org/psion/psionics/syscalls.3 for the X:Y references
int32_t siboScancodeForKeycode(int32_t keycode)
{
    switch (keycode) {
    case opl::enter:
        return 0;
    case opl::rightArrow:
    case opl::endKey:
        return 1;
    case opl::tab:
        return 2;
    case opl::Y:
    case opl::y:
        return 3;
    case opl::leftArrow:
    case opl::homeKey:
        return 4;
    case opl::downArrow:
    case opl::pgDn:
        return 5;
    case opl::N:
    case opl::n:
        return 6;
    // case Psion:
    //     return 7;
    // case Sheet:
    //     return 8; // 1:0
    // case Time:
    //     return 9; // 1:1
    case opl::slash:
    case opl::semicolon:
        return 17; // 2:1
    case opl::minus:
    case opl::underscore:
        return 18; // 2:2
    case opl::plus:
    case opl::equals:
        return 19; // 2:3
    case opl::num0:
    case opl::rightParenthesis:
    case opl::rightSquareBracket:
        return 20; // 2:4
    case opl::P:
    case opl::p:
        return 21; // 2:5
    case opl::asterisk:
    case opl::colon:
        return 22; // 2:6
    case opl::leftShift:
        return 23; // 2:7
    // case Calc:
    //     return 24; // 3:0
    // case Agenda:
    //     return 25; // 3:1
    case opl::backspace:
        return 32; // 4:0
    case opl::K:
    case opl::k:
        return 33; // 4:1
    case opl::I:
    case opl::i:
        return 34; // 4:2
    case opl::num8:
    case opl::questionMark:
    case opl::rightCurlyBracket:
        return 35; // 4:3
    case opl::num9:
    case opl::leftParenthesis:
    case opl::leftSquareBracket:
        return 36; // 4:4
    case opl::O:
    case opl::o:
        return 37; // 4:5
    case opl::L:
    case opl::l:
        return 38; // 4:6
    case opl::control:
        return 39; // 4:7
    // case World:
    //     return 41; // 5:1
    case opl::comma:
    case opl::lessThan:
        return 49; // 6:1
    case opl::help:
        return 50; // 6:2
    case opl::M:
    case opl::m:
        return 51; // 6:3
    case opl::J:
    case opl::j:
        return 52; // 6:4
    case opl::U:
    case opl::u:
        return 53; // 6:5
    case opl::num7:
    case opl::ampersand:
    case opl::leftCurlyBracket:
        return 54; // 6:6
    case opl::rightShift:
        return 55; // 6:7
    // case Data:
    //     return 57; // 7:1
    case opl::space:
        return 64; // 8:0
    case opl::R:
    case opl::r:
        return 65; // 8:1
    case opl::num4:
    case opl::dollar:
    case opl::tilde:
        return 66; // 8:2
    case opl::num5:
    case opl::percent:
    case opl::singleQuote:
        return 67; // 8:3
    case opl::T:
    case opl::t:
        return 68; // 8:4
    case opl::G:
    case opl::g:
        return 69; // 8:5
    case opl::B:
    case opl::b:
        return 70; // 8:6
    case opl::diamond:
    case opl::capsLock:
        return 71; // 8:7
    // case System:
    //     return 73; // 9:1
    case opl::F:
    case opl::f:
        return 81; // 10:1
    case opl::V:
    case opl::v:
        return 82; // 10:2
    case opl::C:
    case opl::c:
        return 83; // 10:3
    case opl::D:
    case opl::d:
        return 84; // 10:4
    case opl::E:
    case opl::e:
        return 85; // 10:5
    case opl::num3:
    case opl::pound:
    case opl::backslash:
        return 86; // 10:6
    case opl::menu:
        return 87; // 10:7
    // case Word:
    //     return 89; // 11:1
    case opl::Q:
    case opl::q:
        return 97; // 12:1
    case opl::A:
    case opl::a:
        return 98; // 12:2
    case opl::Z:
    case opl::z:
        return 99; // 12:3
    case opl::S:
    case opl::s:
        return 100; // 12:4
    case opl::W:
    case opl::w:
        return 101; // 12:5
    case opl::X:
    case opl::x:
        return 102; // 12:6
    case opl::num1:
    case opl::exclamationMark:
        return 113; // 14:1
    case opl::num2:
    case opl::doubleQuote:
    case opl::hash:
        return 114; // 14:2
    case opl::num6:
    case opl::circumflex:
        return 115; // 14:3
    case opl::fullStop:
    case opl::greaterThan:
        return 116; // 14:4
    case opl::upArrow:
    case opl::pgUp:
        return 117; // 14:5
    case opl::H:
    case opl::h:
        return 118; // 14:6
    case opl::escape:
        return 120; // 15:0
    default:
        qWarning("unhandled sibo keycode %d", keycode);
        return -1;
    }
}

int32_t charcodeForKeycode(int32_t keycode)
{
    switch (keycode) {
    case opl::leftShift:
    case opl::rightShift:
    case opl::control:
    case opl::fn:
    case opl::capsLock:
        return 0;
    case opl::menu:
    case opl::menuSoftkey:
        return 290;
    case opl::homeKey:
        return 262;
    case opl::endKey:
        return 263;
    case opl::pgUp:
        return 260;
    case opl::pgDn:
        return 261;
    case opl::leftArrow:
        return 259;
    case opl::rightArrow:
        return 258;
    case opl::upArrow:
        return 256;
    case opl::downArrow:
        return 257;
    default:
        // Everything else has the same charcode as keycode
        return keycode;
    }
}
