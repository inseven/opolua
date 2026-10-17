// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "debuggerwindow.h"

#include <QClipboard>
#include <QFileDialog>
#include <QPlainTextEdit>

#include "codeview.h"
#include "differ.h"
#include "drawableview.h"
#include "luatokenizer.h"
#include "oplapplication.h"
#include "opltokenizer.h"
#include "oplruntime.h"
#include "oplscreenwidget.h"
#include "stackmodel.h"

#include "ui_debuggerwindow.h"

enum SpriteTreeChild {
    SpriteChildBitmap = 0,
    SpriteChildMask = 1,

    // SIBO
    SpriteChildBlackSet = 0,
    SpriteChildBlackClear = 1,
    SpriteChildBlackInvert = 2,
    SpriteChildGreySet = 3,
    SpriteChildGreyClear = 4,
    SpriteChildGreyInvert = 5,
};

enum CustomDataRoles {
    DrawableIdRole = Qt::UserRole,
};

DebuggerWindow::DebuggerWindow(OplRuntime* runtime, const QVariant& config, QWidget *parent)
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
    ui->actionExportBitmap->setVisible(false);
#ifdef Q_OS_MAC
    ui->actionDebugLog->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+D", nullptr));
    ui->actionRestart->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+R", nullptr));
    ui->actionClose->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+W", nullptr));
    ui->actionGotoSymbol->setShortcut(QCoreApplication::translate("DebuggerWindow", "Meta+G", nullptr));
    ui->actionFindNext->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+G", nullptr));
    ui->actionFindPrevious->setShortcut(QCoreApplication::translate("DebuggerWindow", "Ctrl+Shift+G", nullptr));
#endif
    connect(ui->actionAbout, &QAction::triggered, gApp, &OplApplication::showAboutWindow);
    connect(ui->actionClose, &QAction::triggered, gApp, &OplApplication::closeActiveWindow);
    connect(ui->actionPause, &QAction::triggered, runtime, &OplRuntime::pause);
    connect(ui->actionContinue, &QAction::triggered, runtime, &OplRuntime::unpause);
    connect(ui->actionRestart, &QAction::triggered, runtime, &OplRuntime::restart);
    connect(ui->actionStop, &QAction::triggered, runtime, &OplRuntime::interrupt);
    connect(ui->actionStepInto, &QAction::triggered, this, &DebuggerWindow::stepIn);
    connect(ui->actionStepOut, &QAction::triggered, runtime, &OplRuntime::stepOut);
    connect(ui->actionStepOver, &QAction::triggered, this, &DebuggerWindow::stepOver);
    connect(ui->actionToggleBreak, &QAction::triggered, this, &DebuggerWindow::toggleBreak);
    connect(ui->actionFlush, &QAction::triggered, runtime, &OplRuntime::flushGraphicsOps);
    connect(ui->actionClearAllBreakpoints, &QAction::triggered, this, &DebuggerWindow::clearBreakpoints);
    connect(ui->breakOnError, &QAction::triggered, this, &DebuggerWindow::toggleBreakOnError);
    connect(ui->windowFocusEnabled, &QAction::triggered, this, &DebuggerWindow::toggleWindowFocusEnabled);
    connect(ui->heapCheckingEnabled, &QAction::triggered, this, &DebuggerWindow::toggleHeapCheckingEnabled);
    connect(ui->stackView, &StackView::gotoAddress, this, &DebuggerWindow::gotoAddressSlot);
    connect(ui->actionDebugLog, &QAction::triggered, gApp, &OplApplication::showLogWindow);
    connect(ui->actionExportBitmap, &QAction::triggered, this, &DebuggerWindow::exportBitmap);
    connect(ui->actionGotoSymbol, &QAction::triggered, this, &DebuggerWindow::gotoSymbol);
    connect(ui->actionCopy, &QAction::triggered, this, &DebuggerWindow::copy);
    connect(ui->actionFind, &QAction::triggered, this, &DebuggerWindow::showFindDialog);
    connect(ui->actionFindNext, &QAction::triggered, this, &DebuggerWindow::findNext);
    connect(ui->actionFindPrevious, &QAction::triggered, this, &DebuggerWindow::findPrevious);
    connect(ui->actionUseSelectionForFind, &QAction::triggered, this, &DebuggerWindow::useSelectionForFind);

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
    connect(ui->drawablesView, &DrawablesTreeWidget::highlightWindow, this, &DebuggerWindow::highlightWindow);
    ui->drawablesView->setHeaderLabels({"Id", "Rank", "Info"});
    ui->drawablesView->sortByColumn(0, Qt::AscendingOrder);

    // Sprites dock widget
    ui->spritesView->setHeaderLabels({"Id", "Info"});
    connect(ui->spritesView, &QTreeWidget::itemSelectionChanged, this, &DebuggerWindow::spriteItemSelected);

    // Status bar

    mStatusLabel = new QLabel(this);
    ui->statusbar->addWidget(mStatusLabel);

    if (config.isValid()) {
        setDebuggerConfig(config);
    }

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
    mRuntime->stopDebugging();
}

