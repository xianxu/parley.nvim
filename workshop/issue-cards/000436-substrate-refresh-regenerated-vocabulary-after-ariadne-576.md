---
id: 000436
status: working
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
started: 2026-10-23T21:43:04-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# substrate refresh: regenerated vocabulary after ariadne#576

## Problem

start-plan's catch-up runs weave refresh, which regenerates construct/generated/vocabulary/issue.json (and its .weave-sha256) from the newer ariadne: scaffold.collaboration_mode is gone. The regenerated output lands as uncommitted tracked changes on the resting branch, so every parley slot's start-plan and abandon refuse until it is on main.
