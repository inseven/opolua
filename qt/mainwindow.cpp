// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "mainwindow.h"

#include <QFileDialog>
#include <QStandardPaths>

#include "ui_mainwindow.h"
#include "oplapplication.h"
#include "oplruntime.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    setAttribute(Qt::WA_DeleteOnClose);
    currentDevice = ui->actionSeries5;
#ifdef Q_OS_MAC
    // This should be ctrl-esc on ALL platforms
    ui->actionStop->setShortcut(QCoreApplication::translate("MainWindow", "Meta+Esc", nullptr));
    // And these don't need to be ctrl-alt (-> cmd-alt on mac)
    ui->actionOpen->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+O", nullptr));
    ui->actionWelcome->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+L", nullptr));
    ui->actionInstall->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+I", nullptr));
    ui->actionClose->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+W", nullptr));
    ui->actionRestart->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+R", nullptr));
    ui->actionSeries5->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+5", nullptr));
    ui->actionSeries7->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+7", nullptr));
    ui->actionGeofoxOne->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+1", nullptr));
#endif

    statusLabel = new QLabel(this);
    ui->statusbar->addWidget(statusLabel);

    auto runtime = ui->screen->getRuntime();
    connect(ui->actionClose, &QAction::triggered, this, &MainWindow::close);
    connect(ui->actionOpen, &QAction::triggered, this, &MainWindow::openDialog);
    connect(ui->actionWelcome, &QAction::triggered, this, &MainWindow::openWelcome);
    connect(ui->actionInstall, &QAction::triggered, this, &MainWindow::installSis);
    connect(ui->actionStop, &QAction::triggered, runtime, &OplRuntime::interrupt);
    connect(ui->actionRestart, &QAction::triggered, runtime, &OplRuntime::restart);
    connect(ui->actionMenu, &QAction::triggered, runtime, &OplRuntime::pressMenuKey);
    connect(ui->actionSeries5, &QAction::triggered, this, [this] { setDevice(ui->actionSeries5, OplRuntime::Series5); });
    connect(ui->actionSeries7, &QAction::triggered, this, [this] { setDevice(ui->actionSeries7, OplRuntime::Series7); });
    connect(ui->actionGeofoxOne, &QAction::triggered, this, [this] { setDevice(ui->actionGeofoxOne, OplRuntime::GeofoxOne); });
    connect(runtime, &OplRuntime::startedRunning, this, &MainWindow::startedRunning);
    connect(runtime, &OplRuntime::titleChanged, this, &MainWindow::setTitle);
    connect(runtime, &OplRuntime::runComplete, this, &MainWindow::runComplete);
    connect(runtime, &OplRuntime::canRestart, ui->actionRestart, &QAction::setEnabled);
    connect(runtime, &OplRuntime::canRestart, ui->actionSeries5, &QAction::setEnabled);
    connect(runtime, &OplRuntime::canRestart, ui->actionSeries7, &QAction::setEnabled);
    connect(runtime, &OplRuntime::canRestart, ui->actionGeofoxOne, &QAction::setEnabled);
    connect(gApp, &OplApplication::onFileOpened, this, &MainWindow::onFileOpened);
    connect(gApp, &OplApplication::recentFilesChanged, this, &MainWindow::updateRecents);
    sizeWindowToFitInterpreter();
    updateRecents(gApp->getRecentFiles());
}

MainWindow::~MainWindow()
{
    delete ui;
}

OplRuntime& MainWindow::getRuntime()
{
    return *ui->screen->getRuntime();
}

void MainWindow::startedRunning(const QString& path)
{
    statusLabel->setText("Running");
    // Don't try to put path in the title bar for things running from resources
    if (path.startsWith(":")) {
        setWindowFilePath(QString());
    } else {
        setWindowFilePath(path);
    }
    setTitle(QFileInfo(path).fileName());
}

void MainWindow::setTitle(const QString& title)
{
    setWindowTitle(title + " - OpoLua");
}

void MainWindow::sizeWindowToFitInterpreter()
{
    QSize sz = ui->screen->sizeHint();
    if (!sz.isEmpty()) {
        resize(QSize(sz.width(), sz.height() + ui->statusbar->sizeHint().height()));
    }
}

void MainWindow::runComplete(const QString& errMsg, const QString& /*errDetail*/)
{
    if (errMsg.isEmpty()) {
        statusLabel->setText("Completed");
    } else {
        statusLabel->setText(errMsg);
    }
}

