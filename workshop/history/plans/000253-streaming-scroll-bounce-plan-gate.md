---
gate: plan-quality
issue: 253
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T13:37:13-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Replace the enumerated RED cases with named function-level strategies.
          detail: Execution step 2 enumerates test cases, while no function is explicitly named for direct unit testing of endpoint derivation (ARCH-PURE). Compress this into a named pure endpoint test surface and one adversarial-input/mechanical-guard strategy per risky function, distinguishing direct unit tests from Neovim integration tests; keep individual cases in executable specs.
          family: function-level-test-strategy
          round: 1
        - id: PQ-2
          severity: Important
          title: Specify the synchronization contract for attached-UI assertions.
          detail: “Separate real UI state from assertions returned by RPC” does not establish when wheel input, the schedule-wrapped create_handler write (lua/parley/dispatcher.lua:936), and redraw have completed (ARCH-ORDER). Name the observable completion/redraw barrier before reading view state, with bounded waits and diagnostic failure on timeout (ARCH-CONSTRAINTS), so the regression cannot pass by observing state before the offending redraw.
          family: deterministic-ui-observation
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T13:39:00-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: not-addressed
          note: The revision names integration owners but no directly unit-tested pure endpoint derivation function; query_cursor_line only projects the existing row. Explicitly supersede the RED-case enumeration with named function strategies and keep individual cases in executable specs (ARCH-PURE).
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Observable wheel/chunk/callback completion conditions, subsequent synchronous redraw, bounded polling, and diagnostic timeout failures establish the requested observation contract (ARCH-ORDER, ARCH-CONSTRAINTS).
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-14T13:40:20-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The latest revision supersedes the case enumeration with a named pure projection unit-test surface and function-level integration strategies.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Observable input, chunk and completion barriers precede synchronous redraw and view snapshots, with bounded timeout failures.
          round: 3
      blocked: false
content_hash: 4423a42f13ddc68e0ca2d78e7a41ff1fa04c94170659c0484e60164d76d0025d
---

# Gate ledger — parley.nvim#253 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T13:37:13-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace the enumerated RED cases with named function-level strategies.
  Execution step 2 enumerates test cases, while no function is explicitly named for direct unit testing of endpoint derivation (ARCH-PURE). Compress this into a named pure endpoint test surface and one adversarial-input/mechanical-guard strategy per risky function, distinguishing direct unit tests from Neovim integration tests; keep individual cases in executable specs.
- **PQ-2** [Important] `deterministic-ui-observation` Specify the synchronization contract for attached-UI assertions.
  “Separate real UI state from assertions returned by RPC” does not establish when wheel input, the schedule-wrapped create_handler write (lua/parley/dispatcher.lua:936), and redraw have completed (ARCH-ORDER). Name the observable completion/redraw barrier before reading view state, with bounded waits and diagnostic failure on timeout (ARCH-CONSTRAINTS), so the regression cannot pass by observing state before the offending redraw.

## Round 2 — 2026-09-14T13:39:00-07:00 (codex) — BLOCKED

### Disposed

- PQ-1 — not-addressed — The revision names integration owners but no directly unit-tested pure endpoint derivation function; query_cursor_line only projects the existing row. Explicitly supersede the RED-case enumeration with named function strategies and keep individual cases in executable specs (ARCH-PURE).
- PQ-2 — addressed — Observable wheel/chunk/callback completion conditions, subsequent synchronous redraw, bounded polling, and diagnostic timeout failures establish the requested observation contract (ARCH-ORDER, ARCH-CONSTRAINTS).

## Round 3 — 2026-09-14T13:40:20-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The latest revision supersedes the case enumeration with a named pure projection unit-test surface and function-level integration strategies.
- PQ-2 — addressed — Observable input, chunk and completion barriers precede synchronous redraw and view snapshots, with bounded timeout failures.

## Open findings

(none — every finding has been disposed)
