// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "mainwindow.h"

#include <QDesktopServices>
#include <QFileDialog>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMessageBox>
#include <QMimeData>
#include <QSettings>
#include <QStandardPaths>
#include <QUrlQuery>

#ifdef Q_OS_MAC
#include <sys/xattr.h>
#include <CoreFoundation/CoreFoundation.h>
#endif

#include "ui_mainwindow.h"
#include "oplapplication.h"
#include "oplruntimegui.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
    , mCloseSent(false)
    , mForceClosing(false)
{
    ui->setupUi(this);
    setAttribute(Qt::WA_DeleteOnClose);
    setAcceptDrops(true);
    currentDevice = ui->actionSeries5;
#ifdef Q_OS_MAC
    // This should be ctrl-esc on ALL platforms
    ui->actionStop->setShortcut(QCoreApplication::translate("MainWindow", "Meta+Esc", nullptr));
    // And these don't need to be ctrl-alt (-> cmd-alt on mac)
    ui->actionNewWindow->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+N", nullptr));
    ui->actionOpen->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+O", nullptr));
    ui->actionWelcome->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+L", nullptr));
    ui->actionInstall->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+I", nullptr));
    ui->actionDebugLog->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+D", nullptr));
    ui->actionOpenSharedFolder->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+E", nullptr));
    ui->actionClose->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+W", nullptr));
    ui->actionForceClose->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+Shift+W", nullptr));
    ui->actionRestart->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+R", nullptr));
    ui->actionReportIssue->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+P", nullptr));

    ui->actionFaster->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+=", nullptr));
    ui->actionSlower->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+-", nullptr));
    ui->actionFullSpeed->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+9", nullptr));
    ui->actionDefaultSpeed->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+0", nullptr));
    ui->actionSeries5->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+5", nullptr));
    ui->actionSeries7->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+7", nullptr));
    ui->actionGeofoxOne->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+1", nullptr));
    ui->actionRevo->setShortcut(QCoreApplication::translate("MainWindow", "Ctrl+4", nullptr));
#endif

    statusLabel = new QLabel(this);
    ui->statusbar->addWidget(statusLabel);

    speedLabel = new QLabel(this);
    ui->statusbar->addPermanentWidget(speedLabel);

    auto runtime = ui->screen->getRuntime();
    runtime->setSpeed(OplRuntime::DefaultSpeed);

    connect(ui->actionAbout, &QAction::triggered, gApp, &OplApplication::showAboutWindow);
    connect(ui->actionClose, &QAction::triggered, this, &MainWindow::closeActiveWindow);
    connect(ui->actionForceClose, &QAction::triggered, this, &MainWindow::forceClose);
    connect(ui->actionSendCloseEvent, &QAction::triggered, runtime, &OplRuntime::closeEvent);
    connect(ui->actionNewWindow, &QAction::triggered, this, &MainWindow::newWindow);
    connect(ui->actionOpen, &QAction::triggered, this, &MainWindow::openDialog);
    connect(ui->actionWelcome, &QAction::triggered, this, &MainWindow::openWelcome);
    connect(ui->actionInstall, &QAction::triggered, this, &MainWindow::installSis);
    connect(ui->actionDebugLog, &QAction::triggered, gApp, &OplApplication::showLogWindow);
    connect(ui->actionOpenSharedFolder, &QAction::triggered, this, &MainWindow::openSharedFolder);
    connect(ui->actionStop, &QAction::triggered, runtime, &OplRuntime::interrupt);
    connect(ui->actionRestart, &QAction::triggered, runtime, &OplRuntime::restart);
    connect(ui->actionMenu, &QAction::triggered, runtime, &OplRuntime::pressMenuKey);
    connect(ui->actionSeries5, &QAction::triggered, this, [this] { setDevice(ui->actionSeries5, OplRuntime::Series5); });
    connect(ui->actionSeries7, &QAction::triggered, this, [this] { setDevice(ui->actionSeries7, OplRuntime::Series7); });
    connect(ui->actionGeofoxOne, &QAction::triggered, this, [this] { setDevice(ui->actionGeofoxOne, OplRuntime::GeofoxOne); });
    connect(ui->actionRevo, &QAction::triggered, this, [this] { setDevice(ui->actionRevo, OplRuntime::Revo); });
    connect(ui->actionFaster, &QAction::triggered, runtime, &OplRuntime::runFaster);
    connect(ui->actionSlower, &QAction::triggered, runtime, &OplRuntime::runSlower);
    connect(ui->actionDefaultSpeed, &QAction::triggered, this, [this] { getRuntime().setSpeed(OplRuntime::DefaultSpeed); });
    connect(ui->actionFullSpeed, &QAction::triggered, this, [this] { getRuntime().setSpeed(OplRuntime::Fastest); });
    connect(ui->actionReportIssue, &QAction::triggered, this, &MainWindow::reportIssue);
    connect(runtime, &OplRuntime::debugLog, gApp, &OplApplication::appendLogging);
    connect(runtime, &OplRuntimeGui::startedRunningApp, this, &MainWindow::startedRunning);
    connect(runtime, &OplRuntime::titleChanged, this, &MainWindow::setTitle);
    connect(runtime, &OplRuntime::runComplete, this, &MainWindow::runComplete);
    connect(runtime, &OplRuntime::installationComplete, this, &MainWindow::installationComplete);
    // connect(runtime, &OplRuntime::escapeStateChanged, ui->actionRestart, &QAction::setEnabled);
    // connect(runtime, &OplRuntime::escapeStateChanged, ui->actionSeries5, &QAction::setEnabled);
    // connect(runtime, &OplRuntime::escapeStateChanged, ui->actionSeries7, &QAction::setEnabled);
    // connect(runtime, &OplRuntime::escapeStateChanged, ui->actionGeofoxOne, &QAction::setEnabled);
    connect(runtime, &OplRuntime::speedChanged, this, &MainWindow::onSpeedChanged);
    connect(gApp, &OplApplication::recentFilesChanged, this, &MainWindow::updateRecents);
    sizeWindowToFitInterpreter();
    updateRecents(gApp->getRecentFiles());
    onSpeedChanged();
    gApp->updateWindowMenu(this, ui->menuWindow);
}

