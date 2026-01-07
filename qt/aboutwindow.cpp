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

#include "aboutwindow.h"
#include "ui_aboutwindow.h"

#include <QDesktopServices>
#include <QUrl>

#define STR(x) #x
#define QUOTE(x) STR(x)

AboutWindow::AboutWindow(QWidget *parent)
    : QDialog(parent)
    , ui(new Ui::AboutWindow)
{
    ui->setupUi(this);
    ui->versionLabel->setText("OpoLua v" QUOTE(OPOLUA_VERSION));
    connect(ui->aboutQtButton, &QPushButton::clicked, qApp, &QApplication::aboutQt);
    connect(ui->websiteButton, &QPushButton::clicked, this, [] {
        QDesktopServices::openUrl(QUrl("https://opolua.org"));
    });
    connect(ui->emailButton, &QPushButton::clicked, this, [] {
        QDesktopServices::openUrl(QUrl("mailto:support@opolua.org"));
    });
}

AboutWindow::~AboutWindow()
{
    delete ui;
}
