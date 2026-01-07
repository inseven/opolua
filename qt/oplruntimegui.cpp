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

#include "oplruntimegui.h"

#include "filesystem.h"
#include "luasupport.h"

#include <QBitmap>

OplRuntimeGui::OplRuntimeGui(QObject *parent)
    : OplRuntime(parent)
{
    // Make sure we use direct connection to execute synchronously with respect to the Lua runtime, so that we can call
    // getAppInfo().
    connect(this, &OplRuntime::startedRunning, this, &OplRuntimeGui::onStartedRunning, Qt::DirectConnection);
}

QBitmap OplRuntimeGui::pixToBitmap(const QPixmap& pixmap)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    return QBitmap::fromPixmap(pixmap);
#else
    return QBitmap(pixmap);
#endif
}

OplAppInfo OplRuntimeGui::getAppInfo(const QString& aifPath)
{
    OplAppInfo result{};
    QString nativePath = mFs->getNativePath(aifPath);
    if (nativePath.isEmpty()) {
        return result;
    }
    if (nativePath.toLower().endsWith(".app")) {
        auto aif = nativePath.left(nativePath.length() - 4) + ".aif";
        if (QFileInfo(aif).exists()) {
            nativePath = aif;
        }
    }

    QFile f(nativePath);
    if (!f.open(QFile::ReadOnly)) {
        return result;
    }
    auto data = f.readAll();
    f.close();

    require(L, "aif");
    lua_getfield(L, -1, "parseAifToNative");
    lua_remove(L, -2); // aif
    pushValue(L, data);
    int ret = lua_pcall(L, 1, 1, 0);
    if (ret || lua_type(L, -1) != LUA_TTABLE) {
        qDebug("parseAif failed: %s", luaL_tolstring(L, -1, nullptr));
        lua_pop(L, 1);
        return result;
    }

    result.uid = (uint32_t)to_int(L, -1, "uid3");

    rawgetfield(L, -1, "captions");
    QMap<QString, QString> captions;
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        captions[lua_tostring(L, -2)] = lua_tostring(L, -1);
        lua_pop(L, 1);
    }
    lua_pop(L, 1); // captions
    result.appName = captions["en_GB"]; // TODO
    if (nativePath.toLower().endsWith(".opa")) {
        result.deviceAppPath = aifPath;
    } else {
        auto appDir = QFileInfo(nativePath).dir();
        auto apps = appDir.entryList({"*.app"}, QDir::Files);
        if (apps.count() == 1) {
            result.deviceAppPath = aifPath.left(aifPath.lastIndexOf("\\") + 1) + apps[0];
        }
    }

    rawgetfield(L, -1, "icons");
    for (int i = 1; ; i++) {
        if (lua_rawgeti(L, -1, i) != LUA_TTABLE) {
            lua_pop(L, 1);
            break;
        }

        QPixmap img = imageFromBitmap(L, -1);
        QBitmap mask;
        if (rawgetfield(L, -1, "mask") == LUA_TTABLE) {
            mask = pixToBitmap(imageFromBitmap(L, -1));
        }
        lua_pop(L, 1); // mask

        if (!img.isNull()) {
            if (!mask.isNull()) {
                img.setMask(mask);
            }
            result.icon.addPixmap(img);
        }
        lua_pop(L, 1); // icon
    }
    lua_pop(L, 2); // icons, result
    return result;
}

QVector<OplAppInfo> OplRuntimeGui::getCDriveApps()
{
    QVector<OplAppInfo> result;
    auto path = getNativePath("C:\\System\\Apps");
    if (path.isEmpty()) {
        return result;
    }
    QDir appsDir(path);
    for (const QString& appDirName : appsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        // qDebug("Entry %s", qPrintable(appDirName));
        QDir appDir(appsDir.path() + "/" + appDirName, "*.aif", QDir::NoSort, QDir::Files);
        auto aifs = appDir.entryList();
        if (aifs.count() == 1) {
            auto info = getAppInfo("C:\\System\\Apps\\" + appDirName + "\\" + aifs[0]);
            if (!info.deviceAppPath.isEmpty()) {
                result.append(info);
            }
        }
    }
    return result;
}

QVector<OplAppInfo> OplRuntimeGui::getMDriveApps()
{
    QVector<OplAppInfo> result;
    auto path = getNativePath("M:\\APP");
    if (path.isEmpty()) {
        return result;
    }
    QDir appsDir(path);
    for (const QString& appName : appsDir.entryList({"*.OPA", "*.APP"}, QDir::Files)) {
        // qDebug("Entry %s", qPrintable(appName));
        auto info = getAppInfo("M:\\APP\\" + appName);
        if (!info.deviceAppPath.isEmpty()) {
            result.append(info);
        }
    }
    return result;
}

void OplRuntimeGui::onStartedRunning()
{
    OplAppInfo info{};
    if (mDeviceOpoPath.isEmpty()) {
        // Nothing to add
    } else if (!mDeviceOpoPath.toLower().endsWith(".app")) {
        info.deviceAppPath = mDeviceOpoPath;
        info.appName = QFileInfo(getNativePath(mDeviceOpoPath)).fileName();
    } else {
        info = getAppInfo(mDeviceOpoPath);
    }

    emit startedRunningApp(info);
}

QPixmap OplRuntimeGui::imageFromBitmap(lua_State* L, int index)
{
    int width = to_int(L, index, "width");
    int height = to_int(L, index, "height");
    bool color = to_bool(L, index, "isColor");
    auto data = to_bytearray(L, index, "normalizedImgData");
    return imageFromBitmap(color, width, height, data);
}

QPixmap OplRuntimeGui::imageFromBitmap(bool color, int width, int height, const QByteArray& data)
{
    QImage img = QImage(width, height, color ? QImage::Format_RGB32 : QImage::Format_Grayscale8);
    int bytesPerPixel = color ? 4 : 1;
    if (img.bytesPerLine() == bytesPerPixel * width) {
        memcpy(img.bits(), data.data(), img.sizeInBytes());
    } else {
        for (int y = 0; y < height; y++) {
            auto src = (const uchar*)data.data() + width * bytesPerPixel * y;
            auto dest = img.scanLine(y);
            memcpy(dest, src, width * bytesPerPixel);
        }
    }
    return QPixmap::fromImage(img);
}
