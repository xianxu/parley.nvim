---
id: 000347
status: done
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T02:04:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.04
tracker:
    version: 1
    completion:
        token: close-45ac24c4f41f
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd
        evidence_commit: 2475a982d42643b5696a1c4bcb521edea4737571
        landed_commit: 147241e6f2f7558f420353c805c740698ceea12b
---

# fs.ensure_dir fails when another process creates an intermediate directory concurrently

## Problem

The #346 merge suite (dbab417a, 2026-10-16) failed `tests/unit/parley_harness_golden_spec.lua` "payload for single-user matches golden" in `vault.setup`:

```
Vim:E739: Cannot create directory …/tmp/claude/parley-harness: file already exists
fs.lua:18 ensure_dir ← helper.lua:831 prepare_dir ← vault.lua:49 setup ← init.lua:604 setup ← scripts/parley_harness.lua:29
```

Likely cause, read from the code: `fs.ensure_dir` tolerates a concurrent creator only for the LEAF. Here the leaf is `…/parley-harness/state`. When another process creates the intermediate `parley-harness` between Vim's `mkdir -p` checking it and creating it, mkdir raises E739 for the intermediate and the leaf is never created. `isdirectory(leaf)` is then false, and `ensure_dir` re-raises. parley_harness_spec, config_tools_spec and the golden spec all run `parley_harness` against the same `$TMPDIR/claude/parley-harness`, in parallel test files. The same race exists for two nvims starting at once.
