---
id: '000172'
status: done
started: 2026-07-08T11:38:22-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.94
actual_hours: 0.35
---

# display markdown footnotes as diagnostics

## Problem

Define stores durable markdown footnotes such as `ASIN[^asin]` plus a final
managed footer line `[^asin]: Amazon Standard Identification Number.`. The
diagnostic displayed immediately after define is ephemeral Neovim state. After
leaving and reentering a chat buffer, or opening any markdown buffer containing
the same managed footnotes, the footnote remains in the file but no diagnostic
is recreated.
