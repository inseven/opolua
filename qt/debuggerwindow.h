// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef DEBUGGERWINDOW_H
#define DEBUGGERWINDOW_H

#include <QLabel>
#include <QMainWindow>
#include <QTreeWidgetItem>

#include "opldebug.h"

namespace Ui {
class DebuggerWindow;
}

class CodeView;
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
    void toggleBreakOnError();
    void toggleWindowFocusEnabled();
    void stepOver();
    void gotoAddressSlot(const QString& module, uint32_t address);
    void toggleBreak();

private:
    CodeView* currentCodeView() const;
    CodeView* getCodeView(const QString& path);
    void gotoAddress(const QString& module, uint32_t address, bool isBreakPosition = false);
    void clearBreaks();

private:
    Ui::DebuggerWindow *ui;
    QLabel* mStatusLabel;
    OplRuntime* mRuntime;
    QVector<opl::Module> mShownModules;
    QMap<QString, CodeView*> mCodeViews;
    struct SingleStepState {
        QString module;
        QString proc;
        uint32_t lineAddr;
        int frameIdx;
    };
    std::optional<SingleStepState> mSteppingOver;
    std::optional<opl::ProgramInfo> mPauseState;
};

#endif // DEBUGGERWINDOW_H
