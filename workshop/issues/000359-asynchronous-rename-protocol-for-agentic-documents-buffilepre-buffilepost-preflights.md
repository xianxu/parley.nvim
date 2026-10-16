---
id: 000359
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '413f4e171cc1b60513455ec8e1a225212c0d621b' # card fields mirrored from issue-cards; edit via sdlc
---

# Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights)

## Problem

The rename preflights for agentic documents block the editor on a Couch round trip. They run inside `BufFilePre` and `BufFilePost` autocmds, for a `:file` or `:saveas`-style rename of a document, in `lua/parley/agentic_document.lua`:
- `bounded_request`: `register` or `lookup` in `vim.wait`;
- the destination `lookup`.

These autocmds must decide synchronously, before Neovim renames the buffer, so on a busy machine the editor freezes for the length of the wait. #357 makes the waits configurable and reports "not confirmed" instead of failing, and makes the Parley mover's own `move_path` asynchronous. It deliberately leaves this protocol alone (TL decision, 2026-10-16).

## Spec

Let the rename proceed without waiting, and reconcile the registry afterwards. The registry move is recorded as pending, and confirmed or reported once Couch answers. This is a change to the move protocol: the window between the editor's rename and the registry's must be safe. No agent write goes to the old path, and no lock is lost.

## Done when

- A `:saveas` or `:file` rename of an agentic document never blocks in `vim.wait`.
- The registry ends up renamed, or the operator sees one recovery action.
- Tests use a slow fake Couch registry.

## Plan

- [ ]

## Log

### 2026-10-16
