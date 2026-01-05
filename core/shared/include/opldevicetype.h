// Copyright (c) 2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#pragma once

// This is kept separate to the things in opldefs.h to limit how much is
// included by things like oplruntime.h which doesn't need all the other stuff.

enum OplDeviceType {
    psionSeries3,
    psionSeries3c,
    psionSiena,
    psionSeries5,
    psionRevo,
    psionSeries7,
    geofoxOne,
} __attribute__((enum_extensibility(closed)));

typedef enum OplDeviceType OplDeviceType;
