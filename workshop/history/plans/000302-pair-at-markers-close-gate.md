---
gate: boundary-review
issue: 302
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-29T11:47:19-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Adjacent marker pairs fail to generate the second closing pair
          detail: lua/parley/at_pair.lua:10 rejects an opener following an existing closer. Production typing i@@one@@@@two<Esc> produces @@one@@@@two instead of @@one@@@@two@@. Recognize the unpaired trailing at sign and add pure and mapped-typing regressions covering adjacent pairs, skipping, and undo. ARCH-PURPOSE.
          family: pairing-delimiter-boundaries
          round: 1
        - id: BR-2
          severity: Important
          title: Promised Blink and pairing coexistence lacks a committed regression
          detail: tests/packaging/completion_compatibility.lua:15 initializes Blink without preparing Parley chat mappings, while tests/integration/at_pair_spec.lua:86 tests starter pairing without Blink. Commit the combined production-options typing and completion test currently represented only by a temporary smoke script. ARCH-PURPOSE.
          family: acceptance-path-regression-coverage
          round: 1
        - id: BR-3
          severity: Important
          title: Generated help still claims local tags enter AI context
          detail: lua/parley/keybinding_registry.lua:1325-1326 describes outline-only hiding and attached tags prefixing AI context, contradicting this range's projection behavior and updated README. Correct both statements and sweep current user-facing descriptions for the superseded contract. ARCH-PURPOSE.
          family: user-help-contract-consistency
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-29T11:53:39-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: lua/parley/at_pair.lua:10-11 recognizes odd trailing runs. Pure and mapped regressions cover adjacent pairs, skipping, undo and redo. The pre-fix helper fails the new pure assertion and committed Blink test at step 16.
          round: 2
        - id: BR-2
          disposition: addressed
          note: tests/packaging/completion_compatibility.lua:110-155 prepares a real chat with starter options and exercises pairing, skipping, completion acceptance and subsequent pairing. All 21 steps passed with the pinned Blink commit; substituting the pre-fix helper fails step 16.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The pinned diff replaces both obsolete statements at lua/parley/keybinding_registry.lua:1325-1327 with whole-line local-tag exclusion and literal/reference exceptions. These agree with question_tags.local_rows/context_text, context-projection tests, README and atlas; the current documentation sweep found no remaining superseded claim.
          round: 2
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#302 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T11:47:19-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `pairing-delimiter-boundaries` Adjacent marker pairs fail to generate the second closing pair
  lua/parley/at_pair.lua:10 rejects an opener following an existing closer. Production typing i@@one@@@@two<Esc> produces @@one@@@@two instead of @@one@@@@two@@. Recognize the unpaired trailing at sign and add pure and mapped-typing regressions covering adjacent pairs, skipping, and undo. ARCH-PURPOSE.
- **BR-2** [Important] `acceptance-path-regression-coverage` Promised Blink and pairing coexistence lacks a committed regression
  tests/packaging/completion_compatibility.lua:15 initializes Blink without preparing Parley chat mappings, while tests/integration/at_pair_spec.lua:86 tests starter pairing without Blink. Commit the combined production-options typing and completion test currently represented only by a temporary smoke script. ARCH-PURPOSE.
- **BR-3** [Important] `user-help-contract-consistency` Generated help still claims local tags enter AI context
  lua/parley/keybinding_registry.lua:1325-1326 describes outline-only hiding and attached tags prefixing AI context, contradicting this range's projection behavior and updated README. Correct both statements and sweep current user-facing descriptions for the superseded contract. ARCH-PURPOSE.

## Round 2 — 2026-09-29T11:53:39-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — lua/parley/at_pair.lua:10-11 recognizes odd trailing runs. Pure and mapped regressions cover adjacent pairs, skipping, undo and redo. The pre-fix helper fails the new pure assertion and committed Blink test at step 16.
- BR-2 — addressed — tests/packaging/completion_compatibility.lua:110-155 prepares a real chat with starter options and exercises pairing, skipping, completion acceptance and subsequent pairing. All 21 steps passed with the pinned Blink commit; substituting the pre-fix helper fails step 16.
- BR-3 — addressed — The pinned diff replaces both obsolete statements at lua/parley/keybinding_registry.lua:1325-1327 with whole-line local-tag exclusion and literal/reference exceptions. These agree with question_tags.local_rows/context_text, context-projection tests, README and atlas; the current documentation sweep found no remaining superseded claim.

## Open findings

(none — every finding has been disposed)
