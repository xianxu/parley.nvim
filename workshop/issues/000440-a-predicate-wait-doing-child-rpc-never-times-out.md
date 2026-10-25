---
id: 000440
status: codecomplete
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-25
estimate_hours:
card_mirror: 'f78524c789e47b118bb122206bd44178a3a96e9f' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-25T00:03:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "49afb8fe", done: "d9179011"}
actual_hours: 0.45
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

Mechanism (standalone repro, both nvims; see Log): vim.wait's LOOP_PROCESS_EVENTS_UNTIL takes whole elapsed milliseconds off the remaining time and resets its baseline each pass. A predicate that closes a libuv handle queues a close callback, so the next pass returns without blocking. Each pass is then under 1 ms, rounds down to 0, and the wait never expires. Child:request creates, stops and closes a timer around every request, so every predicate doing child RPC has this shape. It is not the stale loop clock, and it is not the RPC itself.

- [x] Regression in tests/integration/embedded_nvim_spec.lua, the helper's existing spec, which is already mapped under infra/test_harness. A false child:exec predicate under vim.wait(300) returns false, and a wait_for-shaped assert fails naming its code. A fence inside the predicate (10x the bound, measured by hrtime) raises 'wait never timed out', so a regression fails loudly instead of stalling to DEADLINE. Red on the current seam.
- [x] Fix at the seam (ARCH-DRY: one place every predicate's RPC goes through): a Child owns one request timer, started and stopped per request and closed when the child stops. The kill-on-deadline path is unchanged.
- [x] Not a suite-wide vim.wait override: product code under test would then pass a wait that hangs for users. Upstream report: asking the hub, since it is outward-facing.
- [x] Targeted runs of infra/test_harness and modes/session_sync on 0.11.7 and 0.12.5.

ARCH: CONSTRAINTS: the timer is a bounded resource, one per child; requests are serial. ORDER: the per-request state (fired) moves to the child; a fired timer kills the child, and the request fails as before. Requests on one child are serial: vim.rpcrequest blocks only on its channel, so no second request rearms the timer mid-flight. FUNERAL: the timer closes in join_and_cleanup (stop, a fired deadline, and a failed setup all go through it); a Child never stopped leaks one timer handle until its nvim exits, as before, when it leaked the child. SECURE, EVOLVE and MOCK: N/A. This touches only the test harness, with no persisted format and no external dependency added.

## Log

### 2026-10-24

### 2026-10-25
- 2026-10-25: closed — Mechanism, standalone repro on 0.11.7 and 0.12.5 (Log, plus side doc upstream-neovim-draft.md): vim.wait subtracts whole elapsed ms per loop pass and resets its baseline. A predicate that closes a libuv handle makes each pass return in under 1 ms, so the wait never expires (close variant hangs until killed; close+1.5ms takes 760 ms for a 500 ms bound). Child:request created and closed a timer per request, so every child-RPC predicate (all wait_for) stalled to DEADLINE; reproduced under make test-spec. Fix: one request timer per embedded Child, closed in join_and_cleanup; atlas/infra/test_harness.md records it. Regression in tests/integration/embedded_nvim_spec.lua: a wait_for-shaped assert over child:exec false fails at its 300 ms timeout naming its code, with an hrtime fence turning a stall into an error. Red on the old seam (wait never timed out), green on the fix. Existing callers unchanged. Targeted tmp regression, infra/test_harness and modes/session_sync green on both nvims at load 37 to 50; pre-close sdlc-local/suite green on 61fd9849 (later commit atlas-only). Upstream filing: the draft is with the operator via the TL.; review verdict: SHIP

Standalone repro (/Volumes/TestScratch/tmp/p440/repro.lua: `nvim --clean --headless -l repro.lua <variant>` with vim.wait(500, pred), killed at 8 s), on 0.11.7 and 0.12.5, same results on each:
- Times out at about 500 ms:
  - cheap (`return false`);
  - rpc to an embedded child, with or without an attached UI and redraws;
  - a timer kept across polls (start and stop only);
  - slow (a 2 ms busy span plus vim.schedule).
- Never returns (killed at 8 s):
  - schedule (vim.schedule per poll);
  - timer (new_timer, start, stop, close per poll: exactly what Child:request does);
  - close-0.6ms (a handle closed plus a 0.6 ms busy span).
- close-1.5ms returns, but after 761 ms for a 500 ms bound: 500 polls, each counted as 1 ms.
So the cause is whole-millisecond truncation with a baseline reset. A pass that returns without blocking, because a close callback or a scheduled callback is pending, takes under 1 ms and counts as 0. Under the real harness (make test-spec, a spec in a scratch clone), local predicates time out at 1000 ms, but `child:exec('return false')` under vim.wait(1000) hits DEADLINE at 200 s.
Upstream: the TL routed filing to the operator, whose account it posts under. The draft is in [upstream-neovim-draft.md](000440-a-predicate-wait-doing-child-rpc-never-times-out.side/upstream-neovim-draft.md). Its 13-line repro was run as written on 0.11.7 and 0.12.5: plain 500 ms, close+1.5ms 760 ms, then the close variant hung until killed at 8 s.
Fix and regression. The 'lets a predicate wait over child requests time out' case was red on the current seam, failing with 'wait never timed out' at its fence rather than stalling. With the per-child timer it is green. Targeted runs in a scratch clone, at a 1-minute load of 37 to 50: tmp/p440 (embedded_nvim_spec), infra/test_harness and modes/session_sync all exit 0 on 0.11.7 and on 0.12.5. Revision: the regression went into the helper's existing spec rather than a new file (ARCH-DRY; it is the same seam's contract).
