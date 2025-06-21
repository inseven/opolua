// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplscreenwidget.h"
#include "oplruntime.h"
#include "clockwidget.h"
#include "asynchandle.h"
#include "palettes.h"

#include <QAudioFormat>
#include <QBuffer>
#include <QPainter>
#include <QSet>

OplScreenWidget::OplScreenWidget(QWidget *parent)
    : QWidget(parent)
    , mAudioAsync(nullptr)
    , mAudio(nullptr)
{
    mRuntime = new OplRuntime(this);
    mRuntime->setScreen(this);

    setFocusPolicy(Qt::StrongFocus);
}

OplScreenWidget::~OplScreenWidget()
{
    auto keys = mDrawables.keys();
    for (int drawableId : keys) {
        closeDrawable(drawableId);
    }
}

OplRuntime* OplScreenWidget::getRuntime() const
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
    // QImage img;
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
int OplScreenWidget::setOrder(int /*drawableId*/, int /*order*/)
{
    return -1;
}

int OplScreenWidget::getRank(int /*drawableId*/)
{
    return -1;
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
        auto drawable = mDrawables.value(cmd.drawableId, nullptr);
        if (drawable) {
            seen.insert(drawable);

            if (cmd.type == OplScreen::copy) {
                auto src = mDrawables.value(cmd.copy.srcDrawableId, nullptr);
                if (src) {
                    drawable->drawCopy(cmd, *src);
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

void OplScreenWidget::copyMultiple(int srcId, int destId, QRgb color, bool invert, const QVector<QRect>& rects, const QVector<QPoint>& points)
{
    auto src = mDrawables.value(srcId, nullptr);
    auto dest = mDrawables.value(destId, nullptr);
     if (!src || !dest) {
        qWarning("Bad src/dest in copyMultiple");
        return;
    }

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
        win->clock(info);
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
    QPainter painter(&mPixmap);
    QPen pen(cmd.mode == OplScreen::clear ? cmd.bgcolor : cmd.color);
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
    mPixmap.swap(newPixmap);
}

void Drawable::drawSetPixels(Drawable& src, const QRect& srcRect, const QRect& destRect, bool /*invert*/, QRgb color)
{
    if (src.mask.isNull()) {
        src.mask = src.mPixmap.createMaskFromColor(0xFFFFFFFF, Qt::MaskInColor);
    }
    QPainter painter(&mPixmap);
    painter.setPen(color);
    painter.drawPixmap(destRect, src.mask, srcRect);
}

void Drawable::drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src)
{
    QPainter painter(&mPixmap);
    painter.drawPixmap(QRect(cmd.origin, cmd.copy.srcRect.size()), src.mPixmap, cmd.copy.srcRect);
}

static uint8_t scale2bpp(uint8_t val)
{
    return val | (val << 2) | (val << 4) | (val << 6);
}

void Drawable::loadFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data)
{
    // qDebug("loadFromBitmap mode=%d width=%d height=%d stride=%d datalen=%d", mode, width, height, stride, data.size());
    QImage img;
    if (mode <= OplScreen::gray256) {
        img = QImage(width, height, QImage::Format_Grayscale8);
        img.fill(0xFF888888);
        switch (mode) {
        case OplScreen::gray2: // 1 bpp
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 8 && x < width; i++, x++) {
                        dest[x] = (((*src) >> i) & 1) ? 0xFF : 0;
                    }
                    src++;
                }
            }
            break;
        case OplScreen::gray4: // 2 bpp
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 4 && x < width; i++, x++) {
                        dest[x] = scale2bpp((*src & (0x3 << (i*2))) >> (i * 2));
                    }
                    src++;
                }
            }
            break;
        // case OplScreen::gray16: break;
        case OplScreen::gray256:
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                memcpy(dest, src, width);
            }
            break;
        default:
            qDebug("TODO loadFromBitmap mode=%d", mode);
        }
    } else {
        switch (mode) {
        case OplScreen::color256:
            img = QImage(width, height, QImage::Format_Indexed8);
            img.setColorTable(QVector<QRgb>(std::begin(kEpoc8bitPalette), std::end(kEpoc8bitPalette)));
            if (img.bytesPerLine() == stride) {
                memcpy(img.bits(), data.data(), stride * height);
            } else {
                for (int y = 0; y < height; y++) {
                    auto src = (const uchar*)data.data() + stride * y;
                    auto dest = img.scanLine(y);
                    memcpy(dest, src, width);
                }
            }
            break;
        case OplScreen::color16:
            img = QImage(width, height, QImage::Format_Indexed8);
            img.setColorTable(QVector<QRgb>(std::begin(kEpoc4bitPalette), std::end(kEpoc4bitPalette)));
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 2 && x < width; i++, x++) {
                        dest[x] = (*src & (0xF << (i*4))) >> (i * 4);
                    }
                    src++;
                }
            }
            break;
        default:
            qDebug("TODO loadFromBitmap mode=%d", mode);
        }
    }
    if (!img.isNull()) {
        // image = img.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        mPixmap = QPixmap::fromImage(img);
    }
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
    setPixmap(mPixmap);
}

void Window::mousePressEvent(QMouseEvent *event)
{
    event->accept();
    reinterpret_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::mouseMoveEvent(QMouseEvent *event)
{
    event->accept();
    reinterpret_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::mouseReleaseEvent(QMouseEvent *event)
{
    event->accept();
    reinterpret_cast<OplScreenWidget*>(parent())->mouseEvent(event, this);
}

void Window::setSize(const QSize& size)
{
    Drawable::setSize(size); // Update image
    resize(size); // update widget
}

void Window::clock(const OplScreen::ClockInfo* info)
{
    if (info && !mClock) {
        mClock = new ClockWidget(this, false);
    } else if (mClock && !info) {
        mClock->hide();
    }

    if (info) {
        mClock->move(info->pos);
        mClock->show();
    }
}
