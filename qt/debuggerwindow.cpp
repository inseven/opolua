// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "debuggerwindow.h"

#include <QFileDialog>
#include <QPlainTextEdit>

#include "codeview.h"
#include "differ.h"
#include "drawableview.h"
#include "luatokenizer.h"
#include "oplapplication.h"
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
    connect(mRuntime, &OplRuntime::debugInfoUpdated, this, &DebuggerWindow::debugInfoUpdated);
    gApp->updateWindowMenu(this, ui->menuWindow);

    // Toolbar/menu

    ui->actionContinue->setVisible(false);
    ui->actionToggleBreak->setEnabled(false);
    ui->breakOnError->setChecked(runtime->breakOnError());
    ui->windowFocusEnabled->setChecked(!runtime->ignoreFocusEvents());
#ifdef Q_OS_MAC
    ui->actionRestart->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+R", nullptr));
    ui->actionClose->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+W", nullptr));
#endif
    connect(ui->actionAbout, &QAction::triggered, gApp, &OplApplication::showAboutWindow);
    connect(ui->actionClose, &QAction::triggered, gApp, &OplApplication::closeActiveWindow);
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
    connect(ui->actionExportBitmap, &QAction::triggered, this, &DebuggerWindow::exportBitmap);

    // Dock widgets

    setCorner(Qt::TopRightCorner, Qt::RightDockWidgetArea);
    setCorner(Qt::BottomRightCorner, Qt::RightDockWidgetArea);
    resizeDocks({ui->variablesDockWidget}, { width() / 3}, Qt::Horizontal);
    resizeDocks({ui->modulesDockWidget}, { 150 }, Qt::Vertical);

    // Modules dock widget

    connect(ui->modulesView, &QTreeWidget::itemSelectionChanged, this, &DebuggerWindow::moduleSelected);
    ui->modulesView->setHeaderLabels({"Name", "Path", "Native Path"});

    // Drawables dock widget

    connect(ui->drawablesView, &QTreeWidget::itemSelectionChanged, this, &DebuggerWindow::drawableSelected);
    ui->drawablesView->setHeaderLabels({"Id", "Info"});

    // Status bar

    mStatusLabel = new QLabel(this);
    ui->statusbar->addWidget(mStatusLabel);

    // Stack info dock widget (do this last as it triggers a debugInfoUpdated)

    auto model = new StackModel(runtime, ui->stackView);
    connect(model, &StackModel::variableRenamed, this, &DebuggerWindow::variableRenamed);
    ui->stackView->setModel(model);
    ui->stackView->expandRecursively(QModelIndex(), 1);
}

DebuggerWindow::~DebuggerWindow()
{
    if (mPauseState.has_value()) {
        mRuntime->unpause();
    }
    delete ui;
}

static QString describeDrawable(const opl::Drawable& d)
{
    if (d.isWindow) {
        return QString("Window (%1, %2) %3x%4 %5bpp")
            .arg(d.rect.x())
            .arg(d.rect.y())
            .arg(d.rect.width())
            .arg(d.rect.height())
            .arg(d.bitDepth);
    } else {
        return QString("Bitmap %1x%2 %3bpp")
            .arg(d.rect.width())
            .arg(d.rect.height())
            .arg(d.bitDepth);
    }
}

