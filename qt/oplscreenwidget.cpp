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

#include "oplscreenwidget.h"

#include "asynchandle.h"
#include "audioplayer.h"
#include "clockwidget.h"
#include "oplfns.h"
#include "oplruntimegui.h"

#include <QDateTime>
#include <QPainter>
#include <QSet>

#if 0
#define PAINTER_BEGIN(name, px) \
    QPainter name; \
    if (!name.begin(px)) { \
        qFatal("QPainter begin failed!"); \
    }
#else
#define PAINTER_BEGIN(name, px) QPainter name(px)
#endif

OplScreenWidget::OplScreenWidget(QWidget *parent)
    : QWidget(parent)
    , mScale(1)
    , mSpriteWidget(nullptr)
    , mAudioChannels{}
{
    mRuntime = new OplRuntimeGui(this);
    mRuntime->setScreen(this);
    connect(mRuntime, &OplRuntime::runComplete, this, &OplScreenWidget::onStopped);
    connect(mRuntime, &OplRuntime::deviceTypeChanged, this, &OplScreenWidget::onDeviceTypeChanged);
    connect(mRuntime, &OplRuntime::systemClockChanged, this, &OplScreenWidget::onSystemClockChanged);

    setFocusPolicy(Qt::StrongFocus);
}

OplScreenWidget::~OplScreenWidget()
{
    init();
}

void OplScreenWidget::init()
{
    auto keys = mDrawables.keys();
    for (int drawableId : keys) {
        closeDrawable(drawableId);
    }
    mWindows.clear();
    mDrawables.clear();
    Q_ASSERT(findChildren<Window*>().count() == 0);
    delete mStoppedShadow;
}

void OplScreenWidget::onStopped()
{
    mSpriteTimer.reset();
    if (mRuntime->lastLauncherCommand() != "launcher") {
        mStoppedShadow = new WindowShadow(this);
        mStoppedShadow->setGeometry(0, 0, width(), height());
        mStoppedShadow->show();
    }
}

OplRuntimeGui* OplScreenWidget::getRuntime() const
{
    return mRuntime;
}

QSize OplScreenWidget::sizeHint() const
{
    if (mRuntime) {
        auto sz = mRuntime->screenSize();
        return QSize(sz.width() * mScale, sz.height() * mScale);
    } else {
        return QSize();
    }
}

void OplScreenWidget::setScale(int scale)
{
    mScale = scale;
    for (Window* w : mWindows) {
        w->setScale(scale);
    }
    auto sz = sizeHint();
    if (mSpriteWidget) {
        mSpriteWidget->resize(sz);
    }
    if (mStoppedShadow) {
        mStoppedShadow->resize(sz);
    }
    if (mShadowOverlay) {
        mShadowOverlay->resize(sz);
    }
    updateGeometry();
}

void OplScreenWidget::onDeviceTypeChanged()
{
    updateGeometry();
    emit deviceTypeChanged();
}

Drawable* OplScreenWidget::getBitmap(int drawableId) const
{
    if (mWindows.value(drawableId)) {
        qDebug("Cannot use getBitmap to fetch a window!");
        return nullptr;
    }
    return mDrawables.value(drawableId);
}

QPixmap OplScreenWidget::getPixmap(int drawableId) const
{
    auto drawable = mDrawables.value(drawableId);
    if (!drawable) {
        return QPixmap();
    }
    return drawable->getPixmap();
}

void OplScreenWidget::keyPressEvent(QKeyEvent *event)
{
    mRuntime->keyEvent(*event);
}

void OplScreenWidget::keyReleaseEvent(QKeyEvent *event)
{
    mRuntime->keyEvent(*event);
}

void OplScreenWidget::mouseEvent(QMouseEvent* event, Window* window)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QPoint pos = event->position().toPoint();
#else
    QPoint pos = event->pos();
#endif

    QPointF localPos(pos.x() / mScale, pos.y() / mScale);
    QPoint windowPos = window->getPos();
    QPointF screenPos(windowPos.x() + localPos.x(), windowPos.y() + localPos.y());
    QMouseEvent me(event->type(), localPos, screenPos, event->button(), event->buttons(), event->modifiers());

    mRuntime->mouseEvent(me, window->getId());
}

void OplScreenWidget::focusInEvent(QFocusEvent *event)
{
    getRuntime()->focusEvent(true);
    QWidget::focusInEvent(event);
}

void OplScreenWidget::focusOutEvent(QFocusEvent *event)
{
    getRuntime()->focusEvent(false);
    QWidget::focusOutEvent(event);
}

void OplScreenWidget::closeDrawable(int drawableId)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (win) {
        delete win;
        mWindows.remove(drawableId);
        updateShadows();
    } else {
        auto drawable = mDrawables.value(drawableId, nullptr);
        if (drawable) {
            delete drawable;
        }
    }
    mDrawables.remove(drawableId);
}

int OplScreenWidget::createWindow(int drawableId, const QRect& rect, BitmapMode mode, int shadowSize)
{
    // qDebug("createWindow id=%d (%d,%d) %dx%d mode=%d", drawableId, rect.x(), rect.y(), rect.width(), rect.height(), mode);
    auto win = new Window(this, drawableId, rect, mode, shadowSize);
    win->setScale(mScale);
    mWindows.insert(drawableId, win);
    mDrawables.insert(drawableId, win);
    if (mShadowOverlay) {
        updateShadows();
    } else {
        mShadowOverlay = new ShadowOverlay(this);
    }
    return KErrNone;
}

