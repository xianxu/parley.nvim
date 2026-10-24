---
id: 000442
status: open
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
---

# Native lost-reply release case flakes under load

## Problem

The #432 case 'retries a clean release whose reply was lost, so the next turn is new (#432)' in tests/integration/session_sync_native_spec.lua failed 2 of 40 reps under capped load. The load was 3 CPU spinners plus an fsync dd loop, on top of the fleet, in a disposable clone of the #427 branch at 300c65f2, on 2026-10-24.

- nvim 0.11.7, rep 19: E484 'Can't open file .../status.md.lock' in turn_of_lock (:697), called at :716. The case reads the lock right after `wait_for(mode=='i')`, but mode i does not mean the admission has finished: the acquire had not written the lock yet. This is a test bug: wait for the lock (exists()) before reading its turn.
- nvim 0.12.5, rep 1: the final `vim.wait(arrival.MS, not exists())` at :724 timed out (-1). The second turn's lock was still there 15 s after its Esc. Not diagnosed: the earlier wait counts the retry when it starts (its trace line), not when it completes. The second turn's i may therefore have raced the retry's completion. Needs a trace.
