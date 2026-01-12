# OpoLua

[![Build](https://github.com/inseven/opolua/actions/workflows/build.yaml/badge.svg)](https://github.com/inseven/opolua/actions/workflows/build.yaml)

An OPO (compiled OPL) interpreter written in Lua and Swift/Qt, based on the Psion Series 5 era format (ie ER5, prior to the Quartz 6.x changes). It lets you run Psion 5 programs written in OPL on any iOS device, subject to the limitations described below, as well as on any platform supported by the Qt port (mac, windows, linux).

Supported features:

* Ability to decode a variety of Psion file types, including MBM, SIS, and databases.
* SIS files can be installed directly by launching them.
* Colour graphics (if the program originally provided them).
* Sound.
* Limited game controller support - although a paired bluetooth keyboard is necessary for some programs that rely on the keyboard rather than touchscreen input (iOS version only).

One thing that is explicitly not supported is programs that aren't pure OPL - ie that are native ARM-format binaries. This project is an OPL interpreter only, it is not a full ARM virtual machine.

There are two versions of the app: one for iOS and macOS Catalyst written in Swift; and one written in Qt which runs on macOS, Windows and linux. The two versions are mostly equivalent with some minor differences in UX.

## Screenshots

Some example OPL programs downloaded from the internet, running in OpoLua on iOS, Windows and macOS respectively:

![Jumpy! Plus](assets/screenshots/jumpy-plus.png)

![Vexed](assets/screenshots/vexed.png)

![Tile Fall](assets/screenshots/tile-fall.png)

## Building the Qt version

On Linux you'll need a version of Qt 5 or 6 and qmake, something like:

```
sudo apt install qt5-qmake qtmultimedia5-dev libqt5multimedia5-plugins
git clone https://github.com/inseven/opolua.git
cd opolua/qt
git submodule update --init --recursive
qmake opolua.pro
make
sudo make install
```

On mac:

```
brew install qt@5
git clone https://github.com/inseven/opolua.git
cd opolua/qt
git submodule update --init --recursive
qmake opolua.pro
make
```

Both Qt 5 and Qt 6 are supported and in theory should run on all platforms supported by Qt. Only macOS, Linux and Windows are tested, however.

## SIBO/EPOC16/Series 3 support

There is preliminary support for running OPL programs which target the Series 3/3a/3c and Siena. Due to the lack of installable SIS files on these platforms, currently only the Qt app and the command line tools support them. You will need to manually construct a directory structure that looks like this:

```
<whatever>.oplsys
|- m/
|  |- APP/
|  |  |- <appname>.OPA
```

Populate any files or directories under the 'm' directory as instructed by the readme for the app. At which point you can open the OPA in the app or (on macOS) double-click the .oplsys bundle. For a double-clickable option on other platforms, create an empty 'launch.oplsys' file next to the 'm' directory. This file can then be double-clicked to launch the app.

The Series 3 support is at an early stage of development and there are many missing features compared to the Series 5 support. Please raise bugs for any programs you particularly want to run! (Help -> Report Issue, in the Qt app).

## QCode

_Disclaimer: My understanding only, based on reading the opl-dev source code._

The OPL bytecode format is called QCode (due to the intermediary parsed code format being called PCode). It is a simple stack machine with variable length commands. Each command consists of an 8-bit opcode followed by variable length parameters. A command like "AddInt" is a single 8-bit opcode, which pops 2 values from the stack and pushes 1 result. The OPO file format defines a collection of procedures with metadata (such as number of arguments, required local variable stack frame size, etc) for each plus the QCode itself.

An "application" is an OPO file called "X.app" alongside a file "X.aif" (Application Info Format) describing the app's icons and localised name (or X.OPA on SIBO).

There are something like 280 defined opcodes, plus another 128 or so "functions" invoked with the `CallFunction` opcode. The distinction between dedicated opcode and function code appears entirely arbitrary as there are some extremely complex "opcodes" and some fairly basic functions codes. Opcodes whose numerical value doesn't fit in a single byte are expressed as opcode 255 ("NextOpcodeTable") followed by a second byte being the real code minus 256. There are no opcodes requiring more than 2 bytes to express.

Strings are limited to a maximum length of 255 bytes using a leading length byte (this was increased in Quartz, as well as making strings support UCS-2). Various other internal data structures were increased from 1 byte to 2 at the same time. Strings not part of a string array have a maxlength byte preceding the length byte - string addresses always point to the length byte. String arrays have a single maxlength byte common to all elements, immediately preceding the first string element. For this reason opcodes that operate on strings take an explicit max length parameter on the stack, since it is not possible to know a string's max length based solely on its address (you need to know whether it's in an array or not, and if so where the start of the array is).

Arrays are limited to 32767 elements (signed 16-bit) although the overall local variable size of a function is also limited to something like 16KB. The array length is stored in the 2 bytes immediately preceding the first element (in the case of number arrays) or preceding the max length byte (in the case of string arrays). Array size is statically fixed at the point of declaration and cannot be changed at runtime. Array addresses always point to the start of the first element. Arrays are not first-class values (you cannot pass an array to a proc, or assign one array to another) but some commands do accept array parameters.

## Implementation notes

This interpreter largely ignores types and specific memory layout restrictions. The stack is represented with a simple Lua table containing Lua number or string values, with no strict distinction between words/longs/floats.

Right now it runs in minimal Lua 5.3 or 5.4 with bare bones I/O support (on any OS), or as a iOS Swift app with fairly comprehensive graphics support (which uses Lua 5.4). There is also now a version using Qt for the front end.

Variables (ie, values not on the stack) are represented by a table of metatable type `Variable`. Calling `var()` gets the value, and calling `var(newVal)` sets it. In the case of array values, `Variable` also supports array indexing. Each item in the array is itself a `Variable`. To assign to the first item in an array variable, do `arrayVar[1](newVal)`.

In OpoLua v1.0 variables were represented solely by Lua data structures using `Variable` and a complex mapping and pseudo-allocator was maintained to support APIs like `ADDR()` and `PEEKB()`. In v1.1 this was rewritten (and simplified) so that all `Variables` are backed by a contiguous address space represented by `Chunk`, which allows more accurate emulation of things like out-of-bounds memory accesses which are technically undefined but many programs relied on how these behaved on real hardware. `Chunk` uses an array of Lua integers to represent the raw memory values, 4 bytes per integer. This allows the interpreter to function in pure-Lua mode while (in principle) allowing a more optimised native backing store.

This interpreter is not 100% behaviour compatible with the original Psion. The more relaxed typing will mean that code which errored on a Psion may execute fine on here. Equally, programs relying on undefined behaviour (like writing to freed memory, or abuse of the asynchronous APIs) may not run correctly. Any non-UB non-erroring program (which also doesn't rely on expecting errors to occur and trapping them) should run OK here. Except for...

**This is a work in progress!** See the next section for missing features.

## Missing features

* Various other less-common opcodes, functions and OPXes
* Not all database features are supported yet, including:
  * Sorting records with ORDER BY
  * Some databases created outside of OPL
  * Writing Psion-format databases
* Invert drawing mode
  * This is mostly done now in the Swift frontend
* Ability to suspend/resume app execution in the iOS UI
* Due to the event handling and rendering pipeline for the Qt and Swift versions being completely different, there might be some differences in how apps behave. We will try to fix bugs in both versions to the extent it is possible to do so.

## Command-line example

[simple.txt](examples/Tests/simple.txt) compiled on a Psion Series 5:

```
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

## Database format

_This is derived from [http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm](https://web.archive.org/web/20041130063903/http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm) with my own analysis added, and represents my best understanding of the format at the time of writing. Where original documentation can be found, I've used Psion terminology for preference. It's not guaranteed to be 100% perfect. -Tomsci_

The base structure of a Database file (leaving aside the layers of implementation that leads to this format) is as follows. Broadly, the file is split into various sections, which are indexed via the TOC (Table Of Contents) section. The header of the file contains the location of the TOC.

Each section (except the header) also has a 2-byte length immediately preceding it, although these lengths are not necessary to parse the format, and are not always accurate (see [paging notes](#paging)). They are more an implementation detail. There are multiple other places where exact byte meanings are not known, and don't seem to affect the ability to parse the basic data from the file.

There are two different variable-length integer encodings used, in addition to the normal fixed-length little-endian representations. The first is what [Frodo Looijaard's docs](https://frodo.looijaard.name/psifiles/Basic_Elements) call 'extra' (or X) encoding. This is `TCardinality` in Epoc source code, and is a 1, 2 or 4 byte encoding depending on the bottom bits. See `readCardinality()` in `init.lua` for the details. This project's source will use 'cardinality' to refer to this type of encoding. The second is a 1 or 2 byte encoding which I couldn't find a reference for in public Epoc sources, and is referred to elsewhere as 'special' (or S) encoding. For want of a better name I use the same, see `readSpecialEncoding()` in `init.lua`. Where types are described below, `X` and `S` are used to refer to cardinality and and special encoding respectively.

`BString` refers to a string where the first byte indicates the length, and the string data follows. `SString` is similar but the length is either 1 or 2 bytes, encoded using the 'special' encoding described above. All strings are 8-bit, in Psion default system encoding (usually CP1252).

### Header

| Offset     | Type     | Name |
| ---------- | -------- | ---- |
| `00000000` | `uint32` | `uid1` |
| `00000004` | `uint32` | `uid2` |
| `00000008` | `uint32` | `uid3` |
| `0000000C` | `uint32` | `uidChecksum` |
| `00000010` | `uint32` | `backup` |
| `00000014` | `uint32` | `handle` |
| `00000018` | `uint32` | `ref` |
| `0000001C` | `uint16` | `crc` |

`backup`, `handle` and `ref` all relate to the table of contents, or TOC.

* If `handle` is non-zero, the TOC is located at file offset `file_length - (12 + 5 * handle)`.
* Otherwise, if `handle` is zero then the TOC should be located at `ref + 20`.
* But if `ref + 20` is greater than `file_length`, then the backup TOC should be used instead, located at `(backup >> 1) + 20`.

### TOC section

| Type         | Name |
| ------------ | ---- |
| `uint32`     | `rootStreamIndex` |
| `uint32`     | `unknown` |
| `uint32`     | `count` |
| `TocEntry[]` | Array of `count` TocEntry structs follow |

`rootStreamIndex` is an index, describing which `TocEntry` points to the root stream section. For OPL-created databases this is generally always 3. The root stream section is an artifact of the frameworks used for writing database files and serves no purpose in decoding the database data.

Each `TocEntry` is 5 bytes, and contains the offset of a section, plus some flags that don't seem to be important. You must add 0x20 to `TocEntry.offset` to get the location in the file.


| Type     | Name |
| -------- | ---- |
| `byte`   | `flags` (usually zero) |
| `uint32` | `offset` (add 0x20 to get file offset) |


The TOC is treated as a one-based array. The first few entries in the TOC always seem to refer to specific sections:

```
TocEntry[1] an uninteresting section, use unknown
TocEntry[2] table definition section
TocEntry[3] rootStream, usually (also uninteresting)
TocEntry[4] first data section of first table, usually
```

Note that while `TocEntry[4]` can be used to locate the first table's data section, it is better to use `dataIndex` in the Table Definition Section because that handles multiple tables.

Other sections may appear at indexes 5 and beyond - some unknown sections, and other data sections linked from the first (see below for description of how data sections link together).

A simple TOC might look something like this (taken from the output of `dumpdb.lua --verbose`):

```
000000D9 Toc.rootStreamIndex 00000003
000000DD Toc.unknown 00000000
000000E1 Toc.count 00000005
000000E5 Toc.TocEntry[1].flags 00
000000E6 Toc.TocEntry[1].offset 00000000
000000EA Toc.TocEntry[2].flags 00
000000EB Toc.TocEntry[2].offset 0000004D
000000EF Toc.TocEntry[3].flags 00
000000F0 Toc.TocEntry[3].offset 00000017
000000F4 Toc.TocEntry[4].flags 00
000000F5 Toc.TocEntry[4].offset 000000AD
000000F9 Toc.TocEntry[5].flags 00
000000FA Toc.TocEntry[5].offset 0000009E
```

### Table definition section

As linked from the TOC entry 2.

| Type     | Name |
| -------- | ---- |
| `uint32` | `KDbmsStoreDatabase` (10000069) |
| `byte`   | nullbyte |
| `uint32` | unknown |
| `X`      | `tableCount` (TCardinality) |
| ...      | `tableCount` Tables follow |

Each `Table` is:

| Type      | Name |
| --------- | ---- |
| `SString` | `tableName` |
| `X`       | `fieldCount` (TCardinality) |
|  ...      | `fieldCount` Fields follow |
| `byte`    | unknown |
| `uint32`  | `dataIndex` |
| `byte`    | unknown |

`dataIndex` is one more than the TOC index of the starting data section for this table. I'm not sure why you have to subtract one to get the TOC index, but this seems to work on the files I've looked at. It's always possible that `dataIndex` is something else entirely that is only coincidentally correct...

Each `Field` is:

| Type      | Name |
| --------- | ---- |
| `SString` | `fieldName` |
| `byte`    | `type` |
| `byte`    | unknown |
| `byte`    | `maxLength` (only present for text fields) |

The possible values for the `type` byte, and their meanings, are listed in the [Table Data section](#table-data-section).

### Table data section

Table data sections are located by looking up the `dataIndex` field in the table definition, see previous section.

Each table data section can contain up to 16 records, as given by the count of bits in `recordBitmask`. The next data section for this table is given by `nextSectionIndex` which is an index into the TOC. It is zero if this is the last data section, that is if there are no more records for this table. The last data section may also have `nextSectionIndex` be non-zero but referring to a TOC entry whose offset is zero. As a special case, if in the first table data section (as referenced by `TocEntry[4]`) the bottom bit of `recordBitmask`, then that data section should be ignored and the data starts in the next section (as given by the first section's `nextSectionIndex`) - note this is my guess at interpreting the format, however. It depends what app created the database file, as to whether the empty first section is present or not.

| Type     | Name |
| -------- | ---- |
| `uint32` | `nextSectionIndex` |
| `uint16` | `recordBitmask` (with `n` bits set) |
| ...      | Array of `n` `recordLength` (TCardinality) |

There is a `recordLength` for each set bit in `recordBitmask`. Each `recordLength` is a variable-length `TCardinality`.

After the record length array, the data for each record follows. The record data is a repeating sequence of `fieldMask` byte, followed by 1-8 fields of data (as determined by `fieldMask`), which repeat up to the limit of `recordLength`.

| Type   | Name |
| ------ | ---- |
| `byte` | `fieldMask` |
| ...    | 1-8 fields follow |
| `byte` | another `fieldMask` |
| ...    | 1-8 more fields follow |
| ...    | _etc_ |

The order of fields is determined by the Table Definition Section. For example in a table with fields A, B and C, bit zero of `fieldMask` refers to A, bit one to B, bit two to C, and the field data would follow A then B then C. If a bit is not set in `fieldMask`, then that field data is not present (and should be considered default-initialized when read). Some field types consume an extra bit in `fieldMask` to encode their value or additional info, so it is necessary to carefully cross-reference against the table definition section when parsing `fieldMask` and the field data.

The reason for this encoding is to make records somewhat self-describing so that, for example, a record that omits some fields does not need to encode the default values.

The format of the field data (and the type byte used in the table definition section) for each field type is as follows:

| Type      | Type byte | Format |
| --------- | --------- | ------ |
| `Boolean` | `00`      | Value in next bit of `fieldMask` |
| `int8`    | `01`      | 1 byte, signed |
| `uint8`   | `02`      | 1 byte, unsigned |
| `int16`   | `03`      | 2 bytes, signed |
| `uint16`  | `04`      | 2 bytes, unsigned |
| `int32`   | `05`      | 4 bytes, signed |
| `uint32`  | `06`      | 4 bytes, unsigned |
| `int64`   | `07`      | 8 bytes, signed |
| `Float`   | `08`      | 4 bytes, IEE754 format |
| `Double`  | `09`      | 8 bytes, IEE754 format |
| `Date`    | `0A`      | 8 bytes, see below |
| `Text`    | `0B`      | `BString` |
| `Unicode` | `0C`      | Unsure, probably `BListW` or `WListW` |
| `Binary`  | `0D`      | Unsure, probably `BListB` |
| `LongText8` | `0E`    | See below |
| `LongText16` | `0F`   | Unsure, probably similar to `LongText8` |
| `LongBinary` | `10`   | See below |

Fields other than `int16`, `int32`, `Double` and `Text` are skipped over when decoded by OPL.

The `Date` type is ([apparently](https://web.archive.org/web/20041130063903/http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm); I haven't verified this myself) microseconds since 0000-01-01, applying Gregorian leap year rules from 1600 onward (ie leap century rules) and Julian leap year rules before that (ie every 4th year is a leap year). Ignoring the other nuances between the calendars. Which by my maths means divide by 1000000 and subtract `719540 * 86400` to convert to a unix-epoch (ie 1970) based date.

The `LongBinary` type consumes an additional bit in `fieldMask` - if this bit is 0, the field data is 4 bytes which is the index into the TOC of a `LongBinary` section. If the bit is 1, there is `LongBinary` data included inline as an `SString` (I think - haven't confirmed this). The `LongBinary` data itself is not documented, and is skipped over during decoding. The `LongText8` (and, presumably, `LongText16`) section behaves the same as `LongBinary`.

It is not clear to me what happens if a `Boolean`, or `Long...` field ends up as the last bit in `fieldMask`, and thus there are no more bits left to consume -- `database.lua` will error if this occurs, please report it if you encounter this.

### Paging

Database files appear to have some sort of paging scheme whereby 2 extra bytes (some sort of tag?) are inserted seemingly every 0x4000 bytes, starting from 0x4020. These bytes aren't part of the format proper and must be stripped out before any of the indexes will be correct. All the documentation above assumes these extra bytes have been removed. It's not clear to me how this paging scheme behaves, more analysis is needed.

For some reason, when the extra bytes fall within a section, that section's prefix length bytes are zeroed - which is why relying on those lengths when parsing is a bad idea (for any file longer than 0x4020 bytes, at least).

## References

Various useful resources which aided greatly in reverse-engineering the OPL and EPOC environments:

* https://github.com/opl-dev/opl-dev
* https://web.archive.org/web/20070716134804/http://3lib.ukonline.co.uk/progindex.htm
* https://web.archive.org/web/20060505220702/http://www.allaboutopl.com/wiki/OPLCommandsListing?v=kbu
* https://www.thouky.co.uk/software/psifs/sis.html
* http://www.koeniglich.de/epoc32_fileformats.txt
* https://frodo.looijaard.name/psifiles/MBM_File
* http://www.davros.org/psion/psionics/
* http://www.users.globalnet.co.uk/~datajam/opl-manual/html/opl/opchapt13.html
* https://web.archive.org/web/20041130063903/http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm

## Contributing

We invite and welcome contributions! There's a pretty comprehensive list of [issues](https://github.com/inseven/opolua/issues) to get you started, and our documentation is always in need of some care and attention.

Please recognise opolua is a labour of love, and be respectful of others in your communications. We will not accept racism, sexism, or any form of discrimination in our community.

## License

OpoLua comprises three main components:

- **OpoLua Core**
  - Lua implementation of the OPL runtime, common utilities, and integration APIs targeting various platforms and languages.
  - Licensed under the MIT License.
  - Located in the 'core' directory.

- **OpoLua iOS**
  - Swift application targeting Apple platforms (iOS, iPadOS, and macOS).
  - Licensed under the MIT License.
  - Located in the 'ios' directory.

- **OpoLua Qt**
  - C++ application targeting Windows, Mac, and Linux, using Qt.
  - Licensed under the GPLv2 or Later license.
  - Located in the 'qt' directory.

Original assets and resources (located in 'resources') remain copyright their creators and are not covered by the licenses herein.

All other material is licensed under the MIT License unless stated.

See [LICENSE](LICENSE) for full license texts.

OpoLua also depends on the following separately licensed third-party libraries and components:

- [Diligence](https://github.com/inseven/diligence), MIT License
- [Interact](https://github.com/inseven/interact), MIT License
- [Licensable](https://github.com/inseven/licensable), MIT License
- [Lua](https://www.lua.org), MIT License
- [Qt](https://doc.qt.io/qt-6/licensing.html), LGPL v3 and GPL v3
