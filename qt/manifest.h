// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef MANIFEST_H
#define MANIFEST_H

#include "opldevicetype.h"
#include <QJsonObject>
#include <QString>

class Manifest
{
public:
    Manifest();
    Manifest(const QString& path);

    QJsonObject toJson() const;
    bool load();
    bool save();

    // accessors

    QString path() const { return mPath; }
    void setPath(const QString& path) { mPath = path; }

    OplDeviceType device() const { return mDevice; }
    void setDevice(OplDeviceType device) { mDevice = device; }

    int scale() const { return mScale; }
    void setScale(int scale) { mScale = scale; }

    QString sourceUrl() const { return mSourceUrl; }
    void setSourceUrl(const QString& sourceUrl) { mSourceUrl = sourceUrl; }

    QString appVersion() const { return mAppVersion; }
    void setAppVersion(const QString& appVersion) { mAppVersion = appVersion; }

private:
    QString mPath;
    OplDeviceType mDevice;
    int mScale;
    QString mSourceUrl;
    QString mAppVersion;

};

#endif // MANIFEST_H
