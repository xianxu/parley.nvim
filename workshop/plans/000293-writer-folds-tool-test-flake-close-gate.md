---
gate: boundary-review
issue: 293
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T20:18:03-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: writer_folds wait_for applies a 1s repair-stall window to waits not gated on repair
          detail: The waits for calls>0, response terminal and flush idle may see no productive repair step, so their effective timeout drops from 5s to 1s under make test load. Use stall_ms of at least 5000, or keep a plain vim.wait for waits not gated on repair.
          family: wait-budget-tightened-for-ungated-waits
          round: 1
        - id: BR-2
          severity: Important
          title: await_helper_spec depends on real-timer and wall-clock margins of 100ms (ARCH-ORDER)
          detail: A descheduled process can read progress before the coalesced scheduled tick runs, so the settle case reports stalled. Inject the clock and wait into until_progress, or widen the margins well past scheduler jitter.
          family: wall-clock-test-oracle
          round: 1
        - id: BR-3
          severity: Minor
          title: repair_work_budget_spec hard-codes 21 for HIGHLIGHT_VIEWPORT_MARGIN + 1 (ARCH-DRY)
          family: restated-constant
          round: 1
        - id: BR-4
          severity: Minor
          title: atlas says the 40s ceiling prevents silent kills, but it only holds per wait, not per file
          family: doc-overclaims-guarantee
          round: 1
        - id: BR-5
          severity: Minor
          title: repair_work_budget_spec creates a tmp_dir per run and never removes it (ARCH-FUNERAL)
          family: test-residue-cleanup
          round: 1
      boundary: M1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#293 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T20:18:03-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `wait-budget-tightened-for-ungated-waits` writer_folds wait_for applies a 1s repair-stall window to waits not gated on repair
  The waits for calls>0, response terminal and flush idle may see no productive repair step, so their effective timeout drops from 5s to 1s under make test load. Use stall_ms of at least 5000, or keep a plain vim.wait for waits not gated on repair.
- **BR-2** [Important] `wall-clock-test-oracle` await_helper_spec depends on real-timer and wall-clock margins of 100ms (ARCH-ORDER)
  A descheduled process can read progress before the coalesced scheduled tick runs, so the settle case reports stalled. Inject the clock and wait into until_progress, or widen the margins well past scheduler jitter.
- **BR-3** [Minor] `restated-constant` repair_work_budget_spec hard-codes 21 for HIGHLIGHT_VIEWPORT_MARGIN + 1 (ARCH-DRY)
- **BR-4** [Minor] `doc-overclaims-guarantee` atlas says the 40s ceiling prevents silent kills, but it only holds per wait, not per file
- **BR-5** [Minor] `test-residue-cleanup` repair_work_budget_spec creates a tmp_dir per run and never removes it (ARCH-FUNERAL)

## Open findings

- **BR-1** [Important] `wait-budget-tightened-for-ungated-waits` writer_folds wait_for applies a 1s repair-stall window to waits not gated on repair
- **BR-2** [Important] `wall-clock-test-oracle` await_helper_spec depends on real-timer and wall-clock margins of 100ms (ARCH-ORDER)
- **BR-3** [Minor] `restated-constant` repair_work_budget_spec hard-codes 21 for HIGHLIGHT_VIEWPORT_MARGIN + 1 (ARCH-DRY)
- **BR-4** [Minor] `doc-overclaims-guarantee` atlas says the 40s ceiling prevents silent kills, but it only holds per wait, not per file
- **BR-5** [Minor] `test-residue-cleanup` repair_work_budget_spec creates a tmp_dir per run and never removes it (ARCH-FUNERAL)
