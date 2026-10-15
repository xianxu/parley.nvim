---
id: 000336
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
---

# Flake: packaging VM guest chat confinement follows transient focus

## Problem

Flake first seen 2026-10-15 during #332 verification: tests/integration/packaging_vm_spec.lua, case exercises guest fake first use, login prompt and real chat dispatch in an isolated profile, failed its guest current-buffer confinement assertion. An unchanged focused rerun passed all17cases. Per test-economy rule, retain this as a tracked flake rather than treating rerun success as disposal.
