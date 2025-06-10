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

public slots:
    void showAboutWindow();
    void updateWindowMenus();

protected:
    bool event(QEvent *event) override;

private:
    void foreach_window_menu(std::function<void(QMainWindow*, QMenu*)> fn);

private:
    QStringList mRecentFiles;

};

#define gApp static_cast<OplApplication*>(qApp)

#endif // OPLAPPLICATION_H
