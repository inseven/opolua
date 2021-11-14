# opolua

An OPO (compiled OPL) interpreter written in Lua.

## Example

[simple.txt](examples/simple.txt) compiled on a Psion 5:

```
$ ./runopo.lua examples/simple.opo 
Hello world!
Waaaat

$ ./dumpopo.lua examples/simple.opo --all
Source name: D:\Program
procTableIdx: 0x0000006B
1: TEST @ 0x0000001F code=0x00000036 line=0
    Subproc 0x0012: WAT nargs=0
00000036: 2B [ConstantString] 'Hello world!'
00000044: 8B [PrintString] 
00000045: 92 [PrintCarriageReturn] 
00000046: 53 [RunProcedure] idx=0x0012 name=WAT nargs=0
00000049: 82 [DropFloat] 
0000004A: 57 [CallFunction] idx=0x0A Get()
0000004C: 80 [DropInt] 
0000004D: 76 [ZeroReturnFloat] 
2: WAT @ 0x0000004E code=0x00000060 line=6
00000060: 2B [ConstantString] 'Waaaat'
00000068: 8B [PrintString] 
00000069: 92 [PrintCarriageReturn] 
0000006A: 76 [ZeroReturnFloat] 
$
```

## References

* https://github.com/opl-dev/opl-dev
* https://web.archive.org/web/20070716134804/http://3lib.ukonline.co.uk/progindex.htm
* https://web.archive.org/web/20060505220702/http://www.allaboutopl.com/wiki/OPLCommandsListing?v=kbu
