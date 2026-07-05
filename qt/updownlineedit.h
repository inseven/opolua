// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef UPDOWNLINEEDIT_H
#define UPDOWNLINEEDIT_H

#include <QLineEdit>

class UpDownLineEdit : public QLineEdit
{
    Q_OBJECT
public:
    explicit UpDownLineEdit(QWidget *parent=nullptr);
    explicit UpDownLineEdit(QString& contents, QWidget *parent=nullptr);

protected:
    void keyPressEvent(QKeyEvent *event) override;

signals:
    void upArrowPressed();
    void downArrowPressed();
};

#endif // UPDOWNLINEEDIT_H
