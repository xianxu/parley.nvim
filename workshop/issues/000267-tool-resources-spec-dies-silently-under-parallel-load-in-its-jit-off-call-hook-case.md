---
id: 000267
status: open
deps: []
github_issue:
created: 2026-09-18
updated: 2026-09-18
estimate_hours:
---

# tool_resources_spec dies silently under parallel load in its JIT-off call-hook case

## Problem

`tests/unit/tool_resources_spec.lua` intermittently kills its Neovim process
under parallel load: exit code 1, no failing assertion, output ending right after
"reserves newly freed capacity for older runnable waiters" — i.e. inside the next
case, "bounds pump work for a full queue of maximum-width dependency chains",
which turns the JIT off (`jit.off(); jit.flush()`) and installs a per-call debug
hook around `R.pump`.

Because `make test` runs its phases in sequence, one abort in the unit phase
skips the whole integration phase. It did so twice in four full runs on the
#266 branch, leaving close evidence without integration results.

## Spec

Find why the process dies and make the case deterministic under load, without
weakening what it bounds (pump work over a full queue of maximum-width chains).

## Done when

- `tool_resources_spec` passes 64/64 under 16-way parallel stress.
- The bounded-work assertion still fails when `R.pump` goes super-linear.

## Plan

- [ ] Reproduce, isolate the dying call, fix, stress.

## Log

### 2026-09-18

Found while closing parley#266 M2; not caused by it — the module and spec are
identical to `main`, and the same stress fails 2/16 at #266's M1 close commit
`f6ebfd83`.

- Alone: passes, ~1.1 s. Under 16 concurrent runs: 1–3 of 16 die (exit 1).
- **Ruled out: the hook's own `error()`.** The pump makes 1,139,718 calls,
  deterministically, against a 3,145,728 budget, so the error branch never runs.
  A copy with the error line removed fails at the same rate (3/16, 2/16).
- A copy containing *only* that case passed 16/16, so preceding cases' state
  (garbage, timers) plausibly matters — a GC finalizer or a scheduled callback
  running with the JIT off and the hook installed is the next thing to test.
