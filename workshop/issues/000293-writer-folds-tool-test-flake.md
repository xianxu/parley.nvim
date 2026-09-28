---
id: 000293
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours: 4.14
card_mirror: '4da3ad18c5c48e51bc2778854bc523f065bb28d5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-27T18:27:58-07:00
flow: {kind: full, provenance: inferred}
---

# writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait

## Problem

`tests/integration/writer_folds_spec.lua` (added in #290), case "folds a tool call and a
result over 4 KiB closed as they are written, with no reconcile work", intermittently
fails at its `wait_for(function() return #calls==2 end)` after `first.complete(...)`:
`did not settle` (5 s `vim.wait`). Measured 2/25 failures run alone on `origin/main`
(pre-#291, so not caused by it) and 1/13 on the #291 branch. The other cases in the file,
including the two-round prose-before-call case, did not fail in those runs.

The case drives a real `read_file` of a 300-line file (a 303-row result block, written
whole since #290) through `chat_respond` with the fixture transport, then waits for the
continuation request. Unknown whether the continuation is only slow (repair of the new
rows, the real tool's async IO under load) or sometimes never issued (a race in the round).

## Spec

- Find the root cause before touching the wait: record where the round is when the wait
  expires (runner/machine phase, whether the result block was written, pending document
  repair, whether the continuation was dispatched late or never).
- If it is a real race (continuation never issued), fix it in the runner/round and add a
  test that reproduces the ordering deterministically.
- If it is only slow, make the test wait on the state it needs (not a longer blind
  timeout), and say which cost made it slow.

## Done when

- The root cause is written in the Log with evidence from a captured failing run.
- `writer_folds_spec` passes 50/50 consecutive runs alone, and within `make test`.

## Plan

Durable plan: `workshop/plans/000293-writer-folds-tool-test-flake-plan.md`.

- [x] M1 — guards: deterministic repair work-budget spec (red) + progress-aware wait in writer_folds_spec
- [x] M2 — sequence combine without defensive copies (purity contract); re-measure find_walk predicates
- [ ] M3 — highlighter computes only rows a window draws (skip closed-fold interiors)

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A primitives + Method B sketch on the diagnosis (6 decision points: race vs slow, pump vs document scheduler, GC vs JIT, maxmcode, highlighter vs index share, purity contract).*

- M1 guards (budget spec + progress wait, helper already drafted): lua-neovim, low design (plan done), impl v2 1.0 → 0.4.
- M2 sequence combine contract + property test: lua-neovim, impl v2 0.8 → 0.3.
- M3 visible_spans + per-span on_win + fold-signature cache key + toggle spec: lua-neovim, impl v2 1.2 → 0.5.
- Re-plan mid-flight (quick-flow → full-flow): scope-pivot.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: method-b-decisions     design=0.9 impl=0.0
item: scope-pivot            design=0.35 impl=0.14
item: lua-neovim             design=0.2 impl=0.4
item: lua-neovim             design=0.2 impl=0.3
item: lua-neovim             design=0.3 impl=0.5
item: atlas-docs             design=0.05 impl=0.05
item: milestone-review       design=0.0 impl=0.15
item: milestone-review       design=0.0 impl=0.15
item: milestone-review       design=0.0 impl=0.15
design-buffer: 0.15
total: 4.14
```

## Log

### 2026-09-27
- 2026-09-27: closed M2 — repair_work_budget_spec summary budget now enabled and green (483057 -> 26224 summary copies, drain ~350-580ms -> ~290ms); document_sequence_spec no-copy + purity/bounded-shape property tests pass; make test-spec SPEC=chat/document 36/36 files green; full-suite load flakes (document_semantic, perf_document) pass alone; single_source_sweeps red only on visible_spans, which M3 defines; review verdict: SHIP
- 2026-09-27: closed M1 — repair_work_budget_spec measures baseline (483057 summary copies; 256 rows queried to draw 9) with both budget cases pending for M2/M3; writer_folds_spec (5s stall window) + await_helper_spec (fake-clock stall/ceiling/progress cases) pass; lint clean; review verdict: SHIP
- 2026-09-27: filed during #291 close (operator request).
- 2026-09-27 diagnosis (probes in the spec, jit.profile, document stats):
  - Not a missed continuation. After `first.complete` the result block is written in
    ~50ms; the round then sits in `executing_tools` with `grant_status=suspended`
    until document repair confirms the written region. The continuation is
    gated on that (generation.lua `grant_status=='valid'`).
  - Repair of the 303-row block = ~658-670 productive `repair_step`s, driven by the
    document's own scheduler (document/init.lua `schedule`, 2ms per timer turn).
    A `repair_slice` in the response pumps changed nothing — they are not the driver
    (tried and reverted).
  - Normal runs: 1.9-5.2s (median 3.2s) vs the 5s wait. Each run copies 6-11 MILLION
    metadata values and ~75-160k query results during that repair (`D.stats`), mostly
    `sequence.lua` `copy()` under `query_walk`/`snapshot`, reached from the
    highlighter's per-redraw viewport query (highlighter.lua:947) and update_rebuild.
  - ~10% of runs are pathological: same copies per step, but ~55ms/step instead of
    ~3ms, so repair needs 35s+ and the file hits plenary's 50s timeout. Cause of the
    per-step blow-up not yet identified (GC heap pressure from the copy volume is the
    leading, UNVERIFIED hypothesis).
  - A progress-aware wait (tests/helpers/await.lua `until_progress`, WIP, uncommitted)
    fixes the "slow" half but cannot meet 50/50 against the pathological runs.
  - Conclusion: the root cause is a document-index performance defect (copy volume
    per repair step), outside this issue's quick-flow shell. Needs a re-plan.
- M1 baselines (tests/integration/repair_work_budget_spec.lua, synchronous drain of a
  303-row block, no redraw): summary_values_copied=483057, metadata_values_copied=230111.
  Highlighter over a closed fold on that block: 256 rows queried to draw 9.
  Budget cases committed `pending`; M2 enables the summary budget (96000 = 1/5), M3 the
  drawn-rows budget. writer_folds_spec waits via Await.until_progress on productive
  repair steps (stall 1s, ceiling 40s — below plenary's 50s kill).
- Estimate note: `method-b-decisions design=0.9` is diagnosis time already spent inside
  the claim window, not future design.
- M2: sequence combines take stored summaries without copies. Synchronous drain of the
  303-row block: summary_values_copied 483057 → 26224 (18x); drain 350-580ms → ~290ms.
  metadata_values_copied unchanged at 230111: ~2200 of ~2500 top-level copy calls are
  `M.at` snapshots at the API boundary (plan non-goal); find_walk predicates ~320 calls
  (<20%) → Task 4 contract extension skipped (YAGNI).
- M2 full suite: document_semantic_spec (180s-deadline corpus) and perf_document_spec
  failed only under parallel load, pass alone (the rotating load-flake set seen pre-#293).
  single_source_sweeps: fixed `_VIEWPORT_MARGIN` row + traceability routing; its
  `visible_spans` row stays red until M3 defines it.

## Revisions

### 2026-09-27 — re-planned as full-flow performance work (operator: "re-plan #293")
- Reason: diagnosis showed no race; the continuation is gated on document repair of the
  303-row block, and repair is slow from work volume (millions of defensive metadata/summary
  copies; highlighter recomputing hidden fold rows every redraw). ~10% of runs are further
  amplified by LuaJIT `failed to allocate mcode memory` trace-flush thrash (arm64, environmental).
- Delta: Spec's "if only slow, fix the test wait" is kept (M1) but no longer the fix; the root
  cause fix is M2 (index copies) + M3 (highlighter drawn rows). Plan moved to milestones and a
  durable plan file.

