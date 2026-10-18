---
id: 000382
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '73871359a770ae8e553510adc4244399f861eaa5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T22:18:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e7cc7b68", done: "65c8fe29"}
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

## Spec

Reproduce first: run the pair in parallel under load, with the registry's error text captured. Find the cause, which may be shared harness state (HOME/XDG, the state dir, a socket or lock path) or a request deadline that load exceeds. Fix it at the cause. If the setup can legitimately be slow, the spec's setup should say why it failed instead of only `unavailable`.

## Done when

- A deterministic or high-rate reproduction of the setup `unavailable`, with the error text captured.
- The fix is at the cause, with a regression test. Both specs pass under the reproduction load, and the full suite passes.

## Plan

- [x] Reproduce, capturing the error text. The setup assertions in both specs now include `code` and `error`.
- [x] Fix at the cause. `document_registry.request` no longer falls back to a 2.5 s literal; a caller that names no deadline gets `agentic_submit_timeout_ms`. `config_ms` moves into `document_registry` as the one owner of agentic deadlines (ARCH-DRY), `agentic_document` uses it, and its two calls that passed that same value explicitly drop it.
- [x] Regression: a `document_registry_spec` case. A lookup with no deadline against a 3 s-slow fake answers; a configured 1 s deadline fails it with "deadline exceeded". With the 2.5 s literal put back, the case fails.
- [x] Re-run the loaded reproduction, then the full suite.

## Log

### 2026-10-17
- Reproduced on the branch base (from main). The pair ran alongside six heavy specs (agentic_document, the two fold-retirement specs, perf_ownership, agentic_document_lifetime and document_move) in one shared test env. Over 6 rounds, the setup was refused in rounds 2, 3 and 4, with `error = "Couch registry deadline exceeded; mutation outcome may be unknown"`. Rounds 2 and 3 hit both specs at once, which is why they fail as a pair.
- Cause: the registry's implicit 2.5 s default deadline. The couch → python3 fake spawn misses it under load. It is not shared state: each spec has its own root, its own fake lock (`<root>/registry.json.lock`) and its own nvim process, and `COUCH_ISOLATED_ROOT` only names the cache namespace.
- The same default was live in production. `document_move`'s journaled metadata renames (lines 994 and 1283) pass `operation.options.registry_options`, which nothing sets, so they ran on 2.5 s.
- Hub check: the journaled rename path does not block the editor while it now waits up to 15 s.
  - `document_move.lua` contains no `vim.wait` or other synchronous wait. Its rename completes through the `metadata_done` / `done` callbacks, on the asynchronous #359 move path, driven by `agentic_document`'s `advance(..., callback)`.
  - The only synchronous registry wait in the product is `agentic_document.bounded_request`, the BufFilePost check before a `:saveas!` overwrite. It already passes its own explicit, shorter deadline (`agentic_move_timeout_ms + 1000`, waited for `agentic_move_timeout_ms`), so this change does not touch it.
  - `git grep vim.wait -- lua` finds only that call plus two unrelated ones, in cliproxy and starter.
- After the fix, the same 6-round loaded reproduction gave 0 deadline hits in either spec (side_inherit 9/9 and owned_move 43/43 in every round), against 3 of 6 rounds before. document_registry_spec passes 8/8.
