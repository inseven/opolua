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

#include "oplscreen.h"

class OplRuntime;
class Drawable;
class Window;
class ClockWidget;

class OplScreenWidget : public QWidget, public OplScreen
{
    Q_OBJECT
public:
    explicit OplScreenWidget(QWidget *parent = nullptr);
    ~OplScreenWidget();
    OplRuntime* getRuntime() const;

    QSize sizeHint() const override;

    void mouseEvent(QMouseEvent* event, Window* window);

protected:
    virtual void keyPressEvent(QKeyEvent *event) override;
    virtual void keyReleaseEvent(QKeyEvent *event) override;

protected:
    void closeDrawable(int drawableId) override;
    int createWindow(int drawableId, const QRect& rect, BitmapMode mode, int shadow) override;
    int createBitmap(int drawableId, const QSize& size, BitmapMode mode) override;
    int loadPng(int drawableId, const QString& path) override;
    int setOrder(int drawableId, int order) override;
    int getRank(int drawableId) override;
    int showWindow(int drawableId, bool flag) override;
    int setWindowRect(int drawableId, const QPoint& position, const QSize* size) override;
    void drawCommands(const QVector<DrawCmd>& commands) override;
    void bitBlt(int drawableId, OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data) override;
    void copyMultiple(int srcId, int destId, QRgb color, bool invert, const QVector<QRect>& rects, const QVector<QPoint>& points) override;
    void clock(int drawableId, const ClockInfo* info) override;
    void playSound(AsyncHandle* handle, const QByteArray& data) override;

private slots:
    void audioStateChanged(QAudio::State state);
    void audioHandleDeleted();

private:
    OplRuntime* mRuntime;
    QMap<int, Window*> mWindows;
    QMap<int, Drawable*> mDrawables;

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
    virtual void setSize(const QSize& size);
    void draw(const OplScreen::DrawCmd& cmd);
    void drawSetPixels(Drawable& src, const QRect& srcRect, const QRect& destRect, bool invert, QRgb color);
    void drawCopy(const OplScreen::DrawCmd& cmd, Drawable& src);
    void loadFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data);

    virtual void update();
protected:
    int id;
    QPixmap mPixmap;
    OplScreen::BitmapMode mode;
    QBitmap mask;
};

class Window : public QLabel, public Drawable
{
public:
    explicit Window(OplScreenWidget* screen, int drawableId, const QRect& rect, OplScreen::BitmapMode mode);
    void setSize(const QSize& size) override;
    void update() override;
    void clock(const OplScreen::ClockInfo* info);

protected:
    virtual void mousePressEvent(QMouseEvent *event) override;
    virtual void mouseMoveEvent(QMouseEvent *event) override;
    virtual void mouseReleaseEvent(QMouseEvent *event) override;

private:
    ClockWidget* mClock;
};

#endif // OPLSCREENWIDGET_H