int OplScreenWidget::createBitmap(int drawableId, const QSize& size, BitmapMode mode)
{
    auto bmp = new Drawable(drawableId, size, mode);
    mDrawables.insert(drawableId, bmp);
    return KErrNone;
}

int OplScreenWidget::loadPng(int drawableId, const QString& path)
{
    QPixmap img;
    bool ok = img.load(path, "PNG");
    if (!ok) {
        return KErrGenFail;
    }

    auto bmp = new Drawable(drawableId, std::move(img), OplScreen::gray2);
    mDrawables.insert(drawableId, bmp);
    return KErrNone;
}

/**
 N.B. In OPL terms position=1 means the front and position=n means the back, whereas child[0] is at the back and
 child[n-1] the front.
 */
int OplScreenWidget::setOrder(int drawableId, int order)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        return KErrDrawNotOpen;
    }
    QList<Window*> children = findChildren<Window*>();
    Q_ASSERT(children.count() == mWindows.count());
    int orderNorm = qMin(qMax(1, order), mWindows.count());
    int currentPos = children.indexOf(win);
    int newPos = mWindows.count() - orderNorm;
    // qDebug("order %d pos %d -> %d count=%d", order, currentPos, newPos, (int)children.count());

    if (newPos == mWindows.count() - 1) {
        win->raise();
        if (mSpriteWidget) {
            mSpriteWidget->raise();
        }
    } else {
        if (newPos > currentPos) {
            // Have to allow for the fact the window is already below the widget we want to stack under
            newPos++;
        }
        win->stackUnder(children[newPos]);
    }
    updateShadows();
    return KErrNone;
}

int OplScreenWidget::getRank(int drawableId)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        return KErrDrawNotOpen;
    }

    QList<Window*> children = findChildren<Window*>();
    int uipos = children.indexOf(win);
    Q_ASSERT(uipos > -1);
    return children.count() - uipos;
}

int OplScreenWidget::showWindow(int drawableId, bool flag)
{
    // qDebug("showWindow %d %d", drawableId, flag);
    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        return KErrDrawNotOpen;
    }
    win->setVisible(flag);
    updateShadows();
    return KErrNone;
}

void OplScreenWidget::highlightWindow(int drawableId)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        qWarning("highlightWindow called on non-existent window id %d", drawableId);
        return;
    }
    win->setHighlighted(true);
    QTimer::singleShot(300, win, [win] { win->setHighlighted(false); });
}

int OplScreenWidget::setWindowRect(int drawableId, const QPoint& position, const QSize* size)
{
    // qDebug("setwin id=%d (%d,%d) %dx%d", drawableId, position.x(), position.y(), size ? size->width() : 0, size ? size->height() : 0);

    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        return KErrDrawNotOpen;
    }
    win->setPos(position);
    if (size) {
        win->setSize(*size);
    }
    updateShadows();
    return KErrNone;
}

void OplScreenWidget::beginBatchDraw()
{
    mBatchSeenDrawables.clear();
}

void OplScreenWidget::draw(const DrawCmd& cmd)
{
    auto drawable = mDrawables.value(cmd.drawableId);
    if (drawable) {
        mBatchSeenDrawables.insert(drawable);

        if (cmd.type == OplScreen::copy) {
            Drawable* src = mDrawables.value(cmd.copy.srcDrawableId);
            Drawable* mask = nullptr;
            if (cmd.copy.maskDrawableId) {
                mask = mDrawables.value(cmd.copy.maskDrawableId);
            }
            if (src) {
                drawable->drawCopy(cmd, *src, mask);
            }
        } else if (cmd.type == OplScreen::pattern) {
            Drawable* src = nullptr;
            if (cmd.pattern.srcDrawableId == -1) {
                // Using a fake drawable to implement the dither pattern isn't perfect, because the psion ensures to
                // always align the pattern whereas this implementation does not. But it's probably good enough(TM).
                if (!mDitherPattern) {
                    if (loadPng(-1, ":/images/dither_pattern.png") == KErrNone) {
                        mDitherPattern.reset(mDrawables.value(-1));
                        mDrawables.remove(-1);
                    }
                }
                src = mDitherPattern.get();
            } else {
                src = mDrawables.value(cmd.pattern.srcDrawableId);
            }
            if (src) {
                drawable->drawCopy(cmd, *src, nullptr);
            }
        } else {
            drawable->draw(cmd);
        }
    }
}

void OplScreenWidget::endBatchDraw()
{
    for (auto drawable : mBatchSeenDrawables) {
        drawable->update();
    }
    mBatchSeenDrawables.clear();
}

void OplScreenWidget::bitBlt(int drawableId, bool color, int width, int height, const QByteArray& data)
{
    auto drawable = mDrawables.value(drawableId, nullptr);
    if (!drawable) {
        qWarning("No drawable %d for bitblt", drawableId);
        return;
    }
    mBatchSeenDrawables.insert(drawable);
    drawable->loadFromBitmap(color, width, height, data);
}

static int maxX(const QRect& rect) {
    return rect.x() + rect.width();
}

static int maxY(const QRect& rect) {
    return rect.y() + rect.height();
}

