// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QAction>
#include <QLabel>
#include <QMainWindow>
#include <QScopedPointer>
#include <QStringList>

namespace Ui {
class MainWindow;
}

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

private slots:
    void closeActiveWindow();
    void forceClose();
    void startedRunning(const OplAppInfo& info);
    void runComplete(const QString& errMsg, const QString& errDetail);
    void installationComplete(const QString& sisPath);
    void updateRecents(const QStringList& recentFiles);
    void onSpeedChanged();
    void onDeviceTypeChanged();
    void reportIssue();
    void openSoftwareIndex();

private:
    void setDevice(QAction* action, int device);
    void setScale(int scale);
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
    QAction* currentDevice;
    QString mManifest;
    QScopedPointer<OplAppInfo> mAppInfo;
    QString mErrMsg;
    QString mErrDetail;
    QString mSourceUrl;
};

#endif // MAINWINDOW_H
