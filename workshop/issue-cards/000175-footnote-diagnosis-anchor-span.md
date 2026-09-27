---
id: '000175'
status: done
started: 2026-07-08T13:46:25-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.24
actual_hours: 0.05
---

# footnote diagnosis should open only on anchor span

## Problem

Parley's custom diagnostic virtual-line display currently opens a footnote
diagnosis whenever the cursor is anywhere on the logical line containing the
diagnostic span. In wrapped prose that is too broad: the diagnosis should appear
only while the cursor is on the selected term / `[^footnote]` anchor span. The
block also needs a small visual inset from the paragraph text column.
