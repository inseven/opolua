// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef SWIPROGRAM_H
#define SWIPROGRAM_H

#include <QJsonObject>

struct SisVersion {
    
    bool operator==(const SisVersion& rhs) {
        return major == rhs.major && minor == rhs.minor;
    }

    bool operator<(const SisVersion& rhs) {
        return major < rhs.major || (major == rhs.major && minor < rhs.minor);
    }

    uint16_t major;
    uint16_t minor;
};

// Each origin can contain multiple named URLs
struct SwiOriginUrl
{
    QString name;
    QString url;
};

struct SwiOrigin
{
    QVector<SwiOriginUrl> urls;
};

enum class SwiFlag {
    epoc16 = 1, // platform == epoc16
    epoc32 = 2, // platform == epoc32
    installer = 4, // kind == installer
    app = 8, // tags.aif, implies kinds.installer
    pureOpl = 0x10, // !tags.nativebin
};

Q_DECLARE_FLAGS(SwiFlags, SwiFlag);
Q_DECLARE_OPERATORS_FOR_FLAGS(SwiFlags);

// The software index (v1) API has 2 levels of nesting below the top-level "program": version and
// variant. The 'version' groups together all instances with the same version tag. Within each
// version are 1 or more variants, which is an instance with a different SHA but the same version.
// Within each variant are one or more items, one item per origin. Ie with the variant, the SHAs
// are all the same but the 'reference' field is different. I think.
// We promote the variants and throw away the grouping by version number, just to make the data
// structure flatter and a bit simpler. We also flatten all the items within the variant into one
// SwiProgramVariant, with a list of origins.
struct SwiProgramVariant
{
    explicit SwiProgramVariant(const QJsonObject& variantItem);
    SwiProgramVariant() = default;
    SwiProgramVariant(const SwiProgramVariant&) = default;
    SwiProgramVariant(SwiProgramVariant&&) = default;
    
    SwiProgramVariant& operator=(const SwiProgramVariant&) = default;
    SwiProgramVariant& operator=(SwiProgramVariant&&) = default;

    void addOrigin(const QJsonObject& variantItem);

    QString name; // proooobably the same as SwiProgram::name()
    QString filename;
    QString uid;
    QString version;
    QString sha256;
    int64_t size;
    QString iconPath;
    SwiFlags flags;

    QVector<SwiOrigin> origins;
};

class SwiProgram
{
public:
    explicit SwiProgram(const QJsonObject& object);

    const QString& name() const { return mName; }
    QString getUrl() const;
    SwiFlags allFlags() const;
    const QVector<SwiProgramVariant>& variants() const { return mVariants; }
    const QString& iconPath() const { return mIconPath; }

private:
    QString mName;
    QString mId;
    QVector<SwiProgramVariant> mVariants;
    QString mIconPath;
};

#endif // SWIPROGRAM_H
