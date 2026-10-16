---
id: 000347
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
---

# fs.ensure_dir fails when another process creates an intermediate directory concurrently

## Problem

The #346 merge suite (dbab417a, 2026-10-16) failed `tests/unit/parley_harness_golden_spec.lua` "payload for single-user matches golden" in `vault.setup`:

```
Vim:E739: Cannot create directory …/tmp/claude/parley-harness: file already exists
fs.lua:18 ensure_dir ← helper.lua:831 prepare_dir ← vault.lua:49 setup ← init.lua:604 setup ← scripts/parley_harness.lua:29
```

Likely cause, read from the code: `fs.ensure_dir` tolerates a concurrent creator only for the LEAF. Here the leaf is `…/parley-harness/state`. When another process creates the intermediate `parley-harness` between Vim's `mkdir -p` checking it and creating it, mkdir raises E739 for the intermediate and the leaf is never created. `isdirectory(leaf)` is then false, and `ensure_dir` re-raises. parley_harness_spec, config_tools_spec and the golden spec all run `parley_harness` against the same `$TMPDIR/claude/parley-harness`, in parallel test files. The same race exists for two nvims starting at once.
