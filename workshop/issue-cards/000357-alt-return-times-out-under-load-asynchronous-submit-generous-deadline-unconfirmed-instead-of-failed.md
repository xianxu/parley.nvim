---
id: 000357
status: done
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T11:11:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.45
tracker:
    version: 1
    completion:
        token: close-1f7791ee5100
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 71341518fbb6feb4c69136b4c72d295f86e0a492
        evidence_commit: 6b21c9bdbe669ef1ee6c6200f3afd1338edf1db5
        landed_commit: 1838a8a55027064668c25901208955001d041782
kind: bug
---

# Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed

## Problem

Alt+Return times out under load. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.
- `document_registry` requests default to `timeout_ms` 2500, and `agentic_document`'s `bounded_request` blocks the editor in `vim.wait(2600)`.
- On a busy machine the couch CLI alone can take longer than that. The submit then fails as "Couch deadline exceeded", although it may still land.
