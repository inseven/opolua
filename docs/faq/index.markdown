---
title: Frequently Asked Questions
---

# FAQ

1. **Where can I find OPL programs to try out?**

   There are a number of sites with links and downloads that might be useful, and the [Internet Archive](https://archive.org) hosts copies of a number of publishers' sites that are no longer available anywhere else online.

   Here are some we've found useful:

   - [3-Lib](https://stevelitchfield.com/cdrom.htm) -- 3-Lib was always _the_ source for Psion shareware, and Steve Litchfield still sells copies of the most recent 3-Lib library CD, physical or digital.
   - [freEPOC (Internet Archive)](https://web.archive.org/web/20010517001827/http://www.freepoc.org/downloads.htm)
   - [Neuon (Internet Archive)](https://web.archive.org/web/20141011212633/http://neuon.com/downloads/) -- Neuon published a sizeable number of Psion apps and released freely available license codes for many of them at the end of their life. While some of these apps use native libraries (and therefore won't work), we've been thoroughly enjoying games like Chain Reaction and Tile Fall.
   - [5mx Software in the 21st Century](https://tobidog.com/programs.htm)

   Needless to say, this isn't a comprehensive list and we would love to hear about sites we've missed.

   _Fortunately, most OPL software was shareware and many authors have made license codes freely available after-the-fact, but please remember that downloading copies of commercial software you have not purchased is illegal. We do not encourage or condone the use of illegally obtained software._

2. **Why aren't databases supported?**

   The Psion database format is complex and unfriendly so we've decided not to try adding support for it just yet--there are a lot of programs that don't require database support and we'd like to improve our support for those before tackling this mammoth task.

   If you're a developer interested in taking on the challenge, please feel free to get in touch; we [welcome contributions and pull requests](https://github.com/inseven/opolua#contributing).

3. **How should I go about reporting problems?**

   [GitHub Issues](https://github.com/inseven/opolua/issues) are the best way for us to track and triage problems and feature requests. Please check for any existing issues before raising a new one--if you don't find one, we'd love to hear your thoughts.

   We're happy to receive issues with as much or as little information as you are able to give (something is better than nothing) but, where possible, please try to provide:

   - details of the program you were running
   - as much information as possible about what you were doing when you encountered the issue
   - specific instructions that might help us reproduce the issue
   - help on how to find the program you were running to let us test changes

4. **What OPXes are supported?**

   OPXes are native C/C++ libraries that OPL programs can use. The following built-in and commonly used OPXes are supported:

   - bmp.opx _fully supported_
   - date.opx _a few unimplemented functions_
   - sysram1.opx _common functions supported_
   - system.opx _common functions supported_
   - systinfo.opx _partial support_
