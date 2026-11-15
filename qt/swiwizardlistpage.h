// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef SWIWIZARDLISTPAGE_H
#define SWIWIZARDLISTPAGE_H

#include <QModelIndex>
#include <QStandardItem>
#include <QWizardPage>

class SoftwareIndexWizard;
class SwiProgram;

namespace Ui {
class SwiWizardListPage;
}

class SwiWizardListPage : public QWizardPage
{
    Q_OBJECT

public:
    explicit SwiWizardListPage(QWidget *parent = nullptr);
    ~SwiWizardListPage();

private slots:
    void loadingComplete();
    void filtersChanged();
    void updateModelFromFilters();
    void listSelectionChanged();
    void listItemDoubleClicked(const QModelIndex& index);
    void iconUpdated(const SwiProgram* program, const QIcon& icon);
    void refreshButtonClicked();

protected:
    void initializePage() override;
    bool isComplete() const override;
    void setVisible(bool visible) override;

private:
    const SwiProgram* programFromListIndex(const QModelIndex& modelIndex) const;
    const SoftwareIndexWizard* wiz() const;
    SoftwareIndexWizard* wiz();

private:
    Ui::SwiWizardListPage *ui;
    bool mShowEpoc16;
    bool mShowEpoc32;
    bool mAppsOnly;
    bool mOplOnly;
    QMap<const SwiProgram*, QStandardItem*> mProgramItems;
};

#endif // SWIWIZARDLISTPAGE_H
