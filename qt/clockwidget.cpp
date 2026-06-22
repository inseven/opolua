/*
 * Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "clockwidget.h"

#include <QBitmap>
#include <QDateTime>
#include <QPainter>
#include <QtMath>

#include "oplfns.h"

static QRect rectForChar(char ch, const OplScreen::FontMetrics& metrics)
{
    int intch = (int)ch;
    int w = metrics.widths[intch];
    if (w) {
        return QRect((intch % 32) * metrics.maxwidth, (intch / 32) * metrics.height, w, metrics.height);
    } else {
        return QRect();
    }
}

static int textWidth(const QString& text, const OplScreen::FontMetrics& metrics)
{
    int w = 0;
    for (QChar ch : text) {
        w += metrics.widths[(int)ch.toLatin1()];
    }
    return w;
}

ClockWidget::ClockWidget(QWidget *parent, OplFontProvider* fontProvider)
    : QWidget(parent)
    , mScale(1)
    , mFontProvider(fontProvider)
{
    mInfo = {};
    mInfo.type = invalidClock;
    resize(mClock.size());
}

void ClockWidget::updateClockInfo(const OplScreen::ClockInfo& info)
{
    if (mClock.isNull() || info.type != mInfo.type || info.mode != mInfo.mode) {
        mInfo = info;
        mClock = QPixmap();
        auto metrics = oplGetClockMetrics(info.type);
        if (metrics.name) {
            mClock = QPixmap(QString(":/images/clock_%1.png").arg(metrics.name));
            mSize = mClock.size();
        }
        if (metrics.timeFont) {
            mTimeFont = QPixmap(mFontProvider->getFont(metrics.timeFont, mTimeFontMetrics));
        }
        if (metrics.dateFont) {
            mDateFont = QPixmap(mFontProvider->getFont(metrics.dateFont, mDateFontMetrics));
        }
        mHourHandLen = metrics.hourHandLen;
        mMinuteHandLen = metrics.minuteHandLen;

        switch (info.type) {
        case digitalSmall: {
            int w = textWidth("10:00", mTimeFontMetrics);
            if (info.showSeconds) {
                w += textWidth(":00", mTimeFontMetrics);
            }
            if (info.showDate) {
                // This is handled very weirdly, the date is put to the left so the time is always in the same place,
                // need to think how to represent that...
            }
            mSize = QSize(w, mTimeFontMetrics.height);
            break;
        }
        case digitalMedium: {
            mInfo.showSeconds = false; // This clock never shows seconds
            int w = textWidth("Mon 30", mTimeFontMetrics);
            mSize = QSize(w, mTimeFontMetrics.height * 2);
            if (mInfo.showDate) {
                mSize.rheight() += 1 + mDateFontMetrics.height;
            }
            break;
        }
        case analogSmall:
            if (mInfo.showDate) {
                mSize.rheight() += 1 + mDateFontMetrics.height;
            }
            break;
        case analogMediumBlack:
            if (mInfo.showDate) {
                mSize.rheight() += 4 + mDateFontMetrics.height;
            }
            break;
        case analogMediumS3a:
            if (mInfo.showDate) {
                mSize.rheight() += 1 + mDateFontMetrics.height;
            }
            break;
        case analogMediumS5:
        case analogMediumColor:
        case analogLargeS3a:
        case analogLargeS5:
        case analogLargeColor:
            break;
        case digitalFont:
            mInfo.showSeconds = false; // This clock never shows seconds
            mSize = QSize(61, 61); // Same as analogMediumS5
            break;
        case digitalFontShadowed:
            mInfo.showSeconds = false; // This clock never shows seconds
            mSize = QSize(51, 51); // Same as analogMediumS3a
            if (mInfo.showDate) {
                mSize.rheight() += 1 + mDateFontMetrics.height;
            }
            break;
        case invalidClock:
            break;
        }
    } else {
        mInfo = info;
    }

    setScale(mScale);
    update();
    show();
}

void ClockWidget::setScale(int scale)
{
    mScale = scale;
    setGeometry(QRect(mInfo.pos.x() * mScale, mInfo.pos.y() * mScale, mSize.width() * mScale, mSize.height() * mScale));
}

void ClockWidget::paintEvent(QPaintEvent* /*event*/)
{
    QPainter painter(this);
    painter.scale(mScale, mScale);

    if (!mClock.isNull()) {
        painter.drawPixmap(QPoint(0, 0), mClock);
    }

    QDateTime now = QDateTime::currentDateTime().addSecs(mInfo.offset);
    auto h = now.time().hour();
    auto m = now.time().minute();
    auto minFrac = m / 60.0;
    double hAngle = 2 * M_PI * (((double)(h % 12) + minFrac) / 12);
    double mAngle = 2 * M_PI * minFrac;

    int displayHours = (h == 12 ? 12 : h % 12);
    auto timeStr = QString("%1:%2").arg(displayHours).arg(now.time().minute(), 2, 10, QLatin1Char('0'));
    int leadingSpace = 0;
    if (displayHours < 10) {
        leadingSpace = textWidth("1", mTimeFontMetrics);
    }

    auto dateStr = now.date().toString("ddd d");

    switch (mInfo.type) {
    case digitalSmall:
        drawText(painter, leadingSpace, 0, timeStr, mTimeFont, mTimeFontMetrics);
        break;
    case digitalMedium: {
        // Bluh, the time is drawn in double-height so we have to do some scaling ourselves here
        QPixmap temp(mSize.width(), mTimeFontMetrics.height);
        temp.fill();
        {
            QPainter tempPainter(&temp);
            drawText(tempPainter, leadingSpace, 0, timeStr, mTimeFont, mTimeFontMetrics);
        }
        QBitmap mask = temp.createMaskFromColor(QColorConstants::White, Qt::MaskInColor);
        QSize destSize(mSize.width(), mTimeFontMetrics.height * 2);
        painter.drawPixmap(QRect(QPoint(0, 0), destSize), mask, QRect(QPoint(0, 0), temp.size()));
        if (mInfo.showDate) {
            drawCenteredText(painter, mSize.height() - mDateFontMetrics.height, dateStr, mDateFont, mDateFontMetrics);
        }
        break;
    }
    case digitalFont: {
        drawCenteredText(painter, 4, timeStr, mTimeFont, mTimeFontMetrics);
        drawCenteredText(painter, 45, dateStr, mDateFont, mDateFontMetrics);
        break;
    }
    case digitalFontShadowed: {
        int textw = textWidth(timeStr, mTimeFontMetrics) + 2;
        int x = (mSize.width() - textw) / 2;
        int y = 8;
        painter.setPen(0xFFAAAAAA);
        drawText(painter, x + 1, y + 1, timeStr, mTimeFont, mTimeFontMetrics);
        painter.setPen(Qt::black);
        drawText(painter, x - 1, y - 1, timeStr, mTimeFont, mTimeFontMetrics);

        if (mInfo.showDate) {
            drawCenteredText(painter, mSize.height() - mDateFontMetrics.height, dateStr, mDateFont, mDateFontMetrics);
        }
        break;
    }
    case analogSmall: {
        drawHands(painter, hAngle, mAngle);
        if (mInfo.showDate) {
            drawCenteredText(painter, mSize.height() - mDateFontMetrics.height, dateStr, mDateFont, mDateFontMetrics);
        }
        break;
    }
    case analogMediumBlack: {
        QPen pen;
        pen.setWidth(2);
        drawHands(painter, hAngle, mAngle, pen);

        if (mInfo.showDate) {
            drawCenteredText(painter, mSize.height() - mDateFontMetrics.height, dateStr, mDateFont, mDateFontMetrics);
        }
        break;
    }
    case analogMediumS3a: {
        QPen pen(Qt::white);
        pen.setWidth(2);
        drawHands(painter, hAngle, mAngle, pen, Qt::black);

        if (mInfo.showDate) {
            drawCenteredText(painter, mSize.height() - mDateFontMetrics.height, dateStr, mDateFont, mDateFontMetrics);
        }
        break;
    }
    case analogMediumS5: // Drop thru
    case analogMediumColor: {
        QPen pen;
        pen.setWidth(2);
        drawHands(painter, hAngle, mAngle, pen);
        break;
    }
    case analogLargeS3a: {
        auto pen = QPen(Qt::white);
        pen.setWidth(3);
        drawHands(painter, hAngle, mAngle, pen, Qt::black);
        break;
    }
    case analogLargeS5: // Drop thru
    case analogLargeColor: {
        QPen pen;
        pen.setWidth(7);
        pen.setCapStyle(Qt::RoundCap);
        drawHands(painter, hAngle, mAngle, pen);
        break;
    }
    case invalidClock:
        break;
    }
}

