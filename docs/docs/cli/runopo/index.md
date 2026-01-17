---
title: runopo
---

# Usage

```plaintext
{% include_relative _help.txt %}
```

# Overview

Run OPL programs on the command line.

# Example

[simple.txt](https://github.com/inseven/opolua/blob/main/examples/Tests/simple.txt) compiled on a Psion Series 5:

```plaintext
$ ./src/runopo.lua --noget examples/Tests/simple.opo
Hello world!
Waaaat
(Skipping get)
$ ./src/dumpopo.lua examples/Tests/simple.opo --all
UID2: 0x10000073
UID3: 0x10000168
translatorVersion: 0x200A minRunVersion: 0x200A
Source name: D:\Program
procTableIdx: 0x0000006B
1: TEST @ 0x0000001F code=0x00000036 line=0
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
2: WAT @ 0x0000004E code=0x00000060 line=6
    maxStack: 0
    iDataSize: 18 (0x00000012)
    iTotalTableSize: 0 (0x00000000)
00000060: 2B [ConstantString] "Waaaat"
00000068: 8B [PrintString]
00000069: 92 [PrintCarriageReturn]
0000006A: 76 [ZeroReturnFloat]
$
```
