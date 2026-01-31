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
