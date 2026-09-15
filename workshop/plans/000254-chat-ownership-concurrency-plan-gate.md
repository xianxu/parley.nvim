---
gate: plan-quality
issue: 254
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T22:29:03-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Replace test-case inventories with named risky functions and concise strategies
          detail: The plan names modules/spec files but does not name the functions to unit-test; repeated case inventories appear at plan lines 270, 293, and 300–302. Compress the test prose across M1–M6 into one strategy line per risky function, naming its adversarial input/event class and mechanical guard or independent oracle, including sequence/grammar repair, ownership transitions, batch validation, tool admission/outcomes, and recovery validation (ARCH-PURE).
          family: function-level-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T22:31:17-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: All six milestones now use named function-level strategies with adversarial classes and independent oracles or mechanical guards, replacing repeated test-case inventories.
          round: 2
      blocked: false
content_hash: 7f9a7b1f40b6fa7a728d4afb65bd3f2e7d18513f86a70dd16795ca6b9989346d
---

# Gate ledger — parley.nvim#254 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T22:29:03-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace test-case inventories with named risky functions and concise strategies
  The plan names modules/spec files but does not name the functions to unit-test; repeated case inventories appear at plan lines 270, 293, and 300–302. Compress the test prose across M1–M6 into one strategy line per risky function, naming its adversarial input/event class and mechanical guard or independent oracle, including sequence/grammar repair, ownership transitions, batch validation, tool admission/outcomes, and recovery validation (ARCH-PURE).

## Round 2 — 2026-09-14T22:31:17-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — All six milestones now use named function-level strategies with adversarial classes and independent oracles or mechanical guards, replacing repeated test-case inventories.

## Open findings

(none — every finding has been disposed)
