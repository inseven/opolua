// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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

public slots:
    void systemClockChanged(bool digital);

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    void drawCenteredText(QPainter& painter, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics);
    bool isDigital() const;

private:
    QPixmap mClock;
    OplFontProvider* mFontProvider;
    QPixmap mDigitalFont;
    OplScreen::FontMetrics mDigitalFontMetrics;
    QPixmap mArialFont;
    OplScreen::FontMetrics mArialFontMetrics;
    OplScreen::ClockType mClockType;
    bool mSystemIsDigital;
};

#endif // CLOCKWIDGET_H
