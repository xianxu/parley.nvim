---
id: 000384
status: done
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
started: 2026-10-18T00:28:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.52
tracker:
    version: 1
    completion:
        token: close-28a611142e54
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 9e3ea59d8048877d821f8b18a8af690530a5c02b
        evidence_commit: e8cdcdc4b0909a13a42288e51cddf35b0b815631
        landed_commit: 61a5826f3e244db0dda3d47877d5b0e2e4450a3c
kind: feature
---

# Frontmatter typeahead for enum values (collaboration-mode first, generic registry)

## Problem

Frontmatter keys with a fixed set of values (`collaboration-mode:` today, `presentation:` with #383, the issue `status:`) are typed from memory, and a typo only surfaces when the review fails (`collaboration-mode` "fails: name the bad mode"). The operator asked for typeahead on these values (via the hub, 10-18). It must draw on the definition parley already enforces, not a second hardcoded list, and be generic, so other enum keys join by declaring their values.
