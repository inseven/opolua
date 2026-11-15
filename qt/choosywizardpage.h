// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#pragma once
#include <functional>
#include <QFileDialog>
#include <QLineEdit>
#include <QPushButton>
#include <QWizardPage>

#include "validators.h"

class ChoosyWizardPage : public QWizardPage
{
public:
    enum ChooserType {
        OplSys,
        PkgFile,
        SisFile,
    };

    ChoosyWizardPage(QWidget *parent);

    void associateChooseButton(QLineEdit* edit, QPushButton* button, ChooserType type, std::function<QString()> nameHint=nullptr);

protected:
    NewFileValidator* mNewFileValidator;
};
