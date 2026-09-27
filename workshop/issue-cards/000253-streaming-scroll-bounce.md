---
id: '000253'
status: done
started: 2026-09-14T13:32:30-07:00
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.83
actual_hours: 0.56
---

# Streaming fold updates bounce the viewport during scrolling

## Problem

Mouse-wheel scrolling toward the streaming tip sometimes bounces back until generation finishes. Reproduced in an attached Neovim UI: fold maintenance changes cursor170/topline160 to170/157, and a second split105to97, even without cursor-follow. Plain headless tests miss this redraw behavior. Separately, smoothscroll plus a long wrapped pending line reaches col2960/skipcol2880 by wheel, then next token resets col0/skipcol0.
