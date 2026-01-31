---
title: Command Line Interface
short_title: CLI
priority: 90
layout: documentation_toc
---

OpoLua includes a suite of command line utilities to help with development OPL programs and working with Psion files.

These are available by cloning the [repository](https://github.com/inseven/opolua), in the `bin` directory. A version of Lua 5.3 or 5.4 must be installed to run them like this, for example:

```
./bin/dumpopo.lua ...
```

or on Windows,

```
lua.exe bin\dumpopo.lua ...
```

They are also bundled in the Qt version of the app, on platforms which support it (which currently, means all of them except Windows). Invoke the OpoLua binary from the command-line with the name of the command and any parameters to it.

For example, on linux:

```
./opolua dumpopo path/to/something.opo
```

or on macOS:

```
./OpoLua\ Qt.app/Contents/MacOS/OpoLua dumpopo path/to/something.opo
```

All the commands support the `--help` option for further explanation of what they do. Some of the more important commands have additional documentation, linked below.
