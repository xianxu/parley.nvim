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

## Open findings

- **BR-1** [Minor] `test-strategy-not-enumeration` fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
- **BR-2** [Minor] `pure-contract-underspecified` FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
- **BR-3** [Minor] `reuse-existing-helper` M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
- **BR-4** [Minor] `interleaving-unmodeled` Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
- **BR-5** [Minor] `preserved-path-underspecified` apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
- **BR-6** [Minor] `walk-early-exit-reports-done` fold_native inventory can break on zC failure yet report done=true, truncating the inventory
- **BR-7** [Minor] `duplicated-expression` clear_uncertainty computes first then recomputes the same expression for job.first
- **BR-8** [Minor] `stale-inventory-guard-precision` reconcile removal guard checks foldlevel at the start row only, not the inventoried extent
