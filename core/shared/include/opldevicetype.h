// Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#pragma once

#ifdef __clang__
#define CLOSED_ENUM __attribute__((enum_extensibility(closed)))
#else
#define CLOSED_ENUM
#endif

// This is kept separate to the things in opldefs.h to limit how much is
// included by things like oplruntime.h which doesn't need all the other stuff.

enum OplDeviceType {
    psionSeries3,
    // psionSeries3a,
    psionSeries3c,
    psionSiena,
    oregonOsaris,
    psionSeries5,
    psionRevo,
    psionSeries7,
    geofoxOne,
} CLOSED_ENUM;

typedef enum OplDeviceType OplDeviceType;

enum OplClockType {
    invalidClock = -1,
    digitalSmall, // type 1
    analogSmall, // type 3
    digitalMedium, // type 4
    analogMediumBlack, // type 5
    analogMediumS3a, // type 7 (S3a)
    analogMediumS5, // type 7 (S5)
    analogMediumColor, // type 7 (color)
    digitalFont, // Type 8, using KFontDigital35 (S5 and later)
    digitalFontShadowed, // Type 8, using shadowed KFontDigital35 (S3a only)
    analogLargeS3a, // type 9 (S3a)
    analogLargeS5, // type 9 (S5)
    analogLargeColor, // type 9 (color)
} CLOSED_ENUM;

typedef enum OplClockType OplClockType;
