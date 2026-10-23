---
id: 000414
status: working
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
---

# Investigate registered-saveas timing flake under load

## Problem

The existing registered native saveas test intermittently exceeds its fixed elapsed-time assertion under load. The same code failed in the full session-sync mapping and passed in one isolated rerun during #410 close review. Related class: #412 (fixed-budget native timing under load); this is a separate test and must not silently inherit that case's exception.
