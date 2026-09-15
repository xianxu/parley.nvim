---
gate: plan-quality
issue: 240
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T20:26:06-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Reconcile preface ownership with consecutive unanswered questions
          detail: 'ARCH-PURPOSE: The authoritative revision requires unchanged question content/end spans while removing attached tags from the preceding component. That component can itself be a question; explicitly permit its content and end span to shrink while preserving its question-start anchor.'
          family: ownership-contract-completeness
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace enumerated test prose with function-specific adversarial strategies
          detail: Compress the active test instructions into named functions with one adversarial input class and mechanical guard per risky function. Retain parse/live/ancestor parity and complete regeneration as integration oracles.
          family: function-level-test-strategy
          round: 1
        - id: PQ-3
          severity: Minor
          title: State the preface design's workload and performance envelope
          detail: 'ARCH-CONSTRAINTS: Replace the superseded cache description with a representative transcript-size assumption, latency or memory expectation and its basis, and defined behavior beyond that envelope.'
          family: explicit-operating-envelope
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T20:27:45-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Plan line 125 explicitly permits the preceding answer or unanswered question's content and end span to shrink while preserving question-start anchors.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Plan lines 127–141 supersede enumerated test instructions with function-specific adversarial strategies and mechanical guards, retaining context parity and completed regeneration oracles.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Plan line 143 replaces cache assumptions with a 5,000-line representative workload, provisional 20ms incremental budget, measurement protocol, and explicit linear behavior beyond that envelope.
          round: 2
      blocked: false
content_hash: 7c3b36bbc5db288f3d29a7d1773737422b31c181e432d006abd98792fd09025a
---

# Gate ledger — parley.nvim#240 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T20:26:06-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `ownership-contract-completeness` Reconcile preface ownership with consecutive unanswered questions
  ARCH-PURPOSE: The authoritative revision requires unchanged question content/end spans while removing attached tags from the preceding component. That component can itself be a question; explicitly permit its content and end span to shrink while preserving its question-start anchor.
- **PQ-2** [Important] `function-level-test-strategy` Replace enumerated test prose with function-specific adversarial strategies
  Compress the active test instructions into named functions with one adversarial input class and mechanical guard per risky function. Retain parse/live/ancestor parity and complete regeneration as integration oracles.
- **PQ-3** [Minor] `explicit-operating-envelope` State the preface design's workload and performance envelope
  ARCH-CONSTRAINTS: Replace the superseded cache description with a representative transcript-size assumption, latency or memory expectation and its basis, and defined behavior beyond that envelope.

## Round 2 — 2026-09-14T20:27:45-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Plan line 125 explicitly permits the preceding answer or unanswered question's content and end span to shrink while preserving question-start anchors.
- PQ-2 — addressed — Plan lines 127–141 supersede enumerated test instructions with function-specific adversarial strategies and mechanical guards, retaining context parity and completed regeneration oracles.
- PQ-3 — addressed — Plan line 143 replaces cache assumptions with a 5,000-line representative workload, provisional 20ms incremental budget, measurement protocol, and explicit linear behavior beyond that envelope.

## Open findings

(none — every finding has been disposed)
