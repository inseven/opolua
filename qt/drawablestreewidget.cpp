// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "drawablestreewidget.h"

#include <QAction>
#include <QContextMenuEvent>
#include <QMenu>

DrawablesTreeWidget::DrawablesTreeWidget(QWidget* parent)
    : QTreeWidget(parent)
{
}

void DrawablesTreeWidget::contextMenuEvent(QContextMenuEvent *event)
{
    auto item = itemAt(event->pos());
    if (item) {

        auto rank = item->text(1);
        if (rank.isEmpty()) {
            // Then it's a bitmap not a window, we have no actions for bitmaps
            return;
        }

        // Then it's a top-level item ie a variable
        // auto frame = model()->getFrameForIndex(index);
        QMenu menu(this);
        QAction* highlightAction = menu.addAction("Highlight");

        auto action = menu.exec(event->globalPos());

        if (!action) {
            return;
        } else if (action == highlightAction) {
            auto id = item->text(0).toInt();
            emit highlightWindow(id);
        }
    }
}
