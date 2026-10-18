---
id: 000382
status: done
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '76dec0b764c30c400a9d55b940f1f4f1e5f2aa2c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T22:18:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e7cc7b68", done: "65c8fe29"}
actual_hours: 0.84
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
- [x] (Revision 1) The deadline bounds the child from its spawn, not from enqueue. Results carry `queued_ms`/`ran_ms`, and refusals carry the child's `exit`/`stderr`. Spec setups print them through `fake_couch.explain`.
- [x] (Revision 1) Every failure-declaring deadline refreshes the loop clock first, through `helper.start_deadline` (uv timers) or `helper.defer_deadline` (drop-in for `vim.defer_fn`).

## Log



- 2026-10-18: closed — BR-5 fixed across its class: every elapsed-time assertion added in #382 now tolerates libuv ms truncation (document_registry ran_ms >= 290 for a 300 ms deadline, matching start_deadline_spec; the queue case keeps its 300 ms floor against a 600 ms hold). document_registry_spec 11/11. (fixed-then-ship) (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-18: closed — Cause 1: hidden 2.5 s registry default deadline (repro 3/6 loaded rounds, error captured); now the product deadline via one owner (3x for renames, native and journaled); regression + mutation. Cause 2 (parley.nvim:1): deadline started at enqueue, counting queue time; now from spawn; 8 lookups vs 0.6 s fake at 1 s all answer; mutation fails it. Cause 3 (parley.nvim:1, measured): libuv timers start from cached loop time (500 ms timer after a 1 s block fired at 6 ms, 0.11.7 and 0.12.5); helper.start_deadline / defer_deadline refresh the clock for every failure-declaring deadline (registry, submit band, move overdue, oauth, tasker x2, dispatcher recovery, cliproxy update-restart), exclusions listed in Revisions; start_deadline_spec 3/3, mutation fails it. Results carry queued_ms/ran_ms/exit/stderr; both specs print them. Loaded repro after fix 0/6. Revisions + Plan items record the post-close scope. Arch specs clean; full suite green on af3d2f43. (done-when: contract moved since change-code; judged by the close review); review verdict: FIX-THEN-SHIP
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
- Second hypothesis from parley.nvim:1, relayed by the hub: libuv timers start from the loop's cached time, and luv's `timer:start` does not refresh it. **Confirmed.** In headless nvim, after a 1 s synchronous block inside a callback, a 500 ms timer fired **6 ms** after it was started (`uv.now()` was 1 s stale). With `uv.update_time()` first, it fired at 500 ms. Identical on NVIM v0.12.5 and v0.11.7. So in the registry, synchronous work before `pump()` starts a child (spec setup, earlier callbacks) cut the deadline short by that much. It is a second contributor alongside the 2.5 s literal, and it also fits "fails only under load".
- Fix at the cause, as a class. `helper.start_deadline(timer, ms, cb, runtime)` refreshes the loop clock (through an injected runtime's `update_time` when there is one; fakes may lack it) and then starts a one-shot timer. Every deadline whose expiry declares a failure now uses it:
  - the registry child deadline;
  - agentic_document's "not confirmed" submit band;
  - oauth's 30 s login timeout;
  - tasker's reconcile delay and its attempt deadline, both through the record's runtime.
  Excluded after review: repeating timers (spinners, pulses, polls) and one-shot timers whose early firing only shifts a redraw or debounce and declares nothing (spell_blink debounce, session_sync idle, chat_pending, highlighter, interview, init).
- New `tests/unit/start_deadline_spec.lua`. A 300 ms deadline started after a 600 ms block fires at ≥ 290 ms; with `update_time` removed (mutation) it fired after 5 ms and the spec fails. The injected-runtime path is covered with and without `update_time`. Mapped in traceability.yaml.
- Targeted runs pass: start_deadline 2, document_registry 11, agentic_document 47, side_inherit 9, owned_move 43, tasker_run 43, tasker_supervision 30, tasker_unit 16, oauth 110, single_source_sweeps 28.
- The recorded suite on d5bc1f90 failed in tests/arch/arrival_budget_spec: the new start_deadline_spec used `vim.wait(5000, …)`, a bare literal (#374 rule). Fixed to `arrival.MS`; both specs pass. Lesson logged.

## Revisions

- 2026-10-18, after close review round 4 (REWORK, BR-3 scope-change-after-close). Two inputs from parley.nvim:1, relayed and approved by the hub, widened the issue after its close; the Log records each with its measurement.
  - **Delta 1:** a registry deadline bounds the child from spawn, not from enqueue. Queued time behind `MAX_ACTIVE` is not Couch being slow, and a request that never ran cannot have an unknown outcome. The queue is bounded by count (`MAX_QUEUE`, 64), not by time; a caller that needs a wall-clock bound has its own (`bounded_request`). Results carry `queued_ms`/`ran_ms`, and refusals carry `exit`/`stderr`, so an `unavailable` names its cause.
  - **Delta 2:** libuv measures timers from the loop's cached time (measured: a 500 ms timer started after a 1 s block fired at 6 ms on 0.11.7 and 0.12.5). Every timer whose expiry declares a failure now refreshes the clock first.
    - Through `helper.start_deadline`: the registry child, agentic_document's submit band, oauth's login timeout, and tasker's reconcile delay and attempt deadline.
    - Through `helper.defer_deadline` (`vim.defer_fn` deadlines): the agentic_document move-overdue band, the dispatcher recovery timeout and the cliproxy update-restart deadline.
    - Excluded with reasons: repeating timers (spinners, pulses, polls); one-shot timers that only delay work (debounces, highlight clears, deferred_work coalescing, session_sync idle, finder deferrals); and deadlines whose pure model re-reads a fresh clock and re-arms if early (skill_invoke's read reconcile, tools/scheduler's arm).
  - `## Done when` is unchanged. Both deltas serve its "fix at the cause" clause, and each has a regression test with a mutation check.

- Full close review: FIX-THEN-SHIP. BR-5 (Important, elapsed-vs-deadline-tolerance): the deadline case asserted `ran_ms >= 300` for a 300 ms deadline. libuv compares expiry against a millisecond-truncated clock and `ran_ms` is floored, so a correct deadline can read 299, and the reviewer saw it once in 30 runs at 10× load. Swept every elapsed assertion I added: start_deadline_spec's two `>= 290` checks already have 10 ms of tolerance, and the queue case's `queued_ms >= 300` against a 600 ms hold has ample margin. Only this one had none; it is now `>= 290`, with the reason stated. document_registry_spec passes 11/11.
