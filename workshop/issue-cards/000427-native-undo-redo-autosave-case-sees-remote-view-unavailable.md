---
id: 000427
status: codecomplete
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: ["lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: open autosave=true", "lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: watch autosave=true"]
started: 2026-10-24T10:09:05-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.49
tracker:
    version: 1
    completion:
        token: close-e8b5ec0909cb
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 05be4ebadddea40cf7885e4cf4fadc780516ff0d
        evidence_commit: 896fbad6bcd40d0601ba6af4aedd2b45bab4c17e
---

# Native undo/redo autosave case sees Remote view unavailable

## Problem

`tests/integration/session_sync_native_spec.lua`, case `session-sync native edits undo releases acquisition baseline, redo retakes: open autosave=true`, failed once at :1593. The notice list held 'Remote view unavailable; reopen the file to retry' where the test expected none.
