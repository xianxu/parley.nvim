---
id: 000344
status: working
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
---

# help-parley omits the make goldens and make perf-finder targets

## Problem

`make help-parley` does not list the `make goldens` and `make perf-finder` targets that #342 added (an advisory Minor from #342's close review).
