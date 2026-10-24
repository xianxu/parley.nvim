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
actual_hours: 1.51
tracker:
    version: 1
    completion:
        token: close-ce140245a7dd
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 604649db4857d4827ad09eb73327935bcd62058a
        evidence_commit: aa5f1497e6c99df5f4e3674df3d23f0794c939fe
---

# Native eight-turn clean release intermittently retains its lock

## Problem

One compatibility full-suite occurrence of session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408) failed at session_sync_native_spec.lua:642: clean acquisition-baseline release was not observed within the existing arrival wait. The failure is not reproduced by the bounded qualification below; its root cause remains unknown.
