// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLAPPLICATION_H
#define OPLAPPLICATION_H

#include <QApplication>
class QMenu;
class QMainWindow;
#include <QStringList>
class QWidget;
#include <QVector>

class LogWindow;
class MainWindow;

#include <functional>

class OplApplication : public QApplication
{
    Q_OBJECT
public:
    explicit OplApplication(int &argc, char **argv);

    void addRecentFile(const QString& path);
    const QStringList& getRecentFiles() const { return mRecentFiles; }
    QVector<MainWindow*> getMainWindows();
    void updateWindowMenu(QMainWindow* window, QMenu* menu);

signals:
    void recentFilesChanged(const QStringList& files);
    void internalDoAppendLogging(const QString& str);

public slots:
    void showAboutWindow();
    void updateWindowMenus();
    void showLogWindow();
    void appendLogging(const QString& str);

public:
    static int registerApp();
    static void unregisterApp();

protected:
    bool event(QEvent *event) override;

private:
    void foreach_window_menu(std::function<void(QMainWindow*, QMenu*)> fn);

private:
    QStringList mRecentFiles;
    LogWindow* mLogWindow;
};

#define gApp static_cast<OplApplication*>(qApp)

#endif // OPLAPPLICATION_H
