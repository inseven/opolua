// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplruntimegui.h"

#include "filesystem.h"
#include "luasupport.h"
#include "palettes.h"

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
        nativePath = nativePath.left(nativePath.length() - 4) + ".aif";
    }

    QFile f(nativePath);
    if (!f.open(QFile::ReadOnly)) {
        return result;
    }
    auto data = f.readAll();
    f.close();

    require(L, "aif");
    lua_getfield(L, -1, "parseAif");
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
    auto appDir = QFileInfo(nativePath).dir();
    auto apps = appDir.entryList({"*.app"}, QDir::Files);
    if (apps.count() == 1) {
        result.deviceAppPath = aifPath.left(aifPath.lastIndexOf("\\") + 1) + apps[0];
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

static uint8_t scale2bpp(uint8_t val)
{
    return val | (val << 2) | (val << 4) | (val << 6);
}

QPixmap OplRuntimeGui::imageFromBitmap(lua_State* L, int index)
{
    auto mode = (OplScreen::BitmapMode)to_int(L, index, "mode");
    int width = to_int(L, index, "width");
    int height = to_int(L, index, "height");
    int stride = to_int(L, index, "stride");
    auto data = to_bytearray(L, index, "imgData");
    return imageFromBitmap(mode, width, height, stride, data);
}

QPixmap OplRuntimeGui::imageFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data)
{
    QImage img;
    if (mode <= OplScreen::gray256) {
        img = QImage(width, height, QImage::Format_Grayscale8);
        img.fill(0xFF888888);
        switch (mode) {
        case OplScreen::gray2: // 1 bpp
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 8 && x < width; i++, x++) {
                        dest[x] = (((*src) >> i) & 1) ? 0xFF : 0;
                    }
                    src++;
                }
            }
            break;
        case OplScreen::gray4: // 2 bpp
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 4 && x < width; i++, x++) {
                        dest[x] = scale2bpp((*src & (0x3 << (i*2))) >> (i * 2));
                    }
                    src++;
                }
            }
            break;
        case OplScreen::gray16:
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    uint8_t b = *src;
                    dest[x++] = ((b & 0xF) << 4) | (b & 0xF); // 0xA -> 0xAA etc
                    dest[x++] = (b & 0xF0) | (b >> 4); // 0x0A -> 0xAA etc
                    src++;
                }
            }
            break;
        case OplScreen::gray256:
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                memcpy(dest, src, width);
            }
            break;
        default:
            Q_UNREACHABLE();
        }
    } else {
        switch (mode) {
        case OplScreen::color256:
            img = QImage(width, height, QImage::Format_Indexed8);
            img.setColorTable(QVector<QRgb>(std::begin(kEpoc8bitPalette), std::end(kEpoc8bitPalette)));
            if (img.bytesPerLine() == stride) {
                memcpy(img.bits(), data.data(), stride * height);
            } else {
                for (int y = 0; y < height; y++) {
                    auto src = (const uchar*)data.data() + stride * y;
                    auto dest = img.scanLine(y);
                    memcpy(dest, src, width);
                }
            }
            break;
        case OplScreen::color16:
            img = QImage(width, height, QImage::Format_Indexed8);
            img.setColorTable(QVector<QRgb>(std::begin(kEpoc4bitPalette), std::end(kEpoc4bitPalette)));
            for (int y = 0; y < height; y++) {
                auto src = (const uchar*)data.data() + stride * y;
                auto dest = img.scanLine(y);
                int x = 0;
                while (x < width) {
                    for (int i = 0; i < 2 && x < width; i++, x++) {
                        dest[x] = (*src & (0xF << (i*4))) >> (i * 4);
                    }
                    src++;
                }
            }
            break;
        default:
            qDebug("TODO imageFromBitmap mode=%d", mode);
        }
    }
    if (!img.isNull()) {
        return QPixmap::fromImage(img);
    } else {
        return QPixmap();
    }
}
