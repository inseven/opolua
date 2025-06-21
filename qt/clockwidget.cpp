// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "clockwidget.h"

#include <QDateTime>
#include <QPainter>
#include <QtMath>

ClockWidget::ClockWidget(QWidget *parent, bool color)
    : QWidget(parent)
    , mClock(color ? ":/clock/medium_color.png" : ":/clock/medium.png", "PNG")
{
    resize(mClock.size());
}

void ClockWidget::paintEvent(QPaintEvent */*event*/)
{
    QPainter painter(this);
    auto pen = QPen(0xFF000000);
    pen.setWidth(2);
    painter.setPen(pen);

    painter.drawPixmap(QPoint(0, 0), mClock);

    QPointF centerPos = rect().center();
    auto now = QDateTime::currentDateTime().time();
    auto minFrac = now.minute() / 60.0;

    const double hourHandLen = 18.0;
    const double minuteHandLen = 25.0;
    double hAngle = 2 * M_PI * (((double)(now.hour() % 12) + minFrac) / 12);
    double mAngle = 2 * M_PI * minFrac;
    painter.drawLines({
        { centerPos, QPoint(centerPos.x() + qSin(hAngle) * hourHandLen, centerPos.y() - qCos(hAngle) * hourHandLen) },
        { centerPos, QPoint(centerPos.x() + qSin(mAngle) * minuteHandLen, centerPos.y() - qCos(mAngle) * minuteHandLen) },
    });
}
