---
id: 000334
status: done
created: 2026-10-15
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T15:03:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.54
tracker:
    version: 1
    completion:
        token: close-e949df1d2245
        repository: github.com/xianxu/parley.nvim
        reviewed_head: ee73224ecf92563c10999557107616e8795edb09
        evidence_commit: 872d916b2be5dd97c1ed5344976da6568a84d70c
        landed_commit: 1fb820c3c3494db149c637ae375cb9ac4b94991c
kind: feature
---

# Leaving a buffer while holding the operator lock flashes the red winbar three times (submit reminder)

## Problem

The operator holds the session-sync lock (red winbar "your turn, Alt+Return to submit") and navigates to another
buffer, e.g. via Alt+o into an answer, then forgets the lock: the agent can't write the file until they come back and
submit. The operator (2026-10-15): when leaving a buffer while holding the operator lock, stop them to submit first,
e.g. flash the winbar three times.
