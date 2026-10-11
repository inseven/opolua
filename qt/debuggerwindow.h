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
    explicit DebuggerWindow(OplRuntime* runtime, const QVariant& config = QVariant(), QWidget *parent = nullptr);
    ~DebuggerWindow();

    QVariant getDebuggerConfig() const;
    void setDebuggerConfig(const QVariant& config);

signals:
    void debuggerConfigChanged();

private slots:
    void debugInfoUpdated();
    void moduleSelected();
    void drawableSelected();
    void spriteItemSelected();
    void toggleBreakOnError();
    void toggleWindowFocusEnabled();
    void toggleHeapCheckingEnabled();
    void stepIn();
    void stepOver();
    void setCurrentEditor(const QString& module);
    void gotoAddressSlot(const QString& module, uint32_t address);
    void gotoSymbol();
    void showFindDialog();
    void findNext();
    void findPrevious();
    void useSelectionForFind();
    void toggleBreak();
    void variableRenamed(const QString& module, const QString& proc, uint32_t index, const QString& newName);
    void breakpointConfigured(const QString& module, uint32_t addr, bool set);
    void clearBreakpoints();
    void exportBitmap();
    void highlightWindow(int drawableId);
    void copy();

protected:
    void keyPressEvent(QKeyEvent *event) override;

private:
    CodeView* currentCodeView() const;
    CodeView* getCodeView(const QString& path);
    void gotoAddress(const QString& module, uint32_t address, bool isBreakPosition = false);
    void clearBreaks();
    DrawableView* currentDrawableView() const;
    const opl::Drawable* getDrawable(int drawableId) const;
    DrawableView* getDrawableView(const opl::Drawable& drawable);
    void setCurrentDrawable(const opl::Drawable& drawable);
    QString getSearchText() const;
    void setSearchText(const QString& text);
    QString relPath(const QString& absPath) const;
    QString absPath(const QString& relPath) const;

private:
    Ui::DebuggerWindow *ui;
    QLabel* mStatusLabel;
    OplRuntime* mRuntime;
    QVector<opl::Module> mShownModules;
    QVector<opl::Drawable> mShownDrawables;
    QVector<opl::Sprite> mShownSprites;
    QMap<QString, CodeView*> mCodeViews;
    QString mLastCodeView;
    QMap<int, DrawableView*> mDrawableViews;
    std::optional<opl::ProgramInfo> mPauseState;
    QMap<QString, QVector<opl::NameOverride>> mNameOverrides; // Map key is module name same as for mCodeViews
#ifndef Q_OS_MAC
    QString mSearchText;
#endif
};

#endif // DEBUGGERWINDOW_H
