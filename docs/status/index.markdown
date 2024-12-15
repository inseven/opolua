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

<table id="s" class="stripe" style="width: 100%">
    <thead>
        <tr>
            <th>Program</th>
            <th>Version</th>
            <th>Author</th>
            <th>Status</th>
            <th>Comments / Issues</th>
        </tr>
    </thead>
        <tbody>
        {% for program in site.data.status %}
            <tr>
                <td>
                    {% if program.url %}
                        <a href="{{ program.url }}">{{ program.name }}</a>
                    {% else %}
                        {{ program.name }}
                    {% endif %}
                </td>
                <td>
                    {{ program.version }}
                </td>
                <td>
                    {{ program.author }}
                </td>
                <td>
                    {% if program.status == "working" %}
                        <div class="status working" alt="Working in OpoLua {{ program.opolua }}" title="Working in OpoLua {{ program.opolua }}">{{ program.opolua }}</div>
                    {% elsif program.status == "issues" %}
                        <div class="status issues" alt="Issues in OpoLua {{ program.opolua }}" title="Issues in OpoLua {{ program.opolua }}">{{ program.opolua }}</div>
                    {% elsif program.status == "broken" %}
                        <div class="status broken" alt="Broken in OpoLua {{ program.opolua }}" title="Broken in OpoLua {{ program.opolua }}">{{ program.opolua }}</div>
                    {% else %}
                        <div class="status" alt="{{ program.status }} in OpoLua {{ program.opolua }}" title="{{ program.status }} in OpoLua {{ program.opolua }}">{{ program.opolua }}</div>
                    {% endif %}
                </td>
                <td>
                    {{ program.comments }}
                </td>
            </tr>
        {% endfor %}
    </tbody>
</table>

<script>
    new DataTable('#s', {
      scrollX: true
  });
</script>

_Note: All programs listed remain the property of their respective creators, owners and publishers. Inclusion in this list is for informational purposes alone and does not represent any awareness of, or endorsement of OPL for iOS or OpoLua by those parties. If you are the copyright owner and would like your program removed from (or included in) this list, please reach out to [support@opolua.org](mailto:support@opolua.org)._
