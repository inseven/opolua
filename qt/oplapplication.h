// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLAPPLICATION_H
#define OPLAPPLICATION_H

#include <QApplication>

class OplApplication : public QApplication
{
    Q_OBJECT
public:
    explicit OplApplication(int &argc, char **argv);

signals:
    void onFileOpened(const QString& path);

protected:
    bool event(QEvent *event) override;
};

#define gApp static_cast<OplApplication*>(qApp)

#endif // OPLAPPLICATION_H
