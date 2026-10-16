---
id: 000345
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '666560cb5c5c96946055fa9d2ad9fd6c0f6d8849' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T01:01:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 2.17
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
- a proxy still answering at the deadline is reported (#237 BR-8). *(Superseded by option B, see ## Revisions: only the interactive commands read async; the budgeted restart paths keep the sync reads.)*

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
| `stop` | changed | lua/parley/cliproxy.lua | The sync stop: kills `_spawned`, then reaps a cliproxy on the managed port; returns `(count, pids, read_err)`. The budgeted paths stop through it (via the sync reads: the in-dispatch repair, the recovery rung, update), as does spec teardown. Its kill steps are shared with `stop_async`. |
| `stop_async` | added | lua/parley/cliproxy.lua | The stop with the identity probe and the listener read async; `cb(count, pids, read_err)`. Used by `:ParleyProxy stop` and the interactive restart (`restart_managed(…, { interactive = true })`, option B). |
| `restart_managed` | changed | lua/parley/cliproxy.lua | Takes a third options argument: `{ interactive = true }` reads the process table async (the user commands); the default keeps the sync reads for the budgeted paths (in-dispatch repair, recovery rung, update). |
| `_restart_budget_keys` | added | lua/parley/cliproxy.lua | The repair-budget terms a plain (sync) restart spends, by name; cliproxy_budget_spec sums these instead of a hand-written list. |
| `_pids_on_port_async` | added | lua/parley/cliproxy.lua | Test seam for the async listener read: lsof through a `vim.system` callback behind a hang guard (`LSOF_GUARD_MS`, 10 s); a timeout reports `lsof timed out`, never "no listener". |
| `_set_lsof_guard_ms` | added | lua/parley/cliproxy.lua | Test seam: shorten the interactive lsof guard for a case (nil restores it). |

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
      listener read, then kill. It calls `cb(count, pids)` *(now `cb(count, pids, read_err)`, see ## Revisions)*. The kill steps are helpers shared with
      the sync `M.stop()`, which stays for spec teardown (10 sites) and keeps its
      return shape. *(Superseded by option B, see ## Revisions: the sync `M.stop()` also stays the stop of the budgeted paths, and returns `read_err` too.)*
- [x] `restart_managed` uses `stop_async`, and `wait_port_released`'s post-exit check uses
      `pids_on_port_async`. `:ParleyProxy stop` uses `stop_async` and notifies from the callback. *(Superseded by option B, see ## Revisions: only `restart_managed(…, { interactive = true })` (the `:ParleyProxy restart` command) uses `stop_async` and the async post-exit read; the default sync reads are main's.)*
- [x] Remaining sync reads are named in ## Log as justified: `port_identity` (the 401 failure branch
      and `:ParleyProxy update`), `peers()` (once per session, documented ~80–150 ms), and
      sync `M.stop()` (spec teardown only). *(Superseded by option B, see ## Revisions: see the Done-when sweep in ## Revisions for the current list.)*
- [x] Test: a `tests/fixtures/fake_lsof` (bounded by `PARLEY_FAKE_LSOF_DELAY_MS`, listed in
      the arch spec's CANNOT_BLOCK) prints `PARLEY_FAKE_LSOF_PIDS` after a 1 s delay. During a
      restart with it, a 50 ms `vim.defer_fn` ticker must keep firing (≥ 10 ticks across the
      read). Mutation: the sync read makes the ticker stall.
- [x] #340's two regressions (the stall window, the peer left on the port) pass, with
      their stop wrappers moved to `stop_async`. *(Superseded by option B, see ## Revisions: the repair and recovery-rung wrappers are back on the sync `stop`, which those paths use.)* Lifecycle, update and command specs and the
      full suite pass.

## Log

### 2026-10-16
- 2026-10-16: closed — Docs-only delta since 383e8a4a (suite green there): BR-6 round 5, Log line 106 ("the restart path now has no main-loop lsof or curl"), the Plan stop_async callback shape, the Spec opening and an old close line now carry dated superseded notes; 10 superseded annotations in total. No code changed. (fixed-then-ship); review verdict: SHIP
- 2026-10-16: closed — Round-4 fixes on 383e8a4a, full suite green there (sdlc-local/suite). BR-6: the issue Plan, Core-concepts and Log claims about option A are corrected with dated superseded notes, and the current main-loop sync-read list is justified. Minors: :ParleyProxy stop WARNs naming read_err when a cliproxy on the port could not be listed (command spec INFO and WARN cases); the restart command test asserts interactive = true; the pids_on_port doc block is reattached; the wait_port_released header names both stops. Lifecycle and command specs green, sweeps guard green. (fixed-then-ship); review verdict: FIX-THEN-SHIP
- 2026-10-16: closed — Option B per TL (recorded in ## Revisions with measurements: lsof 0.11 s idle, over 2 s under 8-way load; why A and C were not taken). Full suite green on 04169ca6 (sdlc-local/suite, main merged). Only :ParleyProxy restart (interactive) and stop read async, behind a 10 s hang guard; the in-dispatch repair, recovery rung and update keep main sync reads, and the repair budget equals main. 8-parallel lifecycle spec: 8 of 8 green (the A-shaped branch was 6 of 8 red; main 8 of 8). Mutation: interactive with sync reads stalls 1600 ms and fails 2; a sync stop without read_err fails the peer-left case; a probe-only release fails 4; a guard that is ignored fails 1. The honest not-stopped message holds on both paths.; review verdict: FIX-THEN-SHIP
- 2026-10-16: closed — Full suite green on a3777a50 (sdlc-local/suite, main merged); one earlier run hit an unrelated starter welcome-lock flake, filed as #348 (passed 3 of 3 alone, files untouched by this branch). Round-2 BR-1 items: _restart_budget_keys single-sources the restart terms (stop_listener_read added; the budget spec sums the keys and asserts each is a real term); a release-wait case with a process exiting at 1.7 s and a 4 s fake lsof decides before 3000 ms, and without the remaining-time pass-through it decides at 3787 ms (mutation fails it). Earlier evidence holds: no main-loop lsof or curl on the restart path *(superseded by option B: true only for the interactive commands)*; max tick gap under 750 ms; mutations: sync read 1, probe-only 4, no lsof timeout 1, ignored limit 1.; review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 127 added lines in code files (limit 100); an earlier round of this close already ran the full review

### 2026-10-16

- The restart path now has no main-loop lsof or curl. Remaining sync reads, each justified: *(Superseded by option B, see ## Revisions: only the interactive commands, `:ParleyProxy restart` and `stop`, are off the main loop; the budgeted paths keep the sync reads.)*
  - `port_identity` (ps + lsof): only on the 401 failure branch of `ensure_running` and in `:ParleyProxy update`. A dispatch that already failed, or an explicit maintenance command.
  - `peers()` (ps + lsof): once per session, behind the latch (documented ~80–150 ms).
  - The sync `stop()`: spec teardown only; no product caller remains. *(Superseded by option B, see ## Revisions: the budgeted paths call it again.)*
- Found while building: `stop_async` SIGTERMs this session's own proxies before its identity probe, as `stop()` always has, so a restart of only our own proxy makes one listener read (the post-exit one). The responsiveness test therefore uses a leftover cliproxy this session did not spawn, so both reads run, and the fake lsof log asserts 2 calls.
- Added `LSOF_MAX_MS` (2 s): an async lsof with no limit could leave a restart waiting forever. Both reads are in `_repair_budget_sec`; cliproxy_budget_spec is green. *(Superseded by option B, see ## Revisions: replaced by `LSOF_GUARD_MS` 10 s on the interactive path only; the budget is main's.)*
- Tests: the responsiveness case (50 ms ticker, max gap < 750 ms across two 1.5 s lsof reads); the lsof time limit; the stop contract run over both `stop()` and `stop_async()`. The #340 stall wrapper moved to `stop_async`; with the sync stop it would have passed without testing anything. *(Superseded by option B, see ## Revisions: the repair is on the sync stop again, and so is the wrapper.)*
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

## Revisions

- 2026-10-16, design revised to option B (TL decision, after the merge run went red under load).
  - **Measured:** lsof is 0.11 s idle, and 0.2 s to over 2 s under 8-way load (one read timed out at 2020 ms). An 8-parallel run of the whole lifecycle spec: main 8 of 8 green, the option-A-shaped branch (2 s cap plus the BR-1 remaining-time cap) failed credential_health in 6 of 8.
  - **Decision (B):** async reads only for the user-initiated `:ParleyProxy restart` and `:ParleyProxy stop`. Those have no backstop, so they take a generous hang guard (`LSOF_GUARD_MS`, 10 s). The budgeted paths keep main's #340 sync reads, so the budget is unchanged: the in-dispatch repair (credential_health), the recovery rung, and `:ParleyProxy update`, which restarts behind its own 20 s deadline. That removes the freeze people see on the commands, and the rare in-dispatch repair stays as robust under load as #340 made it.
  - **Why not A** (async everywhere, a ~5 s guard per read, an honest budget): it needs the dispatcher backstop raised from 30 to ~36 s (or a smaller headroom rule) for a rare path.
  - **Why not C** (shelve): it keeps the visible freeze on the commands.
  - **Removed with A:** `LSOF_MAX_MS`, the `stop_listener_read` budget term, the post-exit remaining-time cap (the close BR-1 fix: the sync path never caps, as on main, and the interactive path has no budget), and its `_wait_port_released` seam and test. Kept: `_restart_budget_keys`, and the honest message when the listener read fails. The sync `stop()` now also returns `read_err`, so that message holds on both paths.
  - **Verified:** the 8-parallel lifecycle run is now 8 of 8 green, like main.
  - **Mutations:**
    - Giving the interactive restart sync reads stalls the loop 1600 ms, failing 2 cases.
    - Dropping the sync stop's `read_err` fails the peer-left case.
    - A probe-only release fails 4 cases.
    - A limit the read ignores fails the guard case.
- 2026-10-16, close round 4 (BR-6, stale prose after the revision): every Plan, Core-concepts and Log claim naming the replaced mechanism is now corrected (the dated "Superseded by option B" notes above, and the current `stop` row). Done-when #1, the current list of main-loop sync reads, each justified:
  - **The budgeted paths' sync identity curl and lsof:** `M.stop()`, and the sync post-exit read. These are the in-dispatch repair (credential_health), the recovery rung and `:ParleyProxy update`. They stay sync by the option-B decision: inside a backstop, an unbounded read that load cannot cut short beats a capped async one that falls onto the stalling probe.
  - **`port_identity`** (ps + lsof): the 401 failure branch and `:ParleyProxy update`.
  - **`peers()`** (ps + lsof): once per session.
  - Not on the main loop any more: `:ParleyProxy restart` and `:ParleyProxy stop`.
- Round 4 Minors fixed:
  - `pids_on_port`'s doc block is back on it; the lsof helpers moved above it. That was the 4th doc-placement instance on this branch; the lessons rule is below.
  - The `wait_port_released` header names both stops.
  - `:ParleyProxy stop` WARNs, naming `read_err`, when a cliproxy on the port could not be listed (command spec: INFO and WARN cases). The restart command test now asserts that it asks for `{ interactive = true }`.