static bool adjustBounds(QRect& srcRect, QRect& destRect, const QSize& srcSize, const QSize& destSize)
{
    QRect destClipped = destRect.intersected(QRect(0, 0, destSize.width(), destSize.height()));
    if (destClipped.isEmpty()) {
        // If no part of the destination is within the bounds of the drawable then this operation is a no-op
        return false;
    }

    // Reduce src to match destClipped
    int srcAdjustedX = srcRect.left() + (destClipped.left() - destRect.left());
    int srcAdjustedY = srcRect.top() + (destClipped.top() - destRect.top());
    int srcAdjustedMaxX = maxX(srcRect) + (maxX(destClipped) - maxX(destRect));
    int srcAdjustedMaxY = maxY(srcRect) + (maxY(destClipped) - maxY(destRect));

    QRect srcAdjusted(srcAdjustedX, srcAdjustedY, srcAdjustedMaxX - srcAdjustedX, srcAdjustedMaxY - srcAdjustedY);
    QRect srcClipped = srcAdjusted.intersected(QRect(0, 0, srcSize.width(), srcSize.height()));
    if (srcClipped.isEmpty()) {
        // Likewise a no-op
        return false;
    }

    int destX = destClipped.left() + (srcClipped.left() - srcAdjusted.left());
    int destY = destClipped.top() + (srcClipped.top() - srcAdjusted.top());

    srcRect = srcClipped;
    destRect = QRect(destX, destY, srcRect.width(), srcRect.height());
    return true;
}

void OplScreenWidget::copyMultiple(const OplScreen::CopyMultipleCmd& cmd, const QVector<QRect>& rects, const QVector<QPoint>& points)
{
    auto src = mDrawables.value(cmd.srcId, nullptr);
    auto dest = mDrawables.value(cmd.destId, nullptr);
     if (!src || !dest) {
        qWarning("Bad src/dest in copyMultiple");
        return;
    }

    dest->invalidateMask();

    for (int i = 0; i < rects.count(); i++) {
        QRect srcRect = rects[i];
        QRect destRect = QRect(points[i], srcRect.size());
        if (adjustBounds(srcRect, destRect, src->size(), dest->size())) {
            dest->drawSetPixels(cmd, *src, srcRect, destRect);
        }
    }
    mBatchSeenDrawables.insert(dest);
}

void OplScreenWidget::clock(int drawableId, const OplScreen::ClockInfo* info)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (win) {
        if (info && !win->mClock) {
            win->mClock = new ClockWidget(win, getRuntime());
            win->mClock->setScale(mScale);
            // God DAMN that cast is nasty. Needed because QWidget has overloads of update making the slot kinda
            // broken. In Qt 6 we can use qOverload<> but that's not available in Qt 5...
            connect(this, &OplScreenWidget::clockTimeChanged, win->mClock, static_cast<void(QWidget::*)()>(&QWidget::update));
        } else if (win->mClock && !info) {
            win->mClock->hide();
        }

        if (info) {
            win->mClock->updateClockInfo(*info);
            startClockTimer();
        }
    }
}

void OplScreenWidget::startClockTimer()
{
    if (!mClockTimer) {
        mClockTimer.reset(new QTimer());
        mClockTimer->setSingleShot(true);
        connect(mClockTimer.get(), &QTimer::timeout, this, &OplScreenWidget::clockTick);
    }
    if (!mClockTimer->isActive()) {
        // I don't like the Qt date/time APIs much. Having QTime as a separate class is weird. This is the best way I
        // can think of to get the time until the next minute changes, that doesn't have unpleasant corner cases when
        // the time is close to midnight or a DST change.
        auto now = QDateTime::currentDateTime();
        auto t = now.time();
        auto elapsedThisMinute = QTime(t.hour(), t.minute(), 0).msecsTo(t);
        auto toNextMin = 60000 - elapsedThisMinute;

        mClockTimer->start(toNextMin);
    }
}

void OplScreenWidget::clockTick()
{
    emit clockTimeChanged();
    startClockTimer();
}

void OplScreenWidget::onSystemClockChanged(bool digital)
{
    for (Window* w : mWindows) {
        if (w->mClock) {
            ClockInfo info = w->mClock->getInfo();
            auto newType = oplModeToClockType(info.mode, mRuntime->getDeviceType(), digital);
            if (newType != info.type) {
                info.type = newType;
                w->mClock->updateClockInfo(info);
            }
        }
    }
}

void OplScreenWidget::playSound(AsyncHandle* handle, int channel, const QByteArray& data)
{
    Q_ASSERT(channel == 0 || channel == 1);
    if (!mAudioChannels[channel]) {
        mAudioChannels[channel] = new AudioPlayer(this);
    }

    mAudioChannels[channel]->playSound(handle, data);
}

void OplScreenWidget::sprite(int drawableId, int spriteId, const OplScreen::Sprite* sprite)
{
    Window* w = mWindows.value(drawableId);
    if (w) {
        w->setSprite(spriteId, sprite);
    } else {
        qDebug("No window found for sprite drawable %d!", drawableId);
    }

    if (sprite && !mSpriteTimer) {
        mSpriteTimer.reset(new QTimer());
        mSpriteTimer->setTimerType(Qt::PreciseTimer);
        mLastSpriteTick = QDateTime::currentMSecsSinceEpoch();
        connect(mSpriteTimer.get(), &QTimer::timeout, this, &OplScreenWidget::spriteTimerTick);
        mSpriteWidget = new SpriteWidget(this);
        mSpriteTimer->start(50);
    }
}

