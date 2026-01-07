/*
 * Copyright (C) 2025-2026 Jason Morley, Tom Sutcliffe
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
#include <QPixmap>
#include <QWidget>

#include "oplscreen.h"

class ClockWidget : public QWidget
{
    Q_OBJECT
public:
    explicit ClockWidget(QWidget *parent, OplFontProvider* fontProvider, bool color);

    void updateClockInfo(const OplScreen::ClockInfo& info);
    void setScale(int scale);

public slots:
    void systemClockChanged(bool digital);

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    void drawCenteredText(QPainter& painter, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics);
    bool isDigital() const;

private:
    int mScale;
    QPixmap mClock;
    OplFontProvider* mFontProvider;
    QPixmap mDigitalFont;
    OplScreen::FontMetrics mDigitalFontMetrics;
    QPixmap mArialFont;
    OplScreen::FontMetrics mArialFontMetrics;
    OplScreen::ClockInfo mInfo;
};

#endif // CLOCKWIDGET_H
