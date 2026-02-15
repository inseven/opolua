// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "stackmodel.h"
#include "oplruntime.h"

#include <QTextStream>

// Each frame is a top level item (ie parent is the invalid index)
// All valid indexes have a 48-bit id where the top 16 bits are the index of the frame.
// The middle 16 bits are the variable index (or 0xFFFF for frames).
// The bottom 16 bits are the array index, for array items (or 0xFFFF otherwise).
// Therefore a frame has the bottom 32 bits 0xFFFFFFFF.
// Yes this will break on 32-bit systems. A better scheme is, at present, left as an exercise for the reader.

static bool isFrame(const QModelIndex& idx)
{
    return (idx.internalId() & 0xFFFFFFFF) == 0xFFFFFFFF;
}

static bool isArrayMember(const QModelIndex& idx)
{
    return (idx.internalId() & 0xFFFF) != 0xFFFF;
}

static bool isVariable(const QModelIndex& idx)
{
    return !isFrame(idx) && !isArrayMember(idx);
}

static int getFrameIndex(const QModelIndex& idx)
{
    return static_cast<int>((idx.internalId() >> 32) & 0xFFFFFFFF);
}

static int getVariableIndex(const QModelIndex& idx)
{
    Q_ASSERT(!isFrame(idx));
    return static_cast<int>((idx.internalId() >> 16) & 0xFFFF);
}

static int getArrayIndex(const QModelIndex& idx)
{
    Q_ASSERT(isArrayMember(idx));
    return static_cast<int>(idx.internalId() & 0xFFFF);
}

static quintptr makeId(int frameIdx, int variableIdx = 0xFFFF, int arrayIdx = 0xFFFF)
{
    return (((quintptr)frameIdx) << 32) | (((quintptr)variableIdx) << 16) | arrayIdx;
}

StackModel::StackModel(OplRuntime* runtime, QObject* parent)
    : QAbstractItemModel(parent)
    , mRuntime(runtime)
{
    mInfo = mRuntime->getDebugInfo();
    connect(mRuntime, &OplRuntime::debugInfoUpdated, this, &StackModel::debugInfoUpdated);
    connect(mRuntime, &OplRuntime::startedRunning, this, &StackModel::startedRunning);
    connect(mRuntime, &OplRuntime::runComplete, this, &StackModel::runComplete);
    connect(&mUpdateTimer, &QTimer::timeout, mRuntime, &OplRuntime::updateDebugInfoIfStale);
    mUpdateTimer.start(1100);
}

void StackModel::runComplete()
{
    mUpdateTimer.stop();
}

void StackModel::startedRunning()
{
    // If we get one of these after construction, it means the runtime restarted and everything needs throwing away
    beginResetModel();
    mInfo = {};
    endResetModel();
    mUpdateTimer.start(1100);
}

