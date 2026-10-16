---
id: 000340
status: done
created: 2026-10-15
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-15T23:44:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.46
tracker:
    version: 1
    completion:
        token: close-a1142debbb32
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 426c2054ab1cf82030d0e9fceb8f910afa3e2b2a
        evidence_commit: 9f143862186c847af19b9081f8bdba945c3d463a
        landed_commit: bbaea2146fb6d8f0ff85d88351c252e09c4dc2b8
---

# Credential-health persistent-404 test times out in the required suite

## Problem

The required suite for #332 completed every recipe but failed one unchanged cliproxy lifecycle case. First seen 2026-10-15 in run acebcf70a6676a7e2e96ef8c6624e95a, on pushed code b5de7d2b4c3d336679135d016baeb58654f262aa. This is independent of the agentic document changes and should be fixed from main.
