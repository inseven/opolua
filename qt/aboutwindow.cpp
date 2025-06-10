// Copyright (c) 2025 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
