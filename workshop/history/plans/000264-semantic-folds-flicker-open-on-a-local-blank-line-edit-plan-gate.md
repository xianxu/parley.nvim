---
gate: plan-quality
issue: 264
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-27T12:23:18-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Minor
          title: fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
          detail: 'Replace Task 2 Step 1''s eight prose cases with one strategy line - property-test random existing/desired interval sets (nested, overlapping, adjacent) with the oracle: applying batches yields exactly desired, exact matches never appear in a batch, each overlap component is in one batch.'
          family: test-strategy-not-enumeration
          round: 1
        - id: PQ-2
          severity: Minor
          title: FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
          detail: State that an oversized connected region forms its own batch that exceeds limit, and give its bound, since reconcile applies one batch per slice.
          family: pure-contract-underspecified
          round: 1
        - id: PQ-3
          severity: Minor
          title: M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
          detail: semantic.lua:255-264 computes restart, pulls back to the answer header and reads the checkpoint from the preceding row's after. Extract that into one helper used by both before_splice and before_fragment, and reuse the header before_fragment already captures (:388).
          family: reuse-existing-helper
          round: 1
        - id: PQ-4
          severity: Minor
          title: Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
          detail: Manual fold commands do not bump changedtick, so the inventory can be stale and N,Mfold can nest inside a user fold. Either re-verify each batch's rows before applying it, or state why the next plan converges benignly.
          family: interleaving-unmodeled
          round: 1
        - id: PQ-5
          severity: Minor
          title: apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
          detail: Say whether suspended windows run inventory+reconcile under foldenable=false or keep the old phases; document_fold_batches_spec and the uncertainty retirement spec depend on which.
          family: preserved-path-underspecified
          round: 1
      blocked: false
content_hash: db906c44b877a9f2096129c79d42dea866103ac23e62afb0544ac841904e7a61
---

# Gate ledger — parley.nvim#264 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T12:23:18-07:00 (claude) — passed

### Raised

- **PQ-1** [Minor] `test-strategy-not-enumeration` fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
  Replace Task 2 Step 1's eight prose cases with one strategy line - property-test random existing/desired interval sets (nested, overlapping, adjacent) with the oracle: applying batches yields exactly desired, exact matches never appear in a batch, each overlap component is in one batch.
- **PQ-2** [Minor] `pure-contract-underspecified` FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
  State that an oversized connected region forms its own batch that exceeds limit, and give its bound, since reconcile applies one batch per slice.
- **PQ-3** [Minor] `reuse-existing-helper` M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
  semantic.lua:255-264 computes restart, pulls back to the answer header and reads the checkpoint from the preceding row's after. Extract that into one helper used by both before_splice and before_fragment, and reuse the header before_fragment already captures (:388).
- **PQ-4** [Minor] `interleaving-unmodeled` Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
  Manual fold commands do not bump changedtick, so the inventory can be stale and N,Mfold can nest inside a user fold. Either re-verify each batch's rows before applying it, or state why the next plan converges benignly.
- **PQ-5** [Minor] `preserved-path-underspecified` apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
  Say whether suspended windows run inventory+reconcile under foldenable=false or keep the old phases; document_fold_batches_spec and the uncertainty retirement spec depend on which.

## Open findings

- **PQ-1** [Minor] `test-strategy-not-enumeration` fold_diff tests are an enumerated case list with no property/fuzz strategy for the riskiest pure function
- **PQ-2** [Minor] `pure-contract-underspecified` FoldDiff says batches hold at most limit groups AND a region is never split - contradictory for a region larger than limit
- **PQ-3** [Minor] `reuse-existing-helper` M2 local restart re-implements before_splice's restart/checkpoint derivation instead of extracting a shared helper (ARCH-DRY)
- **PQ-4** [Minor] `interleaving-unmodeled` Reconcile re-check guards removals only; user zf/zd between inventory slices or inside a creation region is unaddressed (ARCH-ORDER)
- **PQ-5** [Minor] `preserved-path-underspecified` apply above INTERACTIVE_ROWS "keeps current behaviour" while the clear/create phases it uses are deleted
