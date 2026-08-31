// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef IMPORTWIZARDSELECTPAGE_H
#define IMPORTWIZARDSELECTPAGE_H

#include <QWizardPage>

namespace Ui {
class ImportWizardSelectPage;
}

class ImportWizardSelectPage : public QWizardPage
{
    Q_OBJECT

public:
    explicit ImportWizardSelectPage(QWidget *parent = nullptr);
    ~ImportWizardSelectPage();

    bool isComplete() const override;

private slots:
    void chooseSource();
    void chooseInstallPath();
    void choosePackagePath();

private:
    Ui::ImportWizardSelectPage *ui;
};

#endif // IMPORTWIZARDSELECTPAGE_H
