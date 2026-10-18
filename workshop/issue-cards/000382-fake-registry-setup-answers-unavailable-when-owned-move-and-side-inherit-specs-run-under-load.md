---
id: 000382
status: open
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T22:18:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load

## Problem

Under full-suite load, `tests/integration/agentic_document_owned_move_spec.lua` and `tests/integration/agentic_document_side_inherit_spec.lua` fail together. In each, the `before_each` setup `register(...)` gets `kind = "unavailable"` from the fake registry (side_inherit:22, owned_move:56), so every case in both files fails before it starts. Both pass alone and have passed in several recorded suites.

Seen twice:
- In a sandboxed `make test` during #379 (2026-10-17).
- In #379's unchanged recorded rerun on 5f64a8f011e53d4c5ed0dec5f91245242e6773bc, where the 0.12 pass failed on exactly this pair. Log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8f2a16c3db0bb7de1990a5fd23803eeb.log`.

The other #379 attempt (log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/c2a80924993e69f8b0acfab8f82b0969.log`) failed instead on a #267-family stall, `document_fold_batches_spec` on 0.11. That is kept as context, not as this defect.

`side_inherit` is new in #378, so the pair has run together only since then. The specs assert only `kind`, so the logs do not say why the registry answered unavailable.

Already ruled out on reading:
- `COUCH_ISOLATED_ROOT` only names the cache namespace.
- The fake's lock is per registry file (`<root>/registry.json.lock`).
- Each spec uses its own root, and each runs in its own nvim process.
