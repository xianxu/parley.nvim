---
id: '000165'
status: done
started: 2026-07-08T08:23:50-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 1.00
actual_hours: 0.11
---

# visual selection definition search should anchor at right column

## Problem

`define_visual` preserves the selected phrase and wraps that exact span in
`[term]`, but `render_definition` attaches the resulting diagnostic at column
zero with no end column. For a selected term inside a paragraph, the definition
diagnostic is therefore anchored to the line/paragraph instead of the visual
selection that triggered the lookup.
