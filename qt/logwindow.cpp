// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "oplapplication.h"
#include "logwindow.h"
#include "ui_logwindow.h"

LogWindow::LogWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::LogWindow)
{
    ui->setupUi(this);
    // I wonder if Qt Creator 6 lets you specify multiple fonts in the UI...
    QFont font;
    font.setFamilies({"Monaco", "Consolas", "Noto Sans Mono"});
    font.setPointSize(10);
    ui->centralwidget->setFont(font);
    connect(ui->actionClose, &QAction::triggered, this, &QWidget::close);
    connect(ui->actionAbout, &QAction::triggered, gApp, &OplApplication::showAboutWindow);
}

LogWindow::~LogWindow()
{
    delete ui;
}

void LogWindow::append(const QString& str)
{
    ui->centralwidget->appendPlainText(str);
}
