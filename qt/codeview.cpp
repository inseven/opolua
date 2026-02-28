// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "codeview.h"
#include "linenumberarea.h"
#include "highlighter.h"
#include "opltokenizer.h"

#include <QFont>
#include <QTextBlock>
#include <QPainter>
#include <QScrollBar>

CodeView::CodeView(QWidget *parent, TokenizerBase* tokenizer)
    : QPlainTextEdit(parent)
    , mMaxBlockId(0)
    , mUseHexLineAddresses(true)
{
    mLineNumberArea = new LineNumberArea(this);
    mHighlighter = new Highlighter(document(), tokenizer);
    setCenterOnScroll(true);

    QFont f;
    f.setFamilies({"Menlo", "Consolas"});
    f.setPixelSize(11);
    f.setStyleHint(QFont::Monospace);
    setFont(f);
    updateLineNumberAreaWidth();
    connect(this, &CodeView::blockCountChanged, this, &CodeView::updateLineNumberAreaWidth);
    connect(this, &CodeView::updateRequest, this, &CodeView::updateLineNumberArea);
}

void CodeView::setPath(const QString& path)
{
    mPath = path;
}

QString CodeView::path() const
{
    return mPath;
}

void CodeView::setUseHexLineAddresses(bool flag)
{
    mUseHexLineAddresses = flag;
}

void CodeView::setContents(const QVector<std::pair<uint32_t, QString>>& blocks)
{
    const auto scrollPos = verticalScrollBar()->value();
    auto doc = document();
    doc->clear();
    mBlockAddrs.clear();
    mMaxBlockId = 0;
    QTextCursor curs(doc);
    uint32_t prevId = 0;
    for (int i = 0; i < blocks.count(); i++) {
        const auto& block = blocks[i];
        uint32_t id = block.first == 0xFFFFFFFF ? prevId : block.first;
        mBlockAddrs.append(id);
        if (id > mMaxBlockId) {
            mMaxBlockId = id;
        }
        curs.insertText(block.second);
        // If this assert fails, the decompiler has failed to output exactly one newline per block.
        Q_ASSERT(doc->blockCount() - 1 == i + 1);
        prevId = id;
    }
    mBlockAddrs.append(prevId); // So that it has the same size as the block count

    if (mBreak.has_value()) {
        setBreak(*mBreak);
    }

    // Restore scrollbar position (assumes previous content was either empty or the same as now)
    verticalScrollBar()->setValue(scrollPos);
}

// LineNumberArea adapted from https://doc.qt.io/qt-5/qtwidgets-widgets-codeView-example.html

const int kBreakBulletWidth = 10;

int CodeView::lineNumberAreaWidth()
{
    auto maxId = QString::number(mMaxBlockId, 16);
    int space = 6 + fontMetrics().horizontalAdvance(maxId) + kBreakBulletWidth;
    return space;
}

void CodeView::lineNumberPaintEvent(QPaintEvent* event)
{
    QPainter painter(mLineNumberArea);
    painter.fillRect(event->rect(), palette().window().color());

    QTextBlock block = firstVisibleBlock();
    int blockNumber = block.blockNumber();
    int top = qRound(blockBoundingGeometry(block).translated(contentOffset()).top());
    int bottom = top + qRound(blockBoundingRect(block).height());

    while (block.isValid() && top <= event->rect().bottom()) {
        if (block.isVisible() && bottom >= event->rect().top()) {
            QString number;
            uint32_t addr = 0;
            if (blockNumber < mBlockAddrs.count()) {
                addr = mBlockAddrs[blockNumber];
                if (addr != 0 && (blockNumber == 0 || addr != mBlockAddrs[blockNumber - 1])) {
                    number = QString::number(addr, mUseHexLineAddresses ? 16 : 10);
                }
            }
            painter.setPen(palette().windowText().color());
            painter.drawText(kBreakBulletWidth, top, mLineNumberArea->width() - 3 - kBreakBulletWidth,
                             fontMetrics().height(),
                             Qt::AlignRight, number);

            if (!number.isEmpty() && mBreakpoints.contains(addr)) {
                painter.setPen(Qt::red);
                painter.setBrush(Qt::red);
                painter.drawEllipse(QPoint(7, (top + bottom) / 2), 5, 5);
            }
        }

        block = block.next();
        top = bottom;
        bottom = top + qRound(blockBoundingRect(block).height());
        ++blockNumber;
    }
}

void CodeView::updateLineNumberAreaWidth()
{
    setViewportMargins(lineNumberAreaWidth(), 0, 0, 0);
}

void CodeView::updateLineNumberArea(const QRect &rect, int dy)
{
    if (dy) {
        mLineNumberArea->scroll(0, dy);
    } else {
        mLineNumberArea->update(0, rect.y(), mLineNumberArea->width(), rect.height());
    }

    if (rect.contains(viewport()->rect())) {
        updateLineNumberAreaWidth();
    }
}

void CodeView::resizeEvent(QResizeEvent *e)
{
    QPlainTextEdit::resizeEvent(e);

    QRect cr = contentsRect();
    mLineNumberArea->setGeometry(QRect(cr.left(), cr.top(), lineNumberAreaWidth(), cr.height()));
}

void CodeView::scrollToAddress(uint32_t addr, bool selectLine)
{
    auto cursor = cursorForAddress(addr);
    if (selectLine) {
        cursor.movePosition(QTextCursor::EndOfBlock, QTextCursor::KeepAnchor);
        setTextCursor(cursor);
    } else {
        setTextCursor(cursor);
    }
}

uint32_t CodeView::lineAddressForAddress(uint32_t address) const
{
    auto cursor = cursorForAddress(address);
    auto blockIdx = cursor.blockNumber();
    while (blockIdx > 0 && mBlockAddrs[blockIdx - 1] == mBlockAddrs[blockIdx]) {
        blockIdx--;
    }
    return mBlockAddrs[blockIdx];
}

const QTextCursor CodeView::cursorForAddress(uint32_t address) const
{
    auto it = std::lower_bound(mBlockAddrs.cbegin(), mBlockAddrs.cend(), address);
    if (it == mBlockAddrs.end()) {
        qDebug("address %x not found", (unsigned)address);
        return QTextCursor();
    }
    int idx = std::distance(mBlockAddrs.cbegin(), it);
    if (idx > 0 && mBlockAddrs[idx] > address) {
        // The requested position might be midway through a compound statement, always
        // prefer the start of it
        idx--;
    }
    while (idx > 0 && mBlockAddrs[idx - 1] == mBlockAddrs[idx]) {
        // Skip any not-actually-addresses blocks
        idx--;
    }

    return QTextCursor(document()->findBlockByNumber(idx));
}

void CodeView::setBreak(std::optional<uint32_t> address)
{
    mBreak = address;
    if (address.has_value()) {
        scrollToAddress(*address, false);
        QTextEdit::ExtraSelection sel;
        sel.cursor = cursorForAddress(*address);
        QColor background = Qt::red;
        background.setAlphaF(0.3);
        sel.format.setBackground(background);
        sel.format.setProperty(QTextFormat::FullWidthSelection, true);
        setExtraSelections({sel});
    } else {
        setExtraSelections({});
    }
}

void CodeView::toggleBreakpoint()
{
    auto c = textCursor();
    auto addr = mBlockAddrs[c.blockNumber()];
    // qDebug("toggleBreakpoint %x", addr);
    bool set = !mBreakpoints.contains(addr);
    if (set) {
        mBreakpoints.insert(addr);
    } else {
        mBreakpoints.remove(addr);
    }
    mLineNumberArea->update();
    emit breakpointConfigured(mPath, addr, set);
}
