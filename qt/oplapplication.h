// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLAPPLICATION_H
#define OPLAPPLICATION_H

#include <QApplication>
#include <QStringList>

class OplApplication : public QApplication
{
    Q_OBJECT
public:
    explicit OplApplication(int &argc, char **argv);

    void addRecentFile(const QString& path);
    const QStringList& getRecentFiles() const { return mRecentFiles; }

signals:
    void onFileOpened(const QString& path);
    void recentFilesChanged(const QStringList& files);

protected:
    bool event(QEvent *event) override;

private:
    QStringList mRecentFiles;

};

#define gApp static_cast<OplApplication*>(qApp)

#endif // OPLAPPLICATION_H
