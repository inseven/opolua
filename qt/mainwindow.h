/*
 * Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QAction>
#include <QLabel>
#include <QMainWindow>
#include <QPointer>
#include <QScopedPointer>
#include <QStringList>

namespace Ui {
class MainWindow;
}

class DebuggerWindow;
class OplRuntimeGui;
struct OplAppInfo;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

    OplRuntimeGui& getRuntime();
    void showLauncher();

    void setScale(int scale);

protected:
    void closeEvent(QCloseEvent *event) override;
    void dragEnterEvent(QDragEnterEvent *event) override;
    void dropEvent(QDropEvent *event) override;

public slots:
    void newWindow();
    void openDialog();
    void openSharedFolder();
    void openWelcome();
    void setTitle(const QString& title);
    void installSis();
    void openFile(const QString& path);
    void showDebugger();

private slots:
    void forceClose();
    void startedRunning(const OplAppInfo& info);
    void pauseStateChanged(bool paused);

    void runComplete(const QString& errMsg, const QString& errDetail);
    void installationComplete(const QString& sisPath);
    void updateRecents(const QStringList& recentFiles);
    void onSpeedChanged();
    void onDeviceTypeChanged();
    void reportIssue();
    void openSoftwareIndex();

private:
    void setDevice(int device);
    void doSetScale(int scale);
    void sizeWindowToFitInterpreter();
    QString getSourceUrlForPath(const QString& path);
    void applyManifest();
    void updateManifest(const QString& sourceUrl = QString());
    void doInstallSis(const QString& file);

private:
    static QString driveForApp(const QString& appPath);
    static QString manifestForDrive(const QString& drivePath);
    static QString getSharedDrive();

private:
    Ui::MainWindow *ui;
    bool mCloseSent;
    bool mForceClosing;
    QLabel* statusLabel;
    QLabel* speedLabel;
    QString mManifest;
    QScopedPointer<OplAppInfo> mAppInfo;
    QString mErrMsg;
    QString mErrDetail;
    QString mSourceUrl;
    QPointer<DebuggerWindow> mDebugWindow;
};

#endif // MAINWINDOW_H
