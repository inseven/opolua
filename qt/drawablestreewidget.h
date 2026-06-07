// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef DRAWABLESTREEWIDGET_H
#define DRAWABLESTREEWIDGET_H

#include <QTreeWidget>

class DrawablesTreeWidget : public QTreeWidget
{
    Q_OBJECT

public:
    DrawablesTreeWidget(QWidget* parent = nullptr);

signals:
    void highlightWindow(int id);

protected:
    void contextMenuEvent(QContextMenuEvent *event) override;
};

#endif // DRAWABLESTREEWIDGET_H
