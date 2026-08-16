// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
        at,
        playsound,
    };

    explicit AsyncHandle(QObject *parent, uint32_t ref, Type type);

    uint32_t ref() const;
    Type type() const;
    void finished(int code);

private:
    Type mType;
    uint32_t mRef;
};

#endif // ASYNCHANDLE_H