void OplScreenWidget::spriteTimerTick()
{
    int64_t now = QDateTime::currentMSecsSinceEpoch();
    int64_t delta = now - mLastSpriteTick;
    for (Window* w : mWindows) {
        w->animateSprites(delta * 1000);
    }
    mLastSpriteTick = now;

    // An oddity of the sprite API is that they can appear anywhere on the screen, ie are not cropped to the Window they
    // are associated with. For that reason, we need to keep a separate fullscreen transparent pixmap around to render
    // them in to.
    mSpriteWidget->renderSprites(mWindows.values(), mScale);
}

QByteArray OplScreenWidget::peekLine(int drawableId, const QPoint& position, int numPixels, OplScreen::PeekMode mode)
{
    auto src = mDrawables.value(drawableId, nullptr);
    if (!src) {
        qDebug("Bad drawableId %d to peekLine", drawableId);
        return QByteArray();
    }
    auto img = src->getPixmap().toImage();
    img.convertTo(QImage::Format_Grayscale8); // Simplifies logic
    QByteArray result;
    int bitIdx = 0;
    uint8_t currentByte = 0;
    auto addPixel = [&bitIdx, &currentByte, &result, mode](uint8_t value) {
        switch (mode) {
        case oneBitBlack:
            currentByte |= (value == 0 ? 1 : 0) << bitIdx;
            bitIdx += 1;
            break;
        case oneBitWhite:
            currentByte |= (value != 0 ? 1 : 0) << bitIdx;
            bitIdx += 1;
            break;
        case twoBit:
            currentByte |= (value >> 6) << bitIdx;
            bitIdx += 2;
            break;
        case fourBit:
            currentByte |= (value >> 4) << bitIdx;
            bitIdx += 4;
            break;
        }

        if (bitIdx == 8) {
            result.append(currentByte);
            currentByte = 0;
            bitIdx = 0;
        }
    };

    // gPEEKLINE is allowed to look outside the bitmap bounds, it's expected to return white for those. And yes there
    // are things that actually rely on that... (#591)
    int numValidPixels = qMax(0, qMin(numPixels, img.width() - position.x()));
    if (position.y() >= img.height()) {
        numValidPixels = 0;
    }
    if (numValidPixels > 0) {
        auto bits = img.constScanLine(position.y()) + position.x();
        auto endPtr = bits + numValidPixels;
        while (bits < endPtr) {
            addPixel(*bits++);
        }
    }
    while (numValidPixels < numPixels) {
        addPixel(0xFF);
        numValidPixels++;
    }
    if (bitIdx != 0) {
        result.append(currentByte);
    }
    return result;
}

QByteArray OplScreenWidget::getImageData(int drawableId, const QRect& rect)
{
    auto src = mDrawables.value(drawableId, nullptr);
    if (!src) {
        qDebug("Bad drawableId %d to getImageData", drawableId);
        return QByteArray();
    }

    const bool isColor = src->getMode() >= OplScreen::color16;
    auto img = src->getPixmap().toImage().copy(rect);
    img.convertTo(isColor ? QImage::Format_RGB32 : QImage::Format_Grayscale8);
    QByteArray result;
    for (int i = 0; i < img.height(); i++) {
        auto ptr = img.constScanLine(i);
        result.append(reinterpret_cast<const char*>(ptr), img.width() * (isColor ? 4 : 1));
    }
    return result;
}

void OplScreenWidget::updateShadows()
{
    if (mShadowOverlay) {
        mShadowOverlay->raise();
        mShadowOverlay->update();
    }
}

////

Drawable::Drawable(int drawableId, const QSize& size, OplScreen::BitmapMode mode)
    : id(drawableId)
    , mPixmap(size)
    , mode(mode)
{
    mPixmap.fill(QColorConstants::White);
}

Drawable::Drawable(int drawableId, QPixmap&& pixmap, OplScreen::BitmapMode mode)
    : id(drawableId)
    , mPixmap(std::move(pixmap))
    , mode(mode)
{}

int Drawable::getId() const
{
    return id;
}

void Drawable::update()
{
    // For subclass
}

