---
id: 000347
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '9eb24205454fca288904eb700711db8e83e23a80' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T02:04:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6c031e1c", done: "f2b20930"}
---

# fs.ensure_dir fails when another process creates an intermediate directory concurrently

## Problem

The #346 merge suite (dbab417a, 2026-10-16) failed `tests/unit/parley_harness_golden_spec.lua` "payload for single-user matches golden" in `vault.setup`:

```
Vim:E739: Cannot create directory …/tmp/claude/parley-harness: file already exists
fs.lua:18 ensure_dir ← helper.lua:831 prepare_dir ← vault.lua:49 setup ← init.lua:604 setup ← scripts/parley_harness.lua:29
```

Likely cause, read from the code: `fs.ensure_dir` tolerates a concurrent creator only for the LEAF. Here the leaf is `…/parley-harness/state`. When another process creates the intermediate `parley-harness` between Vim's `mkdir -p` checking it and creating it, mkdir raises E739 for the intermediate and the leaf is never created. `isdirectory(leaf)` is then false, and `ensure_dir` re-raises. parley_harness_spec, config_tools_spec and the golden spec all run `parley_harness` against the same `$TMPDIR/claude/parley-harness`, in parallel test files. The same race exists for two nvims starting at once.

## Spec

`ensure_dir` walks the path itself. Each missing level is created by a
single-level `vim.fn.mkdir` (no `p`) with the caller's mode. A failure at any
level is success when the level is a directory afterwards; otherwise the
original error is raised. `vim.fn.mkdir` stays the one production seam.

## Core concepts

| Concept | Meaning |
|---|---|
| `mkdir_level` | creates one directory level and accepts a competitor's directory |

## Done when

- [x] `ensure_dir` succeeds when any ancestor is created concurrently: it keeps going until the leaf exists, and still raises a real failure such as a file at the path or EACCES.
- [x] A test reproduces the intermediate-directory race and fails on the old code.

## Plan

- [x] `fs.ensure_dir` recurses to the parent, then calls `mkdir_level`.
- [x] Red first: a seam case where a competitor wins an intermediate, and the real multi-process race spec.
- [x] Atlas: test_harness.md and traceability.

## Log

### 2026-10-16

- Taken by parley.nvim:3. Measured on the old code: 6 concurrent nvim creators
  x 30 rounds on a shared 8-deep path failed 8 of 180, all E739 on an
  intermediate. Red: `ensure_dir_race_spec` failed 12+ creators in 20 rounds,
  and the new `prepare_dir_spec` seam case failed. Green: both pass, the race
  spec 4 runs in a row, prepare_dir_spec 10/10, luacheck clean.