void DebuggerWindow::keyPressEvent(QKeyEvent *event)
{
    // qDebug() << "Key event" << event->key();
    if (event->key() == Qt::Key_Escape && !mLastCodeView.isEmpty() && currentCodeView() == nullptr) {
        event->accept();
        setCurrentEditor(mLastCodeView);
    } else {
        QMainWindow::keyPressEvent(event);
    }
}

static QString describeDrawable(const opl::Drawable& d)
{
    QString result;
    if (d.isWindow) {
        result = QString("Window (%1, %2) %3x%4 %5bpp")
            .arg(d.rect.x())
            .arg(d.rect.y())
            .arg(d.rect.width())
            .arg(d.rect.height())
            .arg(d.bitDepth);
    } else {
        result = QString("Bitmap %1x%2 %3bpp")
            .arg(d.rect.width())
            .arg(d.rect.height())
            .arg(d.bitDepth);
    }

    if (d.isCurrent) {
        result = result + " (*)";
    }
    return result;
}

static QString describeSprite(const opl::Sprite& s)
{
    QString result = QString("Window %1 (%2, %3)")
        .arg(s.windowId)
        .arg(s.origin.x())
        .arg(s.origin.y());

    if (s.isCurrent) {
        result = result + " (*)";
    }
    return result;
}

static QString describeSpriteFrame(const OplScreen::SpriteFrame& f)
{
    QString result = QString("Offset: (%1, %2) time: %3ms")
        .arg(f.offset.x())
        .arg(f.offset.y())
        .arg(f.time / 1000);
    return result;
}

static QString describeMask(const OplScreen::SpriteFrame& f)
{
    auto result = QString("%1").arg(f.mask);
    if (f.invertMask) {
        result = result + " (inverted)";
    }
    return result;
}

static QTreeWidgetItem* newBitmapItem(int drawableId, const QString& name, const QString& desc = QString())
{
    QString description = desc;
    if (description.isEmpty()) {
        description = QString("%1").arg(drawableId);
    }
    auto item = new QTreeWidgetItem({ name, description });
    item->setData(0, DrawableIdRole, drawableId);
    return item;
}

static void updateSpriteFrameBitmap(QTreeWidgetItem* frameItem, int childIdx, int drawableId, const QString& desc = QString())
{
    QString description = desc;
    if (description.isEmpty()) {
        description = QString("%1").arg(drawableId);
    }
    auto item = frameItem->child(childIdx);
    item->setData(0, DrawableIdRole, drawableId);
    item->setData(1, Qt::DisplayRole, description);
}

