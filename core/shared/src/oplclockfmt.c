// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#include "opldefs.h"
#include "oplfns.h"

#include <string.h>
#include <time.h>

static void append(char** buf, const char* endPtr, const char* text)
{
    size_t bufSz = endPtr - *buf;
    size_t textSz = strlcpy(*buf, text, bufSz);
    *buf = *buf + textSz;
    if (*buf > endPtr) {
        *buf = (char*)endPtr;
    }
}

static void appendStrftime(char** buf, const char* endPtr, const struct tm* t, const char* fmt, bool skipLeadingZero)
{
    size_t bufSz = endPtr - *buf;
    size_t written = strftime(*buf, bufSz, fmt, t);
    // written doesn't include null, and we don't care about null terminating buf until the very end of oplFormatClock
    if (written > 1) {
        // Given the way we call appendStrftime, we will always want to strip leading space if there is one
        if (**buf == ' ') {
            memmove(*buf, *buf + 1, written - 1);
            written = written - 1;
        } else if (skipLeadingZero) {
            // 01 -> 1 and 001 -> 1, but 0 -> 0
            size_t numZeros = 0;
            while ((*buf)[numZeros] == '0' && numZeros + 1 < written) {
                numZeros++;
            }
            if (numZeros) {
                memmove(*buf, *buf + numZeros, written - numZeros);
                written = written - numZeros;
            }
        }
    }
    *buf += written;
}

typedef enum DatePart { Day, Month, Year } DatePart;
typedef enum TimePart { Hour24, Hour12, Minutes, Seconds } TimePart;

static const DatePart dmyOrdering[3][3] = {
    { Day, Month, Year }, // EuropeanFormat
    { Month, Day, Year }, // AmericanFormat
    { Year, Month, Day }, // JapaneseFormat
};

static const DatePart dmOrdering[3][2] = {
    { Day, Month }, // EuropeanFormat
    { Month, Day }, // AmericanFormat
    { Month, Day }, // JapaneseFormat
};

static void insertDatePart(char** buf, const char* endPtr, const struct tm* t, bool abbrev, bool isNumeric, DatePart datePart)
{
    switch (datePart) {
    case Day:
        if (isNumeric) {
             appendStrftime(buf, endPtr, t, abbrev ? "%e" : "%d", false);
        } else {
             appendStrftime(buf, endPtr, t, abbrev ? "%a" : "%A", false);
        }
        break;
    case Month:
        if (isNumeric) {
            appendStrftime(buf, endPtr, t, "%m", abbrev);
        } else {
            appendStrftime(buf, endPtr, t, abbrev ? "%b" : "%B", false);
        }
        break;
    case Year:
        appendStrftime(buf, endPtr, t, abbrev ? "%y" : "%Y", false);
        break;
    }
}

static void insertDatePartN(char** buf, const char* endPtr, const struct tm* t, bool abbrev, const bool* isNumeric, DatePart datePart)
{
    insertDatePart(buf, endPtr, t, abbrev, isNumeric[datePart], datePart);
}

static void insertTimePart(char** buf, const char* endPtr, const struct tm* t, bool abbrev, TimePart datePart)
{
    switch (datePart) {
    case Hour24:
        appendStrftime(buf, endPtr, t, abbrev ? "%k" : "%H", false);
        break;
    case Hour12:
        appendStrftime(buf, endPtr, t, abbrev ? "%l" : "%I", false);
        break;
    case Minutes:
        appendStrftime(buf, endPtr, t, "%M", false);
        break;
    case Seconds:
        appendStrftime(buf, endPtr, t, "%S", false);
        break;
    }
}

static void insertAmPm(char** buf, const char* endPtr, const struct tm* t, bool abbrev, const OplClockFormatSettings* settings)
{
    char* bufInit = *buf;
    if (settings->amText && settings->pmText) {
        append(buf, endPtr, t->tm_hour < 12 ? settings->amText : settings->pmText);
    } else {
        appendStrftime(buf, endPtr, t, "%p", false);
    }

    if (abbrev && *buf > bufInit) {
        *buf = bufInit + 1; // Truncate all but first character of the am/pm text ("a"/"p")
    }
}

