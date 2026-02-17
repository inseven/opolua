// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "debuggerwindow.h"

#include <QPlainTextEdit>

#include "codeview.h"
#include "luatokenizer.h"
#include "opltokenizer.h"
#include "oplruntime.h"
#include "stackmodel.h"

#include "ui_debuggerwindow.h"

DebuggerWindow::DebuggerWindow(OplRuntime* runtime, QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::DebuggerWindow)
    , mRuntime(runtime)
{
    setAttribute(Qt::WA_DeleteOnClose);
    ui->setupUi(this);
    mStatusLabel = new QLabel(this);
    ui->statusbar->addWidget(mStatusLabel);
    setCorner(Qt::TopRightCorner, Qt::RightDockWidgetArea);
    setCorner(Qt::BottomRightCorner, Qt::RightDockWidgetArea);
    ui->actionContinue->setVisible(false);
    ui->actionToggleBreak->setEnabled(false);
    connect(ui->modulesView, &QTreeWidget::itemSelectionChanged, this, &DebuggerWindow::moduleSelected);

#ifdef Q_OS_MAC
    ui->actionRestart->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+R", nullptr));
    ui->actionClose->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+W", nullptr));
#endif
    ui->modulesView->setHeaderLabels({"Name", "Path", "Native Path"});

    connect(mRuntime, &OplRuntime::debugInfoUpdated, this, &DebuggerWindow::debugInfoUpdated);

    auto model = new StackModel(runtime, ui->stackView);
    connect(model, &StackModel::variableRenamed, this, &DebuggerWindow::variableRenamed);

    ui->stackView->setModel(model);
    ui->stackView->expandRecursively(QModelIndex(), 1);
    resizeDocks({ui->variablesDockWidget}, { width() / 3}, Qt::Horizontal);
    resizeDocks({ui->modulesDockWidget}, { 150 }, Qt::Vertical);

    ui->breakOnError->setChecked(runtime->breakOnError());
    ui->windowFocusEnabled->setChecked(!runtime->ignoreFocusEvents());

    connect(ui->actionPause, &QAction::triggered, runtime, &OplRuntime::pause);
    connect(ui->actionContinue, &QAction::triggered, runtime, &OplRuntime::unpause);
    connect(ui->actionRestart, &QAction::triggered, runtime, &OplRuntime::restart);
    connect(ui->actionStop, &QAction::triggered, runtime, &OplRuntime::interrupt);
    connect(ui->actionStepInto, &QAction::triggered, runtime, &OplRuntime::stepIn);
    connect(ui->actionStepOut, &QAction::triggered, runtime, &OplRuntime::stepOut);
    connect(ui->actionStepOver, &QAction::triggered, this, &DebuggerWindow::stepOver);
    connect(ui->actionToggleBreak, &QAction::triggered, this, &DebuggerWindow::toggleBreak);
    connect(ui->actionFlush, &QAction::triggered, runtime, &OplRuntime::flushGraphicsOps);
    connect(ui->breakOnError, &QAction::triggered, this, &DebuggerWindow::toggleBreakOnError);
    connect(ui->windowFocusEnabled, &QAction::triggered, this, &DebuggerWindow::toggleWindowFocusEnabled);
    connect(ui->stackView, &StackView::gotoAddress, this, &DebuggerWindow::gotoAddressSlot);
}

DebuggerWindow::~DebuggerWindow()
{
    if (mPauseState.has_value()) {
        mRuntime->unpause();
    }
    delete ui;
}

