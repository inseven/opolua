// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
