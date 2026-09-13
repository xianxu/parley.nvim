---
gate: plan-quality
issue: 208
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-13T12:30:17-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Replace prose case inventories with named-function test strategies
          detail: The runtime and runner sections enumerate test cases instead of giving one adversarial-input class and mechanical guard per risky function. Compress them into strategies for from_table, load/default/reload, lifecycle helpers, materialize, and build_spawn_argv/run_sdlc_issue_new; retain end-to-end acceptance contracts without duplicating their case inventories. This supplies the required test obligation and supports ARCH-PURE.
          family: function-level-test-strategy
          round: 1
        - id: PQ-2
          severity: Minor
          title: Name when live command conformance runs
          detail: 'ARCH-MOCK: the plan specifies real sdlc help/discovery checks but no recurring execution point. Name the maintainer or CI trigger that reruns these checks so the fake''s command-availability behavior remains checked after implementation.'
          family: conformance-cadence
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T12:31:57-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Function-level strategies specify adversarial inputs and mechanical guards for validation, loading/cache recovery, lifecycle helpers and callers, materialization, and runner behavior without duplicating acceptance inventories.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: make check-sdlc-conformance runs on maintainer machines whenever the runner seam changes and before issue close; explicit invocation fails with advice when sdlc is unavailable.
          round: 2
      blocked: false
content_hash: 7f1972cea173afc6c37513ded547c9637544c91f237a28cdbf7a2800bb4abf46
---

# Gate ledger — parley.nvim#208 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T12:30:17-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace prose case inventories with named-function test strategies
  The runtime and runner sections enumerate test cases instead of giving one adversarial-input class and mechanical guard per risky function. Compress them into strategies for from_table, load/default/reload, lifecycle helpers, materialize, and build_spawn_argv/run_sdlc_issue_new; retain end-to-end acceptance contracts without duplicating their case inventories. This supplies the required test obligation and supports ARCH-PURE.
- **PQ-2** [Minor] `conformance-cadence` Name when live command conformance runs
  ARCH-MOCK: the plan specifies real sdlc help/discovery checks but no recurring execution point. Name the maintainer or CI trigger that reruns these checks so the fake's command-availability behavior remains checked after implementation.

## Round 2 — 2026-09-13T12:31:57-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Function-level strategies specify adversarial inputs and mechanical guards for validation, loading/cache recovery, lifecycle helpers and callers, materialization, and runner behavior without duplicating acceptance inventories.
- PQ-2 — addressed — make check-sdlc-conformance runs on maintainer machines whenever the runner seam changes and before issue close; explicit invocation fails with advice when sdlc is unavailable.

## Open findings

(none — every finding has been disposed)
