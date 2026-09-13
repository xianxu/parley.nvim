---
gate: boundary-review
issue: 246
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-13T15:44:49-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Starter startup overwrites the saved live model with the learner placeholder.
          detail: lua/parley/starter_config.lua:21 sets default_agent unconditionally; lua/parley/init.lua:930 applies it after restoring state. Two independent starter launches reproduced SELECTED=claude-opus-5* followed by RESTORED=Choose a model. Make the placeholder a first-use fallback and add a full-startup restart regression (ARCH-PURPOSE, ARCH-ORDER).
          family: startup-preserves-persisted-selection
          round: 1
        - id: BR-2
          severity: Important
          title: The artifact guard omits home-relative paths and ariadne imports required by the Spec.
          detail: scripts/check-starter.py:9 accepts ~/notes, ~/workspace/ariadne, and require("ariadne"). Extend enforcement across the promised categories, narrowly exempt legitimate installation comments, and add negative fixtures that fail without the correction (ARCH-PURPOSE).
          family: personal-marker-contract-coverage
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T15:50:36-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'starter_config.lua removes the unconditional default_agent; the two-process regression passes at HEAD and fails with “saved model was replaced: Choose a model” when the override is restored in a scratch copy.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: check-starter.py rejects home-relative paths and ariadne references with an exact installation-comment exception; negative fixtures pass at HEAD and incorrectly return success when the new rules are removed.
          round: 2
      blocked: false
---

# Gate ledger — parley.nvim#246 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T15:44:49-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `startup-preserves-persisted-selection` Starter startup overwrites the saved live model with the learner placeholder.
  lua/parley/starter_config.lua:21 sets default_agent unconditionally; lua/parley/init.lua:930 applies it after restoring state. Two independent starter launches reproduced SELECTED=claude-opus-5* followed by RESTORED=Choose a model. Make the placeholder a first-use fallback and add a full-startup restart regression (ARCH-PURPOSE, ARCH-ORDER).
- **BR-2** [Important] `personal-marker-contract-coverage` The artifact guard omits home-relative paths and ariadne imports required by the Spec.
  scripts/check-starter.py:9 accepts ~/notes, ~/workspace/ariadne, and require("ariadne"). Extend enforcement across the promised categories, narrowly exempt legitimate installation comments, and add negative fixtures that fail without the correction (ARCH-PURPOSE).

## Round 2 — 2026-09-13T15:50:36-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — starter_config.lua removes the unconditional default_agent; the two-process regression passes at HEAD and fails with “saved model was replaced: Choose a model” when the override is restored in a scratch copy.
- BR-2 — addressed — check-starter.py rejects home-relative paths and ariadne references with an exact installation-comment exception; negative fixtures pass at HEAD and incorrectly return success when the new rules are removed.

## Open findings

(none — every finding has been disposed)
