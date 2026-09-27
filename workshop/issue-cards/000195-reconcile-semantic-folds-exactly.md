---
id: '000195'
status: done
started: 2026-07-17T20:56:40-07:00
created: 2026-07-17
updated: 2026-07-18
estimate_hours: 3.5
actual_hours: 6.56
---

# Reconcile semantic folds exactly

## Problem

Semantic folds are calculated from `exchange_model`, but the Neovim adapter
only adds manual folds. When streaming changes a block from one semantic shape
to another, Neovim can shrink the old manual fold onto an adjacent blank line;
Parley then adds the new fold without retiring the old one. The result is a
ghost empty-line fold below a valid summary fold.

Clearing every manual fold is not acceptable because operators may create
their own folds. Recomputing every exchange after each streamed chunk is also
unnecessary: the response and tool-loop paths already know which exchange
changed.
