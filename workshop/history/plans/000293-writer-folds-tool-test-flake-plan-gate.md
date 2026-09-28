---
gate: plan-quality
issue: 293
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-27T20:11:42-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: M2 combine change cannot move metadata_values_copied, yet Task 1 budgets both counters and Task 3 expects the index case green
          detail: copy() counts summary=true as summary_values_copied (sequence.lua:15); combine copies are summary-only. Metadata copies come from snapshot :247, find_walk :685/:697, update :454 and membership :60. Split the budgets and assign each to the milestone that actually moves it; make Task 4's threshold consistent with them.
          family: budget-attributed-to-wrong-counter
          round: 1
        - id: PQ-2
          severity: Important
          title: Removing copy() around combine also removes the bounded-schema and value-type assertions on summaries
          detail: copy() enforces the 256-value summary bound and rejects function/userdata values (sequence.lua:11-18). The plan documents only the purity contract. Either keep a cheap bound check on the combine result, or state explicitly that the invariant is dropped for combine outputs.
          family: unstated-seam-contract-change
          round: 1
        - id: PQ-3
          severity: Important
          title: on_win decoration cache is not keyed on fold state once decorations skip closed-fold interiors
          detail: The cache key is toprow/end_row/leftcol/skipcol (highlighter.lua:1076-1078). Opening a fold without a botrow change, or during pagination, leaves the interior rows undecorated. Name the fold-toggle event, invalidate the cache on it (e.g. a fold-span signature), and add a toggle-and-redraw spec case.
          family: cache-key-omits-state-dependency
          round: 1
        - id: PQ-4
          severity: Minor
          title: No fallback if mcode thrash still breaks 50/50 after the work cuts
          detail: The repair step count stays at ~660. State what is re-measured and when to escalate, rather than assuming less work per step reaches 50/50.
          family: done-when-feasibility-unstated
          round: 1
        - id: PQ-5
          severity: Minor
          title: No stated non-goals (grant gate unchanged, LuaJIT mcode fix out of scope, per-row repair cost untouched)
          family: missing-non-goals
          round: 1
        - id: PQ-6
          severity: Minor
          title: Task 5 lists visible_spans cases in prose; replace with one strategy line
          detail: Property-check visible_spans against a brute-force row filter over random fold layouts.
          family: enumerated-test-prose
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-27T20:12:11-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: not-addressed
          note: Plan unchanged; Task 1 still budgets both counters at baseline/5 and Task 3 Step 3 still expects the index case green from a summary-only change.
          round: 2
        - id: PQ-2
          disposition: not-addressed
          note: Task 3 code still drops copy()'s 256-value bound and value-type asserts (sequence.lua:11-18) without saying so.
          round: 2
        - id: PQ-3
          disposition: not-addressed
          note: on_win cache key (highlighter.lua:1076-1078) still omits fold state; Task 6 adds no invalidation and no toggle-and-redraw case.
          round: 2
        - id: PQ-4
          disposition: not-addressed
          note: No re-measure/escalation step for the mcode-thrash tail against the 50/50 Done-when.
          round: 2
        - id: PQ-5
          disposition: not-addressed
          note: No non-goals section.
          round: 2
        - id: PQ-6
          disposition: not-addressed
          note: Task 5 Step 1 still enumerates cases in prose.
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-27T20:13:10-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Index case budgets summary_values_copied only (moved by M2); metadata is logged, or budgeted in Task 4 if the contract is extended.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Bound/type checks on combine outputs moved to a property unit test; insert/replace keep runtime copy() checks.
          round: 3
        - id: PQ-3
          disposition: addressed
          note: Fold signature (serialized visible_spans) added to the on_win cache key; open-fold/redraw spec case added in Task 6 Step 2.
          round: 3
        - id: PQ-4
          disposition: addressed
          note: Verification now names the re-measurement, the 40s escalation threshold, and the next lever.
          round: 3
        - id: PQ-5
          disposition: addressed
          round: 3
        - id: PQ-6
          disposition: addressed
          round: 3
      blocked: false
    - "n": 4
      timestamp: "2026-09-27T20:14:03-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          round: 4
        - id: PQ-2
          disposition: addressed
          round: 4
        - id: PQ-3
          disposition: addressed
          round: 4
        - id: PQ-4
          disposition: addressed
          round: 4
        - id: PQ-5
          disposition: addressed
          round: 4
        - id: PQ-6
          disposition: addressed
          round: 4
      blocked: false
