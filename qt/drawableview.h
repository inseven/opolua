// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef DRAWABLEVIEW_H
#define DRAWABLEVIEW_H

#include <QImage>
#include <QLabel>
#include <QScrollArea>

#include "opldebug.h"

class OplRuntime;

class DrawableView : public QScrollArea
{
    Q_OBJECT
public:
    explicit DrawableView(const opl::Drawable& drawable, QWidget *parent = nullptr);

    void update(const opl::Drawable& info, OplRuntime* runtime);

    const opl::Drawable& drawable() const { return mInfo; }
    QLabel* label() const { return static_cast<QLabel*>(widget()); }
    QImage getImage() const;

private:
    opl::Drawable mInfo;
};

#endif // DRAWABLEVIEW_H
