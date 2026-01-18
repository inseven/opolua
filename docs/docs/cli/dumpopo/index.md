---
title: dumpopo
---

# Usage

```plaintext
{% include_relative _help.txt %}
```

# Overview

Parses compiled-OPL programs, optionally decoding or decompiling the QCode.

For example, when run with no additional arguments, the structure of the file and the procedures it contains are listed. For example, when run on the very basic example program `simple.opo`:

```
$ ./bin/dumpopo.lua examples/Tests/simple.opo
UID2: 0x10000073
UID3: 0x10000168
translatorVersion: 0x200A minRunVersion: 0x200A
Source name: D:\Program
procTableIdx: 0x0000006B
1: TEST @ 0x0000001F code=0x00000036 size=0x00000018 line=0
    Subproc "WAT" offset=0x0012 nargs=0
    maxStack: 8
    iDataSize: 23 (0x00000017)
    iTotalTableSize: 5 (0x00000005)
2: WAT @ 0x0000004E code=0x00000060 size=0x0000000B line=6
    maxStack: 0
    iDataSize: 18 (0x00000012)
    iTotalTableSize: 0 (0x00000000)
```

# Decode support

If a procedure name or `--all` is given, the procedure QCode is decoded:

```
$ ./bin/dumpopo.lua examples/Tests/simple.opo --all
UID2: 0x10000073
UID3: 0x10000168
translatorVersion: 0x200A minRunVersion: 0x200A
Source name: D:\Program
procTableIdx: 0x0000006B
1: TEST @ 0x0000001F code=0x00000036 size=0x00000018 line=0
    Subproc "WAT" offset=0x0012 nargs=0
    maxStack: 8
    iDataSize: 23 (0x00000017)
    iTotalTableSize: 5 (0x00000005)
00000036: 2B [ConstantString] "Hello world!"
00000044: 8B [PrintString]
00000045: 92 [PrintCarriageReturn]
00000046: 53 [RunProcedure] 0x0012 (name="WAT" nargs=0)
00000049: 82 [DropFloat]
0000004A: 57 [CallFunction] 0x0A (Get)
0000004C: 80 [DropInt]
0000004D: 76 [ZeroReturnFloat]
2: WAT @ 0x0000004E code=0x00000060 size=0x0000000B line=6
    maxStack: 0
    iDataSize: 18 (0x00000012)
    iTotalTableSize: 0 (0x00000000)
00000060: 2B [ConstantString] "Waaaat"
00000068: 8B [PrintString]
00000069: 92 [PrintCarriageReturn]
0000006A: 76 [ZeroReturnFloat]
```

# Decompilation

If `--decompile` is given, an attempt is made to convert the QCode back to OPL source code. While the OPL compiler is not hugely complex, not all information is preserved so the source code is unlikely to be identical to the original - in particular, names of local variables are thrown away by the compiler so the decompiler will generate new names for them based on their location in the procedure. In the case of simple.opo which has no variables or complex flow control, the output is very close to the [original](https://github.com/inseven/opolua/blob/main/examples/Tests/simple.txt):

```
$ ./bin/dumpopo.lua examples/Tests/simple.opo --decompile
PROC TEST:
    PRINT "Hello world!"
    WAT:
    GET
ENDP

PROC WAT:
    PRINT "Waaaat"
ENDP
```
