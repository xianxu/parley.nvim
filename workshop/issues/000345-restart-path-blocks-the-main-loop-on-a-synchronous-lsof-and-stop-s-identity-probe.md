---
id: 000345
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '39e5c915ce33c90f35645ea9fd5d99cb978fd7f1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T01:01:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 1.07
---

# Restart path blocks the main loop on a synchronous lsof (and stop's identity probe)

## Problem

#340 (PR #254) made an exit-confirmed restart read the port's listeners before
spawning the replacement: `wait_port_released`'s `exit_poll` calls
`pids_on_port(port)` (lua/parley/cliproxy.lua, near line 519). That is a synchronous
`vim.system({ "lsof", … }):wait()` on the main loop. Under the suite-shaped
8-parallel load it took about 1 s (the #340 harness max rose from 917 ms to 1557 ms
with it), and the editor is frozen for that time. That is once per restart:
`:ParleyProxy restart`, update, the credential-health repair and the recovery
ladder's restart rung. The close review recorded it as an advisory
(sync-io-on-main-loop-poll, ARCH-CONSTRAINTS); the TL asked for it as its own issue.

The same path also blocks in `stop()`: `port_holds_cliproxy` is a synchronous curl
probe (up to `--max-time` 2 s), followed by a synchronous `pids_on_port`.

## Spec

