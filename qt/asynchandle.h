/*
 * Copyright (C) 2025-2026 Jason Morley, Tom Sutcliffe
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

#ifndef ASYNCHANDLE_H
#define ASYNCHANDLE_H

#include <QByteArray>
#include <QObject>

struct Completion {
    int type;
    int ref;
    int code;
    QByteArray data;
};

// For things like timers that need a QObject in order to be cancellable
class AsyncHandle : public QObject {
    Q_OBJECT
public:

    enum Type {
        getevent,
        keya,
        after,
        playsound,
    };

    explicit AsyncHandle(QObject *parent, int ref, Type type)
        : QObject(parent), mType(type), mRef(ref)
    {}

    int ref() const {
        return mRef;
    }

    Type type() const {
        return mType;
    }

    template <typename T>
    void setCompletionData(const T& data) {
        mCompletionData = QByteArray(reinterpret_cast<const char*>(&data), sizeof(T));
    }

    Completion getCompletion(int code) const {
        return {
            .type = mType,
            .ref = mRef,
            .code = code,
            .data = mCompletionData
        };
    }

private:
    Type mType;
    int mRef;
    QByteArray mCompletionData; // Used by getevent/keya types
};

#endif // ASYNCHANDLE_H
