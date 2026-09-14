---
gate: plan-quality
issue: 251
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T10:56:10-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Name risky functions and require effective mapping verification.
          detail: Replace the case enumeration at plan lines 25–28 with one adversarial-input and mechanical-oracle strategy each for keys_for, help_lines, and float_picker.open. Require actual installed mapping and dispatch checks across alias lists and picker mapping modes; descriptor-shape assertions cannot detect the reported help/runtime mismatch (ARCH-PURE, ARCH-PURPOSE).
          family: function-test-strategy
          round: 1
        - id: PQ-2
          severity: Minor
          title: State the expected alias-count envelope.
          detail: Setup-time linear complexity identifies the interaction path but leaves workload size implicit. Add a reasonable expected shortcut-count range and state behavior beyond it, without introducing an arbitrary cap (ARCH-CONSTRAINTS).
          family: explicit-operating-envelope
          round: 1
        - id: PQ-3
          severity: Minor
          title: Make the scope exclusions explicit.
          detail: State that collision precedence, confirmation/focus lifecycle redesign, and configuration API redesign are outside this correction because existing behavior is being preserved.
          family: explicit-non-goals
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T10:57:51-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Revision names keys_for, help_lines, and float_picker.open strategies and requires installed mappings and dispatch checks across aliases and picker modes, plus native ChatFinder confirmation.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Revision states 1–3 shortcuts per action across dozens of actions; larger lists remain accepted with linear setup cost and no new cap.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Revision explicitly excludes collision precedence, configuration API redesign, and confirmation/focus lifecycle redesign while preserving existing behavior.
          round: 2
      blocked: false
content_hash: b3188268bcdc8c3fc085e117eb21853a3b0c3d3e5b53cdaee797ab9eccfe0fa3
---

# Gate ledger — parley.nvim#251 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T10:56:10-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-test-strategy` Name risky functions and require effective mapping verification.
  Replace the case enumeration at plan lines 25–28 with one adversarial-input and mechanical-oracle strategy each for keys_for, help_lines, and float_picker.open. Require actual installed mapping and dispatch checks across alias lists and picker mapping modes; descriptor-shape assertions cannot detect the reported help/runtime mismatch (ARCH-PURE, ARCH-PURPOSE).
- **PQ-2** [Minor] `explicit-operating-envelope` State the expected alias-count envelope.
  Setup-time linear complexity identifies the interaction path but leaves workload size implicit. Add a reasonable expected shortcut-count range and state behavior beyond it, without introducing an arbitrary cap (ARCH-CONSTRAINTS).
- **PQ-3** [Minor] `explicit-non-goals` Make the scope exclusions explicit.
  State that collision precedence, confirmation/focus lifecycle redesign, and configuration API redesign are outside this correction because existing behavior is being preserved.

## Round 2 — 2026-09-14T10:57:51-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Revision names keys_for, help_lines, and float_picker.open strategies and requires installed mappings and dispatch checks across aliases and picker modes, plus native ChatFinder confirmation.
- PQ-2 — addressed — Revision states 1–3 shortcuts per action across dozens of actions; larger lists remain accepted with linear setup cost and no new cap.
- PQ-3 — addressed — Revision explicitly excludes collision precedence, configuration API redesign, and confirmation/focus lifecycle redesign while preserving existing behavior.

## Open findings

(none — every finding has been disposed)
