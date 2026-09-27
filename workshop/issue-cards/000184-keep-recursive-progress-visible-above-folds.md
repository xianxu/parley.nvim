---
id: '000184'
status: done
started: 2026-07-13T14:51:27-07:00
created: 2026-07-13
updated: 2026-07-13
estimate_hours: 1.50
actual_hours: 2.03
---

# Keep recursive progress visible above folds

## Problem

After a client-side tool round, Parley starts the next LLM leg with its progress
extmark anchored to the last line of the final tool-result block. Tool results
are immediately closed into manual folds. Neovim does not render a virtual line
whose anchor is hidden inside a closed fold, so recursive generation can remain
visibly idle even though the pending session and spinner are active. The #183
regression asserts the extmark's semantic end row but does not assert that the
row is outside the closed fold, and therefore codifies the invisible placement.
