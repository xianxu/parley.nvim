---
id: 000446
status: working
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/file_history_spec.lua#per-window file Back (#333) copies the parent's history into a split and keeps later cursors and visits independent]
started: 2026-10-25T16:34:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# file_history split-history case stalls to the absolute deadline under load

## Problem

tests/integration/file_history_spec.lua hit the spec runner's 200 s absolute deadline under load. Its 24th case, 'per-window file Back (#333) copies the parent's history into a split and keeps later cursors and visits independent', made no progress for 138 s after 23 cases completed. The case is fully synchronous: edit, vsplit, set the cursor, FileBack. It has no waits and no child process. The spec normally takes about 67 s.

This is the class ariadne#622 swept in ariadne: a wall-clock bound that fails under machine load rather than on a defect.
