---
id: '000169'
status: done
started: 2026-07-08T10:31:04-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.76
actual_hours: 0.37
---

# diagnostic display should soft-wrap words

## Problem

Parley diagnostics display in `virtual_lines`, which does not soft-wrap long
messages reliably. Review diagnostics already hard-wrap their messages through
`skill_render.wrap`, but the width policy is private to `attach_diagnostics` and
define diagnostics compute their own fixed-ish width in `render_definition`.
Long definitions or explanations can still appear as over-wide diagnostic text
instead of word-wrapped rows.
