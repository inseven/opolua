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

#ifndef OPLSCREEN_H
#define OPLSCREEN_H

#include <QByteArray>
#include <QPoint>
#include <QSize>
#include <QRect>
#include <QVector>

enum OplError {
    KErrNone = 0,
    KErrGenFail = -1,
    KErrInvalidArgs = -2,
    KErrIOCancelled = -48,
    KErrDrawNotOpen = -118,
};

constexpr uint32_t KFontDigital35 = 0x10000128;
constexpr uint32_t KFontArialNormal15 = 0x100001F5;

class AsyncHandle;
class OplFontProvider;

class OplScreen {

public:

    enum BitmapMode {
        monochromeWithGreyPlane = -1, // SIBO only, 1bpp plus grey plane
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

    enum GreyMode {
        drawBlack = 0,
        drawGreyOnly = 1,
        drawBlackAndGrey = 2,
    };

    struct DrawCmd {
        DrawCmdType type;
        int drawableId;
        DrawCmdMode mode;
        QPoint origin;
        uint32_t color;
        uint32_t bgcolor;
        int penWidth;
        GreyMode greyMode;
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
                QSize size;
            } pattern;
            struct {
                int dx;
                int dy;
                QRect rect;
            } scroll;
            struct {
                QRect rect;
                uint32_t borderType;
            } border;
            struct {
                QSize size;
            } invert;
            int shutUpCompiler; // so we can always have something to initialise to silence some compilers
        };
    };

    struct CopyMultipleCmd {
        int srcId;
        int destId;
        uint32_t color;
        bool invert;
        GreyMode greyMode;
    };

    struct FontMetrics {
        int height;
        int maxwidth;
        int ascent;
        int descent;
        int widths[256];
    };

    enum ClockType {
        system = 6,
        analog = 7,
        digital = 8,
    };

    struct ClockInfo {
        ClockType mode;
        bool systemIsDigital;
        bool color;
        QPoint pos;
    };

    struct SpriteFrame {
        QPoint offset;
        int bitmap;
        int mask;
        bool invertMask;
        int time; // microseconds
    };

    struct Sprite {
        QPoint origin;
        QVector<SpriteFrame> frames;
    };

    enum PeekMode {
        oneBitBlack = -1,
        oneBitWhite = 0,
        twoBit = 1,
        fourBit = 2,
    };

    virtual void init() = 0;
    virtual void closeDrawable(int drawableId) = 0;
    virtual int createWindow(int drawableId, const QRect& rect, BitmapMode mode, int shadow) = 0;
    virtual int createBitmap(int drawableId, const QSize& size, BitmapMode mode) = 0;
    virtual int loadPng(int drawableId, const QString& path) = 0;
    virtual int setOrder(int drawableId, int order) = 0;
    virtual int getRank(int drawableId) = 0;
    virtual int showWindow(int drawableId, bool flag) = 0;
    virtual int setWindowRect(int drawableId, const QPoint& position, const QSize* size) = 0;

    virtual void beginBatchDraw() = 0;
    virtual void draw(const DrawCmd& command) = 0;
    virtual void bitBlt(int drawableId, bool color, int width, int height, const QByteArray& data) = 0;
    virtual void copyMultiple(const CopyMultipleCmd& cmd, const QVector<QRect>& rects, const QVector<QPoint>& points) = 0;
    virtual void endBatchDraw() = 0;

    virtual void sprite(int drawableId, int spriteId, const Sprite* sprite) = 0;
    virtual void clock(int drawableId, const ClockInfo* info) = 0;
    virtual void playSound(AsyncHandle* handle, const QByteArray& data) = 0;
    virtual QByteArray peekLine(int drawableId, const QPoint& position, int numPixels, PeekMode mode) = 0;
    virtual QByteArray getImageData(int drawableId, const QRect& rect) = 0; // result should be 8bpp with zero stride padding
};

class OplFontProvider {
public:
    virtual QString getFont(uint32_t uid, OplScreen::FontMetrics& metrics) = 0;
};

#endif // OPLSCREEN_H
