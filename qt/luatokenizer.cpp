// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "luatokenizer.h"
#define _CRT_SECURE_NO_WARNINGS
#include <string.h>

enum ParseState {
    InNothing = 0,
    Long = 1 << 28, // Goes with either Comment or String
    Comment = 1 << 29,
    String = 1 << 30,
    InSingleQuotedString = String | (int)'\'',
    InDoubleQuotedString = String | (int)'"',
    LongNumEqualsMask = 0xFF,
};

#define SPACECHARS " \f\n\r\t\v"
#define ENDOFLINE "\n\r"
#define UNARY_OPS "-+=*/<>&|~%^."
#define CONTROL " break do else elseif end for function goto if repeat return then until while "
#define RESERVED " and false in local nil not or true "
#define MAX_RESERVED_LEN 8


LuaTokenizer::LuaTokenizer()
{
    set(InNothing, nullptr);
}

void LuaTokenizer::set(int state, const char* ptr)
{
    m_state = state;
    m_start = ptr;
    m_ptr = ptr;
}

void LuaTokenizer::skipSpace()
{
    m_ptr += strspn(m_ptr, SPACECHARS);
}

int LuaTokenizer::offset() const
{
    return (int)(m_ptr - m_start);
}

int LuaTokenizer::state() const
{
    return m_state;
}

enum NumState {
    NumStart = -1,
    NumFinished = 0,
    NumLeadingZero,
    NumDecimal,
    NumLeadingDecimalFraction,
    NumDecimalFraction,
    NumLeadingDecimalExponent,
    NumDecimalExponent,
    NumLeadingHex,
    NumHex,
    NumHexFraction,
    NumLeadingHexExponent,
    NumHexExponent,
};

inline bool isDecimal(char ch)
{
    return ch >= '0' && ch <= '9';
}

inline bool isHex(char ch)
{
    return isDecimal(ch) || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f');
}

static bool isIdentifierStart(char ch)
{
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z');
}

static bool isIdentifierChar(char ch)
{
    return isIdentifierStart(ch) || isDecimal(ch) || ch == '_';
}

static NumState isNumChar(char ch, NumState state=NumStart)
{
    switch(state) {
    case NumStart:
        if (ch == '0') {
            return NumLeadingZero;
        } else if (isDecimal(ch)) {
            return NumDecimal;
        } else {
            return NumFinished;
        }
    case NumLeadingZero:
        if (ch == 'x' || ch == 'X') {
            return NumLeadingHex;
        }
        [[fallthrough]]; // Otherwise drop through
    case NumDecimal:
        if (isDecimal(ch)) {
            return NumDecimal;
        } else if (ch == '.') {
            return NumDecimalFraction;
        } else if (ch == 'e' || ch == 'E') {
            return NumLeadingDecimalExponent;
        } else {
            return NumFinished;
        }
    case NumDecimalFraction:
        if (ch == 'e' || ch == 'E') {
            return NumLeadingDecimalExponent;
        }
        [[fallthrough]]; // Otherwise drop through
    case NumLeadingDecimalFraction: // exponent not allowed
        return isDecimal(ch) ? NumDecimalFraction : NumFinished;
    case NumLeadingDecimalExponent:
        if (ch == '+' || ch == '-') {
            return NumDecimalExponent;
        }
        [[fallthrough]]; // Otherwise drop through
    case NumDecimalExponent:
        return isDecimal(ch) ? NumDecimalExponent : NumFinished;
    case NumLeadingHex:
        // fraction or exponent not allowed immediately after the "0x"
        return isHex(ch) ? NumHex : NumFinished;
    case NumHex:
        if (ch == '.') {
            return NumHexFraction;
        }
        [[fallthrough]]; // Otherwise drop through
    case NumHexFraction:
        if (ch == 'p' || ch == 'P') {
            return NumLeadingHexExponent;
        }
        return isHex(ch) ? state : NumFinished;
    case NumLeadingHexExponent:
        if (ch == '+' || ch == '-') {
            return NumHexExponent;
        }
        [[fallthrough]]; // Otherwise drop through
    case NumHexExponent:
        // TIL Hex exponents are expressed in decimal
        return isDecimal(ch) ? NumHexExponent : NumFinished;
    case NumFinished:
        return NumFinished;
    }
    return NumFinished; // won't reach this for legal values of state
}

