---
id: 000447
status: open
deps: []
github_issue:
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
card_mirror: '09798a6937d1ef7bee1d145f1b6216f6e4ba5dad' # card fields mirrored from issue-cards; edit via sdlc
---

# orphan census run-lease case times out its 30 s wait under load

## Problem

tests/unit/reap_test_orphans_spec.lua, case '#220 orphan census serializes real targeted runs and retains orphan cleanup (#409)', runs python3 tests/unit/test_run_lease.py under a fixed 30 s vim.system wait. Under load that wait expires (exit 124), and the case fails on wall clock alone.

This is the class ariadne#622 swept in ariadne: a wall-clock bound that fails under machine load rather than on a defect.

## Spec

Give the wait a bound derived from the suite's load-scaled budget (or the arrival budget), or make the Python test's own waits load-tolerant. Keep the case's assertions. Note: one of the landings that hit this was a docs-only move (#445), which should not need a full suite at all (ariadne#632).

## Done when

- The case passes under load without a fixed 30 s wall-clock bound failing it.
- The flake registration is retired.

## Plan

## Log

Evidence:
- Main baseline suite on 354bb2a7a639306b0be17454e1b6c5df2790e29a during the #445 merge: log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/cbf5aa80bc61fe5013002e0c6adf71d4.log (sha256:668e9c47c2e6). reap_test_orphans_spec.lua:29 expected 0 and got 124. The 1-minute load was 29 to 33 at the time.
- Earlier, during #442 targeted runs on 0.12.5 at a load of about 40, the same timeout (exit 124) occurred; a rerun passed.

Filed at hub direction (6670f8b9).
