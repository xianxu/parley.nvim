---
id: 000437
status: wontfix
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
card_mirror: '875a7fac9c251415b4f5a454b3bcb3b1e678b9ee' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T23:12:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/lock_leave_reminder_spec.lua#lock leave reminder cancels on window close and ignores a late tick]
---

# Lock leave reminder window-close case gets no pulse when the first-edit operator acquire fails

## Problem

lock_leave_reminder_spec.lua "lock leave reminder cancels on window close and ignores a late tick" failed once in the recorded suite: on #436's head a703d593 (attempt 3e28d2cc27d2d3aa04cd71d4d46fc014, log under .git/sdlc/test-stats/failed/), pulse()'s 15 s arrival.MS wait for a pulse timer returned false (spec lines 7 and 12, called from 166). The other 17 cases in the file passed. #436 changes only generated vocabulary JSON that no Lua reads. Afterwards the modes/session_sync mapping passed 4 of 4 serially, unsandboxed, with 18 of 18 lock-reminder cases each run. (Sandboxed runs fail almost every case in the file; they are not evidence.)

## Spec

Mechanism, read from the code. No pulse means document_band.flash was never called. session_sync's BufLeave/WinLeave handler flashes only while outstanding() holds, and that needs read_turn(buf) == "operator". The test's edit() reaches take_turn → acquire_registered → couch.operator_lock, which runs a synchronous vim.system(couch --session-sync operator-acquire …, { timeout = OPERATOR_LOCK_TIMEOUT_MS = 500 }):wait(500) against the Python fake. If that acquire does not come back acquired, take_turn returns, the turn stays free, nothing is outstanding, and the 15 s wait times out exactly as observed.

Why the acquire would fail, two candidates:
1. The #421 stale-loop-clock class. Neovim 0.11's vim.system starts its timeout with a raw uv timer_oneshot right after the synchronous spawn (runtime lua/vim/_system.lua:265, no update_time), so under load the 500 ms kill can fire at once, before the fake answers. Parley's helper.start_deadline and the tests/arch deadline lint cannot see this: the timer is inside Neovim's runtime.
2. A plain 500 ms budget overrun: Python fake startup under full-suite load exceeding half a second.

Both end in the same refused/unavailable acquire. Telling them apart is the first step: block the loop (tests/helpers/loop_clock.block) just before edit() and see whether the acquire fails at once, then measure the fake's startup under capped load.

## Done when

- The failing ordering is reproduced, the cause is named (stale clock vs real budget), and the fix is at the cause: for example the acquire budget measured from a refreshed clock, or the non-deadline acquire in this test using arrival.MS. A regression covers it, the case is unregistered, and its evidence is in the Log.

## Plan

## Log


- 2026-10-24: abandoned (wontfix): fixed in parley.nvim#431 (PR 348, merge 58228d3d): stale-clock vim.system kill of the operator acquire; regression in lock_leave_reminder_spec
