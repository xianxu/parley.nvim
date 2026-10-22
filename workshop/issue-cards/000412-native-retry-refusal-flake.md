---
id: 000412
status: working
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
github_issue:
started: 2026-10-22T12:53:55-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Investigate native o-retry refusal flake on Neovim 0.11

## Problem

During #410 verification, Neovim 0.11.7 intermittently failed the existing `session-sync native edits retries refused admission with native o entry (#408 retry)` case in `tests/integration/session_sync_native_spec.lua`. The failure is in `refuse_insert_entry`, before the o-retry itself: after queuing native I and observing mode i, `assert.is_false(vim.bo.modifiable)` received true. Other retry keys and all remaining existing native cases passed. The new #410 late-autosaved baseline failure in that run is a separate, reproduced defect being fixed in #410.

The failing run used #410 code head c9dd02bb8d2b47b60b75e1f5b97209bcead7fb61: 151 pass, 2 fail, 0 errors across the native file (the second failure was the separate baseline defect). An isolated rerun of the same o-retry case on the same operator runtime, deliberately delaying the fake producer by 200 ms, passed 1/0/0. That rerun included unrelated in-progress #410 adoption/deadline corrections, so it is not claimed as exact-head fail-to-pass registry evidence. A subsequent corrected-head focused run also passed the o case with the pending-input matrix and Couch/architecture checks (80 cases total, zero failures/errors).

The initial failure captured only modifiable=true; it did not capture admission outcome, notifications, per-case duration or instantaneous machine load. Do not infer held refusal versus the approved 500 ms unavailable fallback from this observation. #410 adds notification/mode diagnostics to that assertion without changing its oracle. The tests share the workstation with other slots; elapsed suite times and current load are appended below, explicitly distinct from missing failure-time measurements.
