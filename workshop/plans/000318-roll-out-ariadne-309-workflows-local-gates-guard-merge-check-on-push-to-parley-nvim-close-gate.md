---
gate: boundary-review
issue: 318
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-12T14:46:17-07:00"
      dispatched: "2026-10-12T14:45:42-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Minor
          title: merge-check.yml (incl. new push trigger) relies on scripts/run-merge-checks.sh, which is not tracked in parley.nvim
          detail: I assume bootstrap.sh generates it, as before this diff. Not a regression; noting it so the push-to-main run is watched on its first firing.
          family: ci-generated-entrypoint-untracked
          round: 1
      recipe: milestone-review
      isolation: fenced
      reviewed: 3be5288d15e544449cc0501c4205dba15722b84d
      blocked: false
---

# Gate ledger — parley.nvim#318 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-12T14:46:17-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `ci-generated-entrypoint-untracked` merge-check.yml (incl. new push trigger) relies on scripts/run-merge-checks.sh, which is not tracked in parley.nvim
  I assume bootstrap.sh generates it, as before this diff. Not a regression; noting it so the push-to-main run is watched on its first firing.

## Open findings

- **BR-1** [Minor] `ci-generated-entrypoint-untracked` merge-check.yml (incl. new push trigger) relies on scripts/run-merge-checks.sh, which is not tracked in parley.nvim