Make the restart path's listener read asynchronous (a `vim.system` callback), so
the wait no longer blocks the main loop, and keep #340's contract:
- release is confirmed by the signalled pids exiting AND no listener being left;
- a leftover listener, or a read that fails, falls back to the probe;
- a proxy still answering at the deadline is reported (#237 BR-8).

Decide at planning: whether `stop()`'s synchronous identity probe and lsof move too.
`stop()` is public and returns a count to `:ParleyProxy stop`. An async variant for
the restart path, with the sync command kept, is one option.

## Done when

- [ ] No synchronous lsof (or curl) runs on the main loop in an exit-confirmed restart, or each one that remains is named and justified in ## Log.
- [ ] A test proves the main loop stays responsive during the listener read, e.g. a deferred tick fires while a slow fake lsof runs.
- [ ] #340's regressions (the stall window, the peer left on the port) still pass, with the full suite.

## Core concepts

| Entity | Status | Where | What |
|---|---|---|---|
| `stop` | changed | lua/parley/cliproxy.lua | The sync stop: kills `_spawned`, then reaps a cliproxy on the managed port. Kept for spec teardown; its kill steps are shared with `stop_async`. |
| `stop_async` | added | lua/parley/cliproxy.lua | The same stop with the identity probe and the listener read async; `cb(count, pids)`. Used by `restart_managed` and `:ParleyProxy stop`. |
| `_wait_port_released` | added | lua/parley/cliproxy.lua | Test seam for the release wait, so a spec can drive a process that exits near the deadline (#345 close BR-1). |
| `_restart_budget_keys` | added | lua/parley/cliproxy.lua | The repair-budget terms a plain restart spends, by name; cliproxy_budget_spec sums these instead of a hand-written list. |
| `_pids_on_port_async` | added | lua/parley/cliproxy.lua | Test seam for the async listener read: lsof through a `vim.system` callback, limited to `LSOF_MAX_MS`; a timeout reports `lsof timed out`, never "no listener". |

## Plan

Decision: `stop()`'s reads move too, because they sit on the same restart path. A restart
blocked on its identity curl (up to 2 s) is the same user-visible freeze.

- [x] One lsof seam, two drivers (ARCH-DRY): a pure `parse_listener_pids(stdout)` plus the argv,
      shared by the existing sync `pids_on_port` and a new `pids_on_port_async(port, cb)`.
      The async driver runs a `vim.system` callback, returns to the main loop with
      `vim.schedule`, and degrades the same way when lsof is absent or refused (pcall:
      vim.system raises on EPERM).
- [x] `M.stop_async(cb)`: kill the `_spawned` pids, then run the async identity probe
      (`M.health_probe` + `is_cliproxy_state`, as `port_holds_cliproxy` does), then the async
      listener read, then kill. It calls `cb(count, pids)`. The kill steps are helpers shared with
      the sync `M.stop()`, which stays for spec teardown (10 sites) and keeps its
      return shape.
- [x] `restart_managed` uses `stop_async`, and `wait_port_released`'s post-exit check uses
      `pids_on_port_async`. `:ParleyProxy stop` uses `stop_async` and notifies from the callback.
- [x] Remaining sync reads are named in ## Log as justified: `port_identity` (the 401 failure branch
      and `:ParleyProxy update`), `peers()` (once per session, documented ~80–150 ms), and
      sync `M.stop()` (spec teardown only).
- [x] Test: a `tests/fixtures/fake_lsof` (bounded by `PARLEY_FAKE_LSOF_DELAY_MS`, listed in
      the arch spec's CANNOT_BLOCK) prints `PARLEY_FAKE_LSOF_PIDS` after a 1 s delay. During a
      restart with it, a 50 ms `vim.defer_fn` ticker must keep firing (≥ 10 ticks across the
      read). Mutation: the sync read makes the ticker stall.
- [x] #340's two regressions (the stall window, the peer left on the port) pass, with
      their stop wrappers moved to `stop_async`. Lifecycle, update and command specs and the
      full suite pass.

## Log

### 2026-10-16
- 2026-10-16: closed — Full suite green on a3777a50 (sdlc-local/suite, main merged); one earlier run hit an unrelated starter welcome-lock flake, filed as #348 (passed 3 of 3 alone, files untouched by this branch). Round-2 BR-1 items: _restart_budget_keys single-sources the restart terms (stop_listener_read added; the budget spec sums the keys and asserts each is a real term); a release-wait case with a process exiting at 1.7 s and a 4 s fake lsof decides before 3000 ms, and without the remaining-time pass-through it decides at 3787 ms (mutation fails it). Earlier evidence holds: no main-loop lsof or curl on the restart path; max tick gap under 750 ms; mutations: sync read 1, probe-only 4, no lsof timeout 1, ignored limit 1.; review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 127 added lines in code files (limit 100); an earlier round of this close already ran the full review

### 2026-10-16

- The restart path now has no main-loop lsof or curl. Remaining sync reads, each justified:
  - `port_identity` (ps + lsof): only on the 401 failure branch of `ensure_running` and in `:ParleyProxy update`. A dispatch that already failed, or an explicit maintenance command.
  - `peers()` (ps + lsof): once per session, behind the latch (documented ~80–150 ms).
  - The sync `stop()`: spec teardown only; no product caller remains.
- Found while building: `stop_async` SIGTERMs this session's own proxies before its identity probe, as `stop()` always has, so a restart of only our own proxy makes one listener read (the post-exit one). The responsiveness test therefore uses a leftover cliproxy this session did not spawn, so both reads run, and the fake lsof log asserts 2 calls.
- Added `LSOF_MAX_MS` (2 s): an async lsof with no limit could leave a restart waiting forever. Both reads are in `_repair_budget_sec`; cliproxy_budget_spec is green.
- Tests: the responsiveness case (50 ms ticker, max gap < 750 ms across two 1.5 s lsof reads); the lsof time limit; the stop contract run over both `stop()` and `stop_async()`. The #340 stall wrapper moved to `stop_async`; with the sync stop it would have passed without testing anything.
- Mutation:
  - A sync read stalls the loop for 1594 ms, failing 1 case.
  - A probe-only release fails 4 cases.
  - Dropping the lsof timeout fails 1 case.
- New fixture `tests/fixtures/fake_lsof` is listed in the fixture-lifecycle CANNOT_BLOCK, and the corpus count is 14.
- Close round 1 (FIX-THEN-SHIP):
  - BR-1: the budget modelled the post-exit read and the fallback probe as a `max`, but they run in sequence. Summing them would have taken the repair below the budget spec's 5 s headroom. So the release wait now owns its deadline: the post-exit read gets only the time left (`remaining`, at most `LSOF_MAX_MS`) and is skipped once the deadline passes. The overrun stays one probe, `port_release` = deadline + one probe again, and the stack cannot happen. Test: a read given 300 ms is cut off at that time. Mutation: ignoring the given limit fails it. The `remaining` pass-through in `exit_poll` is covered by the seam test plus inspection; a restart-level timing case would need a proxy that exits near the deadline (the exit-delay variable #343 is retiring).
  - The doc block: `M.stop`'s doc and annotations are back on `M.stop`; the helpers moved above it.
  - The stateless fake: `fake_lsof` now lists only live pids and logs what it printed. The responsiveness test asserts read 1 listed the leftover and read 2 listed none, so it covers the exit-confirmed path.
  - Concurrent spawn reaped during `stop_async`'s async window: accepted, not fixed. The window already existed during the release wait (#340), and a dispatch's `ensure_running` racing an explicit restart is outside this issue. Recorded here.
- Close round 2 (BR-1 kept open):
  - The restart-only budget is now derived: `M._restart_budget_keys` names the terms (adding `stop_listener_read`, which the hand-written list omitted), and cliproxy_budget_spec sums them, asserting each is a real term.
  - The `remaining` pass-through is now tested end to end: "the release wait never runs its listener read past the deadline" drives `_wait_port_released` with a process that exits at 1.7 s and a 4 s fake lsof. Mutation: passing no limit makes the wait decide at 3787 ms, and the case fails (the bound is 3000).
- 2026-10-16, merge run failed, then re-planning. The merge's suite failed `stop_async() reaps a leftover`: the real lsof passed its 2 s limit ("lsof timed out after 2020 ms"; others 1.1–1.6 s under 8-way load; 0.11 s idle). Fixed so far, uncommitted until now: stop_async reports `read_err`, and the restart then says the proxy "was not stopped" rather than claiming it was told to stop (test plus mutation). The async reap test lists the leftover through fake_lsof.
- An 8-parallel run of the whole lifecycle spec: main 8 of 8 green; this branch fails credential_health in 6 of 8 runs (await timeout). Mechanism: the BR-1 cap gives the post-exit read only the time left, and under load lsof needs more, so it is cut off. The restart then falls back to the port probe, the stalling path #340 removed (here the 5 s stall emulation). Main's sync lsof is unbounded, completes in 2–3 s, and never reaches the probe.
- Stopped to re-plan with the TL: responsiveness (async), a bound on lsof that the repair budget must count, and lsof latency under load cannot all hold with a 2 s cap inside a 30 s backstop with 5 s headroom.

