---
id: '000176'
status: done
started: 2026-07-08T14:02:53-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.36
actual_hours: 0.10
---

# footnote diagnosis should display in centered float

## Problem

Virtual-line diagnostics cannot render directly under a soft-wrapped screen row.
For footnote definitions, the desired effect is closer to an automatically
managed diagnostic float: while the cursor is on the term/`[^footnote]` anchor,
show the definition in a centered floating window like the built-in diagnostic
float, sized to most of the editing window.
