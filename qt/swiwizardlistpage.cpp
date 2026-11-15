// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include <QIcon>
#include <QStandardItemModel>

#include "softwareindexwizard.h"
#include "swiwizardlistpage.h"
#include "ui_swiwizardlistpage.h"

enum DataRoles {
    ModelIndexRole = Qt::UserRole,
    SortRole,
};

SwiWizardListPage::SwiWizardListPage(QWidget *parent)
    : QWizardPage(parent)
    , ui(new Ui::SwiWizardListPage)
{
    ui->setupUi(this);
    ui->listView->setIconSize(QSize(32, 32));

    filtersChanged(); // Populates bools

    connect(ui->epoc16Checkbox, &QCheckBox::toggled, this, &SwiWizardListPage::filtersChanged);
    connect(ui->epoc32Checkbox, &QCheckBox::toggled, this, &SwiWizardListPage::filtersChanged);
    connect(ui->appsOnlyCheckbox, &QCheckBox::toggled, this, &SwiWizardListPage::filtersChanged);
    connect(ui->oplOnlyCheckbox, &QCheckBox::toggled, this, &SwiWizardListPage::filtersChanged);
    connect(ui->searchBox, &QLineEdit::textChanged, this, &SwiWizardListPage::updateModelFromFilters);
    connect(ui->listView, &QListView::doubleClicked, this, &SwiWizardListPage::listItemDoubleClicked);
}

SwiWizardListPage::~SwiWizardListPage()
{
    delete ui;
}

const SoftwareIndexWizard* SwiWizardListPage::wiz() const
{
    return static_cast<const SoftwareIndexWizard*>(wizard());
}

SoftwareIndexWizard* SwiWizardListPage::wiz()
{
    return static_cast<SoftwareIndexWizard*>(wizard());
}

void SwiWizardListPage::initializePage()
{
    setTitle("Program list");
    setSubTitle("The Software Index is an online collection of Psion software. Select a program below to install it.");

    ui->listView->setModel(new QStandardItemModel(ui->listView));
    connect(ui->listView->selectionModel(), &QItemSelectionModel::selectionChanged, this, &SwiWizardListPage::listSelectionChanged);

#if QT_VERSION >= QT_VERSION_CHECK(6, 7, 0)
    ui->searchBox->addAction(QIcon::fromTheme(QIcon::ThemeIcon::SystemSearch), QLineEdit::LeadingPosition);
#endif

    connect(wiz(), &SoftwareIndexWizard::indexUpdated, this, &SwiWizardListPage::loadingComplete);
    connect(wiz(), &SoftwareIndexWizard::programIconUpdated, this, &SwiWizardListPage::iconUpdated);
    wiz()->fetchIndex();
    // wiz()->loadIndex();
}

void SwiWizardListPage::loadingComplete()
{
    updateModelFromFilters();
}

bool SwiWizardListPage::isComplete() const
{
    return QWizardPage::isComplete() && ui->listView->selectionModel() && ui->listView->selectionModel()->selectedIndexes().count() == 1;
}

void SwiWizardListPage::filtersChanged()
{
    mShowEpoc16 = ui->epoc16Checkbox->isChecked();
    mShowEpoc32 = ui->epoc32Checkbox->isChecked();
    mAppsOnly = ui->appsOnlyCheckbox->isChecked();
    mOplOnly = ui->oplOnlyCheckbox->isChecked();
    updateModelFromFilters();
}

void SwiWizardListPage::updateModelFromFilters()
{
    auto model = qobject_cast<QStandardItemModel*>(ui->listView->model());
    if (!model) {
        return;
    }
    mProgramItems.clear();
    model->clear();
    // Why doesn't clear emit a selectionChanged?
    listSelectionChanged();

    const QVector<SwiProgram>& programs = wiz()->programs();
    // for (const auto& program : programs) {
    for (int i = 0; i < programs.count(); i++) {
        const auto& program = programs[i];
        auto flags = program.allFlags();
        if (mAppsOnly && !(flags & SwiFlag::app)) {
            continue;
        }
        if (mOplOnly && !(flags & SwiFlag::pureOpl)) {
            continue;
        }
        const auto& name = program.name();
        const auto& searchText = ui->searchBox->text();
        if (!searchText.isEmpty() && !name.contains(searchText, Qt::CaseInsensitive)) {
            continue;
        }
        if ((mShowEpoc16 && (flags & SwiFlag::epoc16)) || (mShowEpoc32 && (flags & SwiFlag::epoc32))) {
            auto item = new QStandardItem(wiz()->getIcon(program), program.name());
            mProgramItems[&program] = item;
            item->setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled);
            item->setData(i, ModelIndexRole);
            item->setData(program.name().toUpper(), SortRole);
            model->appendRow(item);
        }
    }
    model->setSortRole(SortRole);
    model->sort(0);
    ui->label->setText(QString("%1 item(s) matching current filter").arg(model->rowCount()));
}

void SwiWizardListPage::listSelectionChanged()
{
    auto selection = ui->listView->selectionModel()->selectedIndexes();
    const SwiProgram* prog = nullptr;
    if (selection.count() == 1) {
        prog = programFromListIndex(selection[0]);
    }
    wiz()->setSelectedProgram(prog);
    emit completeChanged();
}

const SwiProgram* SwiWizardListPage::programFromListIndex(const QModelIndex& modelIndex) const
{
    auto model = qobject_cast<QStandardItemModel*>(ui->listView->model());
    auto item = model->itemFromIndex(modelIndex);
    if (item) {
        int idx = item->data(ModelIndexRole).toInt();
        return &wiz()->programs()[idx];
    } else {
        return nullptr;
    }
}

void SwiWizardListPage::listItemDoubleClicked(const QModelIndex& index)
{
    auto wizard = wiz();
    wizard->setSelectedProgram(programFromListIndex(index));
    wizard->next();
}

void SwiWizardListPage::iconUpdated(const SwiProgram* program, const QIcon& icon)
{
    auto item = mProgramItems.value(program, nullptr);
    if (item) {
        item->setIcon(icon);
    }
}

void SwiWizardListPage::setVisible(bool visible)
{
    QWizardPage::setVisible(visible);

    if (visible) {
        wizard()->setButtonText(QWizard::CustomButton1, "&Refresh Index");
        wizard()->setOption(QWizard::HaveCustomButton1, true);
        connect(wizard(), &QWizard::customButtonClicked, this, &SwiWizardListPage::refreshButtonClicked);
    } else {
        wizard()->setOption(QWizard::HaveCustomButton1, false);
        disconnect(wizard(), &QWizard::customButtonClicked, this, &SwiWizardListPage::refreshButtonClicked);
    }
}

void SwiWizardListPage::refreshButtonClicked()
{
    wiz()->fetchIndex(true);
}
