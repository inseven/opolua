---
title: Releases
---

# Releases

{% for release in releases -%}
## {% if release.is_released %}<a href="https://github.com/inseven/opolua/releases/tag/{{ release.version }}">{{ release.version }}</a>{% else %}{{ release.version }} (Unreleased){% endif %}
{% for section in release.sections -%}
{% for change in section.changes | reverse -%}
- {% if change.scope %}{{ change.scope }}: {% endif %}{{ change.description | regex_replace("\\s+\\(#(\\d+)\\)$", "") }}
{% endfor %}{% endfor %}
{% endfor %}
