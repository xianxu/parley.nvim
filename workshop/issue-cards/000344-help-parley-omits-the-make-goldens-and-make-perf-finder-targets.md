---
id: 000344
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T00:15:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.01
tracker:
    version: 1
    completion:
        token: close-7e51721f0d51
        repository: github.com/xianxu/parley.nvim
        reviewed_head: b3ce489106e4353652201bb9cfaa3b396edb8b6e
        evidence_commit: 9b096e3c3c61a60a0144fd89d30d5630690fb8a4
---

# help-parley omits the make goldens and make perf-finder targets

## Problem

`make help-parley` does not list the `make goldens` and `make perf-finder` targets that #342 added (an advisory Minor from #342's close review).
