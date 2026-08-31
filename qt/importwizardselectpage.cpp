// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "importwizardselectpage.h"
#include "ui_importwizardselectpage.h"

#include <QFileDialog>
#include <QValidator>
#include <QVariant>

// Must be a directory that exists
class DirectoryValidator : public QValidator
{
public:
    DirectoryValidator(QObject* parent)
        : QValidator(parent)
        {}

    QValidator::State validate(QString &input, int &pos) const override {
        Q_UNUSED(pos);
        QFileInfo info(input);
        return (!info.isRelative() && info.isDir()) ? QValidator::Acceptable : QValidator::Intermediate;
    }
};

// Parent dir must exist, file must not
class NewFileValidator : public QValidator
{
public:
    NewFileValidator(QObject* parent)
        : QValidator(parent)
        {}

    QValidator::State validate(QString &input, int &pos) const override {
        Q_UNUSED(pos);
        QFileInfo info(input);
        if (info.isRelative()) {
            return QValidator::Intermediate;
        }
        bool ok = !info.isRelative() && info.dir().exists() && !info.exists();
        return ok ? QValidator::Acceptable : QValidator::Intermediate;
    }
};

ImportWizardSelectPage::ImportWizardSelectPage(QWidget *parent)
    : QWizardPage(parent)
    , ui(new Ui::ImportWizardSelectPage)
{
    ui->setupUi(this);
    connect(ui->selectSourceButton, &QPushButton::clicked, this, &ImportWizardSelectPage::chooseSource);
    connect(ui->selectInstallPathButton, &QPushButton::clicked, this, &ImportWizardSelectPage::chooseInstallPath);
    connect(ui->selectPackagePathButton, &QPushButton::clicked, this, &ImportWizardSelectPage::choosePackagePath);
    connect(ui->installPath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    connect(ui->installGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->sisPath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    connect(ui->createSisGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->packageFileGroupBox, &QGroupBox::toggled, this, &QWizardPage::completeChanged);
    connect(ui->packagePath, &QLineEdit::textChanged, this, &QWizardPage::completeChanged);
    ui->sourcePath->setValidator(new DirectoryValidator(this));
    auto newFileValidator = new NewFileValidator(this);
    ui->installPath->setValidator(newFileValidator);
    ui->sisPath->setValidator(newFileValidator);
    ui->packagePath->setValidator(newFileValidator);

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

void ImportWizardSelectPage::chooseInstallPath()
{
    auto path = QFileDialog::getSaveFileName(this, "Choose where to save the resulting .oplsys", QString(), "*.oplsys");
    if (!path.isEmpty()) {
        ui->installPath->setText(path);
    }
}

void ImportWizardSelectPage::choosePackagePath()
{
    auto path = QFileDialog::getSaveFileName(this, "Choose where to save the resulting .pkg file", QString(), "*.pkg");
    if (!path.isEmpty()) {
        ui->packagePath->setText(path);
    }
}

bool ImportWizardSelectPage::isComplete() const
{
    return QWizardPage::isComplete() &&
        (ui->installGroupBox->isChecked() || ui->createSisGroupBox->isChecked() || ui->packageFileGroupBox->isChecked()) &&
        (!ui->packageFileGroupBox->isChecked() || ui->packagePath->hasAcceptableInput()) &&
        (!ui->installGroupBox->isChecked() || ui->installPath->hasAcceptableInput()) &&
        (!ui->createSisGroupBox->isChecked() || ui->sisPath->hasAcceptableInput());
}
