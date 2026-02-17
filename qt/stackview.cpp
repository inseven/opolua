// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "stackview.h"
#include "stackmodel.h"

#include <QAction>
#include <QContextMenuEvent>
#include <QMenu>

StackView::StackView(QWidget* parent)
    : QTreeView(parent)
{
}

StackModel* StackView::model() const
{
    return reinterpret_cast<StackModel*>(QTreeView::model());
}

void StackView::rowsInserted(const QModelIndex &parent, int first, int last)
{
    QTreeView::rowsInserted(parent, first, last);
    if (!parent.isValid()) { // ie, top level-row
        // All top-level items should start out expanded (by default they're collapsed)
        for (int i = first; i <= last; i++) {
            setExpanded(model()->index(i, 0, parent), true);
        }
    }
}

void StackView::contextMenuEvent(QContextMenuEvent *event)
{
    auto index = indexAt(event->pos());
    if (index.isValid() /*&& !index.parent().isValid()*/) {
        // Then it's a top-level item ie a variable
        auto frame = model()->getFrameForIndex(index);
        QMenu menu(this);
        QAction* gotoAction = nullptr;
        QAction* expandAction = nullptr;
        if (frame.has_value()) {
            gotoAction = menu.addAction("Go to location");
            expandAction = menu.addAction("Expand All Children");
        }
        auto collapseAction = menu.addAction("Collapse All");

        auto action = menu.exec(event->globalPos());

        if (!action) {
            return;
        } else if (action == gotoAction) {
            emit gotoAddress(frame->procModule, frame->ip);
        } else if (action == expandAction) {
            expandRecursively(index);
        } else if (action == collapseAction) {
            collapseAll();
        }
    }
}
