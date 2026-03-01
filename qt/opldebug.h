// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLDEBUG_H
#define OPLDEBUG_H

#include <QRect>
#include <QString>
#include <QVariant>
#include <QVector>

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
    int bitDepth;
    QRect rect; // For bitmaps, origin will always be 0,0
    uint32_t opCount;
};

struct ProgramInfo
{
    QVector<Frame> frames;
    QVector<Module> modules;
    QVector<Drawable> drawables;
    bool paused;
    std::optional<int> err;
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
        lhs.bitDepth == rhs.bitDepth &&
        lhs.rect == rhs.rect &&
        lhs.opCount == rhs.opCount;
}

struct NameOverride {
    QString proc;
    QString origName;
    QString newName;
};

} // end namespace

#endif // OPLDEBUG_H
