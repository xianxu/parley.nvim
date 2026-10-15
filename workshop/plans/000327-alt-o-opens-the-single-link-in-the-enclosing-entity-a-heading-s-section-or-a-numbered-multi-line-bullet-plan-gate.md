---
gate: plan-quality
issue: 327
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-10-15T01:55:39-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Dispatch the selected occurrence without rerunning legacy reference selection
          detail: 'ARCH-PURPOSE: Plan line 72 reuses a chain that ignores cursor containment for leading @@ forms (lua/parley/init.lua:4928) and otherwise selects the nearest @@ reference (lua/parley/init.lua:4945). Specify kind/span/target-based dispatch so selecting a second @@ occurrence or an artifact beside @@ opens exactly that occurrence, while preserving legacy direct invocation behavior.'
          family: selected-occurrence-identity
          round: 1
        - id: PQ-2
          severity: Important
          title: Preserve origin validation through asynchronous selected-target opening
          detail: 'ARCH-ORDER: The pending/settled model validates picker completion only; artifact resolution subsequently schedules an unguarded open (lua/parley/artifact_ref.lua:213–220), contrary to the claimed existing lifecycle. Specify how entity-selected resolution and any secondary family picker revalidate source validity, changedtick, window and command generation immediately before opening, with controllable delayed-completion tests.'
          family: asynchronous-origin-validation
          round: 1
        - id: PQ-3
          severity: Important
          title: Replace prose test inventories with named function-level strategies
          detail: Execution steps at plan lines 95–96 and 104 enumerate test cases, which this gate explicitly rejects. Compress these into one adversarial-input and mechanical-guard strategy per risky named function, covering navigation_range, occurrence parsers/collect, legacy parser consumers and finish_selection; retain integration verification separately.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-10-15T01:57:00-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Plan line 72 requires exact selected-occurrence dispatch while preserving legacy direct invocation behavior.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Plan line 76 carries origin validation through resolver and family-picker effects, with delayed-completion tests and one-shot family selection.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Plan lines 95–105 replace test-case inventories with named function-level adversarial strategies and mechanical guards, retaining separate integration verification.
          round: 2
      blocked: false
    - "n": 3
      timestamp: "2026-10-15T01:57:56-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Selected kind, span and target drive dispatch without replaying legacy reference selection.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Origin validation extends through scheduled resolver dispatch and secondary family-picker effects.
          round: 3
        - id: PQ-3
          disposition: addressed
          note: Named functions have adversarial input or event strategies and mechanical assertions.
          round: 3
      blocked: false
content_hash: 1621bcb7be2129400fc79a2dd9036654af87c412785e0a1a792ba21e34ae62af
---

# Gate ledger — parley.nvim#327 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T01:55:39-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `selected-occurrence-identity` Dispatch the selected occurrence without rerunning legacy reference selection
  ARCH-PURPOSE: Plan line 72 reuses a chain that ignores cursor containment for leading @@ forms (lua/parley/init.lua:4928) and otherwise selects the nearest @@ reference (lua/parley/init.lua:4945). Specify kind/span/target-based dispatch so selecting a second @@ occurrence or an artifact beside @@ opens exactly that occurrence, while preserving legacy direct invocation behavior.
- **PQ-2** [Important] `asynchronous-origin-validation` Preserve origin validation through asynchronous selected-target opening
  ARCH-ORDER: The pending/settled model validates picker completion only; artifact resolution subsequently schedules an unguarded open (lua/parley/artifact_ref.lua:213–220), contrary to the claimed existing lifecycle. Specify how entity-selected resolution and any secondary family picker revalidate source validity, changedtick, window and command generation immediately before opening, with controllable delayed-completion tests.
- **PQ-3** [Important] `function-level-test-strategy` Replace prose test inventories with named function-level strategies
  Execution steps at plan lines 95–96 and 104 enumerate test cases, which this gate explicitly rejects. Compress these into one adversarial-input and mechanical-guard strategy per risky named function, covering navigation_range, occurrence parsers/collect, legacy parser consumers and finish_selection; retain integration verification separately.

## Round 2 — 2026-10-15T01:57:00-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Plan line 72 requires exact selected-occurrence dispatch while preserving legacy direct invocation behavior.
- PQ-2 — addressed — Plan line 76 carries origin validation through resolver and family-picker effects, with delayed-completion tests and one-shot family selection.
- PQ-3 — addressed — Plan lines 95–105 replace test-case inventories with named function-level adversarial strategies and mechanical guards, retaining separate integration verification.

## Round 3 — 2026-10-15T01:57:56-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Selected kind, span and target drive dispatch without replaying legacy reference selection.
- PQ-2 — addressed — Origin validation extends through scheduled resolver dispatch and secondary family-picker effects.
- PQ-3 — addressed — Named functions have adversarial input or event strategies and mechanical assertions.

## Open findings

(none — every finding has been disposed)
