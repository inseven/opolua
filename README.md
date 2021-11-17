# opolua

An OPO (compiled OPL) interpreter written in Lua, based on the Psion 5 era format (ie ER5, prior to the Quartz 6.x changes).

## QCode

_Disclaimer: My understanding only, based on reading the opl-dev source code._

The OPL bytecode format is called QCode (for some reason). It is a simple stack machine with variable length commands. Each command consists of an 8-bit opcode followed by variable length parameters. An command like "AddInt" is a single 8-bit opcode, which pops 2 values from the stack and pushes 1 result. The OPO file format defines a collection of procedures with metadata (such as number of arguments, required local variable stack frame size, etc) for each plus the QCode itself.

There are something like 280 defined opcodes, plus another 128 or soe "functions" invoked with the `CallFunction` opcode. The distinction between dedicated opcode and function code appears entirely arbitrary as there are some extremely complex "opcodes" and some fairly basic functions codes. Opcodes whose numerical value doesn't fit in a single byte are expressed as opcode 255 ("NextOpcodeTable") followed by a second byte being the real code minus 256. There are no opcodes requiring more than 2 bytes to express.

Strings are limited to a maximum length of 255 bytes (this was increased in Quartz, as well as making strings support UCS-2). Various other internal data structures were increased from 1 byte to 2 at the same time.

Arrays are limited to 32767 elements (signed 16-bit) although the overall local variable size of a function is also limited to something like 16KB. 

## Implementation notes

This interpreter largely ignores types and specific memory layout restrictions. The stack is represented with a simple Lua table containing Lua number or string values, with no strict distinction between words/longs/floats.

Right now it runs in minimal Lua 5.3. At some point graphics integration etc will require some native code integration.

Globals and locals are represented by functions with a unique upvalue holding the actual value (which like the stack is a simple Lua number or string value. Calling `var()` gets the value, and calling `var(newVal)` sets it. This is a quick-and-dirty way to represent passable-by-reference values (the other option being Lua tables, which will be reserved for arrays whenever I get round to that). Using plain Lua values and the garbage collector means a lot of memory juggling can be avoided when resolving externals and similar.

This interpreter is not 100% behavior compatible with the original Psion. The more relaxed typing will mean that code which errored on a Psion may execute fine on here. Any non-erroring program (which also doesn't rely on expecting errors to occur and trapping them) should run OK here. Except for...

**This is a work in progress!** See the next section for missing features.

## Missing features

* Arrays
* Database/file support
* Graphics support
* Various other opcodes and functions
* OCX support (don't hold your breath for that one...)
* Anything which pokes the underlying OS, or allocates memory
* Any sort of performance considerations

## Example

[simple.txt](examples/simple.txt) compiled on a Psion Series 5:

```
$ cd src
$ ./runopo.lua ../examples/simple.opo 
Hello world!
Waaaat

$ ./dumpopo.lua ../examples/simple.opo --all
Source name: D:\Program
procTableIdx: 0x0000006B
1: TEST @ 0x0000001F code=0x00000036 line=0
    Subproc "WAT" offset=0x0012 nargs=0
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
    iTotalTableSize: 0 (0x00000000)
00000060: 2B [ConstantString] "Waaaat"
00000068: 8B [PrintString] 
00000069: 92 [PrintCarriageReturn] 
0000006A: 76 [ZeroReturnFloat] 
$
```

## References

* https://github.com/opl-dev/opl-dev
* https://web.archive.org/web/20070716134804/http://3lib.ukonline.co.uk/progindex.htm
* https://web.archive.org/web/20060505220702/http://www.allaboutopl.com/wiki/OPLCommandsListing?v=kbu
