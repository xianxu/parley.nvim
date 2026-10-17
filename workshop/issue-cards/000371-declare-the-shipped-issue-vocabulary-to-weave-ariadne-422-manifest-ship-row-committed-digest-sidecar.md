---
id: 000371
status: working
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T06:39:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Declare the shipped issue vocabulary to weave (ariadne#422): manifest ship row, committed digest sidecar

## Problem

parley ships `construct/generated/vocabulary/issue.json` in git on purpose (#208): users install the plugin from GitHub through a plugin manager and never run weave, so the plugin reads its issue vocabulary from the installed tree. A fresh CI checkout has no weave ownership inventory (`construct/generated/weave/` is gitignored), so after any ariadne vocabulary change weave refuses the committed copy as "something weave did not write" and parley's main merge-check goes red (#321, #326, PR 285 after ariadne#415).
