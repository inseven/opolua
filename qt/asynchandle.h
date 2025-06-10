// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef ASYNCHANDLE_H
#define ASYNCHANDLE_H

#include <QObject>

// For things like timers that need a QObject in order to be cancellable
class AsyncHandle : public QObject {
    Q_OBJECT
public:
    explicit AsyncHandle(QObject *parent, int ref)
        : QObject(parent), mRef(ref)
    {}

    int ref() const {
        return mRef;
    }

private:
    int mRef;
};

#endif // ASYNCHANDLE_H
