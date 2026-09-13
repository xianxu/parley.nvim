---
gate: plan-quality
issue: 232
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-12T19:46:20-07:00"
      agent: claude
      blocked: true
      protocol_error: no valid findings block
    - "n": 2
      timestamp: "2026-09-12T19:52:30-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Replace the prose test-case inventory with function-level strategies.
          detail: 'The first three Plan items enumerate fixture contents and individual assertions, contrary to this gate''s explicit test-plan contract. Retain _build_picker_items, _build_tree_outline_items, and _is_outline_item by name, and compress coverage into adversarial input classes plus mechanical guards: normalized builder parity over mixed chat syntax and nesting, and direct classifier assertions over annotation delimiters; put individual cases in the tests.'
          family: test-strategy-not-case-inventory
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-12T19:53:13-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The plan names both builders and the classifier, with differential parity and delimiter assertion strategies; individual test cases are deferred to executable specs.
          round: 3
      blocked: false
content_hash: 5fa3038c3cf6d325fd83768255c32aff779ae42e1aa8252d45bbc01ec39f52a7
---

# Gate ledger — parley.nvim#232 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-12T19:46:20-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 2 — 2026-09-12T19:52:30-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `test-strategy-not-case-inventory` Replace the prose test-case inventory with function-level strategies.
  The first three Plan items enumerate fixture contents and individual assertions, contrary to this gate's explicit test-plan contract. Retain _build_picker_items, _build_tree_outline_items, and _is_outline_item by name, and compress coverage into adversarial input classes plus mechanical guards: normalized builder parity over mixed chat syntax and nesting, and direct classifier assertions over annotation delimiters; put individual cases in the tests.

## Round 3 — 2026-09-12T19:53:13-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The plan names both builders and the classifier, with differential parity and delimiter assertion strategies; individual test cases are deferred to executable specs.

## Open findings

(none — every finding has been disposed)
