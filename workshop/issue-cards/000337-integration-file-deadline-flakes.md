---
id: 000337
status: codecomplete
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
actual_hours: 0.90
tracker:
    version: 1
    completion:
        token: close-132e3661d3e9
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 013b81fccc9f2153a1202fff33c01460106e1f15
        evidence_commit: 227eb310770fe838bf6e3b5fc9f8dd7def78f278
---

# Flake: integration files exceed a load-dependent whole-file deadline

## Problem

First seen 2026-10-15 during #332 verification: three integration files passed in one full run and were killed by the harness deadline in the next full run with identical code/tests. The variable deadline reports50s x1.0 on12CPUs (loads8–10) in the failed run. This is recorded as an intermittent timing/deadline failure; cause is not established.
