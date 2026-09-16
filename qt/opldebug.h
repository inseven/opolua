// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLDEBUG_H
#define OPLDEBUG_H

#include <QRect>
#include <QString>
#include <QVariant>
#include <QVector>
#include <optional>

#include "oplscreen.h" // For SpriteFrame

namespace opl {

enum Type
{
    EWord = 0,
    ELong = 1,
    EReal = 2,
    EString = 3,
    EWordArray = 0x80,
    ELongArray = 0x81,
    ERealArray = 0x82,
    EStringArray = 0x83,
};

static inline bool IsArrayType(Type t) {
    return (t & 0x80) != 0;
}

struct Variable
{
    Type type;
    uint32_t address;
    uint16_t index;
    QString name;
    QVariant value;
    bool global;
};

struct Module
{
    QString name;
    QString path;
    QString nativePath;
};

struct Frame
{
    uint32_t ip;
    QString ipDecode;
    QString procName;
    QString procModule; // For convenience, this is a native path
    QVector<Variable> variables;
};

struct Drawable
{
    int id;
    bool isWindow;
    bool isColor;
    bool isCurrent;
    int bitDepth;
    QRect rect; // For bitmaps, origin will always be 0,0
    uint32_t opCount;
    int rank;
};

struct Sprite
{
    int spriteId;
    int windowId;
    QPoint origin;
    bool isGlobal;
    bool isCurrent;
    // Strictly speaking this would normally be predicated on the translatorVersion, but we use
    // bmp.opx sprite APIs for implementing BUSY even on sibo so we have to cope with potentially a
    // mix.
    bool isSibo;
    QVector<OplScreen::SpriteFrame> frames;
};

struct ProgramInfo
{
    QVector<Frame> frames;
    QVector<Module> modules;
    QVector<Drawable> drawables;
    QVector<Sprite> sprites;
    bool paused;
    std::optional<int> err;
    QString exitingError;
};

static inline bool operator==(const Module &lhs, const Module &rhs)
{
    return lhs.path == rhs.path;
}

static inline bool operator==(const Drawable &lhs, const Drawable &rhs)
{
    return lhs.id == rhs.id &&
        lhs.isWindow == rhs.isWindow &&
        lhs.isColor == rhs.isColor &&
        lhs.isCurrent == rhs.isCurrent &&
        lhs.bitDepth == rhs.bitDepth &&
        lhs.rect == rhs.rect &&
        lhs.opCount == rhs.opCount &&
        lhs.rank == rhs.rank;
}

static inline bool operator==(const Sprite &lhs, const Sprite &rhs)
{
    return lhs.spriteId == rhs.spriteId &&
        lhs.windowId == rhs.windowId &&
        lhs.origin == rhs.origin &&
        lhs.isGlobal == rhs.isGlobal &&
        lhs.isCurrent == rhs.isCurrent &&
        lhs.isSibo == rhs.isSibo &&
        lhs.frames == rhs.frames;
}

struct NameOverride {
    QString proc;
    QString origName;
    QString newName;
};

} // end namespace

#endif // OPLDEBUG_H
