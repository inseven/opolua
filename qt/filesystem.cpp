// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "filesystem.h"
#include "luasupport.h"

#include <QString>
#include <QDebug>
#include <QFileInfo>
#include <QDateTime>

FileSystemIoHandler::FileSystemIoHandler()
    : mSimulatedDrive(0)
{
}

void FileSystemIoHandler::addMapping(char drive, const QDir& path, bool writeable)
{
    mPaths[drive] = { writeable, path.absolutePath() };
    if (drive == mSimulatedDrive) {
        mSimulatedDrive = 0;
        mSimulatedPaths.clear();
    }
}

void FileSystemIoHandler::addSimulatedDrive(char drive, const QVector<QString>& files)
{
    mPaths.remove(drive);
    mSimulatedDrive = drive;
    mSimulatedPaths.clear();
    for (const QString& file : files) {
        mSimulatedPaths[QFileInfo(file).fileName()] = file;
    }
}

bool FileSystemIoHandler::writeableCDrive() const
{
    auto drive = mPaths.value('C');
    return !drive.path.isEmpty() && drive.writeable;
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

QString FileSystemIoHandler::getNativePath(const QString& devicePath, bool* writeable) const
{
    if (writeable) {
        *writeable = false;
    }
    auto components = devicePath.split("\\", Qt::SkipEmptyParts);
    if (!(components.size() > 1 && components[0].size() > 1 && components[0][1] == ':')) {
        return QString();
    }

    char drive = components[0][0].toLatin1();
    if (mSimulatedDrive && drive  == mSimulatedDrive) {
        if (components.size() > 2) {
            // Don't support directories on dummy drive
            return QString();
        }
        return mSimulatedPaths.value(components[1]);
    }

    QString nativePath;
    Drive driveStruct = mPaths.value(drive);
    if (!driveStruct.path.isEmpty()) {
        components[0] = driveStruct.path;
        nativePath = components.join("/");
        if (writeable) {
            *writeable = driveStruct.writeable;
        }
    }
    return nativePath;
}

int FileSystemIoHandler::fsop(lua_State* L)
{
    auto self = reinterpret_cast<const FileSystemIoHandler*>(lua_touserdata(L, lua_upvalueindex(1)));
    QString cmd(lua_tostring(L, 1));
    QString path(lua_tostring(L, 2));
    bool writeable = false;
    QString nativePath = self->getNativePath(path, &writeable);
    // qDebug("fsop %s '%s' -> '%s'", qPrintable(cmd), qPrintable(path), qPrintable(nativePath));

    const bool cmdReturnsResult = cmd == "read" || cmd == "dir" || cmd == "stat" || cmd == "disks";
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

    if (cmd == "dir" && self->mSimulatedDrive && path == QString(QChar(self->mSimulatedDrive)) + ":\\") {
        // Special case this
        auto files = self->mSimulatedPaths.keys();
        QStringList result;
        for (const auto& file : files) {
            result.append(path + file);
        }
        pushValue(L, result);
        return 1;
    }

    if (nativePath.isEmpty() && cmd != "disks") {
        // disks cmd doesn't use path so nativePath is irrelevant
        return err(KErrNotReady);
    }

    bool isWriteOp = cmd == "write" || cmd == "delete" || cmd == "mkdir" || cmd == "rmdir" || cmd == "rename";
    if (isWriteOp && !writeable) {
        return err(KErrAccess);
    }

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
    } else if (cmd == "disks") {
        QVector<QString> result;
        for (auto i = self->mPaths.cbegin(), end = self->mPaths.cend(); i != end; ++i) {
            result.append(QString(QChar(i.key())));
        }
        if (!self->mSimulatedPaths.isEmpty()) {
            result.append("C");
        }
        pushValue(L, result);
        return 1;
    } else if (cmd == "dir") {
        if (!QFileInfo(nativePath).isDir()) {
            return err(KErrNotExists);
        }
        auto files = QDir(nativePath).entryList();
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
    }

    qDebug() << "TODO" << cmd << path;
    return err(-1);

}
