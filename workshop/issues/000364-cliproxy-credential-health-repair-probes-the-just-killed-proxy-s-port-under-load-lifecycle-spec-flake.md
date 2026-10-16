---
id: 000364
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '50e84ad66d3c7a2d837194ac59b7c6c094bf677b' # card fields mirrored from issue-cards; edit via sdlc
---

# cliproxy credential_health repair probes the just-killed proxy's port under load (lifecycle spec flake)

## Problem

On 2026-10-16, `sdlc merge` of #357 (PR #277) ran the merged suite on f93bbf41 while a second full suite held the machine's other slot. `tests/integration/cliproxy_lifecycle_spec.lua` failed two `credential_health` cases. Main's baseline (800e0d3e) passed in the same merge, and #357 touches no cliproxy code. Run alone, the spec passed 3 times out of 3.

- "does not restart twice": `cliproxy_lifecycle_spec.lua:986`, "the repair probed the just-killed proxy's port", expected 0, got 1 `window_probes`.
- "restarts a keyless proxy once": `await` timed out at `:967` (8 s budget). That fits the same cause: a probe inside the window stalls `STALL_MS` = 5 s, which with the restart overruns 8 s.

So under load the repair still probes between `stop()` and the next `spawn()`, the window #340 and #345 meant to close ("it waits for the killed process to exit"). Either the product's wait for the old process's exit gives up under load and falls through to a probe, or the spec's window (opened in the `stop` wrapper, closed in `spawn`) doesn't match the product's real ordering. Log: `~/workspace/parley.nvim/.git/sdlc/test-stats/failed/1cd9910d389b48ba5efa70185c8f2c1e.log`.

## Spec

## Done when

- The cause is identified as a product race or a spec mismatch, and fixed at the root. No wider budget unless the budget is shown to be the cause.
- A deterministic reproduction exists, for example a slowed process exit, like #355's `PARLEY_FAKE_GET_DELAY_MS`. It fails before the fix and passes after.

## Plan

- [ ]

## Log

### 2026-10-16
