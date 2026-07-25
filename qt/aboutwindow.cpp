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

#include <QDateTime>
#include <QDesktopServices>
#include <QTimeZone>
#include <QUrl>

#define STR(x) #x
#define QUOTE(x) STR(x)

AboutWindow::AboutWindow(QWidget *parent)
    : QDialog(parent)
    , ui(new Ui::AboutWindow)
{
    ui->setupUi(this);
    setAttribute(Qt::WA_DeleteOnClose);

    // OPOLUA_BUILD_NUM is an 18 char string yyMMddhhmmss12345678 being a 10-digit datetime and the last 8
    // digits are the decimal representation of the 6-hex-digit commit SHA
    auto build = QString::fromLatin1(QUOTE(OPOLUA_BUILD_NUM));
    auto url = QString::fromLatin1("-");
    auto formattedDate = QString::fromLatin1("-");
    if (build.length() == 18) {
        auto datestr = build.left(10);
        auto sha = build.right(8);
#if QT_VERSION >= QT_VERSION_CHECK(6, 7, 0)
        auto date = QDateTime::fromString(datestr, "yyMMddHHmm", 2000);
#else
        auto date = QDateTime::fromString(datestr, "yyMMddHHmm");
        date = date.addYears(100);
#endif
        date.setTimeZone(QTimeZone::utc());
        formattedDate = date.toString();

        url = QString("<a href=\"https://github.com/inseven/opolua/commit/%1\">%1</a>")
            .arg(sha.toInt(), 6, 16, QLatin1Char('0'));
    }

    ui->text->setText(ui->text->text()
        .arg(QUOTE(OPOLUA_VERSION))
        .arg(build)
        .arg(formattedDate)
        .arg(url)
    );

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
