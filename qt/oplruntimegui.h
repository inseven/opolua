// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
    static QPixmap imageFromBitmap(OplScreen::BitmapMode mode, int width, int height, int stride, const QByteArray& data);
    OplAppInfo getAppInfo(const QString& aifPath);

    QVector<OplAppInfo> getCDriveApps();

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
