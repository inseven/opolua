// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef CODEVIEW_H
#define CODEVIEW_H

#include <QPlainTextEdit>
#include <QSet>
#include <QVector>

class Highlighter;
class TokenizerBase;

class CodeView : public QPlainTextEdit
{
    Q_OBJECT
public:
    CodeView(QWidget *parent, TokenizerBase* tokenizer);
    void setPath(const QString& path);
    QString path() const;
    void setUseHexLineAddresses(bool flag);
    void setContents(const QVector<std::pair<uint32_t, QString>>& blocks);
    void scrollToAddress(uint32_t addr, bool selectLine = true);

    uint32_t lineAddressForAddress(uint32_t address) const;

    int lineNumberAreaWidth();
    void lineNumberPaintEvent(QPaintEvent* event);

    void setBreak(std::optional<uint32_t> address);

public slots:
    void toggleBreakpoint();

private slots:
    void updateLineNumberAreaWidth();
    void updateLineNumberArea(const QRect &rect, int dy);

signals:
    void breakpointConfigured(const QString& module, uint32_t addr, bool set);

protected:
    void resizeEvent(QResizeEvent *e) override;

private:
    const QTextCursor cursorForAddress(uint32_t address) const;

private:
    QString mPath;
    uint32_t mMaxBlockId;
    bool mUseHexLineAddresses;
    QWidget* mLineNumberArea;
    Highlighter* mHighlighter;
    // Unlike the output from OplRuntime::decompile(), blocks without an address are represented by duplicating the
    // previous element rather than using 0xFFFFFFFF. This is to make it possible to use std::lower_bound to search the
    // list.
    QVector<uint32_t> mBlockAddrs;
    QSet<uint32_t> mBreakpoints;
    std::optional<uint32_t> mBreak;
};

#endif // CODEVIEW_H
