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
    - "n": 2
      timestamp: "2026-09-29T10:46:37-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: tests/unit/outline_parity_spec.lua parameterizes both actual builders with default/custom prefixes and asserts their rendered labels. tests/packaging/completion_compatibility.lua exercises Ctrl-n twice and Ctrl-p back across distinct candidates. Both suites and the real pinned-Blink smoke pass; independently reversing Ctrl-p in memory makes step 9 fail.
          round: 2
      findings:
        - id: BR-2
          severity: Minor
          title: Remove trailing whitespace from the generated review artifact
          detail: 'git diff --check identifies one instance in this window: workshop/plans/000300-app-labels-buffer-completion-close-review.md:45. Remove the spaces from that blank line when regenerating the artifact.'
          family: patch-whitespace-hygiene
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#300 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T10:41:39-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `acceptance-matrix-coverage` Exercise every promised outline prefix/path and completion selection direction
  tests/unit/question_tags_spec.lua:43 tests custom prefixes only through apply_outline; tests/unit/outline_parity_spec.lua:219 exercises both actual builders only with default prefixes. tests/packaging/completion_compatibility.lua:82 exercises Ctrl-n but never Ctrl-p. The complete missing family is custom tagged labels through the flat builder, custom tagged labels through the tree builder, and real Ctrl-p selection. Parameterize the builder fixture and test both selection directions with distinguishable candidates, with regression assertions that detect default-prefix substitution or a missing/wrong Ctrl-p binding.

## Round 2 — 2026-09-29T10:46:37-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — tests/unit/outline_parity_spec.lua parameterizes both actual builders with default/custom prefixes and asserts their rendered labels. tests/packaging/completion_compatibility.lua exercises Ctrl-n twice and Ctrl-p back across distinct candidates. Both suites and the real pinned-Blink smoke pass; independently reversing Ctrl-p in memory makes step 9 fail.

### Raised

- **BR-2** [Minor] `patch-whitespace-hygiene` Remove trailing whitespace from the generated review artifact
  git diff --check identifies one instance in this window: workshop/plans/000300-app-labels-buffer-completion-close-review.md:45. Remove the spaces from that blank line when regenerating the artifact.

## Open findings

- **BR-2** [Minor] `patch-whitespace-hygiene` Remove trailing whitespace from the generated review artifact
