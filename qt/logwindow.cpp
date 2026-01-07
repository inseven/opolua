/*
 * Copyright (C) 2025-2026 Jason Morley, Tom Sutcliffe
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