MainWindow::~MainWindow()
{
    delete ui;
}

OplRuntimeGui& MainWindow::getRuntime()
{
    return *ui->screen->getRuntime();
}

void MainWindow::closeActiveWindow()
{
    // Don't just call this->close() because there might be about windows etc without menubars
    auto w = qApp->activeWindow();
    if (w) {
        w->close();
    }
}

void MainWindow::closeEvent(QCloseEvent *event)
{
    if (mForceClosing || !getRuntime().running()) {
        event->accept();
    } else if (mCloseSent) {
        auto ret = QMessageBox::question(this,
            "App not responding",
            "The app has not responded to the close event. Forcibly close the app?");
        if (ret == QMessageBox::Yes) {
            event->accept();
        } else {
            event->ignore();
            ui->statusbar->clearMessage();
            mCloseSent = false;
        }
    } else {
        event->ignore();
        getRuntime().closeEvent();
        mCloseSent = true;
        ui->statusbar->showMessage("Closing...");
    }
}

void MainWindow::forceClose()
{
    mForceClosing = true;
    close();
}

void MainWindow::startedRunning(const OplAppInfo& info)
{
    statusLabel->setText("Running");
    mErrMsg = QString();
    mErrDetail = QString();
    // Don't try to put path in the title bar for things running from resources
    auto path = getRuntime().getNativePath(info.deviceAppPath);
    if (path.startsWith(":")) {
        setWindowFilePath(QString());
    } else {
        setWindowFilePath(path);
    }
    setTitle(info.appName);
    if (!info.icon.isNull()) {
        setWindowIcon(info.icon);
    }
    if (!path.isEmpty()) {
        gApp->addRecentFile(path);
    }
    mAppInfo.reset(new OplAppInfo(info));
}

void MainWindow::setTitle(const QString& title)
{
    setWindowTitle(title + " - OpoLua");
}