void Drawable::draw(const OplScreen::DrawCmd& cmd)
{
    invalidateMask();
    PAINTER_BEGIN(painter, &mPixmap);
    QPen pen(cmd.mode == OplScreen::clear ? cmd.bgcolor : cmd.color);
    pen.setWidth(cmd.penWidth);
    QBrush brush(cmd.mode == OplScreen::clear ? cmd.bgcolor : cmd.color);
    painter.setPen(pen);
    if (cmd.mode == OplScreen::invert) {
        painter.setCompositionMode(QPainter::RasterOp_NotSourceXorDestination);
    }

    switch (cmd.type) {
    case OplScreen::fill:
        painter.fillRect(QRect(cmd.origin, cmd.fill.size), brush);
        break;
    case OplScreen::line:
        // qDebug("line col=%x", cmd.color);
        painter.drawLine(cmd.origin, cmd.line.endPoint);
        break;
    case OplScreen::circle:
        if (cmd.circle.fill) {
            painter.setBrush(brush);
        }
        painter.drawEllipse(cmd.origin, cmd.circle.radius, cmd.circle.radius);
        break;
    case OplScreen::ellipse:
        if (cmd.ellipse.fill) {
            painter.setBrush(brush);
        }
        painter.drawEllipse(cmd.origin, cmd.ellipse.hRadius, cmd.ellipse.vRadius);
        break;
    case OplScreen::box:
        painter.drawRect(cmd.origin.x(), cmd.origin.y(), cmd.box.size.width() - 1, cmd.box.size.height() - 1);
        break;
    case OplScreen::scroll: {
        // Make sure we don't inadvertently stretch or try to scroll beyond image limits
        QRect bounds(QPoint(), size());
        QRect origRect = cmd.scroll.rect.intersected(bounds);
        QPixmap pixToScroll = mPixmap.copy(origRect);
        QRect newRect(origRect.x() + cmd.scroll.dx, origRect.y() + cmd.scroll.dy, origRect.width(), origRect.height());
        // This is not entirely the right logic if both dx and dy are non-zero, but probably good enough for now
        int minX = qMin(origRect.x(), newRect.x());
        int minY = qMin(origRect.y(), newRect.y());
        int max_X = qMax(maxX(origRect), maxX(newRect));
        int max_Y = qMax(maxY(origRect), maxY(newRect));
        QRect clearRect = QRect(minX, minY, max_X - minX, max_Y - minY).normalized();
        painter.fillRect(clearRect, QBrush(cmd.bgcolor));
        painter.drawPixmap(newRect, pixToScroll);
        break;
    }
    case OplScreen::border: {
        auto id = QString("%1").arg(cmd.border.borderType, 5, 16, QLatin1Char('0')).toUpper();
        QString borderEra(cmd.border.epoc32 ? "epoc32" : "sibo");
        auto borderPath = QString(":/borders/%1/%2.png").arg(borderEra).arg(id);
        QPixmap px(borderPath, "PNG");
        if (px.isNull()) {
            qDebug("Failed to load border %s w=%d", qPrintable(borderPath), px.width());
        }
        const QRect& r = cmd.border.rect;
        // gXBORDER(1, 3) needs nine pixels, most other borders only 5 or 6
        // gXBORDER(1, $203) on S3a (round corners, double shadow) takes 11!
        int d = qMin(11, qMin(r.width(), r.height()) / 2);
        // qDebug("border (%d, %d, %dx%d) d=%d using %s", r.x(), r.y(), r.width(), r.height(), d, qPrintable(borderPath));
        // TODO these operations don't take into account the current colour. Should they...?
        painter.drawPixmap(r.x(), r.y(), px, 0, 0, d, d); // tl
        painter.drawPixmap(r.x() + r.width() - d, r.y(), px, px.width() - d, 0, d, d); // tr
        painter.drawPixmap(r.x(), r.y() + r.height() - d, px, 0, px.height() - d, d, d); // bl
        painter.drawPixmap(r.x() + r.width() - d, r.y() + r.height() - d, px, px.width() - d, px.height() - d, d, d); // br
        painter.drawPixmap(QRect(r.x() + d, r.y(), r.width() - 2 * d, d), px, QRect(d, 0, px.width() - 2 * d, d)); // top
        painter.drawPixmap(QRect(r.x() + d, r.y() + r.height() - d, r.width() - 2 * d, d), px, QRect(d, px.height() - d, px.width() - 2 * d, d)); // bottom
        painter.drawPixmap(QRect(r.x(), r.y() + d, d, r.height() - 2 * d), px, QRect(0, d, d, px.height() - 2 * d)); // left
        painter.drawPixmap(QRect(r.x() + r.width() - d, r.y() + d, d, r.height() - 2 * d), px, QRect(px.width() - d, d, d, px.height() - 2 * d)); // right
        break;
    }
    case OplScreen::cmdInvert: {
        QPixmap temp(cmd.invert.size);
        temp.fill(QColorConstants::Black);
        {
            PAINTER_BEGIN(tempPainter, &temp);
            tempPainter.setPen(QColorConstants::White);
            tempPainter.drawPoint(0, 0);
            tempPainter.drawPoint(0, cmd.invert.size.height() - 1);
            tempPainter.drawPoint(cmd.invert.size.width() - 1, 0);
            tempPainter.drawPoint(cmd.invert.size.width() - 1, cmd.invert.size.height() - 1);
        }
        painter.setCompositionMode(QPainter::RasterOp_NotSourceXorDestination);
        painter.drawPixmap(cmd.origin, temp);
        break;
    }
    default:
        qWarning("Unhandled draw cmd %d", cmd.type);
    }
}

QSize Drawable::size() const
{
    return mPixmap.size();
}

void Drawable::setSize(const QSize& size)
{
    Q_ASSERT(size.width() && size.height());
    QPixmap newPixmap(size);
    newPixmap.fill(QColorConstants::White);
    mPixmap.swap(newPixmap);
    invalidateMask();
}

QPixmap& Drawable::getPixmap()
{
    return mPixmap;
}

QBitmap& Drawable::getMask()
{
    if (mMask.isNull()) {
        mMask = mPixmap.createMaskFromColor(QColorConstants::White, Qt::MaskInColor);
    }
    return mMask;
}

void Drawable::invalidateMask()
{
    if (!mMask.isNull()) {
        QBitmap null;
        mMask.swap(null);
    }
}

Drawable* Drawable::getGreyPlane() const
{
    // Bitmaps never have a grey plane.
    return nullptr;
}

