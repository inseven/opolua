// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef FILESYSTEM_H
#define FILESYSTEM_H

#include "luasupport.h"

#include <QMap>
#include <QDir>

class FileSystemIoHandler {

public:
    explicit FileSystemIoHandler();
    void addMapping(char drive, const QDir& to, bool writable=false);
    void addSimulatedDrive(char drive, const QVector<QString>& files);
    void removeMapping(char drive);
    void removeAllMappings();
    bool writableCDrive() const;

    void makeFsIoHandlerBridge(lua_State *L) const;
    QString getNativePath(const QString& devicePath, bool* writable=nullptr) const;

private:
    static int fsop(lua_State* L);

private:
    struct Drive {
        bool writable;
        QString path;
    };
    QMap<char, Drive> mPaths;
    QMap<QString, QString> mSimulatedPaths;
    char mSimulatedDrive;
};

#endif // FILESYSTEM_H
