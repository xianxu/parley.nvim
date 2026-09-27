---
gate: boundary-review
issue: 264
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T13:04:40-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
          detail: |-
            Replace Task 2 Step 1's eight prose cases with one strategy line - property-test random existing/desired interval sets (nested, overlapping, adjacent) with the oracle: applying batches yields exactly desired, exact matches never appear in a batch, each overlap component is in one batch.
            (carried from plan-quality PQ-1, deferred to the boundary review)
          family: test-strategy-not-enumeration
          round: 1
        - id: BR-2
          severity: Minor
          title: FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
          detail: |-
            State that an oversized connected region forms its own batch that exceeds limit, and give its bound, since reconcile applies one batch per slice.
            (carried from plan-quality PQ-2, deferred to the boundary review)
          family: pure-contract-underspecified
          round: 1
        - id: BR-3
          severity: Minor
          title: M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
          detail: |-
            semantic.lua:255-264 computes restart, pulls back to the answer header and reads the checkpoint from the preceding row's after. Extract that into one helper used by both before_splice and before_fragment, and reuse the header before_fragment already captures (:388).
            (carried from plan-quality PQ-3, deferred to the boundary review)
          family: reuse-existing-helper
          round: 1
        - id: BR-4
          severity: Minor
          title: Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
          detail: |-
            Manual fold commands do not bump changedtick, so the inventory can be stale and N,Mfold can nest inside a user fold. Either re-verify each batch's rows before applying it, or state why the next plan converges benignly.
            (carried from plan-quality PQ-4, deferred to the boundary review)
          family: interleaving-unmodeled
          round: 1
        - id: BR-5
          severity: Minor
          title: apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
          detail: |-
            Say whether suspended windows run inventory+reconcile under foldenable=false or keep the old phases; document_fold_batches_spec and the uncertainty retirement spec depend on which.
            (carried from plan-quality PQ-5, deferred to the boundary review)
          family: preserved-path-underspecified
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-27T13:04:40-07:00"
      agent: claude
      findings:
        - id: BR-6
          severity: Minor
          title: fold_native inventory can break on zC failure yet report done=true, truncating the inventory
          detail: The `s:fs == -1` break leaves done computed true; the creation pre-check then discards and re-plans without bound. Flag the failure so done is false, or raise an error.
          family: walk-early-exit-reports-done
          round: 2
        - id: BR-7
          severity: Minor
          title: clear_uncertainty computes first then recomputes the same expression for job.first
          family: duplicated-expression
          round: 2
        - id: BR-8
          severity: Minor
          title: reconcile removal guard checks foldlevel at the start row only, not the inventoried extent
          detail: A user fold at the same start row but a different extent, made between slices, would be zD'd. The pre-#264 clear walk had the same reach, so this is not a regression.
          family: stale-inventory-guard-precision
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: false
    - "n": 3
      timestamp: "2026-09-27T15:04:50-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: tests/unit/fold_diff_spec.lua:67 property test over 200 seeds (exact matches untouched, regions whole, desired reached).
          round: 3
        - id: BR-2
          disposition: addressed
          note: fold_diff.lua:11 and plan Step 3 state an oversized connected region forms its own batch exceeding limit, bounded by the plan span.
          round: 3
        - id: BR-3
          disposition: addressed
          note: semantic.lua:220 restart_point shared by before_splice (:272) and before_fragment (:417); header reuse replaced by the helper, deviation logged.
          round: 3
        - id: BR-4
          disposition: addressed
          note: tool_folds.lua reconcile re-verifies each batch before applying it (removals still folded, creation rows fold-free) and discards the plan when stale.
          round: 3
        - id: BR-5
          disposition: addressed
          note: Suspended scopes run the same inventory+reconcile with paged walks (tool_folds.lua:257,262); the old clear/create phases are gone.
          round: 3
      findings:
        - id: BR-9
          severity: Minor
          title: evidence_store entries are hand-built at three sites; one constructor should own the shape after_splice reads
          detail: This is the 2nd finding in family reuse-existing-helper. The rule is that a record read by one consumer (after_splice) is built by one constructor next to it. before_splice evidence() (:246), before_fragment normal (:410) and the new after_fragment local restart (:520) should all build through it, rather than fixing this one site.
          family: reuse-existing-helper
          round: 3
        - id: BR-10
          severity: Minor
          title: prune_from in before_fragment omits the before_rank the plan specified; the deviation is unlogged
          detail: This is the 2nd finding in family preserved-path-underspecified. The rule is that every plan-specified option that the implementation drops is recorded in the Log with its reason. The call matches the fragment path's own restart_origin call, and cost stays bounded by dep_budget.
          family: preserved-path-underspecified
          round: 3
        - id: BR-11
          severity: Minor
          title: No test reaches after_fragment's failing guard branch (index changed since prune)
          detail: semantic.lua:519 falls back to row 0 when w.deps or its roots changed. No fixture mutates the index between before_fragment and after_fragment, so the guard is defensive and unexercised. A unit test that calls deps:add between the two calls would pin it.
          family: guard-branch-untested
          round: 3
      boundary: M2
      recipe: milestone-review
      blocked: false
    - "n": 4
      timestamp: "2026-09-27T15:20:39-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: not-addressed
          note: Code fix present (fold_native.lua:105,176) but untested; Log claims no deterministic trigger, yet foldminlines=1 plus a one-row fold (3,3fold) makes zC fail deterministically (verified headless). Add that fold_native_spec case.
          round: 4
        - id: BR-7
          disposition: addressed
          note: tool_folds.lua:139 computes first once; job.first=first at :147 (pure refactor, no behaviour change).
          round: 4
        - id: BR-8
          disposition: withdrawn
          note: 'Accepted in the Log (M1 review minors item 3): same reach as the pre-#264 clear walk, not a regression; a re-plan converges.'
          round: 4
        - id: BR-9
          disposition: addressed
          note: splice_evidence (semantic.lua:227) is the sole evidence_store writer (:229); before_splice, before_fragment normal and after_fragment local restart all use it.
          round: 4
        - id: BR-10
          disposition: addressed
          note: Plan deviation (prune_from without before_rank) is logged in the issue M2 review entry with its reason.
          round: 4
        - id: BR-11
          disposition: addressed
          note: document_semantic_spec guard test; reverting the guard at semantic.lua:531 in a scratch copy turns it red (21/22).
          round: 4
      findings:
        - id: BR-12
          severity: Minor
          title: splice_evidence takes a status parameter no caller passes
          detail: 'semantic.lua:227: every caller passes nil, so status is always derived from fallback. Drop the parameter so the constructor''s surface matches its use.'
          family: preserved-path-underspecified
          round: 4
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#264 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T13:04:40-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `test-strategy-not-enumeration` fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
  Replace Task 2 Step 1's eight prose cases with one strategy line - property-test random existing/desired interval sets (nested, overlapping, adjacent) with the oracle: applying batches yields exactly desired, exact matches never appear in a batch, each overlap component is in one batch.
  (carried from plan-quality PQ-1, deferred to the boundary review)