void Drawable::drawSetPixels(const OplScreen::CopyMultipleCmd& cmd, Drawable& src, const QRect& srcRect, const QRect& destRect)
{
    PAINTER_BEGIN(painter, &mPixmap);
    painter.setPen(cmd.color);
    if (cmd.invert) {
        // See comment in drawCopy below
        QPixmap tempBuf = mPixmap.copy(destRect);
        QPainter tempPainter(&tempBuf);
        tempPainter.setCompositionMode(QPainter::RasterOp_NotSourceXorDestination);
        tempPainter.drawPixmap(QPoint(), src.mPixmap, srcRect);
        tempPainter.end();
        tempBuf.setMask(OplRuntimeGui::pixToBitmap(src.getMask().copy(srcRect)));
        painter.drawPixmap(destRect, tempBuf);
    } else {
        painter.drawPixmap(destRect, src.getMask(), srcRect);
    }
}

void Drawable::drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src, Drawable* mask)
{
    Q_ASSERT(cmd.type == OplScreen::copy || cmd.type == OplScreen::pattern);
    bool tiled = cmd.type == OplScreen::pattern;
    invalidateMask();
    PAINTER_BEGIN(painter, &mPixmap);
    QRect destRect;
    if (tiled) {
        destRect = QRect(cmd.origin, cmd.pattern.size);
    } else {
        destRect = QRect(cmd.origin, cmd.copy.srcRect.size());
    }
    if (mask) {
        QPixmap maskedSource(src.mPixmap);
        QBitmap pixmask = mask->getMask();
        if (pixmask.size() != maskedSource.size()) {
            // Workaround for broken masks smaller than the source (Tile Fall, looking at you)
            QBitmap newMask(maskedSource.size());
            newMask.clear();
            {
                PAINTER_BEGIN(maskPainter, &newMask);
                maskPainter.drawPixmap(QPoint(), pixmask);
            }
            pixmask.swap(newMask);
        }
        maskedSource.setMask(pixmask);
        painter.drawPixmap(destRect, maskedSource, cmd.copy.srcRect);
    } else if (cmd.mode == OplScreen::set) {
        QPixmap maskedSource(src.mPixmap);
        maskedSource.setMask(src.getMask());
        if (tiled) {
            painter.drawTiledPixmap(destRect, maskedSource);
        } else {
            painter.drawPixmap(destRect, maskedSource, cmd.copy.srcRect);
        }
    } else if (cmd.mode == OplScreen::clear) {
        QPen pen(cmd.bgcolor);
        painter.setPen(pen);
        if (tiled) {
            painter.drawTiledPixmap(destRect, src.getMask());
        } else {
            painter.drawPixmap(destRect, src.getMask(), cmd.copy.srcRect);
        }
    } else if (cmd.mode == OplScreen::invert) {
        // Setting composition mode RasterOp_NotSourceXorDestination _nearly_ gets us what we need here, except for the
        // fact that it ignores the source alpha mask (meaning lots of unintended black areas). So instead, we first
        // take a copy of the dest area, xor into that, then copy that to dest applying the original source mask.
        // QRect destRect(cmd.origin, cmd.copy.srcRect.size());
        QPixmap tempDest(destRect.size());
        {
            PAINTER_BEGIN(tempPainter, &tempDest);
            tempPainter.drawPixmap(QPoint(), mPixmap, destRect);
            tempPainter.setCompositionMode(QPainter::RasterOp_NotSourceXorDestination);
            if (tiled) {
                tempPainter.drawTiledPixmap(tempDest.rect(), src.mPixmap);
            } else {
                tempPainter.drawPixmap(QPoint(), src.mPixmap, cmd.copy.srcRect);
            }
        }

        if (tiled) {
            // have to make a new tiled mask rather than being able to use the original source mask directly
            QBitmap tileMask(destRect.size());
            {
                PAINTER_BEGIN(tempPainter, &tileMask);
                tempPainter.drawTiledPixmap(tempDest.rect(), src.getMask());
            }
            tempDest.setMask(tileMask);
            painter.drawPixmap(cmd.origin, tempDest);
        } else {
            tempDest.setMask(OplRuntimeGui::pixToBitmap(src.getMask().copy(cmd.copy.srcRect)));
            painter.drawPixmap(cmd.origin, tempDest);
        }
    } else { // replace
        if (tiled) {
            painter.drawTiledPixmap(destRect, src.mPixmap);
        } else {
            painter.drawPixmap(destRect, src.mPixmap, cmd.copy.srcRect);
        }
    }
}

void Drawable::loadFromBitmap(bool color, int width, int height, const QByteArray& data)
{
    invalidateMask();
    // qDebug("loadFromBitmap color=%d width=%d height=%d datalen=%d", color, width, height, data.size());
    mPixmap = OplRuntimeGui::imageFromBitmap(color, width, height, data);
}

Window::Window(OplScreenWidget* screen, int drawableId, const QRect& rect, OplScreen::BitmapMode mode, int shadowSize)
    : QLabel(screen)
    , Drawable(drawableId, rect.size(), mode)
    , mClock(nullptr)
    , mScale(1)
    , mShadowSize(shadowSize)
    , mGreyPlane(nullptr)
    , mHighlight(nullptr)
{
    mUnscaledRect = rect;
    setGeometry(rect);
    if (mode == OplScreen::monochromeWithGreyPlane) {
        mGreyPlane.reset(new Drawable(getId(), Drawable::size(), OplScreen::gray2));
    }
    update();
}

void Window::draw(const OplScreen::DrawCmd& cmd)
{
    invalidateMask();
    if (cmd.greyMode && mGreyPlane) {
        // For simplicity of compositing, make sure any non-white colours are set to the grey level we want
        auto greyPlaneCmd = cmd;
        if (greyPlaneCmd.color != 0xFFFFFFFF) {
            greyPlaneCmd.color = 0xFFAAAAAA;
        }
        if (greyPlaneCmd.bgcolor != 0xFFFFFFFF) {
            greyPlaneCmd.bgcolor = 0xFFAAAAAA;
        }
        greyPlane().draw(greyPlaneCmd);
    }

    if (cmd.greyMode != OplScreen::drawGreyOnly) {
        Drawable::draw(cmd);
    }
}

