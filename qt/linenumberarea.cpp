// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "linenumberarea.h"
#include "codeview.h"

LineNumberArea::LineNumberArea(CodeView *parent)
    : QWidget(parent)
    , mCodeView(parent)
{
}

QSize LineNumberArea::sizeHint() const
{
    return QSize(mCodeView->lineNumberAreaWidth(), 0);
}

void LineNumberArea::paintEvent(QPaintEvent* event)
{
    mCodeView->lineNumberPaintEvent(event);
}
