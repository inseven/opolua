// Copyright (c) 2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

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
