// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef STACKVIEW_H
#define STACKVIEW_H

#include <QTreeView>

class StackModel;

class StackView : public QTreeView
{
    Q_OBJECT

public:
    StackView(QWidget* parent = nullptr);
    StackModel* model() const;

signals:
    void gotoAddress(const QString& module, uint32_t address);

protected:
    void contextMenuEvent(QContextMenuEvent *event) override;

private:
    void rowsInserted(const QModelIndex &parent, int first, int last) override;
};

#endif // STACKVIEW_H
