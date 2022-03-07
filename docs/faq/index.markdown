---
title: Frequently Asked Questions
---

# FAQ

1. [How do I install OPL programs?](#installing-programs)
1. [Where can I find OPL programs to try out?](#finding-programs)
2. [Why aren't databases supported?](#database-support)
3. [How should I go about reporting problems?](#reporting-issues)
4. [What OPX libraries are supported?](#opx-support)
5. [Why do the graphics sometimes look wrong?](#invert-draw-mode)

---

<a id="installing-programs"></a>

## How do I install programs?

OPL supports open-in-place for Psion installers (SIS files), allowing you to install programs directly from iCloud Drive using the Files app on your iPhone or iPad.

1. Add the installer to iCloud Drive, or download it directly to your iPhone.

2. Navigate to the installer in the iOS Files app, and tap on the installer (`JUMPY!.SIS` in the example):

   <img class="inline-screenshot" srcset="/images/install-1.png 3x">

3. Select the destination you'd like to install your program to and tap 'Next':

   <img class="inline-screenshot" srcset="/images/install-2.png 3x">

4. If everything has gone to plan 🤞, you should see a summary screen displaying the icon of your newly installed program:

   <img class="inline-screenshot" srcset="/images/install-3.png 3x">

   Tap 'Done' to reveal the program in OPL.

5. Tap the program icon to run it:

   <img class="inline-screenshot" srcset="/images/install-4.png 3x">

If you don't have an installer for the program and only have eg a ZIP of the app directory, you will have to manually construct the correct filesystem layout to be recognized as an program bundle, copy that bundle to eg an iCloud Drive location, then add that location to OpoLua using the "+" toolbar item on the Library screen. The correct layout for an OPL program bundle is:

```
<appname>.system
|- c
   |- System
      |- Apps
         |- <appname>
            | files for the app go here, such as <appname>.app, <appname>.aif etc
```

You must make a separate bundle for each program; installing multiple programs in a single bundle is not currently supported.

<a id="finding-programs"></a>

## Where can I find OPL programs to try out?

There are a number of sites with links and downloads that might be useful, and the [Internet Archive](https://archive.org) hosts copies of a number of publishers' sites that are no longer available anywhere else online.

Here are some we've found useful:

- [3-Lib](https://stevelitchfield.com/cdrom.htm) -- 3-Lib was always _the_ source for Psion shareware, and Steve Litchfield still sells copies of the most recent 3-Lib library CD, physical or digital.
- [freEPOC (Internet Archive)](https://web.archive.org/web/20010517001827/http://www.freepoc.org/downloads.htm)
- [Neuon (Internet Archive)](https://web.archive.org/web/20141011212633/http://neuon.com/downloads/) -- Neuon published a sizeable number of Psion apps and released freely available license codes for many of them at the end of their life. While some of these apps use native libraries (and therefore won't work), we've been thoroughly enjoying games like Chain Reaction and Tile Fall.
- [5mx Software in the 21st Century](https://tobidog.com/programs.htm)

Needless to say, this isn't a comprehensive list and we would love to hear about sites we've missed.

_Fortunately, most OPL software was shareware and many authors have made license codes freely available after-the-fact, but please remember that downloading copies of commercial software you have not purchased is illegal. We do not encourage or condone the use of illegally obtained software._

<a id="database-support"></a>

## Why aren't databases supported?

The Psion database format is complex and unfriendly so we've decided not to try adding support for it just yet--there are a lot of programs that don't require database support and we'd like to improve our support for those before tackling this mammoth task. We're tracking this as issue [#203](https://github.com/inseven/opolua/issues/203).

If you're a developer interested in taking on the challenge, please feel free to get in touch; we [welcome contributions and pull requests](https://github.com/inseven/opolua#contributing).

<a id="reporting-issues"></a>

## How should I go about reporting problems?

[GitHub Issues](https://github.com/inseven/opolua/issues) are the best way for us to track and triage problems and feature requests. Please check for any existing issues before raising a new one--if you don't find one, we'd love to hear your thoughts.

We're happy to receive issues with as much or as little information as you are able to give (something is better than nothing) but, where possible, please try to provide:

- details of the program you were running
- as much information as possible about what you were doing when you encountered the issue
- specific instructions that might help us reproduce the issue
- help on how to find the program you were running to let us test changes

<a id="opx-support"></a>

## What OPX libraries are supported?

OPX libraries are native C/C++ libraries that OPL programs can use. The following built-in and commonly used OPX libraries are supported:

- **bmp.opx** -- fully supported
- **date.opx** -- a few unimplemented functions
- **sysram1.opx** -- common functions supported
- **system.opx** -- common functions supported
- **systinfo.opx** -- partial support

<a id="invert-draw-mode"></a>

## Why do the graphics sometimes look wrong?

We don't currently fully support invert draw mode, meaning that programs that make use of this (often to improve performance or simulate transparency) will look a little strange. We're tracking this on GitHub as issue [#121](https://github.com/inseven/opolua/issues/121).

You can see this issue clearly in Asteroids by Phil Gooch & Neuon, which uses this mode to draw the asteroids:

<img class="program-screenshot" alt="Screenshot of Asteroids running in OPL for iOS" src="/images/asteroids.png">
