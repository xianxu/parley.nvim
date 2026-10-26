---
id: 000442
status: done
created: 2026-10-24
updated: 2026-10-25
estimate_hours:
github_issue:
started: 2026-10-24T11:57:59-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retries a clean release whose reply was lost and the next turn is new (#432)]
actual_hours: 2.42
tracker:
    version: 1
    completion:
        token: close-2b5a72dc7ffb
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 5a566e541bb361b042503268dc5d0a7e5001186b
        evidence_commit: 2b9faba8b3f2c7836dea2aa613a4129e662ed68e
        landed_commit: ed338d6e335ce82e0959ab7c1c5749591eaee733
kind: bug
---

# Native lost-reply release case flakes under load

## Problem

The #432 case 'retries a clean release whose reply was lost, so the next turn is new (#432)' in tests/integration/session_sync_native_spec.lua failed 2 of 40 reps under capped load. The load was 3 CPU spinners plus an fsync dd loop, on top of the fleet, in a disposable clone of the #427 branch at 300c65f2, on 2026-10-24.

- nvim 0.11.7, rep 19: E484 'Can't open file .../status.md.lock' in turn_of_lock (:697), called at :716. The case reads the lock right after `wait_for(mode=='i')`, but mode i does not mean the admission has finished: the acquire had not written the lock yet. This is a test bug: wait for the lock (exists()) before reading its turn.
- nvim 0.12.5, rep 1: the final `vim.wait(arrival.MS, not exists())` at :724 timed out (-1). The second turn's lock was still there 15 s after its Esc. Not diagnosed: the earlier wait counts the retry when it starts (its trace line), not when it completes. The second turn's i may therefore have raced the retry's completion. Needs a trace.
