// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef STACKMODEL_H
#define STACKMODEL_H

#include <memory>

#include <QAbstractItemModel>
#include <QTimer>
#include "opldebug.h"

class OplRuntime;
class ModelIdx;

class StackModel : public QAbstractItemModel
{
    Q_OBJECT

public:
    StackModel(OplRuntime* runtime, QObject* parent = nullptr);
    ~StackModel();

    std::optional<opl::Frame> getFrameForIndex(const QModelIndex& idx) const;

public:
    QModelIndex parent(const QModelIndex &index) const override;
    QModelIndex index(int row, int column, const QModelIndex &parent) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role) override;

protected:
    int columnCount(const QModelIndex &parent) const override;
    int rowCount(const QModelIndex &parent) const override;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;

private slots:
    void debugInfoUpdated();
    void runComplete();
    void startedRunning();

signals:
    void variableRenamed(const QString& module, const QString& proc, const QString& oldName, const QString& newName);

private:
    const opl::Frame& frameForIndex(const QModelIndex& idx) const;
    const opl::Variable& variableForIndex(const QModelIndex& idx) const;

    QString describeValue(const QVariant& value, int role) const;
    QString describeStringValue(const QString& value, bool quoted) const;

    ModelIdx* modelIndexFor(int frameIndex, int variableIndex = -1, int arrayIndex = -1) const;

private:
    OplRuntime* mRuntime;
    QVector<opl::Frame> mFrames;
    std::unique_ptr<ModelIdx> mRootIndex;
    bool mPaused;
    QTimer mUpdateTimer;
};

#endif // STACKMODEL_H
