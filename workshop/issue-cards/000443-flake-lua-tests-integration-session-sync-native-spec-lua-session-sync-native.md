---
id: 000443
status: open
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
---

# flake: lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-new/before-restore (#404), lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-old/before-restore (#404)

## Problem

Known flaky tests (#394), registered with same-head fail→pass evidence:

- lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-new/before-restore (#404): Load reps in a disposable clone of the parley #427 branch at 300c65f2, 2026-10-24: 20 reps of session_sync_native_spec per nvim under 3 CPU spinners plus an fsync dd loop. Both cases failed together in nvim 0.11.7 rep 13 at :1377: after-old with status.md.lock No such file or directory, after-new with fixture must authorize release outside insert. They passed in the other 39 reps on the same code. TL (ops:0) note: the missing lock is the same shape as the #431 stale-clock acquire failures, so first check whether some acquire path still bypasses helper.system (for example a forwarded options table the deadline lint cannot see) before treating this as a new cause.
- lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-old/before-restore (#404): Load reps in a disposable clone of the parley #427 branch at 300c65f2, 2026-10-24: 20 reps of session_sync_native_spec per nvim under 3 CPU spinners plus an fsync dd loop. Both cases failed together in nvim 0.11.7 rep 13 at :1377: after-old with status.md.lock No such file or directory, after-new with fixture must authorize release outside insert. They passed in the other 39 reps on the same code. TL (ops:0) note: the missing lock is the same shape as the #431 stale-clock acquire failures, so first check whether some acquire path still bypasses helper.system (for example a forwarded options table the deadline lint cannot see) before treating this as a new cause.