void ClockWidget::drawCenteredText(QPainter& painter, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics)
{
    int w = textWidth(text, metrics);
    int x = (mSize.width() - w) / 2;
    // qDebug("drawCenteredText '%s' w=%d sz=%d x=%d", qPrintable(text), w, mSize.width(), x);
    drawText(painter, x, y, text, font, metrics);
}

void ClockWidget::drawText(QPainter& painter, int x, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics)
{
    QBitmap mask = font.createMaskFromColor(QColorConstants::White, Qt::MaskInColor);

    // qDebug("draw %s", qPrintable(text));
    for (QChar ch : text) {
        QRect r = rectForChar(ch.toLatin1(), metrics);
        painter.drawPixmap(QPoint(x, y), mask, r);
        x += r.width();
    }
}

void ClockWidget::drawHands(QPainter& painter, double hAngle, double mAngle, QPen pen, QColor shadow)
{
    QPointF centerPos = QRect(0, 0, mClock.width(), mClock.height()).center(); // + QPointF(xoff, yoff);

    if (shadow.alpha() != 0) {
        QPen shadowPen(pen);
        shadowPen.setColor(shadow);
        painter.setPen(shadowPen);
        QPointF shadowCenter(centerPos.x() + 1, centerPos.y() + 1);
        painter.drawLines({
            { shadowCenter, QPoint(shadowCenter.x() + qSin(hAngle) * mHourHandLen, shadowCenter.y() - qCos(hAngle) * mHourHandLen) },
            { shadowCenter, QPoint(shadowCenter.x() + qSin(mAngle) * mMinuteHandLen, shadowCenter.y() - qCos(mAngle) * mMinuteHandLen) },
        });
    }

    painter.setPen(pen);
    painter.drawLines({
        { centerPos, QPoint(centerPos.x() + qSin(hAngle) * mHourHandLen, centerPos.y() - qCos(hAngle) * mHourHandLen) },
        { centerPos, QPoint(centerPos.x() + qSin(mAngle) * mMinuteHandLen, centerPos.y() - qCos(mAngle) * mMinuteHandLen) },
    });

    painter.setPen(QPen());
}
