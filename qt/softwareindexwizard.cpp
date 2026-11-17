// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "softwareindexwizard.h"

#include <optional>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSslConfiguration>
#include <QStandardPaths>
#include <QUrl>

#include "oplapplication.h"
#include "oplruntimegui.h"
#include "mainwindow.h"
#include "swiwizardlistpage.h"
#include "swiwizardinfopage.h"

SoftwareIndexWizard::SoftwareIndexWizard(QWidget *parent)
    : QWizard(parent)
    , mFetchReply(nullptr)
    , mSelectedProgram(nullptr)
    , mSelectedVariant(nullptr)
{
    setWizardStyle(QWizard::ModernStyle);
    setPixmap(QWizard::LogoPixmap, QPixmap(":/images/opolua.png").scaledToHeight(64));
    setOption(QWizard::NoDefaultButton, false); // Why does mac set this
    setOption(QWizard::NoBackButtonOnStartPage, true);
    setAttribute(Qt::WA_DeleteOnClose);
    setWindowTitle("Install app from sofware index");
    resize(800, 550);

    mProgressDialog = new QProgressDialog(this, Qt::Sheet);
    mProgressDialog->setMinimumDuration(0);
    mProgressDialog->setAutoReset(false); // In case we had to guess about the maximum
    connect(mProgressDialog, &QProgressDialog::canceled, this, &SoftwareIndexWizard::cancelDownload);

    addPage(new SwiWizardListPage());
    addPage(new SwiWizardInfoPage());
}

QDir SoftwareIndexWizard::indexDir()
{
    auto cacheDir = QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    cacheDir.mkpath("index");
    return QDir(cacheDir.filePath("index"));
}

std::optional<QDateTime> SoftwareIndexWizard::lastModified()
{
    auto dir = indexDir();
    QFile f(dir.filePath("metadata.json"));
    if (!f.open(QFile::ReadOnly)) {
        return std::nullopt;
    }
    auto doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    auto date = doc["lastModified"];
    if (date.isString()) {
        auto result = QDateTime::fromString(date.toString(), Qt::ISODate);
        if (result.isNull()) {
            return std::nullopt;
        } else {
            return result;
        }
    }
    return std::nullopt;
}

void SoftwareIndexWizard::fetchIndex(bool forceRefresh)
{
    QUrl url("https://software.psion.community/api/v1/programs/");
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    auto lastMod = lastModified();
    if (lastMod.has_value() && !forceRefresh) {
        // qDebug("Adding IfModifiedSinceHeader %s", qPrintable(lastMod->toString()));
        request.setHeader(QNetworkRequest::IfModifiedSinceHeader, *lastMod);
    }

    mFetchReply = mNetwork.get(request);
    mProgressDialog->setLabelText("Updating index...");
    mProgressDialog->setMaximum(40000000); // It's actually about 42MB at time of writing
    mProgressDialog->setValue(0);
    connect(mFetchReply, &QNetworkReply::downloadProgress, this, &SoftwareIndexWizard::downloadProgress);
    connect(mFetchReply, &QNetworkReply::finished, this, &SoftwareIndexWizard::gotIndex);
}

void SoftwareIndexWizard::gotIndex()
{
    mProgressDialog->reset();
    qDebug("gotIndex bytes = %d", (int)mFetchReply->bytesAvailable());
    if (mFetchReply->error() != QNetworkReply::NoError) {
        qWarning("Error fetching index: %d", mFetchReply->error());
        return;
    }
    int code = mFetchReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (code == 304) {
        // qDebug("Not modified!");
        loadIndex();
        return;
    }

    auto data = mFetchReply->readAll();
    auto dir = indexDir();
    QFile contents(dir.filePath("programs.json"));
    if (!contents.open(QFile::WriteOnly | QFile::Truncate)) {
        qWarning("Couldn't open %s", qPrintable(contents.fileName()));
        return;
    }
    contents.write(data);
    contents.close();

    QJsonObject mtobj;
    mtobj["lastModified"] = mFetchReply->header(QNetworkRequest::LastModifiedHeader).toDateTime().toString(Qt::ISODate);

    QFile metadata(dir.filePath("metadata.json"));
    if (!metadata.open(QFile::WriteOnly | QFile::Truncate)) {
        qWarning("Couldn't open %s", qPrintable(metadata.fileName()));
        return;
    }
    metadata.write(QJsonDocument(mtobj).toJson());
    metadata.close();
    mFetchReply->deleteLater();
    // qDebug("Fetch done!");
    loadIndex();
}

void SoftwareIndexWizard::loadIndex()
{
    auto dir = indexDir();
    QFile programsFile(dir.filePath("programs.json"));
    // QFile programsFile("/Users/tomsci/Downloads/5outhpark_program.json");
    if (!programsFile.open(QFile::ReadOnly)) {
        qWarning("Couldn't open %s", qPrintable(programsFile.fileName()));
        return;
    }
    auto programs = QJsonDocument::fromJson(programsFile.readAll()).array();
    programsFile.close();
    mPrograms.clear();
    mSelectedProgram = nullptr;
    for (const auto& prog : programs) {
        mPrograms.append(SwiProgram(prog.toObject()));
    }
    // qDebug("loadindex Done!");
    emit indexUpdated();
}

const QVector<SwiProgram>& SoftwareIndexWizard::programs() const
{
    return mPrograms;
}

