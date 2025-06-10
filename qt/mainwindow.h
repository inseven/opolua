// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QAction>
#include <QLabel>
#include <QMainWindow>
#include <QStringList>

namespace Ui {
class MainWindow;
}

class OplRuntime;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

    OplRuntime& getRuntime();

public slots:
    void openDialog();
    void openWelcome();
    void setTitle(const QString& title);
    void installSis();
    void onFileOpened(const QString& path);
    void showLauncher();

private slots:
    void startedRunning(const QString& path);
    void runComplete(const QString& errMsg, const QString& errDetail);
    void updateRecents(const QStringList& recentFiles);

private:
    void setDevice(QAction* action, int device);
    void sizeWindowToFitInterpreter();

private:
    static QString driveForApp(const QString& appPath);
    static QString getSharedDrive();

private:
    Ui::MainWindow *ui;
    QLabel* statusLabel;
    QAction* currentDevice;
};

#endif // MAINWINDOW_H
