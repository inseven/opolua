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

#ifndef ASYNCHANDLE_H
#define ASYNCHANDLE_H

#include <QByteArray>
#include <QObject>

// For things like timers that need a QObject in order to be cancellable
class AsyncHandle : public QObject {
    Q_OBJECT
public:

    enum Type {
        event,
        after,
        playsound,
    };

    explicit AsyncHandle(QObject *parent, uint32_t ref, Type type)
        : QObject(parent), mType(type), mRef(ref)
    {}

    uint32_t ref() const {
        return mRef;
    }

    Type type() const {
        return mType;
    }

private:
    Type mType;
    uint32_t mRef;
};

#endif // ASYNCHANDLE_H
