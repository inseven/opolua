---
title: Frequently Asked Questions
short_title: FAQ
toc: true
shows_title: true
priority: 50
---

<a id="opx-support"></a>

## What OPX libraries are supported?

OPX libraries are native C/C++ libraries that OPL programs can use. The following built-in and commonly used OPX libraries are supported:

- **bmp.opx** -- fully supported
- **date.opx** -- a few unimplemented functions
- **sysram1.opx** -- common functions supported
- **system.opx** -- common functions supported
- **systinfo.opx** -- partial support

<a id="invert-draw-mode"></a>

## Why do the graphics sometimes look wrong?

We don't currently fully support invert draw mode, meaning that programs that make use of this (often to improve performance or simulate transparency) will look a little strange. We're tracking this on GitHub as issue [#121](https://github.com/inseven/opolua/issues/121).

You can see this issue clearly in Asteroids by Phil Gooch & Neuon, which uses this mode to draw the asteroids:

<img class="program-screenshot" alt="Screenshot of Asteroids running in OPL for iOS" src="/images/asteroids.png">
