// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef DEBUGGERWINDOW_H
#define DEBUGGERWINDOW_H

#include <QLabel>
#include <QMainWindow>
#include <QMap>
#include <QScrollArea>
#include <QScopedPointer>
#include <QTreeWidgetItem>

#include "opldebug.h"

namespace Ui {
class DebuggerWindow;
}

class CodeView;
class DrawableView;
class OplRuntime;

class DebuggerWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit DebuggerWindow(OplRuntime* runtime, QWidget *parent = nullptr);
    ~DebuggerWindow();

private slots:
    void debugInfoUpdated();
    void moduleSelected();
    void drawableSelected();
    void toggleBreakOnError();
    void toggleWindowFocusEnabled();
    void stepOver();
    void setCurrentEditor(const QString& module);
    void gotoAddressSlot(const QString& module, uint32_t address);
    void toggleBreak();
    void variableRenamed(const QString& module, const QString& proc, const QString& oldName, const QString& newName);
    void exportBitmap();

private:
    CodeView* currentCodeView() const;
    CodeView* getCodeView(const QString& path);
    void gotoAddress(const QString& module, uint32_t address, bool isBreakPosition = false);
    void clearBreaks();
    DrawableView* currentDrawableView() const;
    DrawableView* getDrawableView(const opl::Drawable& drawable);
    void setCurrentDrawable(const opl::Drawable& drawable);

private:
    Ui::DebuggerWindow *ui;
    QLabel* mStatusLabel;
    OplRuntime* mRuntime;
    QVector<opl::Module> mShownModules;
    QVector<opl::Drawable> mShownDrawables;
    QMap<QString, CodeView*> mCodeViews;
    QMap<int, DrawableView*> mDrawableViews;
    struct SingleStepState {
        QString module;
        QString proc;
        uint32_t lineAddr;
        int frameIdx;
    };
    std::optional<SingleStepState> mSteppingOver;
    std::optional<opl::ProgramInfo> mPauseState;
    QMap<QString, QVector<opl::NameOverride>> mNameOverrides; // Map key is module name same as for mCodeViews
};

#endif // DEBUGGERWINDOW_H
