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

#include <stdint.h>
#include <stdbool.h>

#include "opldevicetype.h"

#ifdef __cplusplus
extern "C" {
#endif

int32_t oplScancodeForKeycode(int32_t keycode, bool sibo);

int32_t oplCharcodeForKeycode(int32_t keycode);

uint32_t oplModifiersToTEventModifiers(uint32_t modifiers);

// Modified keycodes are those returned by GETEVENT32 keypress events, and take into account the fact that some modifer
// combinations change what the returned keycode is.
int32_t oplModifiedKeycode(int32_t keycode, uint32_t modifiers);

int32_t oplUnicodeToKeycode(uint32_t ch);

const char* oplGetDeviceName(OplDeviceType device);
int oplGetDeviceFromName(const char* name);
void oplGetScreenSize(OplDeviceType device, int* width, int* height);
int oplGetScreenMode(OplDeviceType device);
bool oplIsSiboDevice(OplDeviceType device);

#ifdef __cplusplus
} // extern "C"
#endif
