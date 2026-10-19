// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "manifest.h"
#include "oplfns.h"

#include <QFile>
#include <QJsonDocument>

Manifest::Manifest()
    : Manifest(QString())
{
}

Manifest::Manifest(const QString& path)
    : mPath(path)
    , mDevice(psionSeries5)
    , mScale(1)
{
}

QJsonObject Manifest::toJson() const
{
    QJsonObject obj;
    QString typeStr = oplGetDeviceName(mDevice);
    obj.insert("device", typeStr);
    obj.insert("scale", mScale);
    if (!mSourceUrl.isEmpty()) {
        obj.insert("sourceUrl", mSourceUrl);
    }
    if (!mAppVersion.isEmpty()) {
        obj.insert("appVersion", mAppVersion);
    }
    if (!mDebuggerInfo.isUndefined()) {
        obj.insert("debugger", mDebuggerInfo);
    }
    return obj;
}

bool Manifest::load()
{
    QFile f(mPath);
    if (!f.open(QFile::ReadOnly)) {
        qWarning("Failed to open manifest %s", qPrintable(mPath));
        return false;
    }
    auto manifest = QJsonDocument::fromJson(f.readAll());
    f.close();
    QString device = manifest["device"].toString();

    if (!device.isEmpty()) {
        auto result = oplGetDeviceFromName(device.toUtf8().data());
        if (result == -1) {
            qWarning("Unknown device type %s", qPrintable(device));
            mDevice = psionSeries5;
        } else {
            mDevice = (OplDeviceType)result;
        }
    }
    mScale = manifest["scale"].toInt(1);
    mSourceUrl = manifest["sourceUrl"].toString();
    mAppVersion = manifest["appVersion"].toString();
    mDebuggerInfo = manifest["debugger"];
    return true;
}

bool Manifest::save()
{
    if (mPath.isEmpty()) {
        qWarning("No path, cannot save manifest");
        return false;
    }

    auto obj = toJson();
    QFile f(mPath);
    if (f.open(QFile::ReadWrite | QFile::Truncate)) {
        f.write(QJsonDocument(obj).toJson());
        f.close();
        return true;
    } else {
        qWarning("Failed to open %s", qPrintable(mPath));
        return false;
    }
}
