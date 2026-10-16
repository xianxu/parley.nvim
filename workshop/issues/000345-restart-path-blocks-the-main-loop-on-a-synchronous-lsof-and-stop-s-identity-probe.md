---
id: 000345
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '449354728e33338d51b48a0fbc1ca8a869131eee' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T01:01:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

## Plan

Decision: `stop()`'s reads move too, because they sit on the same restart path. A restart
blocked on its identity curl (up to 2 s) is the same user-visible freeze.

- [ ] One lsof seam, two drivers (ARCH-DRY): a pure `parse_listener_pids(stdout)` plus the argv,
      shared by the existing sync `pids_on_port` and a new `pids_on_port_async(port, cb)`.
      The async driver runs a `vim.system` callback, returns to the main loop with
      `vim.schedule`, and degrades the same way when lsof is absent or refused (pcall:
      vim.system raises on EPERM).
- [ ] `M.stop_async(cb)`: kill the `_spawned` pids, then run the async identity probe
      (`M.health_probe` + `is_cliproxy_state`, as `port_holds_cliproxy` does), then the async
      listener read, then kill. It calls `cb(count, pids)`. The kill steps are helpers shared with
      the sync `M.stop()`, which stays for spec teardown (10 sites) and keeps its
      return shape.
- [ ] `restart_managed` uses `stop_async`, and `wait_port_released`'s post-exit check uses
      `pids_on_port_async`. `:ParleyProxy stop` uses `stop_async` and notifies from the callback.
- [ ] Remaining sync reads are named in ## Log as justified: `port_identity` (the 401 failure branch
      and `:ParleyProxy update`), `peers()` (once per session, documented ~80–150 ms), and
      sync `M.stop()` (spec teardown only).
- [ ] Test: a `tests/fixtures/fake_lsof` (bounded by `PARLEY_FAKE_LSOF_DELAY_MS`, listed in
      the arch spec's CANNOT_BLOCK) prints `PARLEY_FAKE_LSOF_PIDS` after a 1 s delay. During a
      restart with it, a 50 ms `vim.defer_fn` ticker must keep firing (≥ 10 ticks across the
      read). Mutation: the sync read makes the ticker stall.
- [ ] #340's two regressions (the stall window, the peer left on the port) pass, with
      their stop wrappers moved to `stop_async`. Lifecycle, update and command specs and the
      full suite pass.

## Log

### 2026-10-16
