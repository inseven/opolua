// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "asynchandle.h"
#include "oplruntime.h"

AsyncHandle::AsyncHandle(QObject *parent, uint32_t ref, Type type)
    : QObject(parent), mType(type), mRef(ref)
{
}

uint32_t AsyncHandle::ref() const
{
    return mRef;
}

AsyncHandle::Type AsyncHandle::type() const
{
    return mType;
}

void AsyncHandle::finished(int code)
{
    static_cast<OplRuntime*>(parent())->asyncFinished(this, code);
}
