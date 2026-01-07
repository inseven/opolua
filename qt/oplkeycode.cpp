/*
 * Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "oplkeycode.h"
#include <Qt>

// This function only has to handle keys that don't have a printable unicode representation - because all of those are
// handled by calling oplUnicodeToKeycode()
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

    // These declarations are needed for control-modified presses where text() won't return the letter
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

    // case Qt::Key_QuoteLeft: return opl::
    // case Qt::Key_Bar: return opl::
    default:
        // qWarning("No key for Qt code %d", qtKey);
        return 0;
    }
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
