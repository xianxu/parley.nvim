---
gate: plan-quality
issue: 247
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-13T15:56:33-07:00"
      agent: codex
      blocked: false
    - "n": 2
      timestamp: "2026-09-13T20:25:21-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Place the introduction at a boundary that survives prompt resolution.
          detail: 'ARCH-PURPOSE: Appending when obtaining an agent can lose the introduction because agent_info.resolve replaces that prompt with the selected system prompt or chat header. Name the final composition owner and precedence policy, preserving configured text while ensuring the introduction reaches the request exactly once; verify the resolved request prompt.'
          family: prompt-composition-boundary
          round: 2
        - id: PQ-2
          severity: Important
          title: Replace the bundled-help case inventory with named function strategies and failure behavior.
          detail: 'ARCH-PURE/SECURE: Plan lines 358–361 enumerate cases but do not specify unit-test strategies for read, introduction, or a pure section parser. Name the pure parsing/composition surface and thin file reader, define behavior for unreadable or malformed bundled content, and give one adversarial-input/mechanical-guard line per risky function instead of the case list.'
          family: function-test-strategy
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-13T20:26:35-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Plan lines 372–377 name post-resolution composition, preserve prompt precedence, avoid stored-definition mutation, and require repeated-call verification.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Plan lines 379–392 name pure functions and thin readers, bound input, define failure behavior, and provide adversarial parsing and isolated integration strategies.
          round: 3
      blocked: false
    - "n": 4
      timestamp: "2026-09-13T22:07:12-07:00"
      agent: codex
      blocked: false
content_hash: 11b262495faee4bc6adce7130e8de13a8ccd54d13f8c4c6c7e38abe64bc67b3d
---

# Gate ledger — parley.nvim#247 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T15:56:33-07:00 (codex) — passed

## Round 2 — 2026-09-13T20:25:21-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `prompt-composition-boundary` Place the introduction at a boundary that survives prompt resolution.
  ARCH-PURPOSE: Appending when obtaining an agent can lose the introduction because agent_info.resolve replaces that prompt with the selected system prompt or chat header. Name the final composition owner and precedence policy, preserving configured text while ensuring the introduction reaches the request exactly once; verify the resolved request prompt.
- **PQ-2** [Important] `function-test-strategy` Replace the bundled-help case inventory with named function strategies and failure behavior.
  ARCH-PURE/SECURE: Plan lines 358–361 enumerate cases but do not specify unit-test strategies for read, introduction, or a pure section parser. Name the pure parsing/composition surface and thin file reader, define behavior for unreadable or malformed bundled content, and give one adversarial-input/mechanical-guard line per risky function instead of the case list.

## Round 3 — 2026-09-13T20:26:35-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Plan lines 372–377 name post-resolution composition, preserve prompt precedence, avoid stored-definition mutation, and require repeated-call verification.
- PQ-2 — addressed — Plan lines 379–392 name pure functions and thin readers, bound input, define failure behavior, and provide adversarial parsing and isolated integration strategies.

## Round 4 — 2026-09-13T22:07:12-07:00 (codex) — passed

## Open findings

(none — every finding has been disposed)