void StackModel::debugInfoUpdated()
{
    // While the number of vars in a proc can't technically change, the runtime doesn't necessarily know about vars
    // until an instruction touches them (since we cannot know the type until then) so effectively it can. Fortunately
    // (well, it's by design for exactly this reason...) the runtime will cache inferred variable types in the
    // procTable meaning variables should never be able to disappear.

    // Because of how model updates have to work, we can't just replace mInfo, instead we have to massage it a change
    // at a time (with appropriate model change notifications) until it matches newInfo.

    const auto oldInfo = mInfo;
    const auto newInfo = mRuntime->getDebugInfo();
    int unchangedFrameCount = qMin(oldInfo.frames.count(), newInfo.frames.count());
    for (int i = 0; i < unchangedFrameCount; i++) {
        // Two different modules can have the same name, although you can't call both of them at once (proc lookup is
        // performed by name) you can unload one module and load another with a proc of the same name in between
        // debugInfoUpdated calls, so we have to check both proc name and module name here.
        if (newInfo.frames[i].procName != oldInfo.frames[i].procName ||
            newInfo.frames[i].procModule != oldInfo.frames[i].procModule ) {
            unchangedFrameCount = i;
            break;
        }
    }
    // qDebug("unchangedFrameCount = %d", unchangedFrameCount);
    if (unchangedFrameCount < mInfo.frames.count()) {
        beginRemoveRows(QModelIndex(), unchangedFrameCount, mInfo.frames.count() - 1);
        // Temporarily massage mInfo to keep the model internally consistent
        mInfo.frames.resize(unchangedFrameCount);
        endRemoveRows();
    }

    if (mInfo.frames.count() < newInfo.frames.count()) {
        beginInsertRows(QModelIndex(), mInfo.frames.count(), newInfo.frames.count() - 1);
        for (int i = mInfo.frames.count(); i < newInfo.frames.count(); i++) {
            mInfo.frames.append(newInfo.frames[i]);
        }
        endInsertRows();
    }

    // Now check each var in each (unchanged) frame and update
    for (int f = 0; f < unchangedFrameCount; f++) {
        if (newInfo.frames[f].ip != mInfo.frames[f].ip) {
            mInfo.frames[f].ip = newInfo.frames[f].ip;
            auto idx = createIndex(f, 1, makeId(f));
            emit dataChanged(idx, idx);
        }

        int oldIdx = 0;
        while (oldIdx < mInfo.frames[f].variables.count()) {
            const opl::Variable oldVar = mInfo.frames[f].variables[oldIdx]; // copy this as the loop below may invalidate a reference
            int newIdx = oldIdx;
            // Potentially new vars may have been added...
            while (newInfo.frames[f].variables[newIdx].address != oldVar.address) {
                const auto& newVar = newInfo.frames[f].variables[newIdx];
                // qDebug("Adding new variable %s", qPrintable(newVar.name));
                auto parent = createIndex(f, 0, makeId(f));
                beginInsertRows(parent, newIdx, newIdx);
                mInfo.frames[f].variables.insert(newIdx, newVar);
                endInsertRows();
                newIdx++;
                Q_ASSERT(newIdx < newInfo.frames[f].variables.count());
            }
            // At this point oldIdx is (potentially) stale and newIdx is valid in mInfo

            const auto& newVar = newInfo.frames[f].variables[newIdx];
            Q_ASSERT(newVar.address == oldVar.address);
            if (newVar.name != oldVar.name) {
                // qDebug("Variable renamed %s -> %s", qPrintable(oldVar.name), qPrintable(newVar.name));
                mInfo.frames[f].variables[newIdx].name = newVar.name;
                auto idx = createIndex(newIdx, 0, makeId(f, newIdx));
                emit dataChanged(idx, idx);
            }
            if (newVar.value != oldVar.value) {
                // qDebug("Value of %s changed", qPrintable(newVar.name));
                mInfo.frames[f].variables[newIdx].value = newVar.value;
                auto idx = createIndex(newIdx, 1, makeId(f, newIdx));
                emit dataChanged(idx, idx);
                if (IsArrayType(oldVar.type)) {
                    auto oldVal = oldVar.value.toList();
                    auto newVal = newVar.value.toList();
                    for (int a = 0; a < oldVal.count(); a++) {
                        if (newVal[a] != oldVal[a]) {
                            auto arridx = createIndex(a, 1, makeId(f, newIdx, a));
                            emit dataChanged(arridx, arridx);
                        }
                    }
                }
            }

            oldIdx = newIdx + 1;
        }
        // Above loop doesn't handle new vars appended to the end of newInfo
        for (int idx = oldIdx; idx < newInfo.frames[f].variables.count(); idx++) {
            const auto& newVar = newInfo.frames[f].variables[idx];
            qDebug("Adding new variable %s", qPrintable(newVar.name));
            auto parent = createIndex(f, 0, makeId(f));
            beginInsertRows(parent, idx, idx);
            mInfo.frames[f].variables.insert(idx, newVar);
            endInsertRows();
        }
    }

    mInfo.paused = newInfo.paused;
}

const opl::Frame& StackModel::frameForIndex(const QModelIndex& idx) const
{
    int i = getFrameIndex(idx);
    return mInfo.frames[i];
}

std::optional<opl::Frame> StackModel::getFrameForIndex(const QModelIndex& idx) const
{
    if (isFrame(idx)) {
        return frameForIndex(idx);
    }
    return std::nullopt;
}


const opl::Variable& StackModel::variableForIndex(const QModelIndex& idx) const
{
    return frameForIndex(idx).variables[getVariableIndex(idx)];
}

int StackModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return 2;
}

int StackModel::rowCount(const QModelIndex &parent) const
{
    // qDebug() << "rowCount" << parent;
    if (!parent.isValid()) {
        return mInfo.frames.count();
    } else if (isFrame(parent)) {
        return frameForIndex(parent).variables.count();
    } else if (isVariable(parent)) {
        const auto& var = variableForIndex(parent);
        if (IsArrayType(var.type)) {
            return var.value.toList().count();
        } else {
            return 0; // Non-array variables have no children
        }
    } else {
        return 0; // Array members have no children
    }
}

QModelIndex StackModel::index(int row, int column, const QModelIndex &parent) const
{
    // qDebug() << "index row" << row << "column" << column << "parent" << parent;

    if (!parent.isValid()) {
        // these are indexes for the top-level frame items
        auto ret = createIndex(row, column, makeId(row));
        return ret;
    } else if (isFrame(parent)) {
        // Create a variable index
        return createIndex(row, column, makeId(getFrameIndex(parent), row));
    } else {
        const auto& var = variableForIndex(parent);
        Q_ASSERT(IsArrayType(var.type));
        return createIndex(row, column, makeId(getFrameIndex(parent), getVariableIndex(parent), row));
    }
}

QModelIndex StackModel::parent(const QModelIndex &index) const
{
    // qDebug() << "parent" << index;
    Q_ASSERT(index.isValid());
    if (isFrame(index)) {
        return QModelIndex();
    } else if (isVariable(index)) {
        // It's a variable, parent is frame
        int frameIdx = getFrameIndex(index);
        Q_ASSERT(frameIdx >= 0 && frameIdx < mInfo.frames.count());
        return createIndex(frameIdx, 0, makeId(frameIdx));
    } else {
        // Array member, parent is variable
        int frameIdx = getFrameIndex(index);
        int varIdx = getVariableIndex(index);
        return createIndex(varIdx, 0, makeId(frameIdx, varIdx));
    }
}

