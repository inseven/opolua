---
title: Status
---

# Status

The opolua OPL runtime is a reimplementation of the OPL language used by the EPOC Release 5 operating system. This means it differs in behaviour from the original Psion and Psion-compatible systems in some key ways--amongst other things, it implements a much stricter memory model--and some original programs may not run correctly. Right now, the largest omission is the lack of database support (see our [FAQ](/faq/)), but there are also a number of missing opcodes and commands we hope to add support for in the coming months.

This page lists the status of programs we've tested, and any known issues we are tracking. Please raise a [GitHub issue](/faq/#reporting-issues) if you encounter issues, have updates, or programs you're excited to see supported.

<table>

    <tr>
        <th>Program</th>
        <th>Author</th>
        <th>Status</th>
        <th>Comments / Issues</th>
    </tr>

    <tr>
        <td>GemTile</td>
        <td>beelogic</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>CharMap</td>
        <td>Pelican Software</td>
        <td>
            <div class="status issues">Issues</div>
        </td>
        <td>
            No native iOS clipboard integration (<a href="https://github.com/inseven/opolua/issues/205">#205</a>).
        </td>
    </tr>

    <tr>
        <td>Jumpy! Plus</td>
        <td>Jon Read</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>LogJam</td>
        <td>Adam's Software</td>
        <td>
            <div class="status broken">Not Working</div>
        </td>
        <td>
            Requires database support (<a href="https://github.com/inseven/opolua/issues/203">#203</a>).
        </td>
    </tr>

    <tr>
        <td>Mancala</td>
        <td>Neil Sands</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

    <tr>
        <td>Super Breakout</td>
        <td>Bill Walker</td>
        <td>
            <div class="status broken">Not Working</div>
        </td>
        <td>
            Missing operation (<a href="https://github.com/inseven/opolua/issues/204">#204</a>).
        </td>
    </tr>

    <tr>
        <td>Tile Fall</td>
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
        <td>Ewan Spence</td>
        <td>
            <div class="status working">Working</div>
        </td>
        <td></td>
    </tr>

</table>

_Note: All programs listed remain the property of their respective creators, owners and publishers. Inclusion in this list is for informational purposes alone and does not represent any awareness of, or endorsement of OPL for iOS or opolua by those parties. If you are the copyright owner and would like your program removed from (or included in) this list, please reach out to [support@opolua.org](mailto:support@opolua.org)._
