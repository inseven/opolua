// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplapplication.h"
#include <QFileOpenEvent>
#include <QUrl>

OplApplication::OplApplication(int &argc, char **argv)
    : QApplication(argc, argv)
{}

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
