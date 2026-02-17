// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef TOKENIZER_H
#define TOKENIZER_H

class TokenizerBase
{
public:
    // Definitions in tokenizer.lua must align with this
    enum Token {
        TokenNone = 0,
        TokenBoring, // Commas, brackets and similar
        TokenControl, // function, while, end, etc
        TokenReserved, // Any other reserved word that isn't TokenControl
        TokenIdentifier,
        TokenNumber,
        TokenString,
        TokenOperator,
        TokenComment,
        TokenBad,
    };

    virtual ~TokenizerBase() {}

    virtual void set(int state, const char* data) = 0;
    virtual void skipSpace() = 0;
    virtual Token next() = 0;

    virtual int offset() const = 0;
    virtual int state() const = 0;
};

#endif // TOKENIZER_H
