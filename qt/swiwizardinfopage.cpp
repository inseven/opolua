// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "softwareindexwizard.h"
#include "swiwizardinfopage.h"
#include "ui_swiwizardinfopage.h"
#include "validators.h"

#define wiz static_cast<SoftwareIndexWizard*>(wizard())

SwiWizardInfoPage::SwiWizardInfoPage(QWidget *parent)
    : ChoosyWizardPage(parent)
    , ui(new Ui::SwiWizardInfoPage)
{
    ui->setupUi(this);
    auto hintFunc = [this]() {
        return wiz->selectedProgram()->name() + ".oplsys";
    };
    associateChooseButton(ui->installPath, ui->selectInstallPathButton, OplSys, hintFunc);
    connect(ui->installPath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    connect(ui->variants, &QTreeWidget::itemSelectionChanged, this, &SwiWizardInfoPage::selectionChanged);

    registerField("installPath", ui->installPath);
    setButtonText(QWizard::FinishButton, "Install");
}

SwiWizardInfoPage::~SwiWizardInfoPage()
{
    delete ui;
}

void SwiWizardInfoPage::initializePage()
{
    const auto* program = wiz->selectedProgram();

    setTitle(program->name());
    setSubTitle("Select a version to install:");

    ui->variants->clear();
    for (int i = 0, n = program->variants().count(); i < n; i++) {
        const auto& variant =  program->variants()[i];
        auto item = new QTreeWidgetItem(ui->variants, {
            variant.name,
            variant.version,
            QString("%1").arg(variant.size),
            variant.filename,
        });
        item->setIcon(0, wiz->getIcon(variant));
        item->setData(0, Qt::UserRole, i);
    }
    ui->variants->resizeColumnToContents(0);
}

bool SwiWizardInfoPage::isComplete() const
{
    return ChoosyWizardPage::isComplete() && ui->variants->selectedItems().count() == 1 && ui->installPath->hasAcceptableInput();
}

void SwiWizardInfoPage::selectionChanged()
{
    const SwiProgramVariant* variant = nullptr;
    auto items = ui->variants->selectedItems();
    if (items.count() == 1) {
        int idx = items[0]->data(0, Qt::UserRole).toInt();
        variant = &wiz->selectedProgram()->variants()[idx];
    }
    wiz->setSelectedVariant(variant);
    emit completeChanged();
}
