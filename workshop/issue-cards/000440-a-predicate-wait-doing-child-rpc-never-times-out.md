---
id: 000440
status: done
created: 2026-10-24
updated: 2026-10-25
estimate_hours:
github_issue:
started: 2026-10-25T00:03:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.45
tracker:
    version: 1
    completion:
        token: close-b86a52739604
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 42a7409870a66fa1f888362a9c43e223a0143892
        evidence_commit: 80ec879e8102990e09fe2b9c77f4fd51421cff06
        landed_commit: 432cb319855c91bfe4bbd41f4a0f99ff1b1b759b
kind: bug
---

# A predicate wait doing child RPC never times out

## Problem

In the integration harness, a vim.wait whose predicate makes a child RPC (child:exec) never reaches its timeout while the predicate stays false. The spec then stalls until the harness's 120 s idle deadline, instead of failing at the wait with its message.

Measured during #432 (parley.nvim:1, 2026-10-24), on nvim 0.11.7:
- The spec under test was a copy of tests/integration/session_sync_native_spec.lua with every other case pending.
- The case under test was 'warns once when a release stays unconfirmed through its retries', with its WARN removed, so the predicate stayed false.
- The wait was `vim.wait(15000, function() return exhausted_warnings() > 0 end)`, where exhausted_warnings() is a child:exec.
- The predicate was polled about 3 million times between hrtime 337371539 ms and 337487242 ms (about 115 s). The polls came microseconds apart, not every 200 ms, and the wait never returned.
- The harness reported 'DEADLINE: ... stalled after 0 completed case(s); idle 150405ms'.
- A predicate that reads only local state (a trace file) times out normally.

The shared helper `wait_for(code)` in the integration specs is `vim.wait(arrival.MS, function() return exec(code) end)`. It has this shape, so any wait_for that never comes true stalls instead of failing.
