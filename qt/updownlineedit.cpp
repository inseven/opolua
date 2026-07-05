// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "updownlineedit.h"
#include <QDebug>
#include <QKeyEvent>

UpDownLineEdit::UpDownLineEdit(QWidget *parent)
    : QLineEdit(parent)
{
}

UpDownLineEdit::UpDownLineEdit(QString& contents, QWidget *parent)
    : QLineEdit(contents, parent)
{
}

void UpDownLineEdit::keyPressEvent(QKeyEvent *event)
{
    switch (event->key()) {
    case Qt::Key_Up:
        emit upArrowPressed();
        break;
    case Qt::Key_Down:
        emit downArrowPressed();
        break;
    default:
        QLineEdit::keyPressEvent(event);
    }
}
