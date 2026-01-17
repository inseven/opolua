---
title: compile
---

# Usage

```plaintext
{% include_relative _help.txt %}
```

# Overview

There is now support for compiling OPL code, although it is not (yet) integrated into the app. You must clone the repository from github and run the compiler from the command line. You must also have a version of Lua 5.3 or 5.4 installed from somewhere.

Syntax:

```
$ ./bin/compile.lua <src> <output>
```

(See `compile.lua --help` for full syntax).

`src` can be either a text file, or a `.opl` file. OPL files can also be converted to text using `./bin/opltotext.lua`.

The compiler supports most features of Series 5 era OPL, and will usually produce byte-for-byte identical output, compared with a Series 5. It tries to produce useful errors on malformed code, but it's likely there are some combinations that will produce something cryptic. Feel free to raise issues for these, or any examples where the output does not match the Series 5 compiler.

Unlike the original OPL compiler, which parsed the source code into an intermediate format "PCode" before then converting that to QCode, `compiler.lua` is a broadly single-pass compiler that directly generates QCode (with a final pass to fix up variable and branch offsets). Unlike the OpoLua interpreter, which in places has more relaxed runtime type checking than a Series 5, `compiler.lua` tracks expression types in exactly the same way as the original, including such quirks as `-32768` not being a valid integer literal (because internally it is parsed as the unary minus operator applied to 32768, and 32768 does not fit in a 16-bit integer).

# Limitations

Compiling for the Series 3 target is not supported (aka SIBO or "OPL 1993").

The OPL compiler allows a maximum nesting of 8 IF/WHILE statements. Since this isn't a runtime restriction, there is no such limit in compiler.lua.

Type checking isn't always perfect - https://github.com/inseven/opolua/issues/648
