---
id: '000150'
status: done
started: 2026-06-27T12:17:27-07:00
created: 2026-06-27
updated: 2026-06-27
estimate_hours: 0.85
actual_hours: 0.08
---

# tighten repo-mode luabar display

## Problem

Repo-mode luabar still spends space on labels that are redundant in a repo
checkout: the full path/current file consumes width, and the shortened branch
label drops the separator that makes SDLC issue IDs read like a prefix.
