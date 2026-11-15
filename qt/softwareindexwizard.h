// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef SOFTWAREINDEXWIZARD_H
#define SOFTWAREINDEXWIZARD_H

#include <QDir>
#include <QIcon>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QProgressDialog>
#include <QVector>
#include <QWizard>

#include "swiprogram.h"

class SoftwareIndexWizard : public QWizard
{
    Q_OBJECT

public:
    explicit SoftwareIndexWizard(QWidget *parent = nullptr);
    const QVector<SwiProgram>& programs() const;
    QIcon getIcon(const SwiProgram& program);
    QIcon getIcon(const SwiProgramVariant& variant);

    void setSelectedProgram(const SwiProgram* program);
    const SwiProgram* selectedProgram() const;

    void setSelectedVariant(const SwiProgramVariant* variant);
    const SwiProgramVariant* selectedVariant() const;

public slots:
    void fetchIndex(bool forceRefresh=false);
    void loadIndex();

private slots:
    void gotIndex();
    void cancelDownload();
    void gotInstaller();
    void downloadProgress(qint64 bytesReceived, qint64 bytesTotal);

signals:
    void indexUpdated();
    void programIconUpdated(const SwiProgram* program, const QIcon& icon);
    void programVariantIconUpdated(const SwiProgramVariant* variant, const QIcon& icon);

protected:
    void done(int r);

private:
    void doInstall();
    QString fileSystemPathForIconPath(const QString& iconPath) const;
    QIcon gotIcon(const QString& iconPath, QNetworkReply* reply);

public:
    static QDir indexDir();
    static std::optional<QDateTime> lastModified();

private:
    QNetworkAccessManager mNetwork;
    QPointer<QNetworkReply> mFetchReply;
    QVector<SwiProgram> mPrograms;
    const SwiProgram* mSelectedProgram;
    const SwiProgramVariant* mSelectedVariant;
    QPointer<QProgressDialog> mProgressDialog;
};

#endif // SOFTWAREINDEXWIZARD_H
