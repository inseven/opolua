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

#include "filesystem.h"
#include "luasupport.h"

#include <QDateTime>
#include <QDebug>
#include <QFileInfo>
#include <QMutexLocker>
#include <QString>

FileSystemIoHandler::FileSystemIoHandler()
    : mSimulatedDrive(0)
{
}

void FileSystemIoHandler::addMapping(char drive, const QDir& path, bool writable)
{
    removeMapping(drive);
    QMutexLocker lock(&mMutex);
    // qDebug("mapping: %c -> %s writable=%d", drive, qPrintable(path.absolutePath()), (int)writable);
    mPaths[drive] = { writable, false, path.absolutePath() };
}

void FileSystemIoHandler::removeMapping(char drive)
{
    // qDebug("remove mapping: %c", drive);
    QMutexLocker lock(&mMutex);
    mPaths.remove(drive);
    if (drive == mSimulatedDrive) {
        mSimulatedDrive = 0;
        mSimulatedPaths.clear();
    }
}

void FileSystemIoHandler::removeAllMappings()
{
    QMutexLocker lock(&mMutex);
    mPaths.clear();
    mSimulatedDrive = 0;
    mSimulatedPaths.clear();
}

void FileSystemIoHandler::addSimulatedDrive(char drive, const QVector<QString>& files)
{
    removeMapping(drive);
    QMutexLocker lock(&mMutex);
    mSimulatedDrive = drive;
    mSimulatedPaths.clear();
    for (const QString& file : files) {
        mSimulatedPaths[QFileInfo(file).fileName().toLower()] = file;
    }
}

bool FileSystemIoHandler::isWritable(char drive) const
{
    QMutexLocker lock(&mMutex);
    auto driveInfo = mPaths.value(drive);
    return !driveInfo.path.isEmpty() && driveInfo.writable;
}

QString FileSystemIoHandler::mappingForDrive(char drive) const
{
    QMutexLocker lock(&mMutex);
    return mPaths.value(drive).path;
}

void FileSystemIoHandler::makeFsIoHandlerBridge(lua_State *L) const
{
    lua_newtable(L);
    lua_pushlightuserdata(L, (void*)this);
    luaL_Reg fns[] = {
        { "fsop", fsop },
        { nullptr, nullptr },
    };
    luaL_setfuncs(L, fns, 1);
}

enum EpocError {
    KErrNone = 0,
    KErrNotExists = -33,
    KErrAccess = -39,
    KErrNotReady = -62,
};

QMap<QString, QString> getEntryListLowerMap(QDir& dir)
{
    QMap<QString, QString> result;
    for (const QString& entry : dir.entryList()) {
        result[entry.toLower()] = entry;
    }
    return result;
}

QString FileSystemIoHandler::getNativePath(const QString& devicePath, bool* writable) const
{
    QMutexLocker lock(&mMutex);
    const Drive* mapping = nullptr;
    auto result = getNativePathLocked(devicePath, mapping);
    if (writable) {
        *writable = mapping ? mapping->writable : false;
    }
    return result;
}

QString FileSystemIoHandler::getNativePathLocked(const QString& devicePath, const Drive*& mapping) const
{
    auto components = devicePath.split("\\", Qt::SkipEmptyParts);
    if (!(components.size() >= 1 && components[0].size() > 1 && components[0][1] == ':')) {
        return QString();
    }

    char drive = components[0].toUpper()[0].toLatin1();
    if (mSimulatedDrive && drive == mSimulatedDrive) {
        if (components.size() != 2) {
            // Don't support directories on dummy drive
            return QString();
        }
        return mSimulatedPaths.value(components[1].toLower());
    }

    auto drvIter = mPaths.find(drive);
    mapping = (drvIter == mPaths.end()) ? nullptr : &*drvIter;
    if (mapping) {

        QDir dir(mapping->path);

        // Now walk through components[1...] doing case-insensitive corrections where necessary
        const int n = components.count();
        if (n == 1) {
            return mapping->path;
        }
        for (int i = 1; i < n; i++) {
            const QString& component = components[i];
            QString foundEntry;
            if (dir.exists(component)) {
                // qDebug() << dir;
                // qDebug("Entry %s exists with correct case", qPrintable(component));
                foundEntry = component;
            } else {
                // Try a case-insensitive match
                auto map = getEntryListLowerMap(dir);
                foundEntry = map.value(component.toLower());
            }

            if (foundEntry.isEmpty()) {
                // Just go with whatever was requested
                // qDebug("Entry not found, using %s", qPrintable(component));
                foundEntry = component;
            } else {
                // qDebug("Found %s for component %s", qPrintable(foundEntry), qPrintable(component));
            }

            if (i == n - 1) {
                // That's the full path
                return dir.filePath(foundEntry);
            } else {
                // component must be a directory
                dir = QDir(dir.filePath(foundEntry));
                // and continue
            }
        }
    }
    return QString();
}

