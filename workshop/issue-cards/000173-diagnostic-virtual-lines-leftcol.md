---
id: '000173'
status: done
started: 2026-07-08T13:21:02-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.38
actual_hours: 0.14
---

# diagnostic virtual lines blank on long wrapped markdown

## Problem

After #172, managed markdown footnotes are correctly restored as diagnostics,
but their inline virtual-line display can look blank on long wrapped markdown
paragraphs. The diagnostic payload is present and floats display it, but
Neovim's built-in `virtual_lines` handler prefixes the rendered message with
spaces equal to the diagnostic byte column. On a long prose line, the selected
text may be visible on a wrapped screen row while the virtual-line message starts
far to the right outside the viewport.