static QTreeWidgetItem* newFrameItem(int index, bool isSibo, const OplScreen::SpriteFrame& frame)
{
    auto frameItem = new QTreeWidgetItem({ QString("Frame %1").arg(index + 1), describeSpriteFrame(frame) });
    if (isSibo) {
        frameItem->addChildren({
            newBitmapItem(frame.blackSetMask, "set (black)"),
            newBitmapItem(frame.blackClearMask, "clear (black)"),
            newBitmapItem(frame.blackInvertMask, "invert (black)"),
            newBitmapItem(frame.greySetMask, "set (grey)"),
            newBitmapItem(frame.greyClearMask, "clear (grey)"),
            newBitmapItem(frame.greyInvertMask, "invert (grey)")
        });
    } else {
        QString maskDescSuffix;
        if (frame.invertMask) {
            maskDescSuffix = " (inverted)";
        }
        frameItem->addChildren({
            newBitmapItem(frame.bitmap, "bitmap"),
            newBitmapItem(frame.mask, "mask", describeMask(frame))
        });
    }
    return frameItem;
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
            auto item = new QTreeWidgetItem({
                QString("%1").arg(newDrawable.id),
                newDrawable.isWindow ? QString("%1").arg(newDrawable.rank) : QString(),
                desc
            });
            ui->drawablesView->insertTopLevelItems(addedIdx, {item});
            if (addedIdx == 0) {
                // Qt seems to select the first item added after the list was empty
                ui->drawablesView->clearSelection();
            }
        },
        [this](int updatedIdx, const auto& drawable) {
            auto item = ui->drawablesView->topLevelItem(updatedIdx);
            if (drawable.isWindow) {
                item->setData(1, Qt::DisplayRole, QString("%1").arg(drawable.rank));
            }
            item->setData(2, Qt::DisplayRole, describeDrawable(drawable));
            auto currentDrawable = currentDrawableView();
            if (currentDrawable && currentDrawable->drawable().id == drawable.id) {
                currentDrawable->update(drawable, mRuntime);
            }
        }
    );
    Q_ASSERT(mShownDrawables.count() == info.drawables.count());

    bool spritesWasEmpty = mShownSprites.count() == 0;
    Differ<opl::Sprite>::diff(mShownSprites, info.sprites,
        [](const auto& a, const auto& b) { return a.spriteId == b.spriteId && a.isSibo == b.isSibo; },
        [this](int deletedIdx) {
            delete ui->spritesView->takeTopLevelItem(deletedIdx);
        },
        [this](int addedIdx, const auto& newSprite) {
            QString desc = describeSprite(newSprite);
            auto item = new QTreeWidgetItem({
                QString("Sprite %1").arg(newSprite.spriteId),
                desc
            });
            item->setData(0, DrawableIdRole, newSprite.windowId);
            ui->spritesView->insertTopLevelItems(addedIdx, {item});
            if (addedIdx == 0) {
                // Qt seems to select the first item added after the list was empty
                ui->spritesView->clearSelection();
            }

            for (int i = 0; i < newSprite.frames.count(); i++) {
                const auto& frame = newSprite.frames[i];
                item->addChild(newFrameItem(i, newSprite.isSibo, frame));
            }
        },
        [this](int updatedIdx, const auto& sprite) {
            auto item = ui->spritesView->topLevelItem(updatedIdx);
            item->setData(1, Qt::DisplayRole, describeSprite(sprite));
            // Copy here to avoid complications of using recursive diff
            QVector<OplScreen::SpriteFrame> oldFrames = mShownSprites[updatedIdx].frames;
            Differ<OplScreen::SpriteFrame>::diff(oldFrames, sprite.frames,
                [](const auto&, const auto&) { return true; /* There's nothing to distinguish frame uniqueness */ },
                [item](int deletedIdx) {
                    delete item->takeChild(deletedIdx);
                },
                [item, &sprite](int addedIdx, const auto& newFrame) {
                    item->addChild(newFrameItem(addedIdx, sprite.isSibo, newFrame));
                },
                [item, &sprite](int updatedIdx, const auto& frame) {
                    auto frameItem = item->child(updatedIdx);
                    if (sprite.isSibo) {
                        updateSpriteFrameBitmap(frameItem, SpriteChildBlackSet, frame.blackSetMask);
                        updateSpriteFrameBitmap(frameItem, SpriteChildBlackClear, frame.blackClearMask);
                        updateSpriteFrameBitmap(frameItem, SpriteChildBlackInvert, frame.blackInvertMask);
                        updateSpriteFrameBitmap(frameItem, SpriteChildGreySet, frame.greySetMask);
                        updateSpriteFrameBitmap(frameItem, SpriteChildGreyClear, frame.greyClearMask);
                        updateSpriteFrameBitmap(frameItem, SpriteChildGreyInvert, frame.greyInvertMask);
                    } else {
                        updateSpriteFrameBitmap(frameItem, SpriteChildBitmap, frame.bitmap);
                        updateSpriteFrameBitmap(frameItem, SpriteChildMask, frame.mask, describeMask(frame));
                    }
                }
            );
        }
    );
    if (spritesWasEmpty && mShownSprites.count() != 0) {
        ui->spritesView->expandRecursively(QModelIndex());
        ui->spritesView->resizeColumnToContents(0);
    }

    if (info.paused) {
        const auto& topFrame = info.frames.last();
        gotoAddress(topFrame.procModule, topFrame.ip, true);
    }

    QString status;
    if (!info.exitingError.isEmpty()) {
        status = info.exitingError;
    } else if (info.err.has_value()) {
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
    ui->spritesView->clearSelection();
    setCurrentDrawable(drawable);
}

