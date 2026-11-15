// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "choosywizardpage.h"

ChoosyWizardPage::ChoosyWizardPage(QWidget *parent)
    : QWizardPage(parent)
    , mNewFileValidator(nullptr)
{}

void ChoosyWizardPage::associateChooseButton(QLineEdit* edit, QPushButton* button, ChooserType type, std::function<QString()> nameHint)
{
    if (!mNewFileValidator) {
        mNewFileValidator = new NewFileValidator(this);
    }
    edit->setValidator(mNewFileValidator);

    QObject::connect(button, &QPushButton::clicked, this, [this, edit, type, nameHint]() {
        QString path = edit->text();
        if (path.isEmpty()) {
            path = nameHint();
        }

        switch (type) {
        case OplSys:
            path = QFileDialog::getSaveFileName(this, "Choose where to save the resulting .oplsys", path, "*.oplsys");
            break;
        case PkgFile:
            path = QFileDialog::getSaveFileName(this, "Choose where to save the resulting .pkg file", path, "*.pkg");
            break;
        case SisFile:
            path = QFileDialog::getSaveFileName(this, "Choose where to save the resulting .sis file", path, "*.sis");
            break;
        }

        // Is this a macOS-specific bug, that QWizards get sent to the background (and the nearest QMainWindow is
        // activated instead) when a QFileDialog exits?
        auto win = window();
        win->raise();
        win->activateWindow();

        if (!path.isEmpty()) {
            edit->setText(path);
        }
    });
}
