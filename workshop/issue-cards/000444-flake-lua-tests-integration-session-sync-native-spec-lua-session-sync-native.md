---
id: 000444
status: open
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits restores journaled move protection after editor process death]
---

# flake: lua:tests/integration/session_sync_native_spec.lua#session-sync native edits restores journaled move protection after editor process death

## Problem

Known flaky tests (#394), registered with same-head fail→pass evidence:

- lua:tests/integration/session_sync_native_spec.lua#session-sync native edits restores journaled move protection after editor process death: Load reps in a disposable clone of the parley #427 branch at 300c65f2, 2026-10-24: 20 reps of session_sync_native_spec per nvim under 3 CPU spinners plus an fsync dd loop. Failed once in nvim 0.12.5 rep 3 at :30 (expected complete payload missing: status.md.lock observed={}) and passed in the other 39 reps on the same code. TL (ops:0) note: the missing lock payload is the same shape as the #431 stale-clock acquire failures, so first check whether some acquire path still bypasses helper.system (for example a forwarded options table the deadline lint cannot see) before treating this as a new cause.
