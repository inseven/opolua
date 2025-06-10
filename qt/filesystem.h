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
    void addMapping(char drive, const QDir& to, bool writeable=false);
    void addSimulatedDrive(char drive, const QVector<QString>& files);
    bool writeableCDrive() const;

    void makeFsIoHandlerBridge(lua_State *L) const;
    QString getNativePath(const QString& devicePath, bool* writeable=nullptr) const;

private:
    static int fsop(lua_State* L);

private:
    struct Drive {
        bool writeable;
        QString path;
    };
    QMap<char, Drive> mPaths;
    QMap<QString, QString> mSimulatedPaths;
    char mSimulatedDrive;
};

#endif // FILESYSTEM_H