void MainWindow::sizeWindowToFitInterpreter()
{
    // There is definitely a better way to do this...
    QSize sz = ui->screen->sizeHint();
    if (!sz.isEmpty()) {
        QSize windowSz(sz.width(), sz.height() + ui->statusbar->sizeHint().height());
        if (!ui->menubar->isNativeMenuBar()) {
            windowSz.setHeight(windowSz.height() + ui->menubar->height());
        }
        resize(windowSz);
    }
}

void MainWindow::runComplete(const QString& errMsg, const QString& errDetail)
{
    if (errMsg.isEmpty()) {
        statusLabel->setText("Completed");
        if (mCloseSent) {
            close();
        }
    } else {
        statusLabel->setText(errMsg);
    }
    mErrMsg = errMsg;
    mErrDetail = errDetail;
    mCloseSent = false;
    mForceClosing = false;
}

void MainWindow::openDialog()
{
    QString file = QFileDialog::getOpenFileName(this, tr("Select OPL app"), QString(), tr("OPL Apps (*.opo *.app *.oplsys)"));
    // qDebug("open %s", qPrintable(file));

    if (file.isEmpty()) {
        return;
    }

    // qDebug("open %s sys=%s", qPrintable(file), qPrintable(driveForApp(file)));
    openFile(file);
}

QString MainWindow::driveForApp(const QString& appPath)
{
    QFileInfo info(appPath);
    // Figure out what we've got
    QString extension = info.suffix().toLower();
    if (extension == "app") {
        QDir dir(QFileInfo(appPath).absoluteDir());
        dir.cdUp();
        if (dir.dirName().toLower() == "apps") {
            dir.cdUp();
            if (dir.dirName().toLower() == "system") {
                dir.cdUp();
                return dir.absolutePath();
            }
        }
    } else if (extension == "oplsys") {
        if (info.isDir()) {
            // The oplsys bundle itself
            return info.filePath() + "/c";
        } else {
            // ie launch.oplsys
            return info.path() + "/c";
        }
    }


    return QString();
}

QString MainWindow::manifestForDrive(const QString& drivePath)
{
    QDir dir(QFileInfo(drivePath).dir());
    if (dir.path().endsWith(".oplsys")) {
        return QFileInfo(dir, "launch.oplsys").filePath();
    } else {
        return QString();
    }
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

    if (!mManifest.isEmpty() && getRuntime().writableCDrive()) {
        updateManifest();
    }
}

void MainWindow::installSis()
{
    QString file = QFileDialog::getOpenFileName(this, tr("Select SIS file"), QString(), tr("SIS files (*.sis)"));
    qDebug("open %s", qPrintable(file));
    if (file.isEmpty()) {
        return;
    }
    doInstallSis(file);
}

void MainWindow::doInstallSis(const QString& file)
{
    if (getRuntime().running() && getRuntime().writableCDrive()) {
        QString uiPath = QFileInfo(getRuntime().getNativePath("C:\\")).dir().path();
        auto m = new MainWindow();
        m->getRuntime().setDeviceType(getRuntime().getDeviceType());
        m->show();
        m->getRuntime().setDrive(Drive::C, getRuntime().getNativePath("C:\\"));
        m->getRuntime().setDrive(Drive::D, getSharedDrive());
        m->getRuntime().runInstaller(file, uiPath);
    } else {
        openFile(file);
    }
}

