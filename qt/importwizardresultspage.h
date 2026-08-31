// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef IMPORTWIZARDRESULTSPAGE_H
#define IMPORTWIZARDRESULTSPAGE_H

#include <QWizardPage>

namespace Ui {
class ImportWizardResultsPage;
}

class ImportWizardResultsPage : public QWizardPage
{
    Q_OBJECT

public:
    explicit ImportWizardResultsPage(QWidget *parent = nullptr);
    ~ImportWizardResultsPage();
    void initializePage() override;

private:
    Ui::ImportWizardResultsPage *ui;
};

#endif // IMPORTWIZARDRESULTSPAGE_H
