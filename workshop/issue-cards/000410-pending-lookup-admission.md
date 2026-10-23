---
id: 000410
status: working
created: 2026-10-21
updated: 2026-10-23
estimate_hours: 1.987
github_issue:
started: 2026-10-22T11:48:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 4.05
tracker:
    version: 1
    completion:
        token: close-2bef4fc7b48f
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 7b8452dfc3fa90be1118d1d07aac6c5881cb038b
        evidence_commit: 4f2ff92a1aad985f8fdd3de2b31d21f621013cfc
---

# Bound insert admission across pending registration lookup

## Problem

#408 fences insert admission after S1 has a confirmed registered identity. Just after opening a file with no cached identity, S1 may still be looking it up; edits in that unknown interval remain possible and are reconciled on attachment. The operator is most likely to meet that gap when immediately typing into a newly opened session file.