void DebuggerWindow::debugInfoUpdated()
{
    const auto info = mRuntime->getDebugInfo();
    if (info.paused && mPauseState.has_value()) {
        // Nothing can actually have changed that we care about (probably a variable rename or modify)
        return;
    }

    clearBreaks();
    if (info.frames.count() == 0) {
        mPauseState = std::nullopt;
        mStatusLabel->setText("Exited");
        ui->actionPause->setVisible(false);
        ui->actionContinue->setVisible(true);
        ui->actionStop->setEnabled(false);
        ui->actionContinue->setEnabled(false);
        ui->actionStepOver->setEnabled(false);
        ui->actionStepInto->setEnabled(false);
        ui->actionStepOut->setEnabled(false);
        ui->actionFlush->setEnabled(false);
        return;
    }
    if (info.paused) {
        mPauseState = info;
    } else {
        mPauseState = std::nullopt;
    }

    ui->actionPause->setVisible(!info.paused);
    ui->actionContinue->setEnabled(true);
    ui->actionStop->setEnabled(true);
    ui->actionContinue->setVisible(info.paused);
    ui->actionStepOver->setEnabled(info.paused);
    ui->actionStepInto->setEnabled(info.paused);
    ui->actionStepOut->setEnabled(info.paused);
    ui->actionFlush->setEnabled(info.paused);

    const auto& modules = info.modules;

    // The logic here assumes that module order doesn't change, so that a module not being in the expected place means
    // it's been unloaded.
    int modIdx = 0;
    int newIdx = 0;
    while (newIdx < modules.count()) {
        // newIdx always valid here
        if (modIdx < mShownModules.count() && mShownModules[modIdx].path == modules[newIdx].path) {
            // Unchanged
            modIdx++;
            newIdx++;
        } else {
            if (modIdx < mShownModules.count()) {
                // modIdx has been removed
                auto editor = mCodeViews.take(mShownModules[modIdx].nativePath);
                if (editor) {
                    ui->centralwidget->removeWidget(editor);
                    delete editor;
                }
                delete ui->modulesView->takeTopLevelItem(modIdx);
                mShownModules.remove(modIdx);
            } else {
                // new item
                auto item = new QTreeWidgetItem({modules[newIdx].name, modules[newIdx].path, modules[newIdx].nativePath});
                ui->modulesView->addTopLevelItems({item});
                if (newIdx == 0) {
                    ui->modulesView->setCurrentItem(item);
                }
                mShownModules.append(modules[newIdx]);
                modIdx++;
                newIdx++;
            }
        }
    }

    Q_ASSERT(mShownModules.count() == modules.count());

    if (info.paused) {
        const auto& topFrame = info.frames.last();

        if (mSteppingOver.has_value()) {
            auto view = mCodeViews.value(mSteppingOver->module);
            if (!view) {
                // qDebug("Module for step over has gona away??");
                mSteppingOver = std::nullopt;
                mRuntime->unpause();
            } else if (info.frames.count() > mSteppingOver->frameIdx
                && info.frames[mSteppingOver->frameIdx].procModule == mSteppingOver->module
                && info.frames[mSteppingOver->frameIdx].procName == mSteppingOver->proc) {
                // The same proc is still on the stack in the same place
                if (info.frames.count() > mSteppingOver->frameIdx + 1) {
                    // We appear to be stepped in, keep stepping out until we're back in the same frame
                    mRuntime->stepOut();
                } else {
                    // In the same frame
                    auto newLineAddr = view->lineAddressForAddress(topFrame.ip);
                    if (newLineAddr == mSteppingOver->lineAddr) {
                        // qDebug("Continuing step over %x still in same statement %x", topFrame.ip, newLineAddr);
                        mRuntime->singleStep();
                    } else {
                        // qDebug("Made it somewhere else %x != %x", newLineAddr, mSteppingOver->lineAddr);
                        mSteppingOver = std::nullopt;
                        gotoAddress(topFrame.procModule, topFrame.ip, true);
                    }
                }
            } else {
                // Frame no longer there, stepping over a return should probably be treated as a break
                // qDebug("Frame unwound, breaking");
                mSteppingOver = std::nullopt;
                gotoAddress(topFrame.procModule, topFrame.ip, true);
            }
        } else {
            gotoAddress(topFrame.procModule, topFrame.ip, true);
        }
    }

    QString status;
    if (info.err.has_value()) {
        status = QString("Error raised: %1").arg(*info.err);
    } else if (info.paused) {
        status = "Paused";
    } else {
        status = "Running";
    }
    mStatusLabel->setText(status);
}

void DebuggerWindow::moduleSelected()
{
    auto selection = ui->modulesView->selectedItems();
    auto item = selection.count() ? selection[0] : nullptr;
    if (!item) return;
    auto path = item->data(2, Qt::DisplayRole).toString();

    setCurrentEditor(path);
}