QVariant StackModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    Q_UNUSED(section);
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole) {
        return QVariant();
    } else if (section == 0) {
        return QString("Name");
    } else {
        return QString("Value");
    }
}

QString StackModel::describeStringValue(const QString& value, bool quotedIfUsingEscapes) const
{
    QString result;
    QTextStream str(&result);
    str.setPadChar('0');
    str.setIntegerBase(16);
    str.setNumberFlags(QTextStream::UppercaseDigits);
    bool escapes = false;
    const auto endPtr = value.cend();
    for (auto ptr = value.cbegin(); ptr != endPtr; ptr++) {
        auto ch = ptr->unicode();
        if (ch >= 0x20 && ch <= 0x7F) {
            str << *ptr;
        } else {
            str << "\\x" << qSetFieldWidth(2) << (int)ch;
            escapes = true;
        }
    }

    if (quotedIfUsingEscapes && escapes) {
        return QString("\"%1\"").arg(result);
    } else {
        return result;
    }
}

QString StackModel::describeValue(const QVariant& value, int role) const
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    auto type = value.typeId();
#else
    auto type = (QMetaType::Type)value.type();
#endif
    switch (type) {
        case QMetaType::LongLong:
            return QString::number(value.toLongLong(), 10);
        case QMetaType::Double:
            return QString::number(value.toDouble());
        case QMetaType::QString:
            return describeStringValue(value.toString(), role == Qt::EditRole);
        case QMetaType::QVariantList: {
            QString result;
            QTextStream str(&result);
            str << "[";
            auto list = value.toList();
            for (int i = 0; i < list.count(); i++) {
                if (i > 0) {
                    str << ", ";
                }
                str << describeValue(list[i], role);
            }
            str << "]";
            return result;
        }
        default:
            qFatal("Unhandled metatype %d", type);
    }
}

QString stripTypeSuffix(const QString& identifier)
{
    QString result = identifier;
    if (result.endsWith("%") || result.endsWith("&") || result.endsWith("$")) {
        result = result.chopped(1);
    }
    return result;
}

QVariant StackModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || (role != Qt::DisplayRole && role != Qt::EditRole)) {
        return QVariant();
    }

    if (isFrame(index)) {
        // qDebug("frame name=%s", qPrintable(frameForIndex(index).procName));
        if (index.column() == 0) {
            return QString("%1:").arg(frameForIndex(index).procName);
        } else if (index.column() == 1) {
            return frameForIndex(index).ipDecode;
        } else {
            return QVariant();
        }
    } else if (isVariable(index)) {
        const auto& var = variableForIndex(index);
        if (index.column() == 0) {
            if (role == Qt::EditRole) {
                return stripTypeSuffix(var.name);
            } else {
                return var.name;
            }
        } else {
            return describeValue(var.value, role);
        }
    } else {
        const auto& var = variableForIndex(index);
        int arrayIdx = getArrayIndex(index);
        if (index.column() == 0) {
            return QString("[%1]").arg(arrayIdx + 1);
        } else {
            return describeValue(var.value.toList()[arrayIdx], role);
        }
    }
}

Qt::ItemFlags StackModel::flags(const QModelIndex &index) const
{
    auto flags = QAbstractItemModel::flags(index);
    if (isVariable(index) && index.column() == 0) {
        const auto& var = variableForIndex(index);
        // Lua variable names cannot be modified, and nor can globals (because that would break variable lookup)
        if (!frameForIndex(index).procModule.endsWith(".lua") && !var.global) {
            flags |= Qt::ItemIsEditable;
        }
    } else if (mInfo.paused && index.column() == 1
        && (isArrayMember(index) || (isVariable(index) && !IsArrayType(variableForIndex(index).type)))) {
        // edit the value of a variable
        flags |= Qt::ItemIsEditable;
    }
    return flags;
}

bool StackModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    Q_UNUSED(role);
    Q_ASSERT(isVariable(index) || isArrayMember(index));
    const auto& var = variableForIndex(index);
    if (index.column() == 0) {
        // It's a variable rename
        auto newName = value.toString();
        if (newName != var.name) {
            const auto& frame = frameForIndex(index);
            // Copy these so they don't risk getting invalidated by the renameVariable() call
            QString module = frame.procModule;
            QString proc = frame.procName;
            QString oldName = stripTypeSuffix(var.name);
            mRuntime->renameVariable(proc, var.index, newName);
            emit variableRenamed(module, proc, oldName, newName);
            return true;
        }
    } else {
        const auto& frame = frameForIndex(index);
        std::optional<int> arrayIdx = std::nullopt;
        if (isArrayMember(index)) {
            arrayIdx = getArrayIndex(index);
        }
        mRuntime->setVariable(frame, var, arrayIdx, value.toString());
        return true;
    }
    return false;
}
