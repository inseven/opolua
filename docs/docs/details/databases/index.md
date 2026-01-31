---
title: Databases
toc: true
shows_title: true
---

# Database Format


> [!NOTE]
> This is derived from [http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm](https://web.archive.org/web/20041130063903/http://home.t-online.de/home/thomas-milius/Download/Documentation/EPCDB.htm) with my own analysis added, and represents my best understanding of the format at the time of writing. Where original documentation can be found, I've used Psion terminology for preference. It's not guaranteed to be 100% perfect. _---Tomsci_

The base structure of a Database file (leaving aside the layers of implementation that leads to this format) is as follows. Broadly, the file is split into various sections, which are indexed via the TOC (Table Of Contents) section. The header of the file contains the location of the TOC.

Each section (except the header) also has a 2-byte length immediately preceding it, although these lengths are not necessary to parse the format, and are not always accurate (see [paging notes](#paging)). They are more an implementation detail. There are multiple other places where exact byte meanings are not known, and don't seem to affect the ability to parse the basic data from the file.

There are two different variable-length integer encodings used, in addition to the normal fixed-length little-endian representations. The first is what [Frodo Looijaard's docs](https://frodo.looijaard.name/psifiles/Basic_Elements) call 'extra' (or X) encoding. This is `TCardinality` in Epoc source code, and is a 1, 2 or 4 byte encoding depending on the bottom bits. See `readCardinality()` in `init.lua` for the details. This project's source will use 'cardinality' to refer to this type of encoding. The second is a 1 or 2 byte encoding which I couldn't find a reference for in public Epoc sources, and is referred to elsewhere as 'special' (or S) encoding. For want of a better name I use the same, see `readSpecialEncoding()` in `init.lua`. Where types are described below, `X` and `S` are used to refer to cardinality and and special encoding respectively.

`BString` refers to a string where the first byte indicates the length, and the string data follows. `SString` is similar but the length is either 1 or 2 bytes, encoded using the 'special' encoding described above. All strings are 8-bit, in Psion default system encoding (usually CP1252).

## Header

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

## TOC section

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

## Table definition section

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

## Table data section

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

## Paging

Database files appear to have some sort of paging scheme whereby 2 extra bytes (some sort of tag?) are inserted seemingly every 0x4000 bytes, starting from 0x4020. These bytes aren't part of the format proper and must be stripped out before any of the indexes will be correct. All the documentation above assumes these extra bytes have been removed. It's not clear to me how this paging scheme behaves, more analysis is needed.

For some reason, when the extra bytes fall within a section, that section's prefix length bytes are zeroed - which is why relying on those lengths when parsing is a bad idea (for any file longer than 0x4020 bytes, at least).

