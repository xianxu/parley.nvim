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
    - "n": 3
      timestamp: "2026-09-29T12:35:53-07:00"
      agent: codex
      dispose:
        - id: BR-2
          disposition: addressed
          note: The pinned review artifact's blank line is clean; git diff --check across the complete pinned range reports no whitespace errors.
          round: 3
        - id: BR-1
          disposition: addressed
          note: Default/custom prefixes exercise both outline builders; the real pinned-Blink smoke exercises Ctrl-n/p navigation and passes.
          round: 3
      findings:
        - id: BR-3
          severity: Important
          title: Restore the stacked branch's Core concepts inventory
          detail: 'tests/arch/single_source_sweeps_spec.lua:208 and :356 fail under make test-spec SPEC=ui/keybindings. On branch 000303-app-completion-keys, the checker selects workshop/issues/000303-app-completion-keys.md, which contains no Core concepts table. It reports content, context_text, is_local_tag, keys, local_rows, outline_label and project as undocumented exports. Add the complete inventory with ownership, paths and inherited status, append a Revisions entry, and rerun the suite. ARCH-PURPOSE: the existing traceability guard must pass for the actual stacked branch.'
          family: core-concepts-traceability
          round: 3
      recipe: milestone-review
      blocked: true
    - "n": 4
      timestamp: "2026-09-29T12:40:23-07:00"
      agent: codex
      dispose:
        - id: BR-3
          disposition: addressed
          note: workshop/issues/000303-app-completion-keys.md:24-29 inventories all seven inherited exports with ownership and paths; lines 60-64 record the revision. Definitions match, and make test-spec SPEC=ui/keybindings passes both traceability guards.
          round: 4
        - id: BR-1
          disposition: addressed
          note: 'Retained: outline tests exercise default/custom prefixes through both builders, and the real pinned-Blink keyboard test exercises forward/backward selection successfully.'
          round: 4
        - id: BR-2
          disposition: addressed
          note: 'Retained: git diff --check across the complete pinned range passes, including generated review artifacts.'
          round: 4
      recipe: milestone-review
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

## Round 3 — 2026-09-29T12:35:53-07:00 (codex) — BLOCKED

### Disposed

- BR-2 — addressed — The pinned review artifact's blank line is clean; git diff --check across the complete pinned range reports no whitespace errors.
- BR-1 — addressed — Default/custom prefixes exercise both outline builders; the real pinned-Blink smoke exercises Ctrl-n/p navigation and passes.

### Raised

- **BR-3** [Important] `core-concepts-traceability` Restore the stacked branch's Core concepts inventory
  tests/arch/single_source_sweeps_spec.lua:208 and :356 fail under make test-spec SPEC=ui/keybindings. On branch 000303-app-completion-keys, the checker selects workshop/issues/000303-app-completion-keys.md, which contains no Core concepts table. It reports content, context_text, is_local_tag, keys, local_rows, outline_label and project as undocumented exports. Add the complete inventory with ownership, paths and inherited status, append a Revisions entry, and rerun the suite. ARCH-PURPOSE: the existing traceability guard must pass for the actual stacked branch.

## Round 4 — 2026-09-29T12:40:23-07:00 (codex) — passed

### Disposed

- BR-3 — addressed — workshop/issues/000303-app-completion-keys.md:24-29 inventories all seven inherited exports with ownership and paths; lines 60-64 record the revision. Definitions match, and make test-spec SPEC=ui/keybindings passes both traceability guards.
- BR-1 — addressed — Retained: outline tests exercise default/custom prefixes through both builders, and the real pinned-Blink keyboard test exercises forward/backward selection successfully.
- BR-2 — addressed — Retained: git diff --check across the complete pinned range passes, including generated review artifacts.

## Open findings

(none — every finding has been disposed)
