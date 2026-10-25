---
id: 000447
status: open
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
github_issue:
---

# orphan census run-lease case times out its 30 s wait under load

## Problem

tests/unit/reap_test_orphans_spec.lua, case '#220 orphan census serializes real targeted runs and retains orphan cleanup (#409)', runs python3 tests/unit/test_run_lease.py under a fixed 30 s vim.system wait. Under load that wait expires (exit 124), and the case fails on wall clock alone.

This is the class ariadne#622 swept in ariadne: a wall-clock bound that fails under machine load rather than on a defect.
