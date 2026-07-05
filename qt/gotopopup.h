// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef GOTOPOPUP_H
#define GOTOPOPUP_H

#include <QWidget>

namespace Ui {
class GotoPopup;
}

class GotoPopup : public QWidget
{
    Q_OBJECT

public:
    explicit GotoPopup(QWidget *parent = nullptr);
    ~GotoPopup();

    void setSymbols(const QStringList& symbols, int selected = -1);

    QSize sizeHint() const override;

signals:
    void symbolSelected(const QString& symbol);
    void addressEntered(uint32_t address);

protected:
    void keyPressEvent(QKeyEvent *event) override;

private slots:
    void onTextChanged();
    void itemActivated();
    void upArrowPressed();
    void downArrowPressed();

private:
    Ui::GotoPopup *ui;
    QStringList m_symbols;
};

#endif // GOTOPOPUP_H
