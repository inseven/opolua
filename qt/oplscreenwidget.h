// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
    void bitBlt(int drawableId, BitmapMode mode, int width, int height, int stride, const QByteArray& data) override;
    void copyMultiple(int srcId, int destId, QRgb color, bool invert, const QVector<QRect>& rects, const QVector<QPoint>& points) override;
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

signals:
    void clockTimeChanged();

private:
    OplRuntimeGui* mRuntime;
    QMap<int, Window*> mWindows;
    QMap<int, Drawable*> mDrawables;
    QSet<Drawable*> mBatchSeenDrawables;

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
    void draw(const OplScreen::DrawCmd& cmd);
    void drawSetPixels(Drawable& src, const QRect& srcRect, const QRect& destRect, bool invert, QRgb color);
    void drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src, Drawable* mask);
    void loadFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data);

    QPixmap& getPixmap();
    QBitmap& getMask();
    void invalidateMask();

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
    WindowShadow* shadow() const { return mShadow; }

    void update() override;
    void setSprite(int spriteId, const OplScreen::Sprite* sprite);
    void animateSprites(int64_t interval_us);
    void updateSprites(QPainter& painter);

protected:
    virtual void mousePressEvent(QMouseEvent *event) override;
    virtual void mouseMoveEvent(QMouseEvent *event) override;
    virtual void mouseReleaseEvent(QMouseEvent *event) override;

public:
    ClockWidget* mClock;
    QMap<int, WindowSprite> mSprites;
    WindowShadow* mShadow;
    int mShadowSize;
};

class SpriteWidget : public QLabel
{
    Q_OBJECT

public:
    explicit SpriteWidget(OplScreenWidget* screen);
    void renderSprites(const QList<Window*>& windows);

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
