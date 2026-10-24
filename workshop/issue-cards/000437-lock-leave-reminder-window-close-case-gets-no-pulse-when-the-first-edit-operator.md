---
id: 000437
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/lock_leave_reminder_spec.lua#lock leave reminder cancels on window close and ignores a late tick]
---

# Lock leave reminder window-close case gets no pulse when the first-edit operator acquire fails

## Problem

lock_leave_reminder_spec.lua "lock leave reminder cancels on window close and ignores a late tick" failed once in the recorded suite: on #436's head a703d593 (attempt 3e28d2cc27d2d3aa04cd71d4d46fc014, log under .git/sdlc/test-stats/failed/), pulse()'s 15 s arrival.MS wait for a pulse timer returned false (spec lines 7 and 12, called from 166). The other 17 cases in the file passed. #436 changes only generated vocabulary JSON that no Lua reads. Afterwards the modes/session_sync mapping passed 4 of 4 serially, unsandboxed, with 18 of 18 lock-reminder cases each run. (Sandboxed runs fail almost every case in the file; they are not evidence.)
