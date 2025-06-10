// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
    , mAudioAsync(nullptr)
    , mAudio(nullptr)
{
    mRuntime = new OplRuntimeGui(this);
    mRuntime->setScreen(this);
    connect(mRuntime, &OplRuntime::runComplete, this, &OplScreenWidget::onStopped);

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
}

void OplScreenWidget::onStopped()
{
    mSpriteTimer.reset();
}

OplRuntimeGui* OplScreenWidget::getRuntime() const
{
    return mRuntime;
}

QSize OplScreenWidget::sizeHint() const
{
    if (mRuntime) {
        return mRuntime->screenSize();
    } else {
        return QSize();
    }
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

void OplScreenWidget::closeDrawable(int drawableId)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (win) {
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

int OplScreenWidget::createWindow(int drawableId, const QRect& rect, BitmapMode mode, int /*shadow*/)
{
    // qDebug("createWindow id=%d (%d,%d) %dx%d mode=%d", drawableId, rect.x(), rect.y(), rect.width(), rect.height(), mode);
    auto win = new Window(this, drawableId, rect, mode);
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
    } else {
        if (newPos > currentPos) {
            // Have to allow for the fact the window is already below the widget we want to stack under
            newPos++;
        }
        win->stackUnder(static_cast<QWidget*>(children[newPos]));
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
    return KErrNone;
}

int OplScreenWidget::setWindowRect(int drawableId, const QPoint& position, const QSize* size)
{
    // qDebug("setwin id=%d (%d,%d) %dx%d", drawableId, position.x(), position.y(), size ? size->width() : 0, size ? size->height() : 0);

    auto win = mWindows.value(drawableId, nullptr);
    if (!win) {
        return KErrDrawNotOpen;
    }
    win->move(position);
    if (size) {
        win->setSize(*size);
    }
    return KErrNone;
}

void OplScreenWidget::drawCommands(const QVector<DrawCmd>& commands)
{
    QSet<Drawable*> seen;
    for (const auto& cmd : commands) {
        auto drawable = mDrawables.value(cmd.drawableId);
        if (drawable) {
            seen.insert(drawable);

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

    for (auto drawable : seen) {
        drawable->update();
    }
}

void OplScreenWidget::bitBlt(int drawableId, OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data)
{
    auto drawable = mDrawables.value(drawableId, nullptr);
    if (!drawable) {
        qWarning("No drawable %d for bitblt", drawableId);
        return;
    }
    drawable->loadFromBitmap(mode, width, height, stride, data);
    drawable->update();
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

void OplScreenWidget::copyMultiple(int srcId, int destId, uint32_t color, bool invert, const QVector<QRect>& rects, const QVector<QPoint>& points)
{
    auto src = mDrawables.value(srcId, nullptr);
    auto dest = mDrawables.value(destId, nullptr);
     if (!src || !dest) {
        qWarning("Bad src/dest in copyMultiple");
        return;
    }

    dest->invalidateMask();

    for (int i = 0; i < rects.count(); i++) {
        QRect srcRect = rects[i];
        QRect destRect = QRect(points[i], srcRect.size());
        if (adjustBounds(srcRect, destRect, src->size(), dest->size())) {
            dest->drawSetPixels(*src, srcRect, destRect, invert, color);
        }
    }
    dest->update();
}

void OplScreenWidget::mouseEvent(QMouseEvent* event, Window* window)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QPoint pos = event->position().toPoint();
#else
    QPoint pos = event->pos();
#endif
    mRuntime->mouseEvent(*event, window->getId(), QPoint(window->x() + pos.x(), window->y() + pos.y()));
}

void OplScreenWidget::clock(int drawableId, const OplScreen::ClockInfo* info)
{
    auto win = mWindows.value(drawableId, nullptr);
    if (win) {
        if (info && !win->mClock) {
            win->mClock = new ClockWidget(win, getRuntime(), false);
            connect(getRuntime(), &OplRuntime::systemClockChanged, win->mClock, &ClockWidget::systemClockChanged);
        } else if (win->mClock && !info) {
            win->mClock->hide();
        }

        if (info) {
            win->mClock->update(*info);
        }
    }
}

void OplScreenWidget::playSound(AsyncHandle* handle, const QByteArray& data)
{
    mAudioAsync = handle;
    connect(mAudioAsync, &QObject::destroyed, this, &OplScreenWidget::audioHandleDeleted);
    mAudioData = data;
    QAudioFormat format;
    format.setSampleRate(8000);
    format.setChannelCount(1);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    format.setSampleFormat(QAudioFormat::UInt8);
    mAudio = new QAudioSink(format, handle);
    connect(mAudio, &QAudioSink::stateChanged, this, &OplScreenWidget::audioStateChanged);
    // TODO: This doesn't actually work yet
#else
    format.setSampleSize(8);
    format.setCodec("audio/pcm");
    format.setByteOrder(QAudioFormat::LittleEndian);
    format.setSampleType(QAudioFormat::UnSignedInt);
    mAudio = new QAudioOutput(format, handle);
    mAudio->setVolume(0.1); // Full volume is too much
    connect(mAudio, &QAudioOutput::stateChanged, this, &OplScreenWidget::audioStateChanged);
#endif

    QBuffer* buf = new QBuffer(&mAudioData, mAudio);
    buf->open(QIODevice::ReadOnly);
    mAudio->start(buf);
    // qDebug("audio started state=%d err=%d", mAudio->state(), mAudio->error());
    if (mAudio->error() != QAudio::NoError) {
        mRuntime->asyncFinished(mAudioAsync, KErrGenFail);
    }
}

void OplScreenWidget::audioStateChanged(QAudio::State state)
{
    if (!mAudio) {
        return;
    }

    // qDebug("audioStateChanged %d", (int)state);

    // Calling asyncFinished will delete mAudioAsync which will delete mAudio via the QObject parenting
    // (and which will call audioHandleDeleted via the QObject::destroyed signal)
    switch (state) {
    case QAudio::ActiveState:
        break;
    case QAudio::IdleState:
        // Finished playing (no more data).
        // deleting mAudio directly from within audioStateChanged (as would happen here by default due to mAudio's
        // parent being mAudioAsync and asyncFinished deleting that) sometimes causes a deadlock, at least using Qt 5
        // multimedia on mac. Unparenting it and calling deleteLater instead seems to avoid it. As does leaving in the
        // qDebug statement above because of course it does.
        mAudio->setParent(nullptr);
        mAudio->deleteLater();
        mRuntime->asyncFinished(mAudioAsync, KErrNone);
        break;

    case QAudio::StoppedState:
        if (mAudio->error() != QAudio::NoError) {
            qDebug("Audio error %d", (int)mAudio->error());
            mRuntime->asyncFinished(mAudioAsync, KErrGenFail);
        }
        break;
    default:
        qDebug("Unhandled audioStateChanged %d", (int)state);
        break;
    }
}

void OplScreenWidget::audioHandleDeleted()
{
    mAudio = nullptr;
    mAudioData.clear();
    mAudioAsync = nullptr;
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
}

////

Drawable::Drawable(int drawableId, const QSize& size, OplScreen::BitmapMode mode)
    : id(drawableId)
    , mPixmap(size)
    , mode(mode)
{
    mPixmap.fill(0xFFFFFFFF);
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
        // QImage imgToScroll = image.copy(origRect);
        QPixmap pixToScroll = mPixmap.copy(origRect);
        QRect newRect(origRect.x() + cmd.scroll.dx, origRect.y() + cmd.scroll.dy, origRect.width(), origRect.height());
        // This is not entirely the right logic if both dx and dy are non-zero, but probably good enough for now
        int minX = qMin(origRect.x(), newRect.x());
        int minY = qMin(origRect.y(), newRect.y());
        int max_X = qMax(maxX(origRect), maxX(newRect));
        int max_Y = qMax(maxY(origRect), maxY(newRect));
        QRect clearRect = QRect(minX, minY, max_X - minX, max_Y - minY).normalized();
        painter.fillRect(clearRect, QBrush(cmd.bgcolor));
        // painter.drawImage(newRect, imgToScroll);
        painter.drawPixmap(newRect, pixToScroll);
        break;
    }
    case OplScreen::border: {
        auto id = QString("%1").arg(cmd.border.borderType, 5, 16, QLatin1Char('0')).toUpper();
        QPixmap px(QString(":/borders/%1.png").arg(id), "PNG");
        // qDebug("px %s w=%d", qPrintable(QString(":/borders/%1.png").arg(id)), px.width());
        const QRect& r = cmd.border.rect;
        const int d = 5;
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
    newPixmap.fill(0xFFFFFFFF);
    mPixmap.swap(newPixmap);
}

QPixmap& Drawable::getPixmap()
{
    return mPixmap;
}

QBitmap& Drawable::getMask()
{
    if (mMask.isNull()) {
        mMask = mPixmap.createMaskFromColor(0xFFFFFFFF, Qt::MaskInColor);
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

void Drawable::drawSetPixels(Drawable& src, const QRect& srcRect, const QRect& destRect, bool invert, QRgb color)
{
    QPainter painter(&mPixmap);
    painter.setPen(color);
    if (invert) {
        // See comment in drawCopy below
        QPixmap tempBuf = mPixmap.copy(destRect);
        QPainter tempPainter(&tempBuf);
        tempPainter.setCompositionMode(QPainter::RasterOp_NotSourceXorDestination);
        tempPainter.drawPixmap(QPoint(), src.mPixmap, srcRect);
        tempPainter.end();
        tempBuf.setMask(src.getMask().copy(srcRect));
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
        QPixmap tempDest = mPixmap.copy(destRect);
        {
            QPainter tempPainter(&tempDest);
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
            tempDest.setMask(src.getMask().copy(cmd.copy.srcRect));
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

void Drawable::loadFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data)
{
    invalidateMask();
    // qDebug("loadFromBitmap mode=%d width=%d height=%d stride=%d datalen=%d", mode, width, height, stride, data.size());
    mPixmap = OplRuntimeGui::imageFromBitmap(mode, width, height, stride, data);
}

Window::Window(OplScreenWidget* screen, int drawableId, const QRect& rect, OplScreen::BitmapMode mode)
    : QLabel(screen)
    , Drawable(drawableId, rect.size(), mode)
    , mClock(nullptr)
{
    setGeometry(rect);
    update();
}

void Window::update() {
    if (mSprites.isEmpty()) {
        setPixmap(mPixmap);
        return;
    }

    QPixmap buf(mPixmap);
    QPainter painter(&buf);
    auto screen = static_cast<OplScreenWidget*>(parent());

    for (const auto& sprite : mSprites) {
        if (sprite.currentFrame >= sprite.frames.count()) {
            // There can be a lack of a current frame if the sprite has not yet got any frames with valid bitmaps set
            continue;
        }
        auto& frame = sprite.frames[sprite.currentFrame];
        QPoint pos(sprite.origin + frame.offset);
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

    setPixmap(buf);
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

void Window::setSize(const QSize& size)
{
    Drawable::setSize(size); // Update image
    resize(size); // update widget
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
    bool anythingChanged = false;
    for (auto& sprite : mSprites) {
        sprite.remainingFrameTime = sprite.remainingFrameTime - interval_us;
        if (sprite.remainingFrameTime <= 0) {
            anythingChanged = true;
            sprite.currentFrame = (sprite.currentFrame + 1) % sprite.frames.count();
            sprite.remainingFrameTime = sprite.frames[sprite.currentFrame].time;
        }
    }
    if (anythingChanged) {
        update();
    }
}
