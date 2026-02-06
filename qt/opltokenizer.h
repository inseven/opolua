// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef OPLTOKENIZER_H
#define OPLTOKENIZER_H

#include "tokenizer.h"

class OplTokenizer : public TokenizerBase
{
public:
    OplTokenizer();

    void set(int state, const char* data) override;
    void skipSpace() override;
    Token next() override;

    int offset() const override;
    int state() const override;

private:
    int m_state;
    const char* m_start;
    const char* m_ptr;
};

#endif // OPLTOKENIZER_H
