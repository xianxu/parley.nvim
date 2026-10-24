---
id: 000440
status: open
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: '7288225cce89c02eeb4bed570d4a3a4b671d01f3' # card fields mirrored from issue-cards; edit via sdlc
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

## Spec

Find why vim.wait's timeout never fires when its predicate makes a synchronous RPC to the child. A suspect is the stale loop clock from #431: vim.wait's deadline is measured on a loop clock that the synchronous RPC never lets advance. Keep a standalone repro outside the suite, as #431 did. Then make a predicate wait that stays false fail at its own timeout, either in the shared helpers (wait_for and the Embedded child) or upstream with a workaround here.

## Done when

- A standalone repro shows the stall and names the mechanism.
- A wait_for whose condition never comes true fails at its timeout, with its message, in a regression test.
- Existing callers keep their semantics.

## Plan

- [ ]

## Log

### 2026-10-24