content_hash: 23b466086c194a70882fe2458606b024cae290180a7f4bde2421931c928076cd
---

# Gate ledger — parley.nvim#293 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T20:11:42-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `budget-attributed-to-wrong-counter` M2 combine change cannot move metadata_values_copied, yet Task 1 budgets both counters and Task 3 expects the index case green
  copy() counts summary=true as summary_values_copied (sequence.lua:15); combine copies are summary-only. Metadata copies come from snapshot :247, find_walk :685/:697, update :454 and membership :60. Split the budgets and assign each to the milestone that actually moves it; make Task 4's threshold consistent with them.
- **PQ-2** [Important] `unstated-seam-contract-change` Removing copy() around combine also removes the bounded-schema and value-type assertions on summaries
  copy() enforces the 256-value summary bound and rejects function/userdata values (sequence.lua:11-18). The plan documents only the purity contract. Either keep a cheap bound check on the combine result, or state explicitly that the invariant is dropped for combine outputs.
- **PQ-3** [Important] `cache-key-omits-state-dependency` on_win decoration cache is not keyed on fold state once decorations skip closed-fold interiors
  The cache key is toprow/end_row/leftcol/skipcol (highlighter.lua:1076-1078). Opening a fold without a botrow change, or during pagination, leaves the interior rows undecorated. Name the fold-toggle event, invalidate the cache on it (e.g. a fold-span signature), and add a toggle-and-redraw spec case.
- **PQ-4** [Minor] `done-when-feasibility-unstated` No fallback if mcode thrash still breaks 50/50 after the work cuts
  The repair step count stays at ~660. State what is re-measured and when to escalate, rather than assuming less work per step reaches 50/50.
- **PQ-5** [Minor] `missing-non-goals` No stated non-goals (grant gate unchanged, LuaJIT mcode fix out of scope, per-row repair cost untouched)
- **PQ-6** [Minor] `enumerated-test-prose` Task 5 lists visible_spans cases in prose; replace with one strategy line
  Property-check visible_spans against a brute-force row filter over random fold layouts.

## Round 2 — 2026-09-27T20:12:11-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — not-addressed — Plan unchanged; Task 1 still budgets both counters at baseline/5 and Task 3 Step 3 still expects the index case green from a summary-only change.
- PQ-2 — not-addressed — Task 3 code still drops copy()'s 256-value bound and value-type asserts (sequence.lua:11-18) without saying so.
- PQ-3 — not-addressed — on_win cache key (highlighter.lua:1076-1078) still omits fold state; Task 6 adds no invalidation and no toggle-and-redraw case.
- PQ-4 — not-addressed — No re-measure/escalation step for the mcode-thrash tail against the 50/50 Done-when.
- PQ-5 — not-addressed — No non-goals section.
- PQ-6 — not-addressed — Task 5 Step 1 still enumerates cases in prose.

## Round 3 — 2026-09-27T20:13:10-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Index case budgets summary_values_copied only (moved by M2); metadata is logged, or budgeted in Task 4 if the contract is extended.
- PQ-2 — addressed — Bound/type checks on combine outputs moved to a property unit test; insert/replace keep runtime copy() checks.
- PQ-3 — addressed — Fold signature (serialized visible_spans) added to the on_win cache key; open-fold/redraw spec case added in Task 6 Step 2.
- PQ-4 — addressed — Verification now names the re-measurement, the 40s escalation threshold, and the next lever.
- PQ-5 — addressed
- PQ-6 — addressed

## Round 4 — 2026-09-27T20:14:03-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed
- PQ-2 — addressed
- PQ-3 — addressed
- PQ-4 — addressed
- PQ-5 — addressed
- PQ-6 — addressed

## Open findings

(none — every finding has been disposed)
