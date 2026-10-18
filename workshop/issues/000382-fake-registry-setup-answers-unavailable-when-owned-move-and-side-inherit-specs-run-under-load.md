---
id: 000382
status: codecomplete
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '36f8ee7ce38e135355f51b38ec68e98b3b0413a6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T22:18:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e7cc7b68", done: "65c8fe29"}
actual_hours: 0.49
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
- 2026-10-17: closed — Round-2 Minor fixed: the default-deadline case now renames through request() against a fake holding the rename 2 s with a 1 s submit deadline (past 1x, inside 3x) and asserts it is answered; config/env restored after a pcall; reverting request() to the flat deadline fails it (mutation). document_registry_spec 9/9. (fixed-then-ship); review verdict: SHIP
- 2026-10-17: closed — Review Minor fixed as one rule: document_registry.default_deadline_ms gives a rename 3 submit deadlines (file already moved, #359) and anything else 1, for native and journaled renames alike; the native rename now uses it instead of restating 3x; config.lua comment and atlas match; only bounded_request names its own shorter deadline. New document_registry_spec case pins lookup/register/forget=submit and rename=3x under a configured 2000 ms. document_registry 9/9, owned_move 43, document_move 76, agentic_document 47. (fixed-then-ship); review verdict: SHIP
- 2026-10-17: closed — Reproduced: pair under an 8-way shared-env load, setup register refused in 3/6 rounds with "Couch registry deadline exceeded" (2 rounds hit both specs, hence the pairing). Cause: document_registry.request defaulted to a 2.5 s literal when no deadline was named (spec setups; also production document_move journaled renames, registry_options never set). Fix: default is agentic_submit_timeout_ms via one owner, document_registry.config_ms (agentic_document reuses it). Journaled rename path is async (callbacks, no vim.wait in document_move); the only synchronous registry wait (bounded_request) keeps its explicit shorter deadline. Regression: document_registry_spec, no-deadline lookup survives a 3 s fake, 1 s config fails it; restoring 2500 fails it. Same loaded repro after the fix: 0/6 rounds. Full suite green on 50198376 (atlas line since).; review verdict: SHIP
- Reproduced on the branch base (from main). The pair ran alongside six heavy specs (agentic_document, the two fold-retirement specs, perf_ownership, agentic_document_lifetime and document_move) in one shared test env. Over 6 rounds, the setup was refused in rounds 2, 3 and 4, with `error = "Couch registry deadline exceeded; mutation outcome may be unknown"`. Rounds 2 and 3 hit both specs at once, which is why they fail as a pair.
- Cause: the registry's implicit 2.5 s default deadline. The couch → python3 fake spawn misses it under load. It is not shared state: each spec has its own root, its own fake lock (`<root>/registry.json.lock`) and its own nvim process, and `COUCH_ISOLATED_ROOT` only names the cache namespace.
- The same default was live in production. `document_move`'s journaled metadata renames (lines 994 and 1283) pass `operation.options.registry_options`, which nothing sets, so they ran on 2.5 s.
- Hub check: the journaled rename path does not block the editor while it now waits up to 15 s.
  - `document_move.lua` contains no `vim.wait` or other synchronous wait. Its rename completes through the `metadata_done` / `done` callbacks, on the asynchronous #359 move path, driven by `agentic_document`'s `advance(..., callback)`.
  - The only synchronous registry wait in the product is `agentic_document.bounded_request`, the BufFilePost check before a `:saveas!` overwrite. It already passes its own explicit, shorter deadline (`agentic_move_timeout_ms + 1000`, waited for `agentic_move_timeout_ms`), so this change does not touch it.
  - `git grep vim.wait -- lua` finds only that call plus two unrelated ones, in cliproxy and starter.
- After the fix, the same 6-round loaded reproduction gave 0 deadline hits in either spec (side_inherit 9/9 and owned_move 43/43 in every round), against 3 of 6 rounds before. document_registry_spec passes 8/8.
- Close review returned SHIP, with one Minor (deadline-single-owner). Journaled document_move renames got 1× the submit deadline while the native rename got 3×, and the atlas said the registry owned all agentic deadlines while the 3× rule still lived in agentic_document. Fixed as one rule in the registry: `document_registry.default_deadline_ms(op)` gives a rename three submit deadlines and anything else one, because the file has already moved (#359), and that holds for journaled renames too. The native rename now takes the default instead of restating it. The config.lua comment and the atlas now say exactly this; only the inline `:saveas!` check (`bounded_request`) names its own, shorter deadline. New case in document_registry_spec: with the submit deadline at 2000, lookup/register/forget get 2000 and rename gets 6000. Passing: document_registry 9/9, owned_move 43, document_move 76, agentic_document 47.
- Close review round 2 returned SHIP, with one Minor (regression-test-pins-wiring): the default-deadline test checked the helper's arithmetic but stayed green when `request()` stopped using it. The case now also renames through `request()` against a fake that holds the rename 2 s, with a 1 s submit deadline: past one deadline and inside three, so it is still answered. Config and env are restored after a `pcall`. With `request()` reverted to the flat deadline, the case fails. document_registry_spec passes 9/9.
- Input from parley.nvim:1, relayed by the hub, after it hit the same failure in its #267 suite. Both points are adopted:
  1. **Deadline from spawn.** The timer started at enqueue, so time spent queued behind `MAX_ACTIVE` (4) running children counted as Couch being slow, and a request that timed out while still queued reported "mutation outcome may be unknown" although nothing had run. The module header already promises that "the queue and child lifetime are bounded independently": the queue by count (`MAX_QUEUE` 64), the child by its deadline. The timer is now created in `item.start` right after the spawn, and the deadline message names its length.
  2. **The refusal names its cause.** Every result carries `queued_ms` and `ran_ms`, and a refusal from the child also carries its `exit` code and `stderr` (first 400 bytes). The shared `tests/helpers/fake_couch.explain(result)` prints all of it plus `code`/`error`, and both specs' setup assertions use it.
  New document_registry_spec cases:
  - Eight lookups against a 0.6 s fake, each with a 1 s deadline, all answer, and at least 4 of them queued 300 ms or more. Mutation check: counting the queue time (deadline minus queued time) fails it.
  - An unsupported verb returns `exit` 2, the fake's stderr, and `queued_ms`/`ran_ms`. A 300 ms deadline against a 2 s fake says "deadline exceeded after 300 ms", with `ran_ms` ≥ 300.
  Targeted runs pass: document_registry 11, side_inherit 9, owned_move 43, agentic_document 47, lifetime 10, document_move 76, document_band 32, session_sync 64.