const opl::Drawable* DebuggerWindow::getDrawable(int drawableId) const
{
    auto iter = std::find_if(mShownDrawables.begin(), mShownDrawables.end(), [drawableId](const opl::Drawable& d) {
        return d.id == drawableId;
    });
    if (iter != mShownDrawables.end()) {
        return &*iter;
    } else {
        return nullptr;
    }
}

void DebuggerWindow::spriteItemSelected()
{
    auto selection = ui->spritesView->selectedItems();
    auto item = selection.count() ? selection[0] : nullptr;
    if (!item) return;

    int drawableId = item->data(0, DrawableIdRole).toInt();
    auto drawable = getDrawable(drawableId);
    if (drawable) {
        ui->drawablesView->clearSelection();
        setCurrentDrawable(*drawable);
    }
}

void DebuggerWindow::highlightWindow(int drawableId)
{
    auto screen = static_cast<OplScreenWidget*>(mRuntime->getScreen());
    screen->highlightWindow(drawableId);
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
            auto pathInfo = QFileInfo(path);
            auto symbolsInfo = QFileInfo(pathInfo.dir(), pathInfo.completeBaseName() + ".json");
            QString symbolsPath;
            if (symbolsInfo.isFile()) {
                symbolsPath = symbolsInfo.filePath();
                mRuntime->addSymbolsFromFile(path, symbolsPath);
            }
            auto overrides = mNameOverrides.value(path, QVector<opl::NameOverride>());
            auto prog = OplRuntime().decompile(path, symbolsPath, overrides);
            view->setContents(prog);
            view->setSymbolsPath(symbolsPath);
            view->setShownBreakpoints(mRuntime->getModuleBreakpoints(path));
        }
        view->setPath(path);
        view->setReadOnly(true);
        view->moveCursor(QTextCursor::Start);
        view->setTextInteractionFlags(Qt::TextSelectableByMouse | Qt::TextSelectableByKeyboard);
        connect(view, &CodeView::breakpointConfigured, this, &DebuggerWindow::breakpointConfigured);
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
    ui->spritesView->clearSelection();
    auto ed = getCodeView(module);
    ui->centralwidget->setCurrentWidget(ed);
    setWindowTitle(QString("%1 - OpoLua Debugger").arg(QFileInfo(module).fileName()));
    if (module.startsWith(":")) {
        setWindowFilePath(QString());
    } else {
        setWindowFilePath(module);
    }
    ui->actionToggleBreak->setEnabled(!module.endsWith(".lua"));
    ui->actionExportBitmap->setVisible(false);
    ui->actionGotoSymbol->setEnabled(true);
    ui->actionFind->setEnabled(true);
    ui->actionFindNext->setEnabled(true);
    ui->actionFindPrevious->setEnabled(true);
    ui->actionUseSelectionForFind->setEnabled(true);
    ed->setFocus();
    mLastCodeView = module;
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
    setWindowFilePath(QString());
    ui->actionExportBitmap->setVisible(true);
    ui->actionGotoSymbol->setEnabled(false);
    ui->actionFind->setEnabled(false);
    ui->actionFindNext->setEnabled(false);
    ui->actionFindPrevious->setEnabled(false);
    ui->actionUseSelectionForFind->setEnabled(false);
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

