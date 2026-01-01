// Copyright (c) 2025-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLKEYCODE_H
#define OPLKEYCODE_H

#include <Qt>

namespace opl {

#include "opldefs.h"

Q_DECLARE_FLAGS(Modifiers, OplModifier)
Q_DECLARE_OPERATORS_FOR_FLAGS(Modifiers)

} // end namespace


opl::Modifiers getOplModifiers(Qt::KeyboardModifiers modifiers);
int qtKeyToOpl(int qtKey);

#endif
