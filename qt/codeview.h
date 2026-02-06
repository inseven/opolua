// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef CODEVIEW_H
#define CODEVIEW_H

#include <QPlainTextEdit>

class Highlighter;

class CodeView : public QPlainTextEdit
{
    Q_OBJECT
public:
    CodeView(QWidget *parent = nullptr);
    void setPath(const QString& path);
    QString path() const;
    void setContents(const QVector<std::pair<uint32_t, QString>>& blocks);
    void scrollToAddress(uint32_t addr, bool selectLine = true);

    uint32_t lineAddressForAddress(uint32_t address) const;

    int lineNumberAreaWidth();
    void lineNumberPaintEvent(QPaintEvent* event);

    void setBreak(std::optional<uint32_t> address);

private slots:
    void updateLineNumberAreaWidth();
    void updateLineNumberArea(const QRect &rect, int dy);

protected:
    void resizeEvent(QResizeEvent *e) override;

private:
    const QTextCursor cursorForAddress(uint32_t address) const;

private:
    QString mPath;
    uint32_t mMaxBlockId;
    QWidget* mLineNumberArea;
    Highlighter* mHighlighter;
    // Unlike the output from OplRuntime::decompile(), blocks without an address are represented by duplicating the
    // previous element rather than using 0xFFFFFFFF. This is to make it possible to use std::lower_bound to search the
    // list.
    QVector<uint32_t> mBlockAddrs;
};

#endif // CODEVIEW_H