- **BR-2** [Minor] `pure-contract-underspecified` FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
  State that an oversized connected region forms its own batch that exceeds limit, and give its bound, since reconcile applies one batch per slice.
  (carried from plan-quality PQ-2, deferred to the boundary review)
- **BR-3** [Minor] `reuse-existing-helper` M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
  semantic.lua:255-264 computes restart, pulls back to the answer header and reads the checkpoint from the preceding row's after. Extract that into one helper used by both before_splice and before_fragment, and reuse the header before_fragment already captures (:388).
  (carried from plan-quality PQ-3, deferred to the boundary review)
- **BR-4** [Minor] `interleaving-unmodeled` Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
  Manual fold commands do not bump changedtick, so the inventory can be stale and N,Mfold can nest inside a user fold. Either re-verify each batch's rows before applying it, or state why the next plan converges benignly.
  (carried from plan-quality PQ-4, deferred to the boundary review)
- **BR-5** [Minor] `preserved-path-underspecified` apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
  Say whether suspended windows run inventory+reconcile under foldenable=false or keep the old phases; document_fold_batches_spec and the uncertainty retirement spec depend on which.
  (carried from plan-quality PQ-5, deferred to the boundary review)

## Round 2 — 2026-09-27T13:04:40-07:00 (claude) — passed