QIcon SoftwareIndexWizard::getIcon(const SwiProgram& program)
{
    const auto& iconPath = program.iconPath();
    // qDebug("getIcon %s", qPrintable(iconPath));
    if (!iconPath.isEmpty()) {
        auto path = fileSystemPathForIconPath(iconPath);
        if (QFileInfo(path).isFile()) {
            return QIcon(path);
        }

        QUrl url(QString("https://software.psion.community/api/v1/") + iconPath);
        QNetworkRequest request(url);
        request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
        QNetworkReply* reply = mNetwork.get(request);
        const SwiProgram* progPtr = &program;
        connect(reply, &QNetworkReply::finished, this, [this, reply, progPtr, iconPath] {
            if (reply->error() == QNetworkReply::NoError) {
                auto icon = gotIcon(iconPath, reply);
                if (!icon.isNull()) {
                    emit programIconUpdated(progPtr, icon);
                }
            }
            reply->deleteLater();
        });
    }
    return QIcon(":/images/icon_unknown.png");
}

QIcon SoftwareIndexWizard::getIcon(const SwiProgramVariant& variant)
{
    const auto& iconPath = variant.iconPath;
    if (!iconPath.isEmpty()) {
        auto path = fileSystemPathForIconPath(iconPath);
        if (QFileInfo(path).isFile()) {
            return QIcon(path);
        }

        QUrl url(QString("https://software.psion.community/api/v1/") + iconPath);
        QNetworkRequest request(url);
        request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
        QNetworkReply* reply = mNetwork.get(request);
        const SwiProgramVariant* variantPtr = &variant;
        connect(reply, &QNetworkReply::finished, this, [this, reply, variantPtr, iconPath] {
            if (reply->error() == QNetworkReply::NoError) {
                auto icon = gotIcon(iconPath, reply);
                if (!icon.isNull()) {
                    emit programVariantIconUpdated(variantPtr, icon);
                }
            }
            reply->deleteLater();
        });
    }
    return QIcon(":/images/icon_unknown.png");
}


QIcon SoftwareIndexWizard::gotIcon(const QString& iconPath, QNetworkReply* reply)
{
    auto data = reply->readAll();
    auto path = fileSystemPathForIconPath(iconPath);
    QFile f(path);
    if (f.open(QFile::ReadWrite | QFile::Truncate)) {
        f.write(data);
        f.close();
        QIcon icon(path);
        if (icon.isNull()) {
            qWarning("Failed to decode icon from %s", qPrintable(path));
        }
        return icon;
    } else {
        qWarning("Couldn't open %s", qPrintable(path));
        return QIcon();
    }
}

QString SoftwareIndexWizard::fileSystemPathForIconPath(const QString& iconPath) const
{
    auto dir = indexDir();
    dir.cd("icons");
    return QFileInfo(dir, QFileInfo(iconPath).fileName()).filePath();
}

void SoftwareIndexWizard::setSelectedProgram(const SwiProgram* program)
{
    mSelectedProgram = program;
    mSelectedVariant = nullptr;
}

const SwiProgram* SoftwareIndexWizard::selectedProgram() const
{
    return mSelectedProgram;
}

void SoftwareIndexWizard::setSelectedVariant(const SwiProgramVariant* variant)
{
    mSelectedVariant = variant;
}

const SwiProgramVariant* SoftwareIndexWizard::selectedVariant() const
{
    return mSelectedVariant;
}

void SoftwareIndexWizard::done(int r)
{
    if (r == QDialog::Accepted && mSelectedVariant) {
        doInstall();
        return;
    }
    QWizard::done(r);
}

void SoftwareIndexWizard::cancelDownload()
{
    // delete mProgressDialog;
    delete mFetchReply;
    mProgressDialog->reset();
}

void SoftwareIndexWizard::doInstall()
{
    mProgressDialog->setMaximum((int)mSelectedVariant->size);
    mProgressDialog->setLabelText("Downloading...");
    mProgressDialog->setValue(0);

    QUrl url(QString("https://software.psion.community/files/") + mSelectedVariant->sha256);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    mFetchReply = mNetwork.get(request);
    connect(mFetchReply, &QNetworkReply::finished, this, &SoftwareIndexWizard::gotInstaller);
    connect(mFetchReply, &QNetworkReply::downloadProgress, this, &SoftwareIndexWizard::downloadProgress);
    // connect(mFetchReply, &QNetworkReply::socketStartedConnecting, this, []{ qDebug("socketStartedConnecting"); });
    // connect(mFetchReply, &QNetworkReply::requestSent, this, []{ qDebug("requestSent"); });
    // connect(mFetchReply, &QNetworkReply::metaDataChanged, this, []{ qDebug("metaDataChanged"); });
    // qDebug("fetch running=%d finished=%d", (int)mFetchReply->isRunning(), (int)mFetchReply->isFinished());
}

void SoftwareIndexWizard::downloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    // qDebug("Got %d bytes", (int)bytesReceived);
    Q_UNUSED(bytesTotal);
    if (mProgressDialog) {
        mProgressDialog->setValue(bytesReceived);
    }
}

void SoftwareIndexWizard::gotInstaller()
{
    // delete mProgressDialog;
    mProgressDialog->reset();
    auto err = mFetchReply->error();
    qDebug("installer download complete err=%d", (int)err);

    if (err == QNetworkReply::NoError) {
        auto installPath = field("installPath").toString();
        auto data = mFetchReply->readAll();
        auto w = gApp->getUnusedWindow();
        w->raise();
        // w->getRuntime().runInstaller(mSelectedVariant->filename, data, installPath);
        w->runInstallerWithSisData(mSelectedProgram->getUrl(), mSelectedVariant->filename, data, installPath);
    }        

    QWizard::done(QDialog::Accepted);

    mFetchReply->deleteLater();
}
