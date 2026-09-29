---
gate: boundary-review
issue: 300
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-29T10:41:39-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: Exercise every promised outline prefix/path and completion selection direction
          detail: tests/unit/question_tags_spec.lua:43 tests custom prefixes only through apply_outline; tests/unit/outline_parity_spec.lua:219 exercises both actual builders only with default prefixes. tests/packaging/completion_compatibility.lua:82 exercises Ctrl-n but never Ctrl-p. The complete missing family is custom tagged labels through the flat builder, custom tagged labels through the tree builder, and real Ctrl-p selection. Parameterize the builder fixture and test both selection directions with distinguishable candidates, with regression assertions that detect default-prefix substitution or a missing/wrong Ctrl-p binding.
          family: acceptance-matrix-coverage
          round: 1
      recipe: small-diff-review
      blocked: true
---

# Gate ledger — parley.nvim#300 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T10:41:39-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `acceptance-matrix-coverage` Exercise every promised outline prefix/path and completion selection direction
  tests/unit/question_tags_spec.lua:43 tests custom prefixes only through apply_outline; tests/unit/outline_parity_spec.lua:219 exercises both actual builders only with default prefixes. tests/packaging/completion_compatibility.lua:82 exercises Ctrl-n but never Ctrl-p. The complete missing family is custom tagged labels through the flat builder, custom tagged labels through the tree builder, and real Ctrl-p selection. Parameterize the builder fixture and test both selection directions with distinguishable candidates, with regression assertions that detect default-prefix substitution or a missing/wrong Ctrl-p binding.

## Open findings

- **BR-1** [Important] `acceptance-matrix-coverage` Exercise every promised outline prefix/path and completion selection direction
