// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef SWIWIZARDINFOPAGE_H
#define SWIWIZARDINFOPAGE_H

#include "choosywizardpage.h"

#include <QMap>
#include <QTreeWidgetItem>

struct SwiProgramVariant;

namespace Ui {
class SwiWizardInfoPage;
}

class SwiWizardInfoPage : public ChoosyWizardPage
{
    Q_OBJECT

public:
    explicit SwiWizardInfoPage(QWidget *parent = nullptr);
    ~SwiWizardInfoPage();

protected:
    bool isComplete() const override;
    void initializePage() override;

private slots:
    void selectionChanged();
    void iconUpdated(const SwiProgramVariant* variant, const QIcon& icon);

private:
    Ui::SwiWizardInfoPage *ui;
    QMap<const SwiProgramVariant*, QTreeWidgetItem*> mItems;
};

#endif // SWIWIZARDINFOPAGE_H
