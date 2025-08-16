// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "clockwidget.h"

#include <QBitmap>
#include <QDateTime>
#include <QPainter>
#include <QtMath>

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

ClockWidget::ClockWidget(QWidget *parent, OplFontProvider* fontProvider, bool color)
    : QWidget(parent)
    , mClock(color ? ":/images/clock_medium_color.png" : ":/images/clock_medium.png", "PNG")
    , mFontProvider(fontProvider)
    , mClockType(OplScreen::system)
    , mSystemIsDigital(false)
{
    resize(mClock.size());
}

void ClockWidget::updateClockInfo(const OplScreen::ClockInfo& info)
{
    move(info.pos);
    mSystemIsDigital = info.systemIsDigital;
    mClockType = info.mode;
    update();
    show();
}

bool ClockWidget::isDigital() const
{
    return mClockType == OplScreen::digital || (mClockType == OplScreen::system && mSystemIsDigital);
}

void ClockWidget::paintEvent(QPaintEvent* /*event*/)
{
    QPainter painter(this);
    QDateTime now = QDateTime::currentDateTime();

    if (isDigital()) {
        if (mDigitalFont.isNull()) {
            QString path = mFontProvider->getFont(KFontDigital35, mDigitalFontMetrics);
            mDigitalFont = QPixmap(path);
            path = mFontProvider->getFont(KFontArialNormal15, mArialFontMetrics);
            mArialFont = QPixmap(path);
        }

        int displayHours = (now.time().hour() == 12 ? 12 : now.time().hour() % 12);
        auto timeStr = QString("%1:%2").arg(displayHours).arg(now.time().minute(), 2, 10, QLatin1Char('0'));
        drawCenteredText(painter, 4, timeStr, mDigitalFont, mDigitalFontMetrics);
        auto dateStr = now.date().toString("ddd d");
        drawCenteredText(painter, 45, dateStr, mArialFont, mArialFontMetrics);
    } else {
        auto pen = QPen(0xFF000000);
        pen.setWidth(2);
        painter.setPen(pen);

        painter.drawPixmap(QPoint(0, 0), mClock);

        QPointF centerPos = rect().center();
        auto minFrac = now.time().minute() / 60.0;

        const double hourHandLen = 18.0;
        const double minuteHandLen = 25.0;
        double hAngle = 2 * M_PI * (((double)(now.time().hour() % 12) + minFrac) / 12);
        double mAngle = 2 * M_PI * minFrac;
        painter.drawLines({
            { centerPos, QPoint(centerPos.x() + qSin(hAngle) * hourHandLen, centerPos.y() - qCos(hAngle) * hourHandLen) },
            { centerPos, QPoint(centerPos.x() + qSin(mAngle) * minuteHandLen, centerPos.y() - qCos(mAngle) * minuteHandLen) },
        });
    }
}

void ClockWidget::drawCenteredText(QPainter& painter, int y, const QString& text, const QPixmap& font, const OplScreen::FontMetrics& metrics)
{
    QBitmap mask = font.createMaskFromColor(0xFFFFFFFF, Qt::MaskInColor);
    QPixmap masked = font;
    masked.setMask(mask);

    // qDebug("draw %s", qPrintable(text));
    int w = 0;
    for (QChar ch : text) {
        w += rectForChar(ch.toLatin1(), metrics).width();
    }
    int x = (width() - w) / 2;
    for (QChar ch : text) {
        QRect r = rectForChar(ch.toLatin1(), metrics);
        painter.drawPixmap(QPoint(x, y), masked, r);
        x += r.width();
    }
}

void ClockWidget::systemClockChanged(bool digital)
{
    mSystemIsDigital = digital;
    update();
}