int FileSystemIoHandler::fsop(lua_State* L)
{
    auto self = reinterpret_cast<const FileSystemIoHandler*>(lua_touserdata(L, lua_upvalueindex(1)));
    QString cmd(lua_tostring(L, 1));
    QString path(lua_tostring(L, 2));

    const bool cmdReturnsResult = cmd == "read" || cmd == "dir" || cmd == "stat" || cmd == "disks" || cmd == "getNativePath";
    auto err = [L, cmdReturnsResult](int err) {
        if (cmdReturnsResult) {
            lua_pushnil(L);
            lua_pushinteger(L, err);
            return 2;
        } else {
            lua_pushinteger(L, err);
            return 1;
        }
    };

    QMutexLocker lock(&self->mMutex);
    if (self->mSimulatedDrive && path == QString(QChar(self->mSimulatedDrive)) + ":\\") {
        // Some special cases required here
        if (cmd == "dir") {
            auto files = self->mSimulatedPaths.keys();
            QStringList result;
            for (const auto& file : files) {
                result.append(path + file);
            }
            pushValue(L, result);
            return 1;
        } else if (cmd == "exists") {
            return err(KErrNone);
        }
    }

    const Drive* mapping = nullptr;
    QString nativePath = self->getNativePathLocked(path, mapping);
    qDebug("fsop %s '%s' -> '%s'", qPrintable(cmd), qPrintable(path), qPrintable(nativePath));

    if (nativePath.isEmpty() && cmd != "disks") {
        // disks cmd doesn't use path so nativePath is irrelevant
        return err(KErrNotReady);
    }

    bool isWriteOp = cmd == "write" || cmd == "delete" || cmd == "mkdir" || cmd == "rmdir" || cmd == "rename";
    if (isWriteOp && !mapping->writable) {
        return err(KErrAccess);
    }

    // We delay auto-creating the mapping dir until the first time something tries to write to it
    if ((cmd == "write" || cmd == "mkdir") && !mapping->createChecked) {
        mapping->createChecked = true;
        QFileInfo info(mapping->path);
        if (!info.exists()) {
            info.dir().mkpath(info.fileName());
        }
    }
    lock.unlock();
    mapping = nullptr; // Make sure it's not used after unlocking

    if (cmd == "read") {
        QFile f(nativePath);
        if (!f.open(QFile::ReadOnly)) {
            return err(KErrNotExists);
        }
        auto data = f.readAll();
        lua_pushlstring(L, data.data(), data.size());
        return 1;
    } else if (cmd == "stat") {
        QFileInfo info(nativePath);
        if (!info.exists()) {
            return err(KErrNotExists);
        }
        lua_createtable(L, 0, 3);
        SET_BOOL(L, "isDir", info.isDir());
        SET_INT(L, "size", info.size());
        lua_pushnumber(L, info.lastModified().toMSecsSinceEpoch() / 1000.0);
        lua_setfield(L, -2, "lastModified");
        return 1;
    } else if (cmd == "exists") {
        QFileInfo info(nativePath);
        if (info.exists()) {
            return err(KErrNone);
        } else {
            return err(KErrNotExists);
        }
    } else if (cmd == "disks") {
        QVector<QString> result;
        lock.relock();
        for (auto i = self->mPaths.cbegin(), end = self->mPaths.cend(); i != end; ++i) {
            result.append(QString(QChar(i.key())));
        }
        if (self->mSimulatedDrive) {
            result.append(QString(QChar(self->mSimulatedDrive)));
        }
        lock.unlock();
        pushValue(L, result);
        return 1;
    } else if (cmd == "dir") {
        if (!QFileInfo(nativePath).isDir()) {
            return err(KErrNotExists);
        }
        auto files = QDir(nativePath).entryList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot);
        QStringList result;
        for (const auto& file : files) {
            result.append(path + file);
        }
        pushValue(L, result);
        return 1;
    } else if (cmd == "write") {
        QFile f(nativePath);
        if (!f.open(QFile::ReadWrite)) {
            // TODO should do accessdenied for readonly
            return err(KErrNotReady);
        }
        size_t sz = 0;
        const char* data = lua_tolstring(L, 3, &sz);
        auto bytes = QByteArray::fromRawData(data, sz);
        auto written = f.write(bytes);
        if ((size_t)written != sz) {
            return err(KErrNotReady);
        }
        lua_pushinteger(L, KErrNone);
        return 1;
    } else if (cmd == "mkdir") {
        QFileInfo info(nativePath);
        if (info.dir().mkpath(info.fileName())) {
            lua_pushinteger(L, KErrNone);
        } else {
            lua_pushinteger(L, KErrNotReady);
        }
        return 1;
    } else if (cmd == "delete") {
        QFile f(nativePath);
        if (f.remove()) {
            lua_pushinteger(L, KErrNone);
        } else {
            lua_pushinteger(L, KErrNotReady);
        }
        return 1;
    } else if (cmd == "rename") {
        QString dest(lua_tostring(L, 3));
        bool destWritable = false;
        QString destNative = self->getNativePath(dest, &destWritable);
        if (destNative.isEmpty()) {
            qDebug("Failed to map %s", qPrintable(dest));
            return err(KErrNotReady);
        } else if (!destWritable) {
            return err(KErrAccess);
        }
        QFile f(nativePath);
        if (f.rename(destNative)) {
            lua_pushinteger(L, KErrNone);
            return 1;
        } else {
            qDebug("Failed to rename %s to %s", qPrintable(path), qPrintable(dest));
            return err(KErrNotReady);
        }
    } else if (cmd == "getNativePath") {
        // Extension for launcher.lua
        pushValue(L, nativePath);
        return 1;
    }

    qDebug() << "TODO" << cmd << path;
    return err(-1);

}