void Window::drawSetPixels(const OplScreen::CopyMultipleCmd& cmd, Drawable& src, const QRect& srcRect, const QRect& destRect)
{
    if (cmd.greyMode) {
        auto greyPlaneCmd = cmd;
        if (greyPlaneCmd.color != 0xFFFFFFFF) {
            greyPlaneCmd.color = 0xFFAAAAAA;
        }
        greyPlane().drawSetPixels(greyPlaneCmd, src, srcRect, destRect);
    }

    if (cmd.greyMode != OplScreen::drawGreyOnly) {
        Drawable::drawSetPixels(cmd, src, srcRect, destRect);
    }
}

void Window::drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src, Drawable* mask)
{
    if (cmd.greyMode) {
        auto greyPlaneCmd = cmd;
        // mode=clear uses the background colour
        if (greyPlaneCmd.bgcolor != 0xFFFFFFFF) {
            greyPlaneCmd.bgcolor = 0xFFAAAAAA;
        }
        auto greySrc = src.getGreyPlane();
        if (greySrc) {
            // Copy grey to grey
            greyPlane().drawCopy(greyPlaneCmd, *greySrc, mask);
        } else {
            // Copy black to grey
            greyPlane().drawCopy(greyPlaneCmd, src, mask);
        }
    }

    if (cmd.greyMode != OplScreen::drawGreyOnly) {
        // Black to black (if either have a grey plane)
        Drawable::drawCopy(cmd, src, mask);
    }
}

void Window::update()
{
    QPixmap unscaledPixmap;
    if (mGreyPlane) {
        unscaledPixmap = QPixmap(mPixmap.size());
        PAINTER_BEGIN(painter, &unscaledPixmap);
        painter.drawPixmap(QPoint(), mGreyPlane->getPixmap());
        // Now draw the black plane on top with a mask, so its white pixels don't overwrite the grey plane
        QPixmap maskedPixmap(mPixmap);
        maskedPixmap.setMask(getMask());
        painter.drawPixmap(QPoint(), maskedPixmap);
    } else {
        unscaledPixmap = mPixmap;
    }

    if (mScale == 1) {
        setPixmap(unscaledPixmap);
    } else {
        auto scaled = unscaledPixmap.scaled(scaledRect().size());
        setPixmap(scaled);
    }
}

Drawable& Window::greyPlane()
{
    Q_ASSERT(getMode() == OplScreen::monochromeWithGreyPlane);
    return *mGreyPlane;
}

Drawable* Window::getGreyPlane() const
{
    return mGreyPlane.get();
}

void Window::updateSprites(QPainter& painter)
{
    auto screen = static_cast<OplScreenWidget*>(parent());
    for (const auto& sprite : mSprites) {
        if (sprite.currentFrame >= sprite.frames.count()) {
            // There can be a lack of a current frame if the sprite has not yet got any frames with valid bitmaps set
            continue;
        }
        auto& frame = sprite.frames[sprite.currentFrame];
        QPoint pos(this->pos() + sprite.origin + frame.offset);
        Drawable* src = screen->getBitmap(frame.bitmap);
        if (!src) continue;
        if (frame.mask) {
            Drawable* mask = screen->getBitmap(frame.mask);
            if (!mask) continue;
            QPixmap maskedSource(src->getPixmap());
            QBitmap m = mask->getMask();
            if (!frame.invertMask) {
                // Sprite masks are backwards by default, so we have to flip the colours if invertMask is _not_ set
                PAINTER_BEGIN(inverter, &m);
                inverter.setCompositionMode(QPainter::RasterOp_SourceAndNotDestination);
                inverter.fillRect(m.rect(), Qt::color0);
            }
            maskedSource.setMask(m);
            painter.drawPixmap(pos, maskedSource);
        } else {
            painter.drawPixmap(pos, src->getPixmap());
        }
    }
}

