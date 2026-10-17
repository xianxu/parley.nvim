---
id: 000354
status: done
created: 2026-10-16
updated: 2026-10-16
estimate_hours: 3.39
github_issue:
started: 2026-10-16T11:20:37-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 3.60
tracker:
    version: 1
    completion:
        token: close-62492606112a
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 57c581887b9cb89eec44d9e4c2e004128982750a
        evidence_commit: 01bec5e31bbb99556e070ae2737ccde44f76542e
        landed_commit: d5660d82fa60494875b2ab98e910e85c97db9491
---

# Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb

## Problem

The operator uses Alt+o and Alt+Return as an attention pipeline: read, comment, submit, move on. Nothing brings them
back when the agent answers a submitted file. Operator design, 2026-10-16 (ops QA
`teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`). Part of ops project universal-agent-input-interface.