### Raised

- **BR-6** [Minor] `walk-early-exit-reports-done` fold_native inventory can break on zC failure yet report done=true, truncating the inventory
  The `s:fs == -1` break leaves done computed true; the creation pre-check then discards and re-plans without bound. Flag the failure so done is false, or raise an error.
- **BR-7** [Minor] `duplicated-expression` clear_uncertainty computes first then recomputes the same expression for job.first
- **BR-8** [Minor] `stale-inventory-guard-precision` reconcile removal guard checks foldlevel at the start row only, not the inventoried extent
  A user fold at the same start row but a different extent, made between slices, would be zD'd. The pre-#264 clear walk had the same reach, so this is not a regression.

## Round 3 — 2026-09-27T15:04:50-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — tests/unit/fold_diff_spec.lua:67 property test over 200 seeds (exact matches untouched, regions whole, desired reached).
- BR-2 — addressed — fold_diff.lua:11 and plan Step 3 state an oversized connected region forms its own batch exceeding limit, bounded by the plan span.
- BR-3 — addressed — semantic.lua:220 restart_point shared by before_splice (:272) and before_fragment (:417); header reuse replaced by the helper, deviation logged.
- BR-4 — addressed — tool_folds.lua reconcile re-verifies each batch before applying it (removals still folded, creation rows fold-free) and discards the plan when stale.
- BR-5 — addressed — Suspended scopes run the same inventory+reconcile with paged walks (tool_folds.lua:257,262); the old clear/create phases are gone.

### Raised

- **BR-9** [Minor] `reuse-existing-helper` evidence_store entries are hand-built at three sites; one constructor should own the shape after_splice reads
  This is the 2nd finding in family reuse-existing-helper. The rule is that a record read by one consumer (after_splice) is built by one constructor next to it. before_splice evidence() (:246), before_fragment normal (:410) and the new after_fragment local restart (:520) should all build through it, rather than fixing this one site.
- **BR-10** [Minor] `preserved-path-underspecified` prune_from in before_fragment omits the before_rank the plan specified; the deviation is unlogged
  This is the 2nd finding in family preserved-path-underspecified. The rule is that every plan-specified option that the implementation drops is recorded in the Log with its reason. The call matches the fragment path's own restart_origin call, and cost stays bounded by dep_budget.
- **BR-11** [Minor] `guard-branch-untested` No test reaches after_fragment's failing guard branch (index changed since prune)
  semantic.lua:519 falls back to row 0 when w.deps or its roots changed. No fixture mutates the index between before_fragment and after_fragment, so the guard is defensive and unexercised. A unit test that calls deps:add between the two calls would pin it.

## Round 4 — 2026-09-27T15:20:39-07:00 (claude) — passed

### Disposed

- BR-6 — not-addressed — Code fix present (fold_native.lua:105,176) but untested; Log claims no deterministic trigger, yet foldminlines=1 plus a one-row fold (3,3fold) makes zC fail deterministically (verified headless). Add that fold_native_spec case.
- BR-7 — addressed — tool_folds.lua:139 computes first once; job.first=first at :147 (pure refactor, no behaviour change).
- BR-8 — withdrawn — Accepted in the Log (M1 review minors item 3): same reach as the pre-#264 clear walk, not a regression; a re-plan converges.
- BR-9 — addressed — splice_evidence (semantic.lua:227) is the sole evidence_store writer (:229); before_splice, before_fragment normal and after_fragment local restart all use it.
- BR-10 — addressed — Plan deviation (prune_from without before_rank) is logged in the issue M2 review entry with its reason.
- BR-11 — addressed — document_semantic_spec guard test; reverting the guard at semantic.lua:531 in a scratch copy turns it red (21/22).

### Raised

- **BR-12** [Minor] `preserved-path-underspecified` splice_evidence takes a status parameter no caller passes
  semantic.lua:227: every caller passes nil, so status is always derived from fallback. Drop the parameter so the constructor's surface matches its use.

## Open findings

- **BR-6** [Minor] `walk-early-exit-reports-done` fold_native inventory can break on zC failure yet report done=true, truncating the inventory
- **BR-12** [Minor] `preserved-path-underspecified` splice_evidence takes a status parameter no caller passes
