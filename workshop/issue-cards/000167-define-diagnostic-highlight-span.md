---
id: '000167'
status: done
started: 2026-07-08T10:12:09-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.91
actual_hours: 0.16
---

# define diagnostic highlight should target footnote span

## Problem

After #166, visual definitions persist as `term[^id]` plus a managed footnote.
The diagnostic record spans that text, but the visible DiffChange decoration
still highlights the whole line. In a long paragraph that makes the annotation
appear paragraph-scoped instead of scoped to the selected text plus footnote
reference.
