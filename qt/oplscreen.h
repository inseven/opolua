// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLSCREEN_H
#define OPLSCREEN_H

#include <QByteArray>
#include <QPoint>
#include <QSize>
#include <QRgb>
#include <QRect>
#include <QVector>

enum OplError {
    KErrNone = 0,
    KErrGenFail = -1,
    KErrInvalidArgs = -2,
    KErrIOCancelled = -48,
    KErrDrawNotOpen = -118,
};

class AsyncHandle;

class OplScreen {

public:

    enum BitmapMode {
        gray2 = 0, // ie 1bpp
        gray4 = 1, // ie 2bpp
        gray16 = 2, // ie 4bpp grayscale
        gray256 = 3, // ie 8bpp grayscale
        color16 = 4, // ie 4bpp color
        color256 = 5, // ie 8bpp color
        color64K = 6, // 16bpp color
        color16M = 7, // 24bpp color?
        colorRGB = 8, // 32bpp?
        color4K = 9, // ie 12bpp color
    };

    enum DrawCmdType {
        fill,
        circle,
        ellipse,
        line,
        box,
        copy,
        pattern,
        scroll,
        border,
        cmdInvert,
    };

    enum DrawCmdMode {
        set = 0,
        clear = 1,
        invert = 2,
        replace = 3, // Only applicable for copy, pattern and text operations
    };

    enum BorderType {
        // gBORDER
        singlePixel = 0x0,
        singlePixelShadow = 0x1,
        singlePixelShadowRounded = 0x201,
        clearSinglePixelShadow = 0x2,
        clearSinglePixelShadowRounded = 0x202,
        doublePixelShadow = 0x3,
        doublePixelShadowRounded = 0x203,
        clearDoublePixelShadow = 0x4,
        clearDoublePixelShadowRounded = 0x204,

        // gXBORDER type=1
        series3singlePixelShadow = 0x10001,
        series3singlePixelShadowRounded = 0x10201,
        series3clearSinglePixelShadow = 0x10002,
        series3doublePixelShadow = 0x10003,
        series3doublePixelShadowRounded = 0x10203,
        series3clearDoublePixelShadow = 0x10004,

        // gXBORDER type=2
        shallowSunken = 0x20042,
        deepSunken = 0x20044,
        deepSunkenWithOutline = 0x20054,
        shallowRaised = 0x20082,
        deepRaised = 0x20084,
        deepRaisedWithOutline = 0x20094,
        verticalBar = 0x20022,
        horizontalBar = 0x2002A,
    };

    struct DrawCmd {
        DrawCmdType type;
        int drawableId;
        DrawCmdMode mode;
        QPoint origin;
        QRgb color;
        QRgb bgcolor;
        int penWidth;
        // int greyMode; // TODO
        union {
            struct {
                QSize size;
            } fill;
            struct {
                int radius;
                bool fill;
            } circle;
            struct {
                int hRadius;
                int vRadius;
                bool fill;
            } ellipse;
            struct {
                QPoint endPoint;
            } line;
            struct {
                QSize size;
            } box;
            struct {
                int srcDrawableId;
                QRect srcRect;
                int maskDrawableId;
            } copy;
            struct {
                int srcDrawableId;
                QRect srcRect;
            } pattern;
            struct {
                int dx;
                int dy;
                QRect rect;
            } scroll;
            struct {
                QRect rect;
                BorderType borderType;
            } border;
            struct {
                QSize size;
            } invert;
            int shutUpCompiler; // so we can always have something to initialise to silence some compilers
        };
    };

    struct FontMetrics {
        int height;
        int maxwidth;
        int ascent;
        int descent;
        int widths[256];
    };

    struct ClockInfo {
        int mode;
        QPoint pos;
    };

    virtual void closeDrawable(int drawableId) = 0;
    virtual int createWindow(int drawableId, const QRect& rect, BitmapMode mode, int shadow) = 0;
    virtual int createBitmap(int drawableId, const QSize& size, BitmapMode mode) = 0;
    // virtual int loadFont(int drawableId, uint32_t fontUid, FontMetrics& metrics) = 0;
    virtual int loadPng(int drawableId, const QString& path) = 0;
    virtual int setOrder(int drawableId, int order) = 0;
    virtual int getRank(int drawableId) = 0;
    virtual int showWindow(int drawableId, bool flag) = 0;
    virtual int setWindowRect(int drawableId, const QPoint& position, const QSize* size) = 0;
    virtual void drawCommands(const QVector<DrawCmd>& commands) = 0;
    virtual void bitBlt(int drawableId, BitmapMode mode, int width, int height, int stride, const QByteArray& data) = 0;
    virtual void copyMultiple(int srcId, int destId, QRgb color, bool invert, const QVector<QRect>& rects, const QVector<QPoint>& points) = 0;
    // TODO sprite, peekline

    virtual void clock(int drawableId, const ClockInfo* info) = 0;
    virtual void playSound(AsyncHandle* handle, const QByteArray& data) = 0;
};

#endif // OPLSCREEN_H
