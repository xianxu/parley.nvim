---
id: '000179'
status: done
started: 2026-07-09T10:52:37-07:00
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.31
actual_hours: 0.09
---

# structured footnote anchor spans

## Problem

Reloaded definition footnotes can show the floating definition window, but the
span highlight is only reliable for the current single-token inference before
`[^id]`. Multi-word terms such as `Advertising Cost of Sales[^acos]` collapse to
`Sales[^acos]`, and users need a markup-light way to persist the intended anchor
span across reloads.
