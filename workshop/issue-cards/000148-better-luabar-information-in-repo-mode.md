---
id: '000148'
status: done
started: 2026-06-27T11:51:31-07:00
created: 2026-06-27
updated: 2026-06-27
estimate_hours: 1.0
actual_hours: 0.09
---

# better luabar information in repo mode

## Problem

Repo mode supports development and we can have more compact information display on the luabar. basically whenever parley is in repo mode we use display those information:

[mode][repo][branch][repo-status]          [file-type]|[repo-mode][line-percent][line-location]
INSERT parley.nvim:main[*]                 ...
