---
gate: boundary-review
issue: 220
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-22T14:48:45-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: 1803 lines carrying complete spec bodies and the whole census script verbatim
          detail: |-
            The function names plus one strategy line per risky function carry the same
            design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
            is the right instinct done wrong — it already says the arch guard, not the
            table, owns completeness, so the table can go.
            (carried from plan-quality PQ-5, deferred to the boundary review)
          family: plan-restates-the-diff
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-22T14:48:45-07:00"
      agent: codex
      findings:
        - id: BR-2
          severity: Critical
          title: Core-concepts PURE entities are not tested without IO
          detail: 'The plan labels parse_ps, select_orphans, ancestry, and orphaned as PURE (workshop/plans/000220-reap-test-fixture-processes-plan.md:67-129), but the tests invoke the Python script through vim.system and --ps-from (tests/unit/reap_test_orphans_spec.lua:7-10), while watchdog behavior is tested only through real orphaned processes (tests/integration/fixture_reaping_spec.lua:17-85). Add direct no-IO tests for the pure functions, or revise the Core-concepts table and classifications to INTEGRATION; record the correction in ## Revisions.'
          family: pure-entity-test-seam
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-22T14:54:20-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The durable plan remains approximately 1997 lines and still embeds complete spec bodies and census implementation text.
          round: 3
        - id: BR-2
          disposition: addressed
          note: tests/unit/reap_test_orphans_pure.py directly tests parse_ps, select_orphans, ancestry, and orphaned without process or filesystem IO; 5/5 tests pass.
          round: 3
      findings:
        - id: BR-3
          severity: Important
          title: Grace resampling ignores the configured ps command
          detail: scripts/reap-test-orphans.py:115 calls read_process_table(None, "ps") instead of using the caller's --ps-command. A custom or injected process-table provider is used for the initial sample but silently replaced by the real ps during grace polling. Thread ps_command through persistent_candidates and add a regression test proving every sample uses the configured seam. ARCH-MOCK.
          family: external-seam-consistency
          round: 3
      boundary: M1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#220 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-22T14:48:45-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
  The function names plus one strategy line per risky function carry the same
  design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
  is the right instinct done wrong — it already says the arch guard, not the
  table, owns completeness, so the table can go.
  (carried from plan-quality PQ-5, deferred to the boundary review)

## Round 2 — 2026-09-22T14:48:45-07:00 (codex) — BLOCKED

### Raised

- **BR-2** [Critical] `pure-entity-test-seam` Core-concepts PURE entities are not tested without IO
  The plan labels parse_ps, select_orphans, ancestry, and orphaned as PURE (workshop/plans/000220-reap-test-fixture-processes-plan.md:67-129), but the tests invoke the Python script through vim.system and --ps-from (tests/unit/reap_test_orphans_spec.lua:7-10), while watchdog behavior is tested only through real orphaned processes (tests/integration/fixture_reaping_spec.lua:17-85). Add direct no-IO tests for the pure functions, or revise the Core-concepts table and classifications to INTEGRATION; record the correction in ## Revisions.

## Round 3 — 2026-09-22T14:54:20-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The durable plan remains approximately 1997 lines and still embeds complete spec bodies and census implementation text.
- BR-2 — addressed — tests/unit/reap_test_orphans_pure.py directly tests parse_ps, select_orphans, ancestry, and orphaned without process or filesystem IO; 5/5 tests pass.

### Raised

- **BR-3** [Important] `external-seam-consistency` Grace resampling ignores the configured ps command
  scripts/reap-test-orphans.py:115 calls read_process_table(None, "ps") instead of using the caller's --ps-command. A custom or injected process-table provider is used for the initial sample but silently replaced by the real ps during grace polling. Thread ps_command through persistent_candidates and add a regression test proving every sample uses the configured seam. ARCH-MOCK.

## Open findings

- **BR-1** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
- **BR-3** [Important] `external-seam-consistency` Grace resampling ignores the configured ps command
