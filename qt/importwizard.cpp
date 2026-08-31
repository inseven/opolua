// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "importwizard.h"
#include "importwizardselectpage.h"
#include "importwizardresultspage.h"
#include "manifest.h"

#include <QVariant>

ImportWizard::ImportWizard(QWidget *parent)
    : QWizard(parent)
{
    setOption(QWizard::NoDefaultButton, false); // Why does mac set this
    setAttribute(Qt::WA_DeleteOnClose);
    setWindowTitle("Import app");
    addPage(new ImportWizardSelectPage());
    addPage(new ImportWizardResultsPage());
}

void ImportWizard::done(int r)
{
    if (r == QDialog::Accepted) {
        doInstall();
    }
    QWizard::done(r);
}

void ImportWizard::doInstall()
{
    auto pkg = field("packageFile").toString();

    QString baseDir = field("sourcePath").toString();

    if (field("package").toBool()) {
        QString packagePath = field("packagePath").toString();
        baseDir = QFileInfo(packagePath).dir().path();
        QFile f(packagePath);
        if (!f.open(QFile::ReadWrite)) {
            qDebug("Failed to create %s", qPrintable(f.fileName()));
            return;
        }
        f.write(pkg.toUtf8());
    }

    QByteArray sisFile = mRuntime.makeSis(pkg, baseDir);

    if (field("sis").toBool()) {
        auto sisPath = QDir::fromNativeSeparators(field("sisPath").toString());
        QFile f(sisPath);
        if (!f.open(QFile::ReadWrite)) {
            qDebug("Failed to write %s", qPrintable(sisPath));
            return;
        }
        f.write(sisFile);
    }

    if (field("install").toBool()) {
        auto installPath = field("installPath").toString();
        bool ok = mRuntime.installSis("sis.sis", sisFile, installPath);

        if (ok) {
            auto manifestPath = QDir(installPath).filePath("manifest.json");
            Manifest m(manifestPath);
            m.setDevice(mRuntime.getDeviceType());
            m.setAppVersion(field("sisVersion").toString());
            ok = m.save();
        }

#if !defined(Q_OS_MAC)
        // Mac is the only OS with bundle support
        QFile launcherFile(QDir(installPath).filePath("launch.oplsys"));
        launcherFile.open(QFile::WriteOnly);
        launcherFile.close();
#endif

        if (ok && field("shouldLaunch").toBool()) {
            emit launch(installPath);
        }
    }

}
