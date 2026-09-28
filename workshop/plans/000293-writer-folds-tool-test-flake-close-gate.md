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
    - "n": 4
      timestamp: "2026-09-27T21:03:32-07:00"
      agent: claude
      findings:
        - id: BR-8
          severity: Minor
          title: spans_key cache guard has no test; only reachable past 256 drawn rows
          detail: Mutation showed the toggle test stays green without the key (acknowledged in Revisions). A test seam for the 256-row per-redraw budget in on_win would let a small window exercise resume-across-fold-change and pin the key.
          family: untested-guard
          round: 4
        - id: BR-9
          severity: Minor
          title: fold-toggle case asserts query coverage, not the applied decoration Task 6 Step 2 specified
          detail: tests/integration/repair_work_budget_spec.lua checks D.query ranges cover the interior row; the plan asked for an interior row to carry its extmark highlight, which would also pin cache.rows population after the spans_key rebuild. Log the deviation or tighten the assertion.
          family: plan-deviation-unlogged
          round: 4
        - id: BR-10
          severity: Minor
          title: budget spec sets foldmethod=manual on the shared current window without restoring it
          detail: after_each deletes the buffer but leaves vim.wo[win].foldmethod changed for later cases on the same window.
          family: test-window-option-residue
          round: 4
      boundary: M3
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

## Round 4 — 2026-09-27T21:03:32-07:00 (claude) — passed

### Raised

- **BR-8** [Minor] `untested-guard` spans_key cache guard has no test; only reachable past 256 drawn rows
  Mutation showed the toggle test stays green without the key (acknowledged in Revisions). A test seam for the 256-row per-redraw budget in on_win would let a small window exercise resume-across-fold-change and pin the key.
- **BR-9** [Minor] `plan-deviation-unlogged` fold-toggle case asserts query coverage, not the applied decoration Task 6 Step 2 specified
  tests/integration/repair_work_budget_spec.lua checks D.query ranges cover the interior row; the plan asked for an interior row to carry its extmark highlight, which would also pin cache.rows population after the spans_key rebuild. Log the deviation or tighten the assertion.
- **BR-10** [Minor] `test-window-option-residue` budget spec sets foldmethod=manual on the shared current window without restoring it
  after_each deletes the buffer but leaves vim.wo[win].foldmethod changed for later cases on the same window.

## Open findings

- **BR-6** [Minor] `doc-overclaims-guarantee` Plan says the combine purity contract is documented on sequence.new; it is only on the private helper
- **BR-7** [Minor] `purity-test-shallow-alias` Purity property test checks only top-level freshness, not nested aliasing of combine outputs
- **BR-8** [Minor] `untested-guard` spans_key cache guard has no test; only reachable past 256 drawn rows
- **BR-9** [Minor] `plan-deviation-unlogged` fold-toggle case asserts query coverage, not the applied decoration Task 6 Step 2 specified
- **BR-10** [Minor] `test-window-option-residue` budget spec sets foldmethod=manual on the shared current window without restoring it
