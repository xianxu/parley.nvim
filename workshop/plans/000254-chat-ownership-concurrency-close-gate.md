---
gate: boundary-review
issue: 254
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-14T23:35:44-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Automatic topic generation escapes response cancellation ownership
          detail: chat_respond.lua:1755 cancels transport_owner, but generate_topic launches dispatcher.query at line 1216 without that identity. A scratch production-response regression completed the answer, deleted its header during topic generation, and observed no cancellation signal. Propagate ownership through response-owned launch paths and add a regression covering topic cancellation and unrelated-owner preservation (ARCH-PURPOSE, ARCH-ORDER, ARCH-FUNERAL).
          family: cancellation-owner-propagation
          round: 1
        - id: BR-2
          severity: Important
          title: Assign deferred attempt reconciliation to an explicit milestone
          detail: The plan at line 242 promises bounded reconciliation and visible unresolved status, while tasker.lua:130 implements no polling and its reconciliation function has no production caller. The issue log defers this work without an explicit remaining milestone task; add a Revisions entry and assign implementation, admission bounds, diagnostics, and deterministic verification (ARCH-CONSTRAINTS).
          family: deferred-contract-traceability
          round: 1
      boundary: M1
      blocked: true
---

# Gate ledger — 000254-chat-ownership-concurrency#254 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T23:35:44-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `cancellation-owner-propagation` Automatic topic generation escapes response cancellation ownership
  chat_respond.lua:1755 cancels transport_owner, but generate_topic launches dispatcher.query at line 1216 without that identity. A scratch production-response regression completed the answer, deleted its header during topic generation, and observed no cancellation signal. Propagate ownership through response-owned launch paths and add a regression covering topic cancellation and unrelated-owner preservation (ARCH-PURPOSE, ARCH-ORDER, ARCH-FUNERAL).
- **BR-2** [Important] `deferred-contract-traceability` Assign deferred attempt reconciliation to an explicit milestone
  The plan at line 242 promises bounded reconciliation and visible unresolved status, while tasker.lua:130 implements no polling and its reconciliation function has no production caller. The issue log defers this work without an explicit remaining milestone task; add a Revisions entry and assign implementation, admission bounds, diagnostics, and deterministic verification (ARCH-CONSTRAINTS).

## Open findings

- **BR-1** [Critical] `cancellation-owner-propagation` Automatic topic generation escapes response cancellation ownership
- **BR-2** [Important] `deferred-contract-traceability` Assign deferred attempt reconciliation to an explicit milestone