static char* oplFormatClock3(char* buf, const char* endPtr, const char* fmt, const struct tm* t, const OplClockFormatSettings* settings)
{
    bool isNumeric[3] = { true, true, true }; // day, month, year (always true)
    bool isLong[3] = { true, true, true }; // 1st, 2nd, 3rd date component (whatever they are)

    while (*fmt != 0 && buf != endPtr) {
        switch (*fmt) {
        case '%': {
            fmt++;
            bool abbrev = false;
            if (*fmt == '*') {
                abbrev = true;
                fmt++;
            }
            switch (*fmt) {
            case '%':
                append(&buf, endPtr, "%");
                break;
            case ':':
                append(&buf, endPtr, settings->timeSeparator);
                break;
            case '/':
                append(&buf, endPtr, settings->dateSeparator);
                break;
            case 'A': // am/pm or a/p
                insertAmPm(&buf, endPtr, t, abbrev, settings);
                break;
            case 'D': // Day number
                insertDatePart(&buf, endPtr, t, abbrev, true, Day);
                break;
            case 'W': // Week number
                appendStrftime(&buf, endPtr, t, "%V", abbrev);
                break;
            case 'M': // Month number
                insertDatePart(&buf, endPtr, t, abbrev, true, Month);
                break;
            case 'E': // day name
                insertDatePart(&buf, endPtr, t, abbrev, false, Day);
                break;
            case 'N': // month name
                insertDatePart(&buf, endPtr, t, abbrev, false, Month);
                break;
            case 'H':
                insertTimePart(&buf, endPtr, t, abbrev, Hour24);
                break;
            case 'I':
                insertTimePart(&buf, endPtr, t, abbrev, Hour12);
                break;
            case 'S':
                insertTimePart(&buf, endPtr, t, abbrev, Seconds);
                break;
            case 'T':
                insertTimePart(&buf, endPtr, t, abbrev, Minutes);
                break;
            case 'Y':
                insertDatePart(&buf, endPtr, t, abbrev, true, Year);
                break;
            case '1':
                insertDatePartN(&buf, endPtr, t, !isLong[0], isNumeric, dmyOrdering[settings->dateFormat][0]);
                break;
            case '2':
                insertDatePartN(&buf, endPtr, t, !isLong[1], isNumeric, dmyOrdering[settings->dateFormat][1]);
                break;
            case '3':
                insertDatePartN(&buf, endPtr, t, !isLong[2], isNumeric, dmyOrdering[settings->dateFormat][2]);
                break;
            case '4':
                // %G applies to %4 the same way it does %1 (tested on S3a)
                insertDatePartN(&buf, endPtr, t, !isLong[0], isNumeric, dmOrdering[settings->dateFormat][0]);
                break;
            case '5':
                insertDatePartN(&buf, endPtr, t, !isLong[1], isNumeric, dmOrdering[settings->dateFormat][1]);
                break;
            case '6':
                insertTimePart(&buf, endPtr, t, abbrev, settings->system24hour ? Hour24 : Hour12);
                break;
            case '7':
                if (!settings->system24hour) {
                    // %*7 does abbreviate
                    insertAmPm(&buf, endPtr, t, abbrev, settings);
                }
                break;
            case 'F':
                isNumeric[Day] = !isNumeric[Day];
                break;
            case 'O':
                isNumeric[Month] = !isNumeric[Month];
                break;
            case 'G':
                isLong[0] = !isLong[0];
                break;
            case 'P':
                isLong[1] = !isLong[1];
                break;
            case 'U':
                isLong[2] = !isLong[2];
                break;
            case 'L': // Add day number suffix
                break; // Nope
            default:
                append(&buf, endPtr, "%");
                if (buf != endPtr) {
                    *buf++ = *fmt;
                }
                break;
            }
            if (*fmt) {
                fmt++;
            }
            break;
        }
        default:
            if (buf != endPtr) {
                *buf++ = *fmt;
            }
            fmt++;
        }
    }
    return buf;
}

