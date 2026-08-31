// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef IMPORTWIZARD_H
#define IMPORTWIZARD_H

#include "oplruntime.h"

#include <QWizard>

class ImportWizard : public QWizard
{
    Q_OBJECT
public:
    explicit ImportWizard(QWidget *parent = nullptr);

    OplRuntime& runtime() { return mRuntime; }

    void done(int result) override;

signals:
    void launch(const QString& oplSysPath);

private:
    void doInstall();

private:
    OplRuntime mRuntime;
};

#endif // IMPORTWIZARD_H
