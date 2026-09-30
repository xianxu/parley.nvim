---
gate: plan-quality
issue: 304
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-29T16:00:16-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: 'ARCH-PURPOSE / ARCH-ORDER: Prevent preview edits during Blink list refresh'
          detail: The navigation override in plan lines 18 and 110 does not cover pinned Blink completion/list.lua:125, which reselects without options; :195–200 then uses configured auto_insert and applies a preview. Specify a concrete safeguard for refresh-driven selection, including delayed mixed-provider updates, that preserves explicit-only edits without changing unrelated user configuration.
          family: explicit-edit-authorization
          round: 1
        - id: PQ-2
          severity: Important
          title: Compress test-case inventories into named function strategies
          detail: Plan lines 89–90, 99–101, 109–112 and 121–122 enumerate test cases contrary to this gate's requirements. Replace these inventories with the functions under test and one adversarial-input or event-sequence strategy plus mechanical guard per risky function; retain suite commands and the real-Blink verification boundary.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-29T16:01:42-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The context-scoped selection-mode adapter covers refresh-driven previews, with delayed mixed-provider verification and unchanged foreign configuration.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: The cited inventories now use function-level adversarial strategies and mechanical guards while retaining suite commands and real-Blink verification.
          round: 2
      blocked: false
    - "n": 3
      timestamp: "2026-09-29T16:03:10-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Context-scoped selection policy covers refresh previews while preserving foreign contexts and user configuration.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Named function strategies specify adversarial inputs and mechanical guards, retaining real-Blink verification.
          round: 3
      blocked: false
content_hash: b3cc8820d6bb63967056b001707b5f1843ccb6502b8729fa9517629f70b1733c
---

# Gate ledger — parley.nvim#304 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T16:00:16-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `explicit-edit-authorization` ARCH-PURPOSE / ARCH-ORDER: Prevent preview edits during Blink list refresh
  The navigation override in plan lines 18 and 110 does not cover pinned Blink completion/list.lua:125, which reselects without options; :195–200 then uses configured auto_insert and applies a preview. Specify a concrete safeguard for refresh-driven selection, including delayed mixed-provider updates, that preserves explicit-only edits without changing unrelated user configuration.
- **PQ-2** [Important] `function-level-test-strategy` Compress test-case inventories into named function strategies
  Plan lines 89–90, 99–101, 109–112 and 121–122 enumerate test cases contrary to this gate's requirements. Replace these inventories with the functions under test and one adversarial-input or event-sequence strategy plus mechanical guard per risky function; retain suite commands and the real-Blink verification boundary.

## Round 2 — 2026-09-29T16:01:42-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The context-scoped selection-mode adapter covers refresh-driven previews, with delayed mixed-provider verification and unchanged foreign configuration.
- PQ-2 — addressed — The cited inventories now use function-level adversarial strategies and mechanical guards while retaining suite commands and real-Blink verification.

## Round 3 — 2026-09-29T16:03:10-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Context-scoped selection policy covers refresh previews while preserving foreign contexts and user configuration.
- PQ-2 — addressed — Named function strategies specify adversarial inputs and mechanical guards, retaining real-Blink verification.

## Open findings

(none — every finding has been disposed)
