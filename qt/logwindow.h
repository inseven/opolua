// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef LOGWINDOW_H
#define LOGWINDOW_H

#include <QMainWindow>

namespace Ui {
class LogWindow;
}

class LogWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit LogWindow(QWidget *parent = nullptr);
    ~LogWindow();

public slots:
    void append(const QString& str);

private:
    Ui::LogWindow *ui;
};

#endif // LOGWINDOW_H
