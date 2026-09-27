---
id: '000174'
status: done
started: 2026-07-08T13:37:10-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.20
actual_hours: 0.04
---

# diagnostic virtual lines should align with buffer text

## Problem

The #173 diagnostic display fix made long-line footnote diagnostics visible by
rendering Parley-owned virtual lines from the left edge of the window. In
practice that starts the block in the gutter/line-number area, so the
`Diagnostics:` label and wrapped text are visibly misaligned with the paragraph
text.
