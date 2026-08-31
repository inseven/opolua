// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "importwizard.h"
#include "importwizardresultspage.h"
#include "ui_importwizardresultspage.h"

#include <QtGlobal>
#include <QFileIconProvider>
#include <QVariant>

namespace {

template <typename T>
QString left(const QList<T>& list, int n) {
    QList<T> result;
    while (result.count() < n) {
        result.append(list[result.count()]);
    }
    return result.join("\\");
}

void treeifyPathList(QTreeWidget* tree, const QStringList& paths)
{
    QFileIconProvider iconProvider;
    QMap<QString, QTreeWidgetItem*> dirs;
    dirs[QString("")] = tree->invisibleRootItem();
    for (const auto& path : paths) {
        auto parts = path.split("\\");
        auto fileName = parts.last();
        QStringList dir = parts;
        dir.removeLast();
        QString dirStr = dir.join("\\");
        auto dirItem = dirs.value(dirStr);
        if (!dirItem) {
            // Iterate path creating intermediary directories wherever needed
            for (int depth = 1; depth <= dir.count(); depth++) {
                QString intermediateDir = left(dir, depth);
                if (!dirs.value(intermediateDir)) {
                    dirItem = new QTreeWidgetItem({ dir[depth-1] });
                    dirItem->setData(0, Qt::DecorationRole, iconProvider.icon(QFileIconProvider::Folder));
                    dirs.value(left(dir, depth-1))->addChild(dirItem);
                    dirs[intermediateDir] = dirItem;
                }
            }
        }
        auto fileItem = new QTreeWidgetItem({fileName});
        fileItem->setData(0, Qt::DecorationRole, iconProvider.icon(QFileIconProvider::File));
        dirItem->addChild(fileItem);
    }
    tree->expandAll();
}

} // end namespace

ImportWizardResultsPage::ImportWizardResultsPage(QWidget *parent)
    : QWizardPage(parent)
    , ui(new Ui::ImportWizardResultsPage)
{
    ui->setupUi(this);
    setTitle("Analysis Results");
    setButtonText(QWizard::FinishButton, "Import");
    registerField("shouldLaunch", ui->launchCheckbox);
    registerField("packageFile", ui->packageFile, "plainText", SIGNAL(textChanged()));
}

ImportWizardResultsPage::~ImportWizardResultsPage()
{
    delete ui;
}

void ImportWizardResultsPage::initializePage()
{
    auto path = QDir::fromNativeSeparators(field("sourcePath").toString());
    OplRuntime& runtime = static_cast<ImportWizard*>(wizard())->runtime();
    auto result = runtime.analyzeAppFolder(path);
    std::sort(result.files.begin(), result.files.end(), [](const OplRuntime::FileRename& a, const OplRuntime::FileRename& b) {
        return a.nativePath < b.nativePath;
    });

    // Remove any pkg file in the directory itself
    if (!result.appName.isEmpty()) {
        auto basename = QFileInfo(path).fileName();
        QString pkgFile = basename + ".pkg";
        auto iter = std::remove_if(result.files.begin(), result.files.end(), [&pkgFile](const OplRuntime::FileRename& f) {
            return f.nativePath == pkgFile;
        });
        result.files.erase(iter, result.files.end());
    }

    QStringList sourcePaths;
    QStringList devicePaths;
    for (const auto& f : result.files) {
        sourcePaths.append(f.nativePath);
        devicePaths.append(f.devicePath);
    }
    ui->sourceFiles->clear();
    treeifyPathList(ui->sourceFiles, sourcePaths);

    ui->deviceFiles->clear();
    treeifyPathList(ui->deviceFiles, devicePaths);

    ui->launchCheckbox->setVisible(field("install").toBool());
    auto ver = field("sisVersion").toString();
    if (!ver.isEmpty()) {
        result.version = ver;
    }

    if (field("package").toBool()) {
        // adjust native paths to be relative to the package file location
        auto pkgFile = QDir::fromNativeSeparators(field("packagePath").toString());
        auto pkgDir = QFileInfo(pkgFile).dir();
        auto filesDir = QDir(path);
        for (auto& f : result.files) {
            auto absPath = filesDir.absoluteFilePath(f.nativePath.replace("\\", "/"));
            auto relPath = pkgDir.relativeFilePath(absPath).replace("/", "\\");
            f.nativePath = relPath;
        }
    }

    ui->packageFile->setPlainText(runtime.makePackageFile(result));
}
