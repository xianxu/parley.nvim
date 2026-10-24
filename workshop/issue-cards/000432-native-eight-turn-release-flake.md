---
id: 000432
status: codecomplete
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408)]
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.90
tracker:
    version: 1
    completion:
        token: close-3fc520744c7f
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 4cba6ab06aa4a2115c9490f99b7a46fe6b876852
        evidence_commit: 98bd29500c89133cb40a2cb5d74179edd01418c2
---

# Native eight-turn clean release intermittently retains its lock

## Problem

One compatibility full-suite occurrence of session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408) failed at session_sync_native_spec.lua:642: clean acquisition-baseline release was not observed within the existing arrival wait. The failure is not reproduced by the bounded qualification below; its root cause remains unknown.