CodeView* DebuggerWindow::getCodeView(const QString& path)
{
    auto view = mCodeViews.value(path);
    if (!view) {
        if (path.startsWith(":/lua/")) {
            view = new CodeView(this, new LuaTokenizer);
            view->setUseHexLineAddresses(false);
            // Native module (basically meaning just toolbar.lua), try sources dir
            QString srcPath(path);
            srcPath.replace(0, 5, ":/luasrc");
            QFile f(srcPath);
            QVector<std::pair<uint32_t, QString>> lines;
            uint32_t lineNum = 1;
            if (f.open(QFile::ReadOnly | QIODevice::Text)) {
                while (!f.atEnd()) {
                    auto line = QString(f.readLine());
                    lines.append({ lineNum++, line });
                }
                view->setContents(lines);
            }
        } else {
            view = new CodeView(this, new OplTokenizer);
            view->setUseHexLineAddresses(true);
            auto prog = OplRuntime().decompile(path);
            view->setContents(prog);
        }
        view->setPath(path);
        view->setReadOnly(true);
        view->setTextInteractionFlags(Qt::TextSelectableByMouse | Qt::TextSelectableByKeyboard);
        connect(view, &CodeView::breakpointConfigured, mRuntime, &OplRuntime::configureBreakpoint);
        mCodeViews[path] = view;
        ui->centralwidget->addWidget(view);
    }
    return view;
}

void DebuggerWindow::setCurrentEditor(const QString& module)
{
    auto ed = getCodeView(module);
    ui->centralwidget->setCurrentWidget(ed);
    setWindowTitle(QString("%1 - OpoLua Debugger").arg(QFileInfo(module).fileName()));
    ui->actionToggleBreak->setEnabled(!module.endsWith(".lua"));
    ed->setFocus();
}

void DebuggerWindow::gotoAddressSlot(const QString& module, uint32_t address)
{
    gotoAddress(module, address, false);
}

void DebuggerWindow::gotoAddress(const QString& module, uint32_t address, bool isBreakPosition)
{
    // Rather than call setCurrentEditor directly, set in the moduleView so its highlight stays in sync
    auto items = ui->modulesView->findItems(module, Qt::MatchFixedString, 2);
    if (items.count()) {
        ui->modulesView->setCurrentItem(items[0]);
    }

    auto ed = getCodeView(module);
    if (isBreakPosition) {
        ed->setBreak(address);
    } else {
        ed->scrollToAddress(address, address != 0);
    }
}

void DebuggerWindow::clearBreaks()
{
    for (const auto view : mCodeViews) {
        view->setBreak(std::nullopt);
    }
}

void DebuggerWindow::toggleBreakOnError()
{
    bool newState = ui->breakOnError->isChecked();
    mRuntime->setBreakOnError(newState);
}

void DebuggerWindow::toggleWindowFocusEnabled()
{
    bool newState = ui->windowFocusEnabled->isChecked();
    mRuntime->setIgnoreFocusEvents(!newState);
}

CodeView* DebuggerWindow::currentCodeView() const
{
    return qobject_cast<CodeView*>(ui->centralwidget->currentWidget());
}

void DebuggerWindow::stepOver()
{
    if (!mPauseState.has_value()) {
        return;
    }
    const auto& topFrame = mPauseState->frames.last();
    auto view = mCodeViews.value(topFrame.procModule);
    Q_ASSERT(view);
    auto currentAddr = view->lineAddressForAddress(topFrame.ip);
    // qDebug("Stepping over from addr = %x", currentAddr);
    mSteppingOver = {
        .module = topFrame.procModule,
        .proc = topFrame.procName,
        .lineAddr = currentAddr,
        .frameIdx = (int)(mPauseState->frames.count() - 1)
    };
    mRuntime->singleStep();
}

void DebuggerWindow::toggleBreak()
{
    auto view = currentCodeView();
    if (!view) {
        return;
    }
    view->toggleBreakpoint();
}

void DebuggerWindow::variableRenamed(const QString& module, const QString& proc, const QString& oldName, const QString& newName)
{
    auto& overrides = mNameOverrides[module];
    bool found = false;
    for (int i = 0; i < overrides.count(); i++) {
        if (overrides[i].proc == proc && overrides[i].newName == oldName) {
            // Update existing
            found = true;
            overrides[i].newName = newName;
            break;
        }
    }
    if (!found) {
        // If there's no existing rename, the current name must be the original name
        overrides.append({
            .proc = proc,
            .origName = oldName,
            .newName = newName
        });
    }

    CodeView* view = getCodeView(module);
    auto prog = OplRuntime().decompile(module, overrides);
    view->setContents(prog);
}
