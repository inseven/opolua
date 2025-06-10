// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef CLOCKWIDGET_H
#define CLOCKWIDGET_H

#include <QPixmap>
#include <QWidget>

class ClockWidget : public QWidget
{
    Q_OBJECT
public:
    explicit ClockWidget(QWidget *parent, bool color);

signals:

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    QPixmap mClock;
};

#endif // CLOCKWIDGET_H
