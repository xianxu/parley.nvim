---
id: 000414
status: done
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
github_issue:
started: 2026-10-23T05:49:02-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 2.08
tracker:
    version: 1
    completion:
        token: close-1dd8df0599cb
        repository: github.com/xianxu/parley.nvim
        reviewed_head: b11e2e9ce3838fdba088932557e6425ad68b930c
        evidence_commit: 6a173e8c48f5f76045f270e75da09a2fcb285465
        landed_commit: d24a04c287b137c020baecf0e6230bdaebe29691
kind: bug
---

# Investigate registered-saveas timing flake under load

## Problem

The existing registered native saveas test intermittently exceeds its fixed elapsed-time assertion under load. The same code failed in the full session-sync mapping and passed in one isolated rerun during #410 close review. Related class: #412 (fixed-budget native timing under load); this is a separate test and must not silently inherit that case's exception.