void DebuggerWindow::debugInfoUpdated()
{
    const auto info = mRuntime->getDebugInfo();

    if (info.frames.count() == 0) {
        clearBreaks();
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
    if (info.paused && mPauseState.has_value()) {
        // Nothing can actually have changed that we care about (probably a variable rename or modify)
        return;
    }
    clearBreaks();
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

    Differ<opl::Module>::diff(mShownModules, info.modules,
        [](const auto& a, const auto& b) { return a.path == b.path; },
        [this](int deletedIdx) {
            // qDebug("Deleted module %s", qPrintable(mShownModules[deletedIdx].nativePath));
            auto editor = mCodeViews.take(mShownModules[deletedIdx].nativePath);
            if (editor) {
                ui->centralwidget->removeWidget(editor);
                delete editor;
            }
            delete ui->modulesView->takeTopLevelItem(deletedIdx);
        },
        [this](int addedIdx, const auto& newModule) {
            auto item = new QTreeWidgetItem({newModule.name, newModule.path, newModule.nativePath});
            ui->modulesView->insertTopLevelItems(addedIdx, {item});
            if (addedIdx == 0) {
                ui->modulesView->setCurrentItem(item);
            }
        },
        [](int updatedIdx, const auto& module) {
            // This shouldn't happen as modules don't mutate
            qWarning("Unexpected update of module %d path=%s!", updatedIdx, qPrintable(module.path));
        }
    );
    Q_ASSERT(mShownModules.count() == info.modules.count());

    Differ<opl::Drawable>::diff(mShownDrawables, info.drawables,
        [](const auto& a, const auto& b) { return a.id == b.id; },
        [this](int deletedIdx) {
            // qDebug("Drawable %d removed", mShownDrawables[deletedIdx].id);
            auto view = mDrawableViews.take(mShownDrawables[deletedIdx].id);
            if (view) {
                ui->centralwidget->removeWidget(view);
                delete view;
            }
            delete ui->drawablesView->takeTopLevelItem(deletedIdx);
        },
        [this](int addedIdx, const auto& newDrawable) {
            QString desc = describeDrawable(newDrawable);
            auto item = new QTreeWidgetItem({ QString("%1").arg(newDrawable.id), desc });
            ui->drawablesView->insertTopLevelItems(addedIdx, {item});
            if (addedIdx == 0) {
                // Qt seems to select the first item added after the list was empty
                ui->drawablesView->clearSelection();
            }
        },
        [this](int updatedIdx, const auto& drawable) {
            ui->drawablesView->topLevelItem(updatedIdx)->setData(1, Qt::DisplayRole, describeDrawable(drawable));
            auto currentDrawable = currentDrawableView();
            if (currentDrawable && currentDrawable->drawable().id == drawable.id) {
                currentDrawable->update(drawable, mRuntime);
            }
        }
    );
    Q_ASSERT(mShownDrawables.count() == info.drawables.count());

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

void DebuggerWindow::drawableSelected()
{
    auto selection = ui->drawablesView->selectedItems();
    auto item = selection.count() ? selection[0] : nullptr;
    if (!item) return;
    const auto& drawable = mShownDrawables[ui->drawablesView->indexOfTopLevelItem(item)];
    setCurrentDrawable(drawable);
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

DrawableView* DebuggerWindow::getDrawableView(const opl::Drawable& drawable)
{
    auto view = mDrawableViews.value(drawable.id);
    if (!view) {
        view = new DrawableView(drawable, this);
        mDrawableViews[drawable.id] = view;
        ui->centralwidget->addWidget(view);
        view->update(drawable, mRuntime);
    }
    return view;
}

void DebuggerWindow::setCurrentEditor(const QString& module)
{
    ui->drawablesView->clearSelection();
    auto ed = getCodeView(module);
    ui->centralwidget->setCurrentWidget(ed);
    setWindowTitle(QString("%1 - OpoLua Debugger").arg(QFileInfo(module).fileName()));
    ui->actionToggleBreak->setEnabled(!module.endsWith(".lua"));
    ui->actionExportBitmap->setVisible(false);
    ed->setFocus();
}

void DebuggerWindow::setCurrentDrawable(const opl::Drawable& drawable)
{
    ui->modulesView->clearSelection();
    auto view = getDrawableView(drawable);
    view->update(drawable, mRuntime);

    ui->centralwidget->setCurrentWidget(view);
    setWindowTitle(QString("%1 %2 - OpoLua Debugger")
        .arg(drawable.isWindow ? "Window" : "Bitmap")
        .arg(drawable.id));
    ui->actionExportBitmap->setVisible(true);
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

DrawableView* DebuggerWindow::currentDrawableView() const
{
    return qobject_cast<DrawableView*>(ui->centralwidget->currentWidget());
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

void DebuggerWindow::exportBitmap()
{
    auto view = currentDrawableView();
    if (!view) {
        qWarning("No drawable!");
        return;
    }

    auto defaultName = QString("%1_%2.png")
        .arg(view->drawable().isWindow ? "window" : "bitmap")
        .arg(view->drawable().id);
    auto path = QFileDialog::getSaveFileName(this, "Save bitmap as PNG", defaultName, "PNG (*.png)");
    if (path.isEmpty()) return;

    QImage img = view->getImage();
    if (!img.save(path, "PNG")) {
        qWarning("Failed to save image");
    }
}
