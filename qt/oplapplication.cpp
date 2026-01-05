// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplapplication.h"
#include "oplruntimegui.h"
#include "aboutwindow.h"
#include "logwindow.h"
#include "mainwindow.h"

#include <QAction>
#include <QActionGroup>
#include <QFileOpenEvent>
#include <QMainWindow>
#include <QMenuBar>
#include <QSettings>
#include <QUrl>

static QtMessageHandler g_default_msg_handler = nullptr;

void DebugHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    gApp->appendLogging(msg);
    if (g_default_msg_handler) {
        g_default_msg_handler(type, context, msg);
    }
}

OplApplication::OplApplication(int &argc, char **argv)
    : QApplication(argc, argv)
{
    QCoreApplication::setOrganizationName("opolua");
    QCoreApplication::setOrganizationDomain("opolua.org");
    QCoreApplication::setApplicationName("opolua-qt");
    QSettings settings;
    mRecentFiles = settings.value("recentFiles").toStringList();
    connect(this, &QApplication::focusChanged, this, &OplApplication::updateWindowMenus);
    mLogWindow = new LogWindow();
    connect(this, &OplApplication::internalDoAppendLogging, mLogWindow, &LogWindow::append);
    g_default_msg_handler = qInstallMessageHandler(&DebugHandler);

    registerApp();
}

bool OplApplication::event(QEvent *event)
{
    if (event->type() == QEvent::FileOpen) {
        QFileOpenEvent *openEvent = static_cast<QFileOpenEvent *>(event);
        const QUrl url = openEvent->url();
        if (url.isLocalFile()) {
            // qDebug("onFileOpened %s", qPrintable(url.toLocalFile()));
            auto windows = getMainWindows();
            auto w = new MainWindow;
            w->show();
            w->openFile(url.toLocalFile());

            if (windows.count() == 1 && windows[0]->getRuntime().runningLauncherCommand() == "launcher") {
                // There will be one launcher window immediately after the app is launched, which we don't need
                windows[0]->close();
            }

            return true;
        }
    }
    return QApplication::event(event);
}

void OplApplication::addRecentFile(const QString& path)
{
    mRecentFiles.insert(0, path);
    mRecentFiles.removeDuplicates();
    while (mRecentFiles.count() > 10) {
        mRecentFiles.removeLast();
    }
    QSettings settings;
    settings.setValue("recentFiles", mRecentFiles);

    emit recentFilesChanged(mRecentFiles);
}

void OplApplication::showAboutWindow()
{
    auto w = new AboutWindow(nullptr);
    w->show();
}

QVector<MainWindow*> OplApplication::getMainWindows()
{
    QVector<MainWindow*> result;
    for (auto w : topLevelWidgets()) {
        auto mainWindow = qobject_cast<MainWindow*>(w);
        if (mainWindow) {
            result.append(mainWindow);
        }
    }
    return result;
}

void OplApplication::foreach_window_menu(std::function<void(QMainWindow*, QMenu*)> fn)
{
    for (auto w : topLevelWidgets()) {
        auto mainWindow = qobject_cast<QMainWindow*>(w);
        if (!mainWindow) continue;
        auto menuBar = mainWindow->menuBar();
        if (!menuBar) continue;
        auto windowMenu = menuBar->findChild<QMenu*>("menuWindow", Qt::FindDirectChildrenOnly);
        if (!windowMenu) continue;
        fn(mainWindow, windowMenu);
    }
}

void OplApplication::updateWindowMenu(QMainWindow* menuWindow, QMenu* menu)
{
    auto focussed = activeWindow();
    auto windows = topLevelWidgets();
    auto actionGroup = menuWindow->findChild<QActionGroup*>("windowActionGroup");
    if (!actionGroup) {
        actionGroup = new QActionGroup(menuWindow);
        actionGroup->setObjectName("windowActionGroup");
    }
    // Dumbest impl: just remove everything and re-add
    for (auto action : actionGroup->actions()) {
        menu->removeAction(action);
        actionGroup->removeAction(action);
        delete action;
    }
    for (QWidget* window : windows) {
        if (!window->isVisible() || !window->isWindow()) {
            continue;
        }
        auto action = new QAction(actionGroup);
        action->setMenuRole(QAction::NoRole); // Otherwise the item for the "About OpoLua" window will be moved!
        // qDebug("Adding action for %s to %s", qPrintable(window->windowTitle()), qPrintable(window->windowTitle()));
        action->setText(window->windowTitle());
        action->setCheckable(true);
        action->setChecked(window == focussed);
        menu->addAction(action);
        connect(window, &QWidget::windowTitleChanged, action, [action](const QString& newTitle) {
           action->setText(newTitle);
        });
        connect(action, &QAction::triggered, window, [window]() {
            window->raise();
            window->activateWindow();
        });
        connect(window, &QObject::destroyed, action, [menu, actionGroup, action]() {
            menu->removeAction(action);
            actionGroup->removeAction(action);
            delete action;
        });
    }
}

void OplApplication::updateWindowMenus()
{
    // qDebug("updateWindowMenus");
    foreach_window_menu([this](QMainWindow* menuWindow, QMenu* menu) {
        updateWindowMenu(menuWindow, menu);
    });
}

void OplApplication::appendLogging(const QString& str)
{
    // Do this via a signal so that this fn is safe to call from any thread
    emit internalDoAppendLogging(str);
    // mLogWindow->append(str);
}

void OplApplication::showLogWindow()
{
    mLogWindow->show();
    mLogWindow->raise();
}

int OplApplication::registerApp()
{
#ifdef Q_OS_WIN
    QSettings hkcu("HKEY_CURRENT_USER", QSettings::NativeFormat);
    QString applicationKey = "SOFTWARE/Classes/Applications/opolua.exe";
    QString applicationSupportedTypes = applicationKey + "/SupportedTypes";
    QString shellKey = applicationKey + "/shell/open/command/.";

    hkcu.setValue(applicationSupportedTypes + "/.sis", "");
    hkcu.setValue(applicationSupportedTypes + "/.oplsys", "");
    hkcu.setValue(applicationSupportedTypes + "/.opa", "");
    hkcu.setValue(shellKey, QString("\"%1\" open \"%2\"").arg(QDir::toNativeSeparators(QCoreApplication::applicationFilePath()), "%1"));

    QString dotSisRegistration = "SOFTWARE/Classes/.sis/OpenWithList/opolua.exe/.";
    hkcu.setValue(dotSisRegistration, "");

    QString dotOplsysRegistration = "SOFTWARE/Classes/.oplsys/OpenWithList/opolua.exe/.";
    hkcu.setValue(dotOplsysRegistration, "");
#endif
    return 0;
}

void OplApplication::unregisterApp()
{
#ifdef Q_OS_WIN
    QSettings hkcu("HKEY_CURRENT_USER", QSettings::NativeFormat);
    hkcu.remove("SOFTWARE/Classes/Applications/opolua.exe");
    hkcu.remove("SOFTWARE/Classes/.sis/OpenWithList/opolua.exe");
    hkcu.remove("SOFTWARE/Classes/.oplsys/OpenWithList/opolua.exe");
#endif
}
