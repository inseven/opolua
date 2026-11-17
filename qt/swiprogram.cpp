// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "swiprogram.h"

#include <QJsonArray>

static QString iconPathFromObject(const QJsonObject& icon)
{
    auto iconPath = icon["path"].toString();
    if (!iconPath.isEmpty() && icon["height"].toInt() != 0 && icon["width"].toInt() != 0) {
        return iconPath;
    } else {
        return QString();
    }
}

SwiProgramVariant::SwiProgramVariant(const QJsonObject& object)
{
    name = object["name"].toString();
    filename = object["filename"].toString();
    if (filename.endsWith(".SIS")) {
        // Normalise this here cos it annoys me
        filename = filename.chopped(4) + ".sis";
    }
    uid = object["uid"].toString();
    version = object["version"].toString();
    sha256 = object["sha256"].toString();
    size = object["size"].toInt();
    iconPath = iconPathFromObject(object["icon"].toObject());

    auto platform = object["platform"].toString();
    if (platform == "epoc16") {
        flags |= SwiFlag::epoc16;
    } else if (platform == "epoc32") {
        flags |= SwiFlag::epoc32;
    }

    if (object["kind"].toString() == "installer") {
        flags |= SwiFlag::installer;
    }

    for (const auto& tag : object["tags"].toArray()) {
        auto tagStr = tag.toString();
        if (tagStr == "aif") {
            flags |= SwiFlag::app;
        }
    }

    bool seenOpl = false;
    bool seenOthers = false;
    for (const auto& runtime : object["runtimes"].toArray()) {
        auto runtimeStr = runtime.toString();
        if (runtimeStr == "opl") {
            seenOpl = true;
        } else if (runtimeStr == "native") {
            seenOthers = true;
        } else {
            seenOthers = true;
            qWarning("Unexpected runtime %s in %s", qPrintable(runtimeStr), qPrintable(filename));
        }
    }

    if (seenOpl && !seenOthers) {
        flags |= SwiFlag::pureOpl;
    }
}

void SwiProgramVariant::addOrigin(const QJsonObject& variantItem)
{
    SwiOrigin origin;
    for (const auto& refItem : variantItem["reference"].toArray()) {
        QString name = refItem.toObject()["name"].toString();
        QString url = refItem.toObject()["url"].toString(); // This can be null, apparently
        origin.urls.append({ .name = name, .url = url });
    }
    origins.append(origin);
}

SwiProgram::SwiProgram(const QJsonObject& object)
{
    mName = object["name"].toString();
    mId = object["id"].toString();
    mIconPath = iconPathFromObject(object["icon"].toObject());

    for (const auto& version : object["versions"].toArray()) {
        for (const auto variant : version.toObject()["variants"].toArray()) {
            QJsonObject obj = variant.toObject();
            QJsonArray items = obj["items"].toArray();
            if (items.count() < 1) {
                continue;
            }
            SwiProgramVariant pv(items[0].toObject());
            
            if (!(pv.flags & SwiFlag::installer)) {
                // We aren't interested in anything we can't install (sorry epoc16)
                continue;
            }

            // if (!(pv.flags & (SwiFlag::epoc16 | SwiFlag::epoc32))) {
            //     // Likewise anything that isn't epoc (There are some WINS SIS files in the index)
            //     continue;
            // }

            for (const auto& item : items) {
                pv.addOrigin(item.toObject());
            }
            mVariants.append(pv);
        }
    }
}

// allFlags is the union of all variants' flags. So the program is considered to have the flag if any variant does.
SwiFlags SwiProgram::allFlags() const
{
    SwiFlags result;
    for (const auto& variant : mVariants) {
        result |= variant.flags;
    }
    return result;
}

QString SwiProgram::getUrl() const
{
    return QString("https://software.psion.community/programs/%1").arg(mId);
}
