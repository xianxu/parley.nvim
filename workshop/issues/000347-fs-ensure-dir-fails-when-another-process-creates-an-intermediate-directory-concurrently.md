---
id: 000347
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '0737e219b25277d6f8ac9f85dcec665729b2fe77' # card fields mirrored from issue-cards; edit via sdlc
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

## Done when

- `ensure_dir` succeeds when any ancestor is created concurrently: it keeps going until the leaf exists, and still raises a real failure such as a file at the path or EACCES.
- A test reproduces the intermediate-directory race and fails on the old code.

## Plan

- [ ]

## Log

### 2026-10-16
