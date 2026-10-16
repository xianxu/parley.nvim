---
id: 000358
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T12:49:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 2.47
tracker:
    version: 1
    completion:
        token: close-93fe30ace220
        repository: github.com/xianxu/parley.nvim
        reviewed_head: b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d
        evidence_commit: 69e4a41287d7cc25c097f5b16945802494ca2104
---

# Keep the cursor and view across parley's own agent rewrites (file_refresh, review round edit!)

## Problem

#356 keeps each window's cursor and top line on its text across the two external-write reload paths in `session_sync`: `reload()`'s `edit!`, and the native `FileChangedShell` reload. That covers the session file and every agentic document. Two other paths also rewrite a document the operator has open, and they still keep line numbers, so the cursor jumps:
- `lua/parley/tools/file_refresh.lua`: after parley's own chat agent writes a file (the write and edit tools), it refreshes the captured buffers from the committed bytes.
- `lua/parley/skills/review/init.lua`: the review round reloads its document with `:edit!` (the projection watcher is suppressed around it).

Found by #356's close review (an advisory, ARCH-PURPOSE). It was out of #356's scope, which was session_sync.