void MainWindow::openFile(const QString& path)
{
    if (getRuntime().runningLauncherCommand() == "launcher") {
        getRuntime().interruptAndRun([this, path]() {
            openFile(path);
        });
        return;
    } else if (getRuntime().running()) {
        MainWindow* m = new MainWindow();
        m->show();
        m->openFile(path);
        return;
    }
    mManifest = QString();

    QFileInfo info(path);
    QString extension = info.suffix().toLower();

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
            dest = dest + ".oplsys";
            i++;
        } while (QFileInfo(dest).exists());

        getRuntime().setDrive(Drive::C, dest + "/c");
        getRuntime().setDrive(Drive::D, getSharedDrive());
        getRuntime().runInstaller(path, dest);
    } else if (extension == "app" || extension == "oplsys") {
        QString drive = driveForApp(path);
        if (!drive.isEmpty()) {
            mManifest = manifestForDrive(drive);
            if (!mManifest.isEmpty()) {
                applyManifest();
            }

            getRuntime().setDrive(Drive::C, drive);
            getRuntime().setDrive(Drive::D, getSharedDrive());

            QString appPath;
            if (extension == "app") {
                appPath = QString("C:\\System\\Apps\\") + info.dir().dirName() + "\\" + info.fileName();
            } else {
                auto apps = getRuntime().getCDriveApps();
                if (apps.count() == 1) {
                    appPath = apps[0].deviceAppPath;
                }
            }
            if (!appPath.isEmpty()) {
                getRuntime().run(appPath);
            } else {
                getRuntime().runAppSelector();
            }
        } else {
            qDebug("Don't know how to launch %s", qPrintable(path));
        }
    } else {
        getRuntime().setDrive(Drive::D, getSharedDrive());
        getRuntime().runOpo(path);
    // } else {
    //     qDebug("unhandled openFile %s", qPrintable(path));
    }
}

void MainWindow::installationComplete(const QString& sisPath)
{
    auto path = getRuntime().getNativePath("C:\\");
    Q_ASSERT(!path.isEmpty());
    mManifest = manifestForDrive(path);
    QString source(getSourceUrlForPath(sisPath));
    updateManifest(source);
}

void MainWindow::updateManifest(const QString& sourceUrl)
{
    Q_ASSERT(!mManifest.isEmpty());
    QJsonObject obj;
    QFile f(mManifest);
    if (f.open(QFile::ReadOnly)) {
        obj = QJsonDocument::fromJson(f.readAll()).object();
        f.close();
    }

    auto deviceType = getRuntime().getDeviceType();
    QString typeStr = OplRuntime::deviceTypeToString(deviceType);
    obj.insert("device", typeStr);
    if (!sourceUrl.isEmpty()) {
        obj.insert("sourceUrl", sourceUrl);
    }

    if (f.open(QFile::ReadWrite | QFile::Truncate)) {
        f.write(QJsonDocument(obj).toJson());
        f.close();
    } else {
        qDebug("Failed to open %s", qPrintable(mManifest));
    }
}

void MainWindow::applyManifest()
{
    QFile f(mManifest);
    if (!f.open(QFile::ReadOnly)) {
        qWarning("Failed to open manifest %s", qPrintable(mManifest));
        mSourceUrl = QString();
        return;
    }
    auto manifest = QJsonDocument::fromJson(f.readAll());
    QString device = manifest["device"].toString();

    if (device == "psion-series-3c") {
        getRuntime().setDeviceType(OplRuntime::Series3c);
    } else if (device == "psion-series-5") {
        getRuntime().setDeviceType(OplRuntime::Series5);
    } else if (device == "psion-revo") {
        getRuntime().setDeviceType(OplRuntime::Revo);
    } else if (device == "psion-series-7") {
        getRuntime().setDeviceType(OplRuntime::Series7);
    } else if (device == "geofox-one") {
        getRuntime().setDeviceType(OplRuntime::GeofoxOne);
    } else {
        qWarning("Unknown device type in manifest: %s", qPrintable(device));
    }

    mSourceUrl = manifest["sourceUrl"].toString();
    qDebug("sourceUrl = %s", qPrintable(mSourceUrl));

    sizeWindowToFitInterpreter();
}

QString MainWindow::getSharedDrive()
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/opolua");
    dir.mkpath("SharedDrive");
    dir.cd("SharedDrive");
    return dir.path();
}

void MainWindow::newWindow()
{
    auto m = new MainWindow();
    m->showLauncher();
}

void MainWindow::showLauncher()
{
    show();
    getRuntime().runLauncher();
}

void MainWindow::openSharedFolder()
{
    auto path = getSharedDrive();
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
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
        connect(action, &QAction::triggered, this, [this, path]() { openFile(path); });
    }
}