void DebuggerWindow::toggleHeapCheckingEnabled()
{
    bool newState = ui->heapCheckingEnabled->isChecked();
    mRuntime->setHeapCheck(newState);
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
    mRuntime->stepOver(view->nextLineAddressForAddress(currentAddr));
}

void DebuggerWindow::stepIn()
{
    if (!mPauseState.has_value()) {
        return;
    }
    const auto& topFrame = mPauseState->frames.last();
    auto view = mCodeViews.value(topFrame.procModule);
    Q_ASSERT(view);
    auto currentAddr = view->lineAddressForAddress(topFrame.ip);
    mRuntime->stepIn(view->nextLineAddressForAddress(currentAddr));
}

void DebuggerWindow::toggleBreak()
{
    auto view = currentCodeView();
    if (!view) {
        return;
    }
    view->toggleBreakpoint();
}

void DebuggerWindow::variableRenamed(const QString& module, const QString& proc, uint32_t index, const QString& newName)
{
    auto& overrides = mNameOverrides[module];
    bool found = false;
    for (int i = 0; i < overrides.count(); i++) {
        if (overrides[i].proc == proc && overrides[i].index == index) {
            // Update existing
            found = true;
            overrides[i].newName = newName;
            break;
        }
    }
    if (!found) {
        overrides.append({
            .proc = proc,
            .index = index,
            .newName = newName
        });
    }

    CodeView* view = getCodeView(module);
    auto prog = OplRuntime().decompile(module, view->symbolsPath(), overrides);
    view->setContents(prog);
    emit debuggerConfigChanged();
}

