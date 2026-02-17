// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef HIGHLIGHTER_H
#define HIGHLIGHTER_H

#include <QScopedPointer>
#include <QSyntaxHighlighter>
#include "tokenizer.h"

class Highlighter : public QSyntaxHighlighter
{
    Q_OBJECT
public:
    explicit Highlighter(QTextDocument *document, TokenizerBase* tokenizer);

    void highlightBlock(const QString& text) override;

private:
    QScopedPointer<TokenizerBase> mTokenizer;
};

#endif // HIGHLIGHTER_H
