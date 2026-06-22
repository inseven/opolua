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

#ifndef CLOCKWIDGET_H
#define CLOCKWIDGET_H

#include <QPainter>
#include <QPen>
#include <QPixmap>
#include <QWidget>

#include "oplscreen.h"

class ClockWidget : public QWidget
{
    Q_OBJECT
public:
    explicit ClockWidget(QWidget *parent, OplFontProvider* fontProvider);

    void updateClockInfo(const OplScreen::ClockInfo& info);
    const OplScreen::ClockInfo& getInfo() const { return mInfo; }
    void setScale(int scale);

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    void drawText(QPainter& painter, int x, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics);
    void drawCenteredText(QPainter& painter, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics);
    void drawHands(QPainter& painter, double hAngle, double mAngle, QPen pen=QPen(), QColor shadow=Qt::transparent);

private:
    QSize mSize; // Unscaled
    int mScale;
    QPixmap mClock;
    OplFontProvider* mFontProvider;
    QPixmap mTimeFont;
    OplScreen::FontMetrics mTimeFontMetrics;
    QPixmap mDateFont;
    OplScreen::FontMetrics mDateFontMetrics;
    OplScreen::ClockInfo mInfo;
    double mHourHandLen;
    double mMinuteHandLen;

};

#endif // CLOCKWIDGET_H