void MainWindow::dragEnterEvent(QDragEnterEvent *event)
{
    if (event->mimeData()->hasUrls()) {
        auto urls = event->mimeData()->urls();
        if (urls.count() == 1 && urls[0].isLocalFile() && urls[0].fileName().toLower().endsWith(".sis")) {
            event->acceptProposedAction();
        }
    }
}

void MainWindow::dropEvent(QDropEvent *event)
{
    Q_ASSERT(event->mimeData()->hasUrls());
    event->acceptProposedAction();
    auto path = event->mimeData()->urls()[0].toLocalFile();
    doInstallSis(path);
}

constexpr char const* kSpeedNames[] = {
    "Slowest (1)",
    "Slower (2)",
    "Slow (3)",
    "Tardy (4)",
    "Default (5)",
    "Snappy (6)",
    "Fast (7)",
    "Faster (8)",
    "Fastest (9)",
};

void MainWindow::onSpeedChanged()
{
    auto speed = getRuntime().getSpeed();
    ui->actionSpeed->setText(QString("Speed: %1").arg(kSpeedNames[(int)speed - 1]));
    speedLabel->setText(QString("Speed: %1").arg((int)speed));
}

QString MainWindow::getSourceUrlForPath(const QString& path)
{
    QString result;
#if defined(Q_OS_MAC)
    auto p = QDir::toNativeSeparators(path);
    auto buf = CFDataCreateMutable(NULL, 0);
    CFDataSetLength(buf, 2048);
    auto ret = getxattr(p.toUtf8().data(), "com.apple.metadata:kMDItemWhereFroms",
        CFDataGetMutableBytePtr(buf), CFDataGetLength(buf), 0, 0);
    if (ret > 0) {
        CFDataSetLength(buf, ret);
        auto props = CFPropertyListCreateWithData(NULL, buf, kCFPropertyListImmutable, NULL, NULL);
        if (props && CFGetTypeID(props) == CFArrayGetTypeID()) {
            auto arr = (CFArrayRef)props;
            if (CFArrayGetCount(arr) > 0) {
                auto val = CFArrayGetValueAtIndex(arr, 0);
                if (CFGetTypeID(val) == CFStringGetTypeID()) {
                    result = QString::fromCFString((CFStringRef)val);
                }
            }
        }   

        CFRelease(props);
    }
    CFRelease(buf);
#elif defined(Q_OS_WIN)
    QSettings info(path + ":Zone.Identifier", QSettings::IniFormat);
    result = info.value("ZoneTransfer/HostUrl").toString();
#else
    // I don't think there's any (standard) way this is done on Linux?
    Q_UNUSED(path);
#endif
    return result;
}

void MainWindow::reportIssue()
{
    QUrl githubUrl("https://github.com/inseven/opolua/issues/new", QUrl::StrictMode);
    QString title;
    if (mAppInfo && !mAppInfo->appName.isEmpty()) {
        title = QString("[%1]").arg(mAppInfo->appName);
    }
    if (!mErrMsg.isEmpty()) {
        if (!title.isEmpty()) {
            title = title + " ";
        }
        title += mErrMsg;
    }
    auto description = QString(R"(## Description

_Please provide details of the program you were running, and what you were doing when you encountered the error._

## Metadata

| Key | Value |
| --- | --- |
| **App name** | %1 |
| **UID** | %2 |
| **Source URL** | %3 |
)");
    description = description
        .arg((mAppInfo && !mAppInfo->appName.isEmpty()) ? mAppInfo->appName : QString("*unknown*"))
        .arg((mAppInfo && mAppInfo->uid != 0) ? QString("0x%1").arg(mAppInfo->uid, 0, 16) : "*unknown*")
        .arg(mSourceUrl.isEmpty() ? "*unknown*" : mSourceUrl);

    if (!mErrDetail.isEmpty()) {
        description = QString("%1\n\n## Details\n\n```\n%2\n```").arg(description, mErrDetail);
    }

    qDebug("Submitting report description: %s", qPrintable(description));
    QUrlQuery query;
    query.addQueryItem("title", QUrl::toPercentEncoding(title));
    query.addQueryItem("body", QUrl::toPercentEncoding(description));
    githubUrl.setQuery(query);
    QDesktopServices::openUrl(githubUrl);
}