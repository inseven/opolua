// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef LUATOKENIZER_H
#define LUATOKENIZER_H

#include "tokenizer.h"

class LuaTokenizer : public TokenizerBase
{
public:
    LuaTokenizer();

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

#endif // LUATOKENIZER_H