void Window::mousePressEvent(QMouseEvent *event)
{
    event->accept();
    static_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::mouseMoveEvent(QMouseEvent *event)
{
    event->accept();
    static_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::mouseReleaseEvent(QMouseEvent *event)
{
    event->accept();
    static_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::mouseDoubleClickEvent(QMouseEvent *event)
{
    event->accept();
    static_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

QPoint Window::getPos() const
{
    return mUnscaledRect.topLeft();
}

void Window::setPos(const QPoint& pos)
{
    mUnscaledRect.moveTo(pos);
    auto scaledPos = scaledRect().topLeft();
    move(scaledPos); // in QWidget
}

void Window::setSize(const QSize& size)
{
    mUnscaledRect.setSize(size);
    Drawable::setSize(size); // Update image
    auto scaledSize = scaledRect().size();
    resize(scaledSize); // update widget
    if (mGreyPlane) {
        mGreyPlane->setSize(size);
    }
    if (mHighlight) {
        mHighlight->resize(scaledSize);
    }
}

void Window::setScale(int scale)
{
    if (scale != mScale) {
        mScale = scale;
        setPos(mUnscaledRect.topLeft());
        // Don't call setSize as that will invalidate the Drawable contents
        auto scaled = scaledRect().size();
        resize(scaled);
        if (mClock) {
            mClock->setScale(mScale);
        }

        update();
    }
}

QRect Window::scaledRect() const
{
    return QRect(mUnscaledRect.x() * mScale, mUnscaledRect.y() * mScale,
        mUnscaledRect.width() * mScale, mUnscaledRect.height() * mScale);
}

void Window::setSprite(int spriteId, const OplScreen::Sprite* sprite)
{
    if (!sprite) {
        mSprites.remove(spriteId);
        return;
    }
    WindowSprite s{};
    s.origin = sprite->origin;
    s.frames = sprite->frames;
    if (sprite->frames.count()) {
        s.remainingFrameTime = sprite->frames[0].time;
    }
    mSprites[spriteId] = s;
    update();
}

void Window::animateSprites(int64_t interval_us)
{
    if (mSprites.isEmpty()) {
        return;
    }
    for (auto& sprite : mSprites) {
        sprite.remainingFrameTime = sprite.remainingFrameTime - interval_us;
        if (sprite.remainingFrameTime <= 0) {
            sprite.currentFrame = (sprite.currentFrame + 1) % sprite.frames.count();
            sprite.remainingFrameTime = sprite.frames[sprite.currentFrame].time;
        }
    }
}

void Window::setHighlighted(bool flag)
{
    if (!mHighlight && flag) {
        QColor col(255, 0, 0, 128); // 50% transparent red
        mHighlight = new WindowShadow(this, col);
        auto rect = scaledRect();
        mHighlight->setGeometry(0, 0, rect.width(), rect.height());
    }

    if (mHighlight) {
        mHighlight->setVisible(flag);
    }
}

//

SpriteWidget::SpriteWidget(OplScreenWidget* screen)
    : QLabel(screen)
{
    setAttribute(Qt::WA_TransparentForMouseEvents);
    resize(screen->size()); // This will configure mPixmap via resizeEvent
    show();
}

void SpriteWidget::renderSprites(const QList<Window*>& windows, int scale)
{
    // The sprite widget follows the Qt size of OplScreenWidget (ie scaled)
    mPixmap.fill(Qt::transparent);
    PAINTER_BEGIN(painter, &mPixmap);
    painter.scale(scale, scale);
    for (Window* w : windows) {
        w->updateSprites(painter);
    }
    painter.end();
    setPixmap(mPixmap);
}

void SpriteWidget::resizeEvent(QResizeEvent *event)
{
    QLabel::resizeEvent(event);
    mPixmap = QPixmap(size());
    mPixmap.fill(Qt::transparent);
    setPixmap(mPixmap);
}

//

WindowShadow::WindowShadow(QWidget* parent, QColor color)
    : QWidget(parent)
    , mColor(color)
{
    if (!mColor.isValid()) {
        mColor = QColor(128, 128, 128, 128); // 50% transparent grey
    }
}

void WindowShadow::paintEvent(QPaintEvent* event)
{
    QPainter painter(this);
    QBrush brush(mColor);
    painter.fillRect(event->rect(), brush);
}

//

ShadowOverlay::ShadowOverlay(QWidget* parent)
    : QWidget(parent)
{
    setAttribute(Qt::WA_TransparentForMouseEvents);
    setGeometry(0, 0, parent->width(), parent->height());
    show();
}

void ShadowOverlay::paintEvent(QPaintEvent* event)
{
    // This is the union of everywhere on screen that a shadow should be drawn to.
    QRegion shadow;

    // This is parts of the screen drawn to by a window above i in the window list (which is updated as we traverse the
    // list). Occluded areas should not get shadows from windows later down in the order.
    QRegion occludedi;

    auto screen = qobject_cast<OplScreenWidget*>(parent());
    const int scale = screen->getScale();

    QList<Window*> windows = screen->findChildren<Window*>();
    // windows is ordered back-to-front
    std::reverse(windows.begin(), windows.end());
    // windows is now ordered front-to-back
    const int n = windows.count();
    // For each window, iterate the windows below it and work out where shadows should fall on each window
    // Note, windows without shadow do not cause shadow depth to increase.
    for (int i = 0; i < n; i++) {
        Window& window = *windows[i];
        const auto shadowSize = window.getShadowSize();
        QRegion windowRegion(window.geometry());
        occludedi += windowRegion;
        if (shadowSize == 0 || !window.isVisible()) {
            continue;
        }
        QRegion occludedj(occludedi);
        int shadowDepth = 1;

        // We use <= n and pretend there is a fullscreen window at j==n
        for (int j = i + 1; j <= n; j++) {
            QRect jrect;
            if (j == n) {
                jrect = screen->rect();
            } else {
                if (!windows[j]->isVisible()) {
                    continue;
                }
                jrect = windows[j]->geometry();
            }
            int shadowOffset = shadowSize * scale * shadowDepth;
            QRegion winShadowRegion(
                window.x() + shadowOffset,
                window.y() + shadowOffset,
                window.width(),
                window.height()
            );
            auto region = winShadowRegion.subtracted(occludedj).intersected(jrect);
            shadow |= region;
            occludedj += jrect;
            if (j < n && windows[j]->getShadowSize()) {
                shadowDepth++;
            }
        }
    }

    QPainter painter(this);
    QBrush brush(QColor(128, 128, 128, 128)); // 50% transparent grey
    painter.setClipRegion(shadow);
    painter.fillRect(event->rect(), brush);
}

