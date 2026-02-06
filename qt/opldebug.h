// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLDEBUG_H
#define OPLDEBUG_H

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

struct ProgramInfo
{
    QVector<Frame> frames;
    QVector<Module> modules;
    bool paused;
    std::optional<int> err;
};

static inline bool operator==(const Module &lhs, const Module &rhs)
{
    return lhs.path == rhs.path;
}

} // end namespace

#endif // OPLDEBUG_H
