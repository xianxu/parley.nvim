---
id: 000343
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'da5e98e496f2d8ff1e13995a66839d7b388d5323' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T20:29:03-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# cliproxy_update_spec: 'old proxy outlives the restart' races the fake's 4 s exit delay under load

## Problem

`tests/integration/cliproxy_update_spec.lua` "does not reuse an old proxy that
outlives the restart, and says so" failed once in a full `make test` on the #204
branch (1ba9af6f, 2026-10-15). It then passed alone, in 3 parallel runs, and in
the next full suite. Failure:

```
cliproxy_update_spec.lua:494: Expected objects to be the same.
Passed in: { [2] = 'down' }
Expected:  { [1] = '9.9.4' }
```

The case keeps the old fake serving for a wall-clock `PARLEY_FAKE_EXIT_DELAY_MS
= 4000` after SIGTERM, and then asserts the old proxy STILL answers at the end.
Between the SIGTERM and that final `version_probe` come restart_managed's 2 s
port wait, the update's install and the message, and they can take longer than
4 s on a loaded machine. The old fake exits, the probe reads `down`, and the
assertion fails. Likely root cause: the exit delay is an absolute wall-clock
window the case races, not a state the case controls (cf. #337 lesson BR-1:
control the timing inputs a deadline assertion depends on).

It has a second failure mode, seen 2026-10-15 in the #204 merge-suite run
(merged head 304582ba, case took 56 s): the old fake exited BEFORE
restart_managed's 2 s port wait ended, so the update reported success and
`r.ok` was `true` at line 490:

```
cliproxy_update_spec.lua:490: updated 9.9.4 → 9.9.11 — restarting the proxy; now serving 9.9.11
Expected: (boolean) false   Passed in: (boolean) true
```

Both modes come from one cause. Under load, the 4 s wall-clock exit delay can
end before the port wait finishes (this mode), or before the final probe (the
first mode).

Sibling: the lifecycle restart-timing flake is #340.

## Spec

Measured (idle machine, slot 3): lowering the case's exit delay to 1000 ms or
2500 ms fails it deterministically in mode 2 (`r.ok` true at :490), so the
shipped 4000 ms window has under 1.5 s of margin before any load.

Fix: replace the wall-clock window with a state the case controls. The fake's
`PARLEY_FAKE_EXIT_DELAY_MS` is retired for `PARLEY_FAKE_IGNORE_SIGTERM=1`: the
old proxy ignores SIGTERM and keeps serving until it is SIGKILLed. The port wait
then always ends with the old proxy answering, the final probe always sees
9.9.4, and the spec's reap SIGKILLs it (the shared reap drops `sigterm`: its
only reason was this window).

## Core concepts

| Concept | Meaning |
|---|---|
| `PARLEY_FAKE_IGNORE_SIGTERM` | fake_cliproxy ignores SIGTERM; only SIGKILL (the spec's reap) ends it |

## Done when

- [ ] The case no longer depends on the old fake outliving a wall-clock window
      (e.g. the fake ignores SIGTERM until released by the case, then is reaped).
- [ ] The case passes under a loaded full suite (repeat runs as evidence).

## Plan

- [ ] fake_cliproxy: `PARLEY_FAKE_IGNORE_SIGTERM` replaces `PARLEY_FAKE_EXIT_DELAY_MS`.
- [ ] cliproxy_update_spec: the case uses it; reap uses SIGKILL; comments in
      cliproxy.lua, fixture_process.lua and fixture_reaping_spec follow.
- [ ] Red: the old case fails at a compressed window; the new case has no window.
- [ ] Evidence: the case passes in repeated runs under a loaded machine (parallel runs).

## Log

### 2026-10-15
