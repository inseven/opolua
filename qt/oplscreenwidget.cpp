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
#include "oplruntimegui.h"
#include "clockwidget.h"
#include "asynchandle.h"

#include <QAudioFormat>
#include <QBuffer>
#include <QDateTime>
#include <QPainter>
#include <QSet>

OplScreenWidget::OplScreenWidget(QWidget *parent)
    : QWidget(parent)
    , mScale(1)
    , mSpriteWidget(nullptr)
    , mAudioAsync(nullptr)
    , mAudio(nullptr)
{
    mRuntime = new OplRuntimeGui(this);
    mRuntime->setScreen(this);
    connect(mRuntime, &OplRuntime::runComplete, this, &OplScreenWidget::onStopped);
    connect(mRuntime, &OplRuntime::deviceTypeChanged, this, &OplScreenWidget::onDeviceTypeChanged);

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
        if (win->shadow()) {
            delete win->shadow();
        }
        delete win;
        mWindows.remove(drawableId);
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
 subviews[n-1] the front.
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
    // qDebug("order %d pos %d -> %d count=%d", order, currentPos, newPos, children.count());

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
    if (win->shadow()) {
        win->shadow()->stackUnder(win);
    }
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
    if (win->shadow()) {
        win->shadow()->setVisible(flag);
    }
    return KErrNone;
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
            win->mClock = new ClockWidget(win, getRuntime(), info->color);
            win->mClock->setScale(mScale);
            connect(getRuntime(), &OplRuntime::systemClockChanged, win->mClock, &ClockWidget::systemClockChanged);
            // God DAMN that cast is nasty. Needed because QWidget has overloads of update making the slot kinda
            // broken.
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

void OplScreenWidget::playSound(AsyncHandle* handle, const QByteArray& data)
{
    Q_ASSERT(mAudioAsync == nullptr);
    mAudioAsync = handle;
    connect(mAudioAsync, &QObject::destroyed, this, &OplScreenWidget::audioHandleDeleted);
    mAudioData = data;
    // qDebug("playSound len=%d", (int)data.size());
    Q_ASSERT((data.size() & 1) == 0); // must be 16-bit

    // We keep mAudio around after completing playing a sound so we can reuse it quickly, because there can be some
    // tangible delay involved in setting up a new audio playback object, so reusing it makes sense given we always
    // use the same audio format.
    if (!mAudio) {
        QAudioFormat format;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        format.setChannelConfig(QAudioFormat::ChannelConfigMono);
        format.setSampleRate(48000); // See comment below
        format.setSampleFormat(QAudioFormat::Int16);
        mAudio = new QAudioSink(format, this);
        connect(mAudio, &QAudioSink::stateChanged, this, &OplScreenWidget::audioStateChanged);
#else
        format.setChannelCount(1);
        format.setSampleRate(8000);
        format.setSampleSize(16);
        format.setCodec("audio/pcm");
        format.setByteOrder(QAudioFormat::LittleEndian);
        format.setSampleType(QAudioFormat::SignedInt);
        mAudio = new QAudioOutput(format, this);
        connect(mAudio, &QAudioOutput::stateChanged, this, &OplScreenWidget::audioStateChanged);
#endif
    }
    // mAudio->setVolume(0.5); // Full volume is too much

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Qt 6 (on mac at least?) seems to only support sample rates from 44.1kHz up, which is absolutely bonkers. So
    // we will say 48kHz and manually stretch our sample data out by a factor of 6 (since our input data is always
    // 8kHz). When doing that, we have to also do some interpolation to the next sample so that it doesn't sound
    // square-wave-y. This is not perfect (not sure what the optimal thing to do is) but it sounds a lot better
    // than not doing any interpolation at all.
    QByteArray newData(mAudioData.size() * 6, Qt::Uninitialized);
    auto iptr = reinterpret_cast<const int16_t*>(mAudioData.cbegin());
    auto eptr = reinterpret_cast<const int16_t*>(mAudioData.cend());
    auto optr = reinterpret_cast<int16_t*>(newData.data());
    while (iptr != eptr) {
        auto val = *iptr++;
        int16_t delta = 0;
        if (iptr != eptr) {
            delta = (*iptr - val) / 5;
        }
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val; val += delta;
        *optr++ = val;
    }
    newData.swap(mAudioData);
#endif

    QBuffer* buf = new QBuffer(&mAudioData, handle);
    buf->open(QIODevice::ReadOnly);
    mAudio->start(buf);
    // qDebug("audio started state=%d err=%d", mAudio->state(), mAudio->error());
    if (mAudio->error() != QAudio::NoError) {
        qDebug("audio failed to start err=%d", mAudio->error());
        if (mAudioAsync) {
            mRuntime->asyncFinished(mAudioAsync, KErrGenFail);
        }
    }
}

void OplScreenWidget::audioStateChanged(QAudio::State state)
{
    if (!mAudio) {
        return;
    }

    // qDebug("audioStateChanged %d", (int)state);

    // Calling asyncFinished will delete mAudioAsync which will call audioHandleDeleted via the QObject::destroyed signal
    switch (state) {
    case QAudio::ActiveState:
        break;
    case QAudio::IdleState:
        // Finished playing (no more data). Note, on Qt 5 calling stop triggers an immediate callback to
        // audioStateChanged which can be problematic, eg causing deadlocks.
        mAudio->stop();
        break;
    case QAudio::StoppedState: {
        int err = KErrNone;
        if (mAudio->error() != QAudio::NoError) {
            qDebug("Audio error %d", (int)mAudio->error());
            err = KErrGenFail;
        }

        if (mAudioAsync) {
            mRuntime->asyncFinished(mAudioAsync, err);
        }
        break;
    }
    default:
        qDebug("Unhandled audioStateChanged %d", (int)state);
        break;
    }
}

void OplScreenWidget::audioHandleDeleted()
{
    mAudioAsync = nullptr; // Will prevent audioStateChanged trying to make another asyncFinished call as a result of the stop
    if (mAudio->state() == QAudio::ActiveState) {
        mAudio->stop();
    }
    mAudioData.clear();
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
    auto bits = img.constScanLine(position.y()) + position.x();
    auto endPtr = bits + numPixels;
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
    while (bits < endPtr) {
        addPixel(*bits++);
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
    QPainter painter(&mPixmap);
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
        auto borderPath = QString(":/borders/%1.png").arg(id);
        QPixmap px(borderPath, "PNG");
        if (px.isNull()) {
            qDebug("Failed to load border %s w=%d", qPrintable(borderPath), px.width());
        }
        const QRect& r = cmd.border.rect;
        // gXBORDER(1, 3) needs nine pixels, most other borders only 5 or 6
        int d = qMin(9, qMin(r.width(), r.height()) / 2);
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
            QPainter tempPainter(&temp);
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
    QPainter painter(&mPixmap);
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
    QPainter painter(&mPixmap);
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
                QPainter maskPainter(&newMask);
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
            QPainter tempPainter(&tempDest);
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
                QPainter tempPainter(&tileMask);
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
    , mShadow(nullptr)
    , mShadowSize(shadowSize)
    , mGreyPlane(nullptr)
{
    mUnscaledRect = rect;
    setGeometry(rect);
    if (mode == OplScreen::monochromeWithGreyPlane) {
        mGreyPlane.reset(new Drawable(getId(), Drawable::size(), OplScreen::gray2));
    }
    if (mShadowSize) {
        mShadow = new WindowShadow(screen);
        mShadow->setGeometry(x() + mShadowSize, y() + mShadowSize, width(), height());
        mShadow->stackUnder(this);
    }
    update();
}

void Window::draw(const OplScreen::DrawCmd& cmd)
{
    invalidateMask();
    if (cmd.greyMode) {
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
        QPainter painter(&unscaledPixmap);
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
                QPainter inverter(&m);
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

QPoint Window::getPos() const
{
    return mUnscaledRect.topLeft();
}

void Window::setPos(const QPoint& pos)
{
    mUnscaledRect.moveTo(pos);
    auto scaledPos = scaledRect().topLeft();
    move(scaledPos); // in QWidget
    if (mShadow) {
        mShadow->move(scaledPos.x() + mShadowSize * mScale, scaledPos.y() + mShadowSize * mScale);
    }
}

void Window::setSize(const QSize& size)
{
    mUnscaledRect.setSize(size);
    Drawable::setSize(size); // Update image
    auto scaledSize = scaledRect().size();
    resize(scaledSize); // update widget
    if (mShadow) {
        mShadow->resize(scaledSize);
    }
    if (mGreyPlane) {
        mGreyPlane->setSize(size);
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
        if (mShadow) {
            mShadow->resize(scaled);
        }
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
    QPainter painter;
    painter.begin(&mPixmap);
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

WindowShadow::WindowShadow(QWidget* parent)
    : QWidget(parent)
{
}

void WindowShadow::paintEvent(QPaintEvent* event)
{
    QPainter painter(this);
    QBrush brush(QColor(128, 128, 128, 128)); // 50% transparent grey
    painter.fillRect(event->rect(), brush);
}
