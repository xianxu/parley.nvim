---
id: 000436
status: codecomplete
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
actual_hours: 0.02
tracker:
    version: 1
    completion:
        token: close-e56b761e10d3
        repository: github.com/xianxu/parley.nvim
        reviewed_head: acde0888ea717bdab41bcbe2efd4549e865d2791
        evidence_commit: 80c7dc66a8c296802192c7d0173c8d68b168fe75
---

# substrate refresh: regenerated vocabulary after ariadne#576

## Problem

start-plan's catch-up runs weave refresh, which regenerates construct/generated/vocabulary/issue.json (and its .weave-sha256) from the newer ariadne: scaffold.collaboration_mode is gone. The regenerated output lands as uncommitted tracked changes on the resting branch, so every parley slot's start-plan and abandon refuse until it is on main.
