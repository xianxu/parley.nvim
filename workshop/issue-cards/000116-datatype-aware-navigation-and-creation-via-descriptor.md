---
id: '000116'
status: done
created: 2026-04-30
updated: 2026-06-30
estimate_hours: 2.8
actual_hours: 7.83
---

# datatype-aware navigation and creation via descriptor

## Problem

#115 narrows `<C-g>m` to find datatype artifacts. This issue is the broader follow-up: make parley.nvim a first-class client of ariadne's datatype system, on both the read side (typed pickers) and the write side (template scaffolding for human-driven creation).

Background context: [pensive on parley/datatype duality](../../../ariadne/docs/vision/2026-04-30-01-pensive-parley-datatype-duality.md).
