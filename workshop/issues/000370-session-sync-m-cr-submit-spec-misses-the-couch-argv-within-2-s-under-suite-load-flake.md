---
id: 000370
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '06765a03f0f34f789c5e41b991de07afd8a400e5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T02:49:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "55321af3", done: "848e1784"}
---

# session_sync M-CR submit spec misses the couch argv within 2 s under suite load (flake)

## Problem

`tests/integration/session_sync_spec.lua` failed once in a full suite: "session-sync buffer <M-CR> saves, deletes the lock, leaves the buffer editable and sends one couch message (#315)", at line 205. `vim.wait(2000, …)` for the fake couch's argv file returned -1 (a timeout): the submit's couch call didn't record its argv within 2 s.

- First seen: 2026-10-16 23:57, during #360's full suite on head b824c4695487fed80b979bbdd177368ec40edd79. That branch changes only `tests/helpers/ready_port.lua` and four cliproxy specs, nothing on the session-sync path.
- The run passed 457 other spec files with lint clean; this was its only failure.
- Retained log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/ce404b3086f731fa89502659bcac6231.log`.
- Three same-head focused runs of the spec passed 63/63 each.

## Spec

Find out why the async couch submit can take more than 2 s to reach the fake under suite load. Candidates: a fixed 2 s literal below the submit path's own budget (the #355 class), or the asynchronous submit queue from #357. Size the wait from the path's real budget, or make the arrival observable, rather than raising the literal blindly.

## Done when

- A deterministic reproduction exists, for example a delayed fake couch, that fails before the fix and passes after.
- The fix sits at the cause; the focused spec and the full suite pass.

## Plan

Root cause: fixture timing, not ordering. A traced focused run (couch.run wrapped to log argv and times) shows Alt+Return starts exactly one process: couch --send-to begins 15 ms after the key, with nothing queued ahead of it, and the argv appears at 128 ms unloaded. The failing run's file took 30 s, inside its normal 22 to 33 s under a suite (141 recorded attempts), and the case's "submitted to ops:0" never printed: the fake send had not finished. The product allows a submit 15 s (agentic_submit_timeout_ms) before the band says "still waiting for Couch". The spec's 2 s is a load guess below that (the #355 class).

- [x] Regression: "<M-CR> waits out a slow couch send", with the fake send sleeping 2.5 s; red on the 2 s literal.
- [x] One arrival bound in the spec, the submit's deadline from config (default when setup set none). Every positive wait in the file uses it (33 waits on 2 s and the 3 s registry lookup). The absence checks keep their short fixed waits.
- [x] Focused spec green (64/64). With the bound set back to 2000, only the regression fails. luacheck clean.

## Log

### 2026-10-16

### 2026-10-17
- 2026-10-17: closed — Regression "<M-CR> waits out a slow couch send" (fake send sleeps 2.5 s) failed on the 2 s literal and passes on the arrival bound. Focused session_sync_spec 64/64; with the bound set back to 2000, only the regression fails. luacheck clean. Traced run: one couch --send-to started 15 ms after the key, nothing queued (no ordering bug). Test-only fix; no new architectural surface, so no atlas change.; review verdict: SHIP

- Not swept: 19 other spec files carry `assert.is_true(vim.wait(2000, ...))`. Some may wait on processes; named for the hub to file.
