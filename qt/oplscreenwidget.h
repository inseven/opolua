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

#ifndef OPLSCREENWIDGET_H
#define OPLSCREENWIDGET_H

#include <QtGlobal>
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QAudioSink>
#else
#include <QAudioOutput>
#endif
#include <QBitmap>
#include <QImage>
#include <QKeyEvent>
#include <QLabel>
#include <QMap>
#include <QPainter>
#include <QPointer>
#include <QScopedPointer>
#include <QSet>
#include <QTimer>

#include "oplscreen.h"

class OplRuntimeGui;
class Drawable;
class Window;
class ClockWidget;
class SpriteWidget;
class WindowShadow;

struct WindowSprite : public OplScreen::Sprite
{
    int currentFrame;
    int64_t remainingFrameTime;
};

class OplScreenWidget : public QWidget, public OplScreen
{
    Q_OBJECT
public:
    explicit OplScreenWidget(QWidget *parent = nullptr);
    ~OplScreenWidget();
    OplRuntimeGui* getRuntime() const;

    int getScale() const { return mScale; }
    void setScale(int scale);
    QSize sizeHint() const override;

    void mouseEvent(QMouseEvent* event, Window* window);
    Drawable* getBitmap(int drawableId) const;

protected:
    virtual void keyPressEvent(QKeyEvent *event) override;
    virtual void keyReleaseEvent(QKeyEvent *event) override;
    void focusInEvent(QFocusEvent *event) override;
    void focusOutEvent(QFocusEvent *event) override;

protected:
    void init() override;
    void closeDrawable(int drawableId) override;
    int createWindow(int drawableId, const QRect& rect, BitmapMode mode, int shadow) override;
    int createBitmap(int drawableId, const QSize& size, BitmapMode mode) override;
    int loadPng(int drawableId, const QString& path) override;
    int setOrder(int drawableId, int order) override;
    int getRank(int drawableId) override;
    int showWindow(int drawableId, bool flag) override;
    int setWindowRect(int drawableId, const QPoint& position, const QSize* size) override;
    void beginBatchDraw() override;
    void draw(const DrawCmd& command) override;
    void bitBlt(int drawableId, bool color, int width, int height, const QByteArray& data) override;
    void copyMultiple(const CopyMultipleCmd& cmd, const QVector<QRect>& rects, const QVector<QPoint>& points) override;
    void endBatchDraw() override;
    void clock(int drawableId, const ClockInfo* info) override;
    void startClockTimer();
    void playSound(AsyncHandle* handle, const QByteArray& data) override;
    void sprite(int drawableId, int spriteId, const Sprite* sprite) override;
    QByteArray peekLine(int drawableId, const QPoint& position, int numPixels, PeekMode mode) override;
    QByteArray getImageData(int drawableId, const QRect& rect) override;

private slots:
    void audioStateChanged(QAudio::State state);
    void audioHandleDeleted();
    void spriteTimerTick();
    void onStopped();
    void clockTick();
    void onDeviceTypeChanged();

signals:
    void clockTimeChanged();
    void deviceTypeChanged();

private:
    OplRuntimeGui* mRuntime;
    QMap<int, Window*> mWindows;
    QMap<int, Drawable*> mDrawables;
    QSet<Drawable*> mBatchSeenDrawables;
    int mScale;

    QPointer<WindowShadow> mStoppedShadow;
    QScopedPointer<Drawable> mDitherPattern;
    SpriteWidget* mSpriteWidget;
    QScopedPointer<QTimer> mSpriteTimer;
    int64_t mLastSpriteTick;
    QScopedPointer<QTimer> mClockTimer;

    AsyncHandle* mAudioAsync;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QAudioSink* mAudio;
#else
    QAudioOutput* mAudio;
#endif
    QByteArray mAudioData;
};

class Drawable
{
public:
    explicit Drawable(int drawableId, const QSize& size, OplScreen::BitmapMode mode);
    explicit Drawable(int drawableId, QPixmap&& pixmap, OplScreen::BitmapMode mode);
    virtual ~Drawable() {}
    int getId() const;
    QSize size() const;
    OplScreen::BitmapMode getMode() const { return mode; }
    virtual void setSize(const QSize& size);
    virtual void draw(const OplScreen::DrawCmd& cmd);
    virtual void drawSetPixels(const OplScreen::CopyMultipleCmd& cmd, Drawable& src, const QRect& srcRect, const QRect& destRect);
    virtual void drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src, Drawable* mask);
    void loadFromBitmap(bool color, int width, int height, const QByteArray& data);

    QPixmap& getPixmap();
    QBitmap& getMask();
    void invalidateMask();
    virtual Drawable* getGreyPlane() const;

    virtual void update();

protected:
    int id;
    QPixmap mPixmap;
    OplScreen::BitmapMode mode;
    QBitmap mMask;
};

class Window : public QLabel, public Drawable
{
    Q_OBJECT
public:
    explicit Window(OplScreenWidget* screen, int drawableId, const QRect& rect, OplScreen::BitmapMode mode, int shadowSize);
    void setSize(const QSize& size) override;
    void setPos(const QPoint& pos);
    QPoint getPos() const;
    void setScale(int scale);
    QRect scaledRect() const;
    WindowShadow* shadow() const { return mShadow; }

    void draw(const OplScreen::DrawCmd& cmd) override;
    void drawSetPixels(const OplScreen::CopyMultipleCmd& cmd, Drawable& src, const QRect& srcRect, const QRect& destRect) override;
    void drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src, Drawable* mask) override;
    Drawable* getGreyPlane() const override;
    void update() override;
    void setSprite(int spriteId, const OplScreen::Sprite* sprite);
    void animateSprites(int64_t interval_us);
    void updateSprites(QPainter& painter);

protected:
    virtual void mousePressEvent(QMouseEvent *event) override;
    virtual void mouseMoveEvent(QMouseEvent *event) override;
    virtual void mouseReleaseEvent(QMouseEvent *event) override;
    virtual void mouseDoubleClickEvent(QMouseEvent *event) override;

private:
    Drawable& greyPlane();

public:
    ClockWidget* mClock;
    QMap<int, WindowSprite> mSprites;
private:
    QRect mUnscaledRect;
    int mScale;
    WindowShadow* mShadow;
    int mShadowSize;
    QScopedPointer<Drawable> mGreyPlane;
};

class SpriteWidget : public QLabel
{
    Q_OBJECT

public:
    explicit SpriteWidget(OplScreenWidget* screen);
    void renderSprites(const QList<Window*>& windows, int scale);

protected:
    void resizeEvent(QResizeEvent *event);

private:
    QPixmap mPixmap;
};

class WindowShadow : public QWidget
{
    Q_OBJECT

public:
    explicit WindowShadow(QWidget* parent);

protected:
    void paintEvent(QPaintEvent *event) override;

};

#endif // OPLSCREENWIDGET_H
