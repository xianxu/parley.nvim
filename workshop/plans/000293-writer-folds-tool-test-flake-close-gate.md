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
    - "n": 2
      timestamp: "2026-09-27T20:20:11-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: writer_folds_spec.lua wait_for now passes stall_ms=5000 (old fixed budget); helper case "no progress at all gets exactly the stall window" pins the contract.
          round: 2
        - id: BR-2
          disposition: addressed
          note: until_progress takes env{now,wait}; await_helper_spec drives it with a fake clock and asserts exact times (350, 300, 5000); 4/4 pass.
          round: 2
        - id: BR-3
          disposition: addressed
          note: highlighter.lua exports _VIEWPORT_MARGIN = HIGHLIGHT_VIEWPORT_MARGIN; spec uses drawn + highlighter._VIEWPORT_MARGIN + 1.
          round: 2
        - id: BR-4
          disposition: addressed
          note: atlas/infra/test_harness.md now states the ceiling bounds one wait, not the file, and several slow waits can still reach 50s.
          round: 2
        - id: BR-5
          disposition: addressed
          note: VimLeavePre deletes tmp_dir; a run on HEAD left no new parley-test-repair-budget dir (the remaining ones predate the fix commit).
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: false
    - "n": 3
      timestamp: "2026-09-27T20:35:31-07:00"
      agent: claude
      findings:
        - id: BR-6
          severity: Minor
          title: Plan says the combine purity contract is documented on sequence.new; it is only on the private helper
          detail: 'This is the 2nd finding in family doc-overclaims-guarantee. Rule: a contract the plan says is "documented on X" must appear at X, the public entry point callers read. Add a one-line purity requirement to the M.new header (sequence.lua:182) instead of rewording the plan.'
          family: doc-overclaims-guarantee
          round: 3
        - id: BR-7
          severity: Minor
          title: Purity property test checks only top-level freshness, not nested aliasing of combine outputs
          detail: document_sequence_spec.lua checks out ~= a and out ~= b; a combine that returns {flags=a.flags} would pass and alias stored summaries. Walk out and assert no nested table is also reachable from a or b.
          family: purity-test-shallow-alias
          round: 3
      boundary: M2
      recipe: milestone-review
      blocked: false
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

## Round 2 — 2026-09-27T20:20:11-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — writer_folds_spec.lua wait_for now passes stall_ms=5000 (old fixed budget); helper case "no progress at all gets exactly the stall window" pins the contract.
- BR-2 — addressed — until_progress takes env{now,wait}; await_helper_spec drives it with a fake clock and asserts exact times (350, 300, 5000); 4/4 pass.
- BR-3 — addressed — highlighter.lua exports _VIEWPORT_MARGIN = HIGHLIGHT_VIEWPORT_MARGIN; spec uses drawn + highlighter._VIEWPORT_MARGIN + 1.
- BR-4 — addressed — atlas/infra/test_harness.md now states the ceiling bounds one wait, not the file, and several slow waits can still reach 50s.
- BR-5 — addressed — VimLeavePre deletes tmp_dir; a run on HEAD left no new parley-test-repair-budget dir (the remaining ones predate the fix commit).

## Round 3 — 2026-09-27T20:35:31-07:00 (claude) — passed

### Raised

- **BR-6** [Minor] `doc-overclaims-guarantee` Plan says the combine purity contract is documented on sequence.new; it is only on the private helper
  This is the 2nd finding in family doc-overclaims-guarantee. Rule: a contract the plan says is "documented on X" must appear at X, the public entry point callers read. Add a one-line purity requirement to the M.new header (sequence.lua:182) instead of rewording the plan.
- **BR-7** [Minor] `purity-test-shallow-alias` Purity property test checks only top-level freshness, not nested aliasing of combine outputs
  document_sequence_spec.lua checks out ~= a and out ~= b; a combine that returns {flags=a.flags} would pass and alias stored summaries. Walk out and assert no nested table is also reachable from a or b.

## Open findings

- **BR-6** [Minor] `doc-overclaims-guarantee` Plan says the combine purity contract is documented on sequence.new; it is only on the private helper
- **BR-7** [Minor] `purity-test-shallow-alias` Purity property test checks only top-level freshness, not nested aliasing of combine outputs
