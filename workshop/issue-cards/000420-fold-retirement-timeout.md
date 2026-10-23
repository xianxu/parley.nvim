---
id: 000420
status: working
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
github_issue:
started: 2026-10-23T09:28:51-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Investigate embedded fold-retirement timeout under native suite load

## Problem

A complete recorded #410 integration suite passed its preferred runtime but failed one suspended-fold retirement case on installed Neovim 0.11.7. A subsequent isolated run of the exact same case and product code passed. The precise hang cause is unproven; this is linked to the #412/#414 native timing-under-load family for investigation, not asserted to share their root cause.
