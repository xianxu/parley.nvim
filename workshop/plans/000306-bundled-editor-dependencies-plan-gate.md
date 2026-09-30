---
gate: plan-quality
issue: 306
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-30T10:54:59-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Define bundle ownership, publication, and interrupted recovery.
          detail: 'ARCH-ORDER and ARCH-FUNERAL: Tasks 2 and 4 promise safe publication and retry cleanup without specifying writer serialization, active-reader protection, or recovery after process death. Name the production state-transition function, lock scope, publication mechanism, ownership evidence for cleanup, and a controllable sequence-testing strategy.'
          family: durable-publication-ordering
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace prose test inventories with named risky functions and strategies.
          detail: 'ARCH-PURE: Tasks 1–4 enumerate test cases but do not name the unit-tested archive-validation, receipt-parsing, payload-verification, and publication-decision functions. Compress those inventories into one adversarial-input class and mechanical guard per named risky function; retain production-path acceptance checks.'
          family: function-level-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-30T10:56:47-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: not-addressed
          note: 'ARCH-ORDER/ARCH-FUNERAL: The parent-held shared lease can disappear while its Neovim child survives, allowing subsequent cleanup to delete an active reader''s bundle. Require protection for every surviving consumer, specify ownership across wrapper death, and verify it with controlled parent-termination and competing-writer tests.'
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Named pure validation and publication-decision functions now have adversarial-input classes and mechanical guards; stateful integration and production-path acceptance checks remain.
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-30T10:58:08-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Named lifecycle and decision functions, exclusive/shared leases inherited by consumers, atomic publication, ownership-checked cleanup, and controlled interruption/recovery tests resolve the ownership and publication contract.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Named risky functions retain adversarial strategies, with stateful integration tests exercising the production lifecycle.
          round: 3
      blocked: false
    - "n": 4
      timestamp: "2026-09-30T11:12:11-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Ownership, inherited reader leases, atomic publication and interrupted recovery are explicitly specified.
          round: 4
        - id: PQ-2
          disposition: addressed
          note: Risky pure functions have named adversarial strategies, with lifecycle integration tests exercising production wrappers.
          round: 4
      blocked: false
content_hash: d79671bfd548cec170b370a75165616e5642b9120c64f156222b7451a226e45e
---

# Gate ledger — parley.nvim#306 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-30T10:54:59-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `durable-publication-ordering` Define bundle ownership, publication, and interrupted recovery.
  ARCH-ORDER and ARCH-FUNERAL: Tasks 2 and 4 promise safe publication and retry cleanup without specifying writer serialization, active-reader protection, or recovery after process death. Name the production state-transition function, lock scope, publication mechanism, ownership evidence for cleanup, and a controllable sequence-testing strategy.
- **PQ-2** [Important] `function-level-test-strategy` Replace prose test inventories with named risky functions and strategies.
  ARCH-PURE: Tasks 1–4 enumerate test cases but do not name the unit-tested archive-validation, receipt-parsing, payload-verification, and publication-decision functions. Compress those inventories into one adversarial-input class and mechanical guard per named risky function; retain production-path acceptance checks.

## Round 2 — 2026-09-30T10:56:47-07:00 (codex) — BLOCKED

### Disposed

- PQ-1 — not-addressed — ARCH-ORDER/ARCH-FUNERAL: The parent-held shared lease can disappear while its Neovim child survives, allowing subsequent cleanup to delete an active reader's bundle. Require protection for every surviving consumer, specify ownership across wrapper death, and verify it with controlled parent-termination and competing-writer tests.
- PQ-2 — addressed — Named pure validation and publication-decision functions now have adversarial-input classes and mechanical guards; stateful integration and production-path acceptance checks remain.

## Round 3 — 2026-09-30T10:58:08-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Named lifecycle and decision functions, exclusive/shared leases inherited by consumers, atomic publication, ownership-checked cleanup, and controlled interruption/recovery tests resolve the ownership and publication contract.
- PQ-2 — addressed — Named risky functions retain adversarial strategies, with stateful integration tests exercising the production lifecycle.

## Round 4 — 2026-09-30T11:12:11-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Ownership, inherited reader leases, atomic publication and interrupted recovery are explicitly specified.
- PQ-2 — addressed — Risky pure functions have named adversarial strategies, with lifecycle integration tests exercising production wrappers.

## Open findings

(none — every finding has been disposed)
