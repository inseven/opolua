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

#ifndef FILESYSTEM_H
#define FILESYSTEM_H

#include "luasupport.h"

#include <QMap>
#include <QMutex>
#include <QDir>

class FileSystemIoHandler {

public:
    explicit FileSystemIoHandler();
    void addMapping(char drive, const QDir& to, bool writable=false);
    void addSimulatedDrive(char drive, const QVector<QString>& files);
    void removeMapping(char drive);
    void removeAllMappings();
    bool isWritable(char drive) const;

    void makeFsIoHandlerBridge(lua_State *L) const;
    QString getNativePath(const QString& devicePath, bool* writable=nullptr) const;

private:
    static int fsop(lua_State* L);

private:
    struct Drive {
        bool writable;
        QString path;
    };
    mutable QMutex mMutex;
    QMap<char, Drive> mPaths;
    QMap<QString, QString> mSimulatedPaths;
    char mSimulatedDrive;
};

#endif // FILESYSTEM_H