void DebuggerWindow::breakpointConfigured(const QString& module, uint32_t addr, bool set)
{
    mRuntime->configureBreakpoint(module, addr, set);
    emit debuggerConfigChanged();
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

void DebuggerWindow::gotoSymbol()
{
    auto codeview = currentCodeView();
    if (codeview) {
        codeview->toggleGotoPopup();
    }    
}

void DebuggerWindow::showFindDialog()
{
    auto codeview = currentCodeView();
    if (codeview) {
        codeview->setFocus();
        auto text = codeview->showFindDialog(getSearchText());
        if (!text.isEmpty()) {
            setSearchText(text);
        }
    }    
}

void DebuggerWindow::copy()
{
    auto codeview = currentCodeView();
    if (codeview) {
        codeview->copy();
    } else {
        auto view = currentDrawableView();
        if (view) {
            qApp->clipboard()->setImage(view->getImage());
        }
    }
}

void DebuggerWindow::findPrevious()
{
    auto codeview = currentCodeView();
    if (codeview) {
        codeview->findPrevious(getSearchText());
    }
}

void DebuggerWindow::findNext()
{
    auto codeview = currentCodeView();
    if (codeview) {
        codeview->findNext(getSearchText());
    }
}

void DebuggerWindow::useSelectionForFind()
{
    auto codeview = currentCodeView();
    if (codeview) {
        auto selection = codeview->textCursor().selectedText();
        if (!selection.isEmpty()) {
            setSearchText(selection.replace(QChar(0x2029), "\n"));
        }
    }
}

void DebuggerWindow::setSearchText(const QString& text)
{
#ifdef Q_OS_MAC
    qApp->clipboard()->setText(text, QClipboard::FindBuffer);
#else
    mSearchText = text;
#endif
}

QString DebuggerWindow::getSearchText() const
{
#ifdef Q_OS_MAC
    return qApp->clipboard()->text(QClipboard::FindBuffer);
#else
    return mSearchText;
#endif
}

QString DebuggerWindow::relPath(const QString& absPath) const
{
    QDir dir(mRuntime->mappingForDrive(mRuntime->mainDrive()));
    dir.cdUp();
    return dir.relativeFilePath(absPath);
}

QString DebuggerWindow::absPath(const QString& relPath) const
{
    QDir dir(mRuntime->mappingForDrive(mRuntime->mainDrive()));
    dir.cdUp();
    return dir.absoluteFilePath(relPath);
}

QVariant DebuggerWindow::getDebuggerConfig() const
{
    QMap<QString, QVariant> result;

    const QMap<QString, QVector<uint32_t>> breakpoints = mRuntime->getBreakpoints();
    QMap<QString, QVariant> brkvar;
    for (auto iter = breakpoints.begin(), endIter = breakpoints.end(); iter != endIter; iter++) {
        QList<QVariant> lst;
        for (uint32_t addr : iter.value()) {
            lst.append(addr);
        }
        brkvar[relPath(iter.key())] = lst;
    }
    if (!brkvar.isEmpty()) {
        result["breakpoints"] = brkvar;
    }

    // renames format is:
    // {
    //     "<module-relative-path>": {
    //         "<procname>": {
    //             "<offset>": "<newname>",
    //             ...
    //          },
    //     },
    //     ...
    // }


    QMap<QString, QVariant> modules;

    for (auto iter = mNameOverrides.cbegin(), endIter = mNameOverrides.cend(); iter != endIter; iter++) {
        QString moduleName = relPath(iter.key());
        QMap<QString, QMap<QString, QString>> procs;
        for (const opl::NameOverride& override : iter.value()) {
            QString varName = QString("%1").arg(override.index, 4, 16, QLatin1Char('0')).toUpper();
            procs[override.proc][varName] = override.newName;
        }
        if (!procs.isEmpty()) {
            // Have to convert procs into a QVariant which doesn't happen automatically for recursive types
            QMap<QString, QVariant> procsVariant;
            for (auto procIter = procs.cbegin(), endProcIter = procs.cend(); procIter != endProcIter; procIter++) {
                const QMap<QString, QString>& vars = procIter.value();
                QMap<QString, QVariant> varsVariant;
                for (auto varIter = vars.cbegin(), endVarIter = vars.cend(); varIter != endVarIter; varIter++) {
                    varsVariant[varIter.key()] = varIter.value();
                }
                procsVariant[procIter.key()] = varsVariant;
            }
            modules[moduleName] = procsVariant;
        }
    }
    if (!modules.isEmpty()) {
        result["renames"] = modules;
    }

    return result.isEmpty() ? QVariant() : result;
}

void DebuggerWindow::setDebuggerConfig(const QVariant& config)
{
    if (!config.isValid()) {
        return;
    }
    if (!config.canConvert<QMap<QString, QVariant>>()) {
        qWarning("Bad type in setDebuggerConfig!");
        return;
    }
    mNameOverrides.clear();

    const QMap<QString, QVariant> configMap = config.toMap();
    const QMap<QString, QVariant> breakpoints = configMap["breakpoints"].toMap();
    for (auto iter = breakpoints.cbegin(), endIter = breakpoints.cend(); iter != endIter; iter++) {
        QString path = absPath(iter.key());
        auto codeview = mCodeViews.value(path, nullptr);
        QList<QVariant> addrs = iter.value().toList();
        for (const QVariant& addrVar : addrs) {
            uint32_t addr = addrVar.value<uint32_t>();
            if (addr) {
                mRuntime->setBreakpoint(path, addr);
                if (codeview) {
                    codeview->showBreakpoint(addr);
                }
            }
        }
    }

    const QMap<QString, QVariant> renames = configMap["renames"].toMap();
    for (auto iter = renames.cbegin(), endIter = renames.cend(); iter != endIter; iter++) {
        const QString path = absPath(iter.key());
        const QMap<QString, QVariant> modRenames = iter.value().toMap();
        for (auto riter = modRenames.cbegin(), rendIter = modRenames.cend(); riter != rendIter; riter++) {
            QString procName = riter.key();
            const QMap<QString, QVariant> vars = riter.value().toMap();
            for (auto varIter = vars.cbegin(), varEndIter = vars.cend(); varIter != varEndIter; varIter++) {
                QString varName = varIter.key();
                QString newName = varIter.value().toString();
                uint32_t index = (uint32_t)varName.toLong(nullptr, 16);
                // For code views
                mNameOverrides[path].append({
                    .proc = procName,
                    .index = index,
                    .newName = newName,
                });
                // And for the debug info, stack model etc
                mRuntime->renameVariable(path, procName, index, newName);
            }
        }
    }
}

void DebuggerWindow::clearBreakpoints()
{
    mRuntime->clearAllBreakpoints();
    for (CodeView* codeview : mCodeViews) {
        codeview->setShownBreakpoints({});
    }
    emit debuggerConfigChanged();
}
