---
id: 000377
status: done
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T12:11:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.22
tracker:
    version: 1
    completion:
        token: close-7e0e1efcdbc2
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 0342dddacf2bd79268ec0c437ab515d28a5eddb3
        evidence_commit: 4211b6390f207b6322673352eba1cefe0e220276
        landed_commit: b390b3ff586af7d6118d46021c66ca7ff4b44cb9
kind: feature
---

# Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat

## Problem

Pair's draft nvim puts "attach an image" on Alt+i. In parley, Alt+i creates a sub-chat (branch_ref), and image paste sits on Alt+v. The operator wants one image key across both editors, and wants sub-chat creation moved to Alt+b.
