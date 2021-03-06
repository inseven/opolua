---
title: Status
---

# Status

## Files

OPL provides read-only support for the following file types:

- [AIF resources](http://fileformats.archiveteam.org/wiki/EPOC_AIF)
- [MBM images](http://fileformats.archiveteam.org/wiki/EPOC_MBM)
- OPL files
- Sound files

## Programs

The OpoLua OPL runtime is a reimplementation of the OPL language used by the EPOC Release 5 operating system. This means it differs in behaviour from the original Psion and Psion-compatible systems in some key ways--amongst other things, it implements a much stricter memory model--and some original programs may not run correctly. Right now, the largest omission is the lack of database support (see our [FAQ](/faq/)), but there are also a number of missing opcodes and commands we hope to add support for in the coming months.

This page lists the status of programs we've tested, and any known issues we are tracking. Please raise a [GitHub issue](/faq/#reporting-issues) if you encounter issues, have updates, or programs you're excited to see supported.

<table>

    <tr>
        <th>Program</th>
        <th>Version</th>
        <th>Author</th>
        <th>Status</th>
        <th>Comments / Issues</th>
    </tr>

    <tr>
        <td>CharMap</td>
        <td></td>
        <td>Pelican Software</td>
        <td>
            <div class="status issues">Issues</div>
        </td>
        <td>
            No native iOS clipboard integration (<a href="https://github.com/inseven/opolua/issues/205">#205</a>).
        </td>
    </tr>

    <tr>
        <td>Dark Horizon</td>
        <td>1.21</td>
        <td>JS Greenwood & Pocket IQ</td>
        <td>
            <div class="status broken">Broken</div>
        </td>
        <td>
            Redraw issues (<a href="https://github.com/inseven/opolua/issues/121">#121</a>).<br />
            Fails to open after first run (<a href="https://github.com/inseven/opolua/issues/213">#213</a>).
        </td>
    </tr>

    <tr>
        <td>GemTile</td>
        <td></td>
        <td>beelogic</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>Jumpy! Plus</td>
        <td></td>
        <td>Jon Read</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>LogJam</td>
        <td></td>
        <td>Adam's Software</td>
        <td>
            <div class="status broken">Broken</div>
        </td>
        <td>
            Requires database support (<a href="https://github.com/inseven/opolua/issues/203">#203</a>).
        </td>
    </tr>

    <tr>
        <td>Mancala</td>
        <td></td>
        <td>Neil Sands</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>Super Breakout</td>
        <td></td>
        <td>Tim Rohrer</td>
        <td>
            <div class="status broken">Broken</div>
        </td>
        <td>
            Redraw issues (<a href="https://github.com/inseven/opolua/issues/121">#121</a>).
        </td>
    </tr>

    <tr>
        <td>Tile Fall</td>
        <td></td>
        <td>Adam Dawes & Neuon</td>
        <td>
            <div class="status issues">Issues</div>
        </td>
        <td>
            Help menu item doesn't work (<a href="https://github.com/inseven/opolua/issues/202">#202</a>).
        </td>
    </tr>

    <tr>
        <td>Vexed</td>
        <td></td>
        <td>Ewan Spence</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

</table>

_Note: All programs listed remain the property of their respective creators, owners and publishers. Inclusion in this list is for informational purposes alone and does not represent any awareness of, or endorsement of OPL for iOS or OpoLua by those parties. If you are the copyright owner and would like your program removed from (or included in) this list, please reach out to [support@opolua.org](mailto:support@opolua.org)._
