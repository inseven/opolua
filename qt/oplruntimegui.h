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

#ifndef OPLRUNTIMEGUI_H
#define OPLRUNTIMEGUI_H

#include <QByteArray>
#include <QBitmap>
#include <QIcon>
#include <QPixmap>

#include "oplruntime.h"

struct OplAppInfo;

class OplRuntimeGui : public OplRuntime
{
    Q_OBJECT

public:
    explicit OplRuntimeGui(QObject *parent = nullptr);

    static QBitmap pixToBitmap(const QPixmap& pixmap);
    static QPixmap imageFromBitmap(lua_State* L, int index);
    static QPixmap imageFromBitmap(bool color, int width, int height, const QByteArray& data);
    OplAppInfo getAppInfo(const QString& aifPath);

    QVector<OplAppInfo> getCDriveApps();
    QVector<OplAppInfo> getMDriveApps();

signals:
    void startedRunningApp(const OplAppInfo& app);

private slots:

    void onStartedRunning();
};

struct OplAppInfo {
    QString deviceAppPath;
    QString appName;
    QIcon icon;
    uint32_t uid;
};

Q_DECLARE_METATYPE(OplAppInfo)

#endif // OPLRUNTIMEGUI_H
