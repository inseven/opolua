// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "opltokenizer.h"
#define _CRT_SECURE_NO_WARNINGS
#include <string.h>

enum ParseState {
    InNothing = 0,
    Comment = 1 << 29,
    String = 1 << 30,
    InDoubleQuotedString = String | (int)'"',
};

#define SPACECHARS " \f\n\r\t\v"
#define ENDOFLINE "\n\r"
#define UNARY_OPS "-+=*/<>."
#define CONTROL " APP BREAK CONST CONTINUE DO ELSE ELSEIF ENDA ENDIF ENDP ENDV ENDWH GOTO IF PROC RETURN UNTIL VECTOR WHILE "
#define RESERVED " AND CAPTION FLAGS GLOBAL ICON INCLUDE LOCAL OFF ON OR "
#define MAX_RESERVED_LEN 8


OplTokenizer::OplTokenizer()
{
    set(InNothing, nullptr);
}

void OplTokenizer::set(int state, const char* ptr)
{
    m_state = state;
    m_start = ptr;
    m_ptr = ptr;
}

void OplTokenizer::skipSpace()
{
    m_ptr += strspn(m_ptr, SPACECHARS);
}

int OplTokenizer::offset() const
{
    return (int)(m_ptr - m_start);
}

int OplTokenizer::state() const
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
    return isIdentifierStart(ch) || isDecimal(ch) || ch == '_' || ch == '%' || ch == '&' || ch == '$';
}

static NumState isNumChar(char ch, NumState state=NumStart)
{
    switch(state) {
    case NumStart:
        if (ch == '0') {
            return NumLeadingZero;
        } else if (isDecimal(ch)) {
            return NumDecimal;
        } else if (ch == '&' || ch == '$') {
            return NumLeadingHex;
        } else {
            return NumFinished;
        }
    case NumLeadingZero:
        [[fallthrough]];
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
        return isHex(ch) ? state : NumFinished;
    case NumFinished:
        return NumFinished;
    }
    return NumFinished; // won't reach this for legal values of state
}

OplTokenizer::Token OplTokenizer::next()
{
    if (!m_ptr || !*m_ptr) return TokenNone;

    if (m_state & String) {
        // Ie "" or '' string
        char endch = (char)(m_state & 0xFF);
        char last = '\0';
        char ch;
        while ((ch = *m_ptr++)) {
            if (ch == endch && last != '"') {
                // Found string terminator
                m_state = InNothing;
                break;
            } else if ((ch == '\n' || ch == '\r')) {
                // Unterminated string is considered to end at the end of line
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
        if (toklen == 3 && memcmp(token_start_ptr, "REM", 3) == 0) {
            m_ptr += strcspn(m_ptr, ENDOFLINE);
            return TokenComment;
        }
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

    if (ch == '"') {
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
