---
id: 000336
status: done
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T15:41:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.39
tracker:
    version: 1
    completion:
        token: close-bc252754d6e1
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 01ebf08816a07f290c4382c016fc195792b43c19
        evidence_commit: db85e81c583c2e6280c307fe511320c879ee735b
        landed_commit: 42899731dc07c17968df53a8d1af9c70be2b9810
---

# Flake: packaging VM guest chat confinement follows transient focus

## Problem

Flake first seen 2026-10-15 during #332 verification: tests/integration/packaging_vm_spec.lua, case exercises guest fake first use, login prompt and real chat dispatch in an isolated profile, failed its guest current-buffer confinement assertion. An unchanged focused rerun passed all17cases. Per test-economy rule, retain this as a tracked flake rather than treating rerun success as disposal.