void MainWindow::openDialog()
{
    QString file = QFileDialog::getOpenFileName(this, tr("Select OPL app"), QString(), tr("OPL Apps (*.opo *.app)"));
    // qDebug("open %s", qPrintable(file));

    if (file.isEmpty()) {
        return;
    }

    // qDebug("open %s sys=%s", qPrintable(file), qPrintable(driveForApp(file)));
    onFileOpened(file);
}

QString MainWindow::driveForApp(const QString& appPath)
{
    QDir dir(QFileInfo(appPath).absoluteDir());
    dir.cdUp();
    if (dir.dirName().toLower() == "apps") {
        dir.cdUp();
        if (dir.dirName().toLower() == "system") {
            dir.cdUp();
            return dir.absolutePath();
        }
    }
    return QString();
}

void MainWindow::openWelcome()
{
    auto m = this;
    if (getRuntime().running()) {
        m = new MainWindow();
        m->show();
    }
    OplRuntime& runtime = m->getRuntime();
    runtime.removeAllDrives();
    runtime.setDrive(Drive::C, ":/welcome/c");

    runtime.run("C:\\System\\Apps\\Welcome\\Welcome.app");
}

void MainWindow::setDevice(QAction* action, int device)
{
    currentDevice->setChecked(false);
    action->setChecked(true);
    currentDevice = action;

    getRuntime().setDeviceType((OplRuntime::DeviceType)device);
    sizeWindowToFitInterpreter();
    getRuntime().restart();
}

void MainWindow::installSis()
{
    QString file = QFileDialog::getOpenFileName(this, tr("Select SIS file"), QString(), tr("SIS files (*.sis)"));
    qDebug("open %s", qPrintable(file));
    if (file.isEmpty()) {
        return;
    }
    onFileOpened(file);
}

void MainWindow::onFileOpened(const QString& path)
{
    if (getRuntime().runningLauncherCommand() == "launcher") {
        getRuntime().interruptAndRun([this, path]() {
            onFileOpened(path);
        });
        return;
    } else if (getRuntime().running()) {
        MainWindow* m = new MainWindow();
        m->show();
        m->onFileOpened(path);
        return;
    }

    QString extension = QFileInfo(path).suffix().toLower();

    if (extension == "sis") {
        QFileInfo fileInfo(path);
        QDir dir = fileInfo.absoluteDir();
        QString destBase = fileInfo.completeBaseName();
        int i = 0;
        QString dest;
        do {
            dest = QFileInfo(dir, destBase).filePath();
            if (i) {
                dest = dest + QString("-%1").arg(i);
            }
            dest = dest + ".oplapp";
            i++;
        } while (QFileInfo(dest).exists());

        getRuntime().setDrive(Drive::C, dest + "/c");
        getRuntime().setDrive(Drive::D, getSharedDrive());
        getRuntime().runInstaller(path, dest);
    } else if (extension == "app") {
        QFileInfo info(path);
        QString drive = driveForApp(path);
        if (!drive.isEmpty()) {
            gApp->addRecentFile(path);
            getRuntime().setDrive(Drive::C, drive);
            getRuntime().setDrive(Drive::D, getSharedDrive());
            getRuntime().run(QString("C:\\System\\Apps\\") + info.dir().dirName() + "\\" + info.fileName());
        } else {
            qDebug("Don't know how to launch %s", qPrintable(path));
        }
    } else {
        gApp->addRecentFile(path);
        getRuntime().setDrive(Drive::D, getSharedDrive());
        getRuntime().runOpo(path);
    // } else {
    //     qDebug("unhandled onFileOpened %s", qPrintable(path));
    }
}

QString MainWindow::getSharedDrive()
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/opolua");
    dir.mkpath("SharedDrive");
    dir.cd("SharedDrive");
    return dir.path();
}

void MainWindow::showLauncher()
{
    show();
    getRuntime().runLauncher();
}

void MainWindow::updateRecents(const QStringList& recentFiles)
{
    qDeleteAll(ui->menuOpenRecent->actions());
    if (recentFiles.isEmpty()) {
        ui->menuOpenRecent->addAction("No recent files")->setEnabled(false);
        return;
    }

    for (int i = 0; i < recentFiles.count(); i++) {
        const auto& path = recentFiles[i];
        // qDebug("recent: %s", qPrintable(path));
        QAction* action = ui->menuOpenRecent->addAction(path);
        action->setData(path);
        if (i == 0) {
#ifdef Q_OS_MAC
            action->setShortcut(QString("Ctrl+Shift+T"));
#else
            action->setShortcut(QString("Ctrl+Alt+T"));
#endif
        }
        connect(action, &QAction::triggered, this, [this, path]() { onFileOpened(path); });
    }
}
