---
id: 000282
status: codecomplete
created: 2026-09-26
updated: 2026-09-28
estimate_hours:
github_issue:
started: 2026-09-28T21:14:10-07:00
actual_hours: 0.48
tracker:
    version: 1
    completion:
        token: close-33b535642c70
        repository: github.com/xianxu/parley.nvim
        reviewed_head: cefca4ba14d23e69c0ce0f6582078c12cce80003
        evidence_commit: 9de982f485ca88426a6274a980d0b41a580f5e26
---

# Make each answer one undo history entry

## Problem

Streaming an assistant answer currently records many incremental buffer edits.
Undo can therefore remove individual chunks instead of reverting the answer as
one user-visible action.