static char* oplFormatClock5(char* buf, const char* endPtr, const char* fmt, const struct tm* t, const OplClockFormatSettings* settings)
{
    bool formatIndependent = false;
    bool isAbbrev[3] = { false, false, false }; // day, month, year
    bool isNumeric[3] = { true, true, true }; // day (not used), month, year (not used)

    while (*fmt != 0 && buf != endPtr) {
        switch (*fmt) {
        case '%': {
            fmt++;
            bool abbrev = false;
            bool before = false;
            bool after = false;
            if (*fmt == '-') {
                before = true;
                fmt++;
            }
            if (*fmt == '+') {
                if (before) {
                    return NULL;
                }
                after = true;
                fmt++;
            }
            if ((before || after) && *fmt != 'A' && *fmt != 'B') {
                return NULL;
            }

            if (*fmt == '*') {
                abbrev = true;
                fmt++;
            }
            switch (*fmt) {
            case '%':
                append(&buf, endPtr, "%");
                break;
            case ':':
                append(&buf, endPtr, settings->timeSeparator);
                // Skip the number, don't care (should error if out of range)
                fmt++;
                break;
            case '/':
                append(&buf, endPtr, settings->dateSeparator);
                // Skip the number, don't care (should error if out of range)
                fmt++;
                break;
            case '1': {
                // Unlike on s3, %*1 is valid so either %*D or %*1 means abbreviated day (assuming European format)
                DatePart part = dmyOrdering[settings->dateFormat][0];
                insertDatePart(&buf, endPtr, t, isAbbrev[part] || abbrev, isNumeric[part], part);
                break;
            }
            case '2': {
                DatePart part = dmyOrdering[settings->dateFormat][1];
                insertDatePart(&buf, endPtr, t, isAbbrev[part] || abbrev, isNumeric[part], part);
                break;
            }
            case '3': {
                DatePart part = dmyOrdering[settings->dateFormat][2];
                insertDatePart(&buf, endPtr, t, isAbbrev[part] || abbrev, isNumeric[part], part);
                break;
            }
            case '4': {
                DatePart part = dmOrdering[settings->dateFormat][0];
                insertDatePart(&buf, endPtr, t, isAbbrev[part] || abbrev, isNumeric[part], part);
                break;
            }
            case '5': {
                DatePart part = dmOrdering[settings->dateFormat][1];
                insertDatePart(&buf, endPtr, t, isAbbrev[part] || abbrev, isNumeric[part], part);
                break;
            }
            case 'A': // am/pm
                if (before) {
                    // Does any locale actually put am/pm before the date?
                    break;
                }
                if (!abbrev) {
                    append(&buf, endPtr, " ");
                }
                insertAmPm(&buf, endPtr, t, false, settings);
                break;
            case 'B': // am/pm only when 12 hour
                if (before || settings->system24hour) {
                    break;
                }
                if (!abbrev) {
                    append(&buf, endPtr, " ");
                }
                insertAmPm(&buf, endPtr, t, false, settings);
                break;
            // %C actually does something but is undocumented and I don't know what it is. It seems to output 000000 on
            // my Series 5.
            case 'D':
                if (abbrev) {
                    isAbbrev[Day] = true;
                }
                // Note, isNumeric[Day] is not set (or used) by anything
                if (formatIndependent) {
                    insertDatePart(&buf, endPtr, t, isAbbrev[Day], true, Day);
                }
                break;
            case 'E': // day name (note, this is not conditional on %F)
                insertDatePart(&buf, endPtr, t, abbrev, false, Day);
                break;
            case 'F':
                formatIndependent = true;
                break;
            case 'H':
                insertTimePart(&buf, endPtr, t, abbrev, Hour24);
                break;
            case 'I':
                insertTimePart(&buf, endPtr, t, true, Hour12);
                break;
            case 'J':
                if (settings->system24hour) {
                    insertTimePart(&buf, endPtr, t, abbrev, Hour24);
                } else {
                    insertTimePart(&buf, endPtr, t, true, Hour12);
                }
                break;
            case 'M':
                if (abbrev) {
                    isAbbrev[Month] = true;
                }
                isNumeric[Month] = true;
                if (formatIndependent) {
                    insertDatePart(&buf, endPtr, t, isAbbrev[Month], isNumeric[Month], Month);
                }
                break;
            case 'N':
                if (abbrev) {
                    isAbbrev[Month] = true;
                }
                isNumeric[Month] = false;
                if (formatIndependent) {
                    insertDatePart(&buf, endPtr, t, isAbbrev[Month], isNumeric[Month], Month);
                }
                break;
            case 'S':
                insertTimePart(&buf, endPtr, t, abbrev, Seconds);
                break;
            case 'T':
                insertTimePart(&buf, endPtr, t, abbrev, Minutes);
                break;
            case 'W': // Week number
                appendStrftime(&buf, endPtr, t, "%V", abbrev);
                break;
            case 'X': // Add day number suffix
                break; // Nope
            case 'Y':
                if (abbrev) {
                    isAbbrev[Year] = true;
                }
                isNumeric[Year] = true;
                if (formatIndependent) {
                    insertDatePart(&buf, endPtr, t, isAbbrev[Year], isNumeric[Year], Year);
                }
                break;
            case 'Z':
                appendStrftime(&buf, endPtr, t, "%j", abbrev);
                break;
            default:
                if (buf != endPtr) {
                    *buf++ = *fmt;
                }
                break;
            }
            if (*fmt) {
                fmt++;
            }
            break;
        }
        default:
            // Unlike on the s3, an invalid sequence like "%L" does _not_ output the percent
            if (buf != endPtr) {
                *buf++ = *fmt;
            }
            fmt++;
        }
    }
    return buf;
}

bool oplFormatClock(char* buf, int bufSz, const char* fmt, const struct tm* t, const OplClockFormatSettings* settings)
{
    if (bufSz == 0) {
        return false;
    }
    const char* endPtr = buf + bufSz;

    char* endBuf;
    if (settings->type == customFormatS3a) {
        endBuf = oplFormatClock3(buf, endPtr, fmt, t, settings);
    } else {
        endBuf = oplFormatClock5(buf, endPtr, fmt, t, settings);
    }

    if (!endBuf) {
        return false;
    }

    if (endBuf == endPtr) {
        endBuf--; // So we have room to null terminate
    }
    *endBuf = '\0';
    return true;
}

bool oplClockFormatHasSeconds(const char* fmt)
{
    return strstr(fmt, "%S") != NULL;
}
