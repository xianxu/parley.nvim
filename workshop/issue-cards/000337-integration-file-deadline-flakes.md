---
id: 000337
status: working
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T16:04:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Flake: integration files exceed a load-dependent whole-file deadline

## Problem

First seen 2026-10-15 during #332 verification: three integration files passed in one full run and were killed by the harness deadline in the next full run with identical code/tests. The variable deadline reports50s x1.0 on12CPUs (loads8–10) in the failed run. This is recorded as an intermittent timing/deadline failure; cause is not established.
