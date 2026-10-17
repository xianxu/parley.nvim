---
id: 000359
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T12:52:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 5.04
tracker:
    version: 1
    completion:
        token: close-ea37c339a4e6
        repository: github.com/xianxu/parley.nvim
        reviewed_head: aae97db73b9403cb42264d9f7e39a5e40d877513
        evidence_commit: 0dcbb1b4116dd59b1632ca8973a414a6a10a9139
---

# Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights)

## Problem

The rename preflights for agentic documents block the editor on a Couch round trip. They run inside `BufFilePre` and `BufFilePost` autocmds, for a `:file` or `:saveas`-style rename of a document, in `lua/parley/agentic_document.lua`:
- `bounded_request`: `register` or `lookup` in `vim.wait`;
- the destination `lookup`.

These autocmds must decide synchronously, before Neovim renames the buffer, so on a busy machine the editor freezes for the length of the wait. #357 makes the waits configurable and reports "not confirmed" instead of failing, and makes the Parley mover's own `move_path` asynchronous. It deliberately leaves this protocol alone (TL decision, 2026-10-16).
