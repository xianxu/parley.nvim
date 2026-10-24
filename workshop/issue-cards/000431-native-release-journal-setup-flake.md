---
id: 000431
status: codecomplete
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-new/before-restore (#404), lua:tests/integration/session_sync_native_spec.lua#session-sync native edits detaches without unlocking and preserves user option overrides]
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: N/A
tracker:
    version: 1
    completion:
        token: close-14171b141bfb
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 838d439028664564b76a616cc5fcea7df4b0a55e
        evidence_commit: f7475a9fece770098e1e9275c479a21450ea9a38
---

# Native release-journal test intermittently loses its setup lock

## Problem

The native session-sync test retained release journal respects current intent at after-new/before-restore (#404) intermittently cannot open status.md.lock while setting up its asserted journal/intent state. The original error is line1238, Error executing lua: io.open/assert: No such file or directory. This is a separate case from the8-turn release failure being classified for #418.
