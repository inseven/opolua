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
            Q_ASSERT(false);
            return keycode;
        }
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
