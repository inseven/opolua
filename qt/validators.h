// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#pragma once
#include <QDir>
#include <QFileInfo>
#include <QValidator>

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