LuaTokenizer::Token LuaTokenizer::next()
{
    if (!m_ptr || !*m_ptr) return TokenNone;

    if (m_state & Long) {
        int num_eq = m_state & LongNumEqualsMask;
        char endseq[258] = "]";
        int i;
        for (i = 0; i < num_eq; i++) {
            endseq[i+1] = '=';
        }
        endseq[i+1] = ']';
        endseq[i+2] = '\0';
        auto found_end = strstr(m_ptr, endseq);
        Token ret = (m_state & Comment) ? TokenComment : TokenString;
        if (found_end) {
            m_state = InNothing;
            m_ptr = found_end + strlen(endseq);
        } else {
            m_ptr += strlen(m_ptr);
        }
        return ret;
    } else if (m_state & String) {
        // Ie "" or '' string
        char endch = (char)(m_state & 0xFF);
        char last = '\0';
        char ch;
        while ((ch = *m_ptr++)) {
            if (ch == endch && last != '\\') {
                // Found string terminator
                m_state = InNothing;
                break;
            } else if (ch == 'z' && last == '\\') {
                skipSpace();
            } else if ((ch == '\n' || ch == '\r') && last != '\\') {
                // Unterminated string is considered to end at the end of line if there's no \ at the end
                m_state = InNothing;
                break;
            }
            last = ch;
        }
        return TokenString;
    }

    skipSpace();
    if (!*m_ptr) return TokenBoring;
    const char* token_start_ptr = m_ptr;
    char ch = *m_ptr++;
    if (isIdentifierStart(ch)) {
        while (isIdentifierChar(*m_ptr)) {
            m_ptr++;
        }
        int toklen = (int)(m_ptr - token_start_ptr);
        if (toklen <= MAX_RESERVED_LEN) {
            char buf[MAX_RESERVED_LEN+3] = "";
            strncat(buf, " ", 2);
            strncat(buf, token_start_ptr, toklen);
            strncat(buf, " ", 2);
            if (strstr(CONTROL, buf)) {
                return TokenControl;
            } else if (strstr(RESERVED, buf)) {
                return TokenReserved;
            }
        }
        return TokenIdentifier;
    }

    if (ch == '-' && *m_ptr == '-') {
        // Comment ahoy!
        m_ptr++; // consume 2nd dash
        if (*m_ptr != '[') {
            m_ptr += strcspn(m_ptr, ENDOFLINE);
            return TokenComment;
        } else {
            m_state |= Comment;
            ch = *m_ptr++; // Move ch up
            // And drop through to long string handling
        }
    }
    if (ch == '[' && (*m_ptr == '[' || *m_ptr == '=')) {
        int num_eq = (int)strspn(m_ptr, "=");
        m_state |= Long | num_eq;
        if (!(m_state & Comment)) {
            m_state |= String;
        }
        m_ptr += num_eq; // consume equalses
        if (*m_ptr != '[') {
            // Invalid
            m_state = InNothing;
            return TokenBad;
        }
        m_ptr++;
        return next();
    }

    if (ch == '"' || ch == '\'') {
        m_state = String | (int)ch;
        return next();
    }

    // Don't care about including '-' at start of number, always treat as operator minus
    // Also not bothered about correctly distinguishing multi-char operators
    if (strspn(token_start_ptr, UNARY_OPS) >= 1) {
        return TokenOperator;
    }

    auto numstate = isNumChar(ch);
    if (numstate) {
        while (numstate != NumFinished) {
            numstate = isNumChar(*m_ptr, numstate);
            if (numstate) m_ptr++;
        }
        return TokenNumber;
    }

    return TokenBoring;
}
