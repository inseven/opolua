// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "importwizardselectpage.h"
#include "ui_importwizardselectpage.h"

#include <QFileDialog>
#include <QVariant>

ImportWizardSelectPage::ImportWizardSelectPage(QWidget *parent)
    : ChoosyWizardPage(parent)
    , ui(new Ui::ImportWizardSelectPage)
{
    ui->setupUi(this);
    connect(ui->selectSourceButton, &QPushButton::clicked, this, &ImportWizardSelectPage::chooseSource);
    associateChooseButton(ui->installPath, ui->selectInstallPathButton, OplSys);
    associateChooseButton(ui->packagePath, ui->selectPackagePathButton, PkgFile);
    associateChooseButton(ui->sisPath, ui->selectSisPathButton, SisFile);
    connect(ui->installPath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    connect(ui->installGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->sisPath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    connect(ui->createSisGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->packageFileGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->packagePath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    ui->sourcePath->setValidator(new DirectoryValidator(this));

    setTitle("Import an application");
    setSubTitle("If an app is distributed without an installable SIS file, this wizard attempts to guess the correct "
        "device filesystem layout, and creates a .oplsys bundle from it that OpoLua can run.");

    registerField("sourcePath*", ui->sourcePath);
    registerField("installPath", ui->installPath);
    registerField("packagePath", ui->packagePath);
    registerField("sisPath", ui->sisPath);
    registerField("sisVersion", ui->version);
    registerField("package", ui->packageFileGroupBox, "checked", SIGNAL(toggled(bool)));
    registerField("sis", ui->createSisGroupBox, "checked", SIGNAL(toggled(bool)));
    registerField("install", ui->installGroupBox, "checked", SIGNAL(toggled(bool)));
}

ImportWizardSelectPage::~ImportWizardSelectPage()
{
    delete ui;
}

void ImportWizardSelectPage::chooseSource()
{
    auto path = QFileDialog::getExistingDirectory(nullptr);
    if (!path.isEmpty()) {
        auto basename = QFileInfo(path).fileName();
        ui->sourcePath->setText(QDir::toNativeSeparators(path));
        ui->installPath->setText(QDir::toNativeSeparators(path + ".oplsys"));
        ui->sisPath->setText(QDir::toNativeSeparators(path + ".sis"));
        ui->packagePath->setText(QDir::toNativeSeparators(path + "/" + basename + ".pkg"));
    }
}

bool ImportWizardSelectPage::isComplete() const
{
    return ChoosyWizardPage::isComplete() &&
        (ui->installGroupBox->isChecked() || ui->createSisGroupBox->isChecked() || ui->packageFileGroupBox->isChecked()) &&
        (!ui->packageFileGroupBox->isChecked() || ui->packagePath->hasAcceptableInput()) &&
        (!ui->installGroupBox->isChecked() || ui->installPath->hasAcceptableInput()) &&
        (!ui->createSisGroupBox->isChecked() || ui->sisPath->hasAcceptableInput());
}
