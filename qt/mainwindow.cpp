// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "mainwindow.h"

#include <QFileDialog>

#include "ui_mainwindow.h"
#include "oplapplication.h"
#include "oplruntime.h"

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
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
    connect(ui->actionSeries5, &QAction::triggered, this, [this] { setDevice(ui->actionSeries5, OplRuntime::Series5); });
    connect(ui->actionSeries7, &QAction::triggered, this, [this] { setDevice(ui->actionSeries7, OplRuntime::Series7); });
    connect(ui->actionGeofoxOne, &QAction::triggered, this, [this] { setDevice(ui->actionGeofoxOne, OplRuntime::GeofoxOne); });
    connect(runtime, &OplRuntime::startedRunning, this, &MainWindow::startedRunning);
    connect(runtime, &OplRuntime::titleChanged, this, &MainWindow::setTitle);
    connect(runtime, &OplRuntime::runComplete, this, &MainWindow::runComplete);
    connect(gApp, &OplApplication::onFileOpened, this, &MainWindow::onFileOpened);
    sizeWindowToFitInterpreter();
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
    qDebug("open %s", qPrintable(file));
    if (!file.isEmpty()) {
        auto m = this;
        if (getRuntime().running()) {
            m = new MainWindow();
            m->show();
        }
        m->getRuntime().runOpo(file);
    }
}

void MainWindow::openWelcome()
{
    auto m = this;
    if (getRuntime().running()) {
        m = new MainWindow();
        m->show();
    }
    m->getRuntime().run(QDir(":/welcome/c"), "C:\\System\\Apps\\Welcome\\Welcome.app");
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
    if (path.toLower().endsWith(".sis")) {
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

        // For now, just make a new window. Eventually, support installing into an existing runtime
        auto m = this;
        if (getRuntime().running()) {
            m = new MainWindow();
            m->show();
        }

        m->getRuntime().runInstaller(path, dest);
    } else {
        qDebug("unhandled onFileOpened %s", qPrintable(path));
    }
}