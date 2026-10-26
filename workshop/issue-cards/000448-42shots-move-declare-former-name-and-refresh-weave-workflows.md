---
id: 000448
status: open
created: 2026-10-26
updated: 2026-10-26
estimate_hours:
github_issue:
started: 2026-10-26T11:00:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/42shots/parley.nvim
---

# 42shots move: declare former name and refresh weave workflows

## Problem

parley.nvim moved to github.com/42shots/parley.nvim (the 42shots move, phase C). sdlc refuses to match records made before the move unless the repository declares its former name (ariadne#644). Separately, CI on weave pins older than ariadne#641 goes red (ariadne#646), so no landing can pass until the seeded workflows are refreshed.
