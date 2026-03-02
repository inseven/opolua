// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "drawableview.h"

#include "oplruntime.h"
#include "oplscreenwidget.h"

DrawableView::DrawableView(const opl::Drawable& drawable, QWidget *parent)
    : QScrollArea(parent)
    , mInfo(drawable)
{
    setAlignment(Qt::AlignHCenter | Qt::AlignVCenter);
    auto label = new QLabel;
    setWidget(label);
}

void DrawableView::update(const opl::Drawable& info, OplRuntime* runtime)
{
    Q_ASSERT(info.id == mInfo.id);
    if (info == mInfo && !label()->pixmap(Qt::ReturnByValue).isNull()) {
        return;
    }
    mInfo = info;
    auto screen = static_cast<OplScreenWidget*>(runtime->getScreen());
    auto px = screen->getPixmap(mInfo.id);
    label()->resize(info.rect.size());
    label()->setPixmap(px);
}

QImage DrawableView::getImage() const
{
    // The ReturnByValue is a compat workaround for Qt 5.
    return label()->pixmap(Qt::ReturnByValue).toImage();
}
