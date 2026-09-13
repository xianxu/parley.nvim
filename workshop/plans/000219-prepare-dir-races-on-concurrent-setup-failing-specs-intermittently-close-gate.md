---
gate: boundary-review
issue: 219
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-13T13:12:17-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Minor
          title: The Plan's focused-test command does not run the regression
          detail: workshop/plans/000219-prepare-dir-race-plan.md:31 specifies SPEC=prepare_dir, but that key has no traceability mapping and the command exits 2. Document a working isolated Plenary invocation or add the mapping; the regression passes when run directly.
          family: verification-command-accuracy
          round: 1
        - id: BR-2
          severity: Minor
          title: The Core concepts table omits the required Kind column
          detail: workshop/plans/000219-prepare-dir-race-plan.md:15 should classify ensure_dir as INTEGRATION. Its implementation and surrounding prose agree on that classification, so this is a table-format omission rather than an ARCH-PURE contradiction.
          family: core-concept-classification
          round: 1
      blocked: false
---

# Gate ledger — 000219-prepare-dir-races-on-concurrent-setup-failing-specs-intermittently#219 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T13:12:17-07:00 (codex) — passed

### Raised

- **BR-1** [Minor] `verification-command-accuracy` The Plan's focused-test command does not run the regression
  workshop/plans/000219-prepare-dir-race-plan.md:31 specifies SPEC=prepare_dir, but that key has no traceability mapping and the command exits 2. Document a working isolated Plenary invocation or add the mapping; the regression passes when run directly.
- **BR-2** [Minor] `core-concept-classification` The Core concepts table omits the required Kind column
  workshop/plans/000219-prepare-dir-race-plan.md:15 should classify ensure_dir as INTEGRATION. Its implementation and surrounding prose agree on that classification, so this is a table-format omission rather than an ARCH-PURE contradiction.

## Open findings

- **BR-1** [Minor] `verification-command-accuracy` The Plan's focused-test command does not run the regression
- **BR-2** [Minor] `core-concept-classification` The Core concepts table omits the required Kind column
