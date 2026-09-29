---
id: 000282
status: codecomplete
created: 2026-09-26
updated: 2026-09-28
estimate_hours:
github_issue:
started: 2026-09-28T21:14:10-07:00
actual_hours: 1.03
tracker:
    version: 1
    completion:
        token: close-967b91a76550
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 5ad0ab93d21f3e01c1bbe9f5cfb21bfd4614b333
        evidence_commit: d1be3fee12c80d5e40c50021fbe194f3d3b1bc84
---

# Make each answer one undo history entry

## Problem

Streaming an assistant answer currently records many incremental buffer edits.
Undo can therefore remove individual chunks instead of reverting the answer as
one user-visible action.
