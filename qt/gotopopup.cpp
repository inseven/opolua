// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "gotopopup.h"
#include "ui_gotopopup.h"

#include <QDebug>
#include <QKeyEvent>

GotoPopup::GotoPopup(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::GotoPopup)
{
    ui->setupUi(this);
    connect(ui->lineEdit, &QLineEdit::textEdited, this, &GotoPopup::onTextChanged);
    connect(ui->lineEdit, &QLineEdit::returnPressed, this, &GotoPopup::itemActivated);
    connect(ui->lineEdit, &UpDownLineEdit::upArrowPressed, this, &GotoPopup::upArrowPressed);
    connect(ui->lineEdit, &UpDownLineEdit::downArrowPressed, this, &GotoPopup::downArrowPressed);
    connect(ui->listWidget, &QListWidget::itemActivated, this, &GotoPopup::itemActivated);
    
    setFocusProxy(ui->lineEdit);
}

GotoPopup::~GotoPopup()
{
    delete ui;
}

void GotoPopup::setSymbols(const QStringList& symbols, int selected)
{
    m_symbols = symbols;
    onTextChanged(); // To recalculate filters
    if (selected >= 0) {
        ui->listWidget->setCurrentRow(selected);
    }
}

bool textMatches(const QString& candidate, const QString& text)
{
    // TODO match against candidate transformed into x.*y.*z
    return text.contains(candidate, Qt::CaseInsensitive);
}

void GotoPopup::onTextChanged()
{
    ui->listWidget->clear();
    auto text = ui->lineEdit->text();
    for (const auto& sym : m_symbols) {
        if (textMatches(text, sym)) {
            ui->listWidget->addItem(sym);
        }
    }
}

void GotoPopup::itemActivated()
{
    auto item = ui->listWidget->currentItem();
    if (item) {
        emit symbolSelected(item->text());
    } else {
        // if there's no matching symbol, it's likely an address
        bool isnum = false;
        auto addr = ui->lineEdit->text().toUInt(&isnum, 16);
        if (isnum) {
            emit addressEntered(addr);
        }
    }
}

void GotoPopup::upArrowPressed()
{
    int row = ui->listWidget->currentRow();
    if (row > 0) {
        ui->listWidget->setCurrentRow(row - 1);
    }
}

void GotoPopup::downArrowPressed()
{
    int row = ui->listWidget->currentRow();
    if (row + 1 < ui->listWidget->count()) {
        ui->listWidget->setCurrentRow(row + 1);
    }
}

QSize GotoPopup::sizeHint() const
{
    return QSize(600, 300);
}

void GotoPopup::keyPressEvent(QKeyEvent *event)
{
    if (event->key() == Qt::Key_Escape) {
        hide();
        return;
    }
    QWidget::keyPressEvent(event);
}
