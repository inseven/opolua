// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "highlighter.h"

#include <QDebug>

static const QColor kHighlightBackgroundColor(0xff, 0x7e, 0x7e);

Highlighter::Highlighter(QTextDocument *parent, TokenizerBase* tokenizer)
    : QSyntaxHighlighter(parent)
    , mTokenizer(tokenizer)
{
}

void Highlighter::highlightBlock(const QString& text)
{
    int state = previousBlockState();
    if (state == -1) state = 0;

    QByteArray raw = text.toUtf8();
    raw.append('\n'); // Tell tokenizer about the line ending, useful for things like unterminated strings
    raw.append('\0'); // Make null terminated
    auto& tok = *mTokenizer;
    tok.set(state, raw.data());
    while (true) {
        if (!tok.state()) {
            tok.skipSpace();
        }
        int start = tok.offset();
        auto type = tok.next();
        int len = tok.offset() - start;
        if (type == TokenizerBase::TokenNone) {
            break;
        }
        switch(type) {
        case TokenizerBase::TokenNumber:
            setFormat(start, len, QColor(249, 174, 87));
            break;
        case TokenizerBase::TokenOperator:
            setFormat(start, len, QColor(249, 123, 87));
            break;
        case TokenizerBase::TokenComment:
            setFormat(start, len, QColor(153, 153, 153));
            break;
        case TokenizerBase::TokenString:
            setFormat(start, len, QColor(128, 185, 121));
            break;
        case TokenizerBase::TokenControl:
            setFormat(start, len, QColor(198, 149, 198));
            break;
        case TokenizerBase::TokenReserved:
            setFormat(start, len, QColor(236, 96, 102));
            break;
        case TokenizerBase::TokenBad: {
            QTextCharFormat fmt;
            fmt.setBackground(QBrush(kHighlightBackgroundColor));
            setFormat(start, len, fmt);
            break;
        }
        case TokenizerBase::TokenBoring:
        default:
            break;
        }
    }
    // qDebug() << "end state for line " << currentBlock().firstLineNumber() << "is " << tok.state();
    setCurrentBlockState(tok.state());
}
