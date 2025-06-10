// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplapplication.h"
#include <QFileOpenEvent>
#include <QSettings>
#include <QUrl>

OplApplication::OplApplication(int &argc, char **argv)
    : QApplication(argc, argv)
{
    QCoreApplication::setOrganizationName("opolua");
    QCoreApplication::setOrganizationDomain("opolua.org");
    QCoreApplication::setApplicationName("opolua-qt");
    QSettings settings;
    mRecentFiles = settings.value("recentFiles").toStringList();
}

bool OplApplication::event(QEvent *event)
{
    if (event->type() == QEvent::FileOpen) {
        QFileOpenEvent *openEvent = static_cast<QFileOpenEvent *>(event);
        const QUrl url = openEvent->url();
        if (url.isLocalFile()) {
            // Don't know why they don't just define this in QApplication...
            qDebug("onFileOpened %s", qPrintable(url.toLocalFile()));
            emit onFileOpened(url.toLocalFile());
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
