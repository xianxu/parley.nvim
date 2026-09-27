---
gate: boundary-review
issue: 285
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T16:53:46-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Re-ask payloads can retain stale tool-call answer blocks
          detail: '`input_parsed` is deep-copied before `exchange.answer = nil`, so target answers containing tool_use/tool_result blocks remain eligible for inclusion in `build_messages`; clear the target answer in the payload snapshot and add a regression test.'
          family: resubmit-capture-excludes-target-answer
          round: 1
        - id: BR-2
          severity: Important
          title: Production cancellation and admission cleanup lack regression coverage
          detail: The new lifecycle cleanup is tested only through direct document helpers, not through response cancellation or failed admission; add integration tests that prove no pending snapshot survives either path.
          family: pending-snapshot-terminal-path-coverage
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-26T17:00:18-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The target answer is cleared from input_parsed, but no regression test exercises a re-ask containing tool_use/tool_result blocks; the required behavior-changing evidence is absent.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Production cancellation now has integration coverage, but failed-admission cleanup still has no regression test, so the finding is only partially addressed.
          round: 2
      findings:
        - id: BR-3
          severity: Critical
          title: Overlapping re-asks can clear another attempt's pending snapshot
          detail: The pending slot is stored by entity with generation=nil and release clears by entity plus nil generation; an earlier response can therefore retire a later response's snapshot before its generation adopts it. Add per-attempt ownership/token matching and an overlapping re-ask regression test. ARCH-ORDER, ARCH-FUNERAL.
          family: pending-snapshot-generation-ownership
          round: 2
        - id: BR-4
          severity: Minor
          title: Footer result is overwritten before use
          detail: The assignment at lua/parley/chat_respond.lua:1516 is overwritten at line 1529; remove it to restore a clean lint run.
          family: dead-intermediate-assignment
          round: 2
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#285 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T16:53:46-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `resubmit-capture-excludes-target-answer` Re-ask payloads can retain stale tool-call answer blocks
  `input_parsed` is deep-copied before `exchange.answer = nil`, so target answers containing tool_use/tool_result blocks remain eligible for inclusion in `build_messages`; clear the target answer in the payload snapshot and add a regression test.
- **BR-2** [Important] `pending-snapshot-terminal-path-coverage` Production cancellation and admission cleanup lack regression coverage
  The new lifecycle cleanup is tested only through direct document helpers, not through response cancellation or failed admission; add integration tests that prove no pending snapshot survives either path.

## Round 2 — 2026-09-26T17:00:18-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The target answer is cleared from input_parsed, but no regression test exercises a re-ask containing tool_use/tool_result blocks; the required behavior-changing evidence is absent.
- BR-2 — not-addressed — Production cancellation now has integration coverage, but failed-admission cleanup still has no regression test, so the finding is only partially addressed.

### Raised

- **BR-3** [Critical] `pending-snapshot-generation-ownership` Overlapping re-asks can clear another attempt's pending snapshot
  The pending slot is stored by entity with generation=nil and release clears by entity plus nil generation; an earlier response can therefore retire a later response's snapshot before its generation adopts it. Add per-attempt ownership/token matching and an overlapping re-ask regression test. ARCH-ORDER, ARCH-FUNERAL.
- **BR-4** [Minor] `dead-intermediate-assignment` Footer result is overwritten before use
  The assignment at lua/parley/chat_respond.lua:1516 is overwritten at line 1529; remove it to restore a clean lint run.

## Open findings

- **BR-1** [Critical] `resubmit-capture-excludes-target-answer` Re-ask payloads can retain stale tool-call answer blocks
- **BR-2** [Important] `pending-snapshot-terminal-path-coverage` Production cancellation and admission cleanup lack regression coverage
- **BR-3** [Critical] `pending-snapshot-generation-ownership` Overlapping re-asks can clear another attempt's pending snapshot
- **BR-4** [Minor] `dead-intermediate-assignment` Footer result is overwritten before use
