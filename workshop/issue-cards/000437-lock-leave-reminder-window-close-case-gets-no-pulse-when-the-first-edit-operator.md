---
id: 000437
status: wontfix
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/lock_leave_reminder_spec.lua#lock leave reminder cancels on window close and ignores a late tick]
started: 2026-10-23T23:12:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
tracker:
    version: 1
    abandoned: {}
kind: bug
---

# Lock leave reminder window-close case gets no pulse when the first-edit operator acquire fails

## Problem

lock_leave_reminder_spec.lua "lock leave reminder cancels on window close and ignores a late tick" failed once in the recorded suite: on #436's head a703d593 (attempt 3e28d2cc27d2d3aa04cd71d4d46fc014, log under .git/sdlc/test-stats/failed/), pulse()'s 15 s arrival.MS wait for a pulse timer returned false (spec lines 7 and 12, called from 166). The other 17 cases in the file passed. #436 changes only generated vocabulary JSON that no Lua reads. Afterwards the modes/session_sync mapping passed 4 of 4 serially, unsandboxed, with 18 of 18 lock-reminder cases each run. (Sandboxed runs fail almost every case in the file; they are not evidence.)
