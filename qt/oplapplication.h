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
