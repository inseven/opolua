---
title: Graphics
toc: true
shows_title: true
---

# Limitations

We don't currently fully support invert draw mode, meaning that programs that make use of this (often to improve performance or simulate transparency) will look a little strange. We're tracking this on GitHub as issue [#121](https://github.com/inseven/opolua/issues/121).

You can see this issue clearly in Asteroids by Phil Gooch & Neuon, which uses this mode to draw the asteroids:

<img class="program-screenshot" alt="Screenshot of Asteroids running in OPL for iOS" src="/images/asteroids.png">
