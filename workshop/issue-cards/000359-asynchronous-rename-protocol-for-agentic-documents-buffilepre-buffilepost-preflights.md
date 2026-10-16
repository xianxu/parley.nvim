---
id: 000359
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
---

# Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights)

## Problem

The rename preflights for agentic documents block the editor on a Couch round trip. They run inside `BufFilePre` and `BufFilePost` autocmds, for a `:file` or `:saveas`-style rename of a document, in `lua/parley/agentic_document.lua`:
- `bounded_request`: `register` or `lookup` in `vim.wait`;
- the destination `lookup`.

These autocmds must decide synchronously, before Neovim renames the buffer, so on a busy machine the editor freezes for the length of the wait. #357 makes the waits configurable and reports "not confirmed" instead of failing, and makes the Parley mover's own `move_path` asynchronous. It deliberately leaves this protocol alone (TL decision, 2026-10-16).
