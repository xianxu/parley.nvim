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
    - "n": 2
      timestamp: "2026-09-14T23:46:39-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: chat_respond.lua:2127 propagates response ownership into automatic topics; dispatcher.lua:881 preserves it across retries. Removing topic ownership in a scratch copy makes both deletion regressions fail at chat_ownership_spec.lua:157. The pinned tests verify unrelated-owner preservation and retention until exit/drain.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The pinned plan adds an explicit M6 task at line 310 covering bounded reconciliation, admission limits, diagnostics, timer cleanup, and deterministic verification. Its Revisions entry at lines 443–451 accurately distinguishes tasker.lua:130's current retention-only behavior from future supervision.
          round: 2
      boundary: M1
      blocked: false
    - "n": 3
      timestamp: "2026-09-15T00:44:23-07:00"
      agent: codex
      findings:
        - id: BR-3
          severity: Critical
          title: Local text certificates permit stale confirmed semantic publication
          detail: 'lua/parley/document/structure.lua:115–154 captures only local text evidence and epoch. After changing an earlier question marker to an assistant marker and completing repair, publishing previously captured body metadata succeeds and restores question semantics with confirmed=true. ARCH-ORDER / ARCH-SECURE: validate incoming semantic state and dependencies, or restrict publication to lexical metadata; add controlled stale-publication and disjoint-edit regressions.'
          family: semantic-publication-evidence
          round: 3
        - id: BR-4
          severity: Critical
          title: Ordinary-fence suppression removes a required reasoning boundary
          detail: 'lua/parley/document/grammar.lua:202–225 rewrites fenced tool markers to text before reasoning termination. For question, answer, opening fence, reasoning marker, tool-result marker, closing fence, the new core marks the last two rows thinking while the legacy reducer marks them text. ARCH-PURPOSE: preserve original structural boundary semantics separately from tool-section admission and cover both tool-marker kinds across section states.'
          family: grammar-boundary-preservation
          round: 3
      boundary: M2
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

## Round 2 — 2026-09-14T23:46:39-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — chat_respond.lua:2127 propagates response ownership into automatic topics; dispatcher.lua:881 preserves it across retries. Removing topic ownership in a scratch copy makes both deletion regressions fail at chat_ownership_spec.lua:157. The pinned tests verify unrelated-owner preservation and retention until exit/drain.
- BR-2 — addressed — The pinned plan adds an explicit M6 task at line 310 covering bounded reconciliation, admission limits, diagnostics, timer cleanup, and deterministic verification. Its Revisions entry at lines 443–451 accurately distinguishes tasker.lua:130's current retention-only behavior from future supervision.

## Round 3 — 2026-09-15T00:44:23-07:00 (codex) — BLOCKED

### Raised

- **BR-3** [Critical] `semantic-publication-evidence` Local text certificates permit stale confirmed semantic publication
  lua/parley/document/structure.lua:115–154 captures only local text evidence and epoch. After changing an earlier question marker to an assistant marker and completing repair, publishing previously captured body metadata succeeds and restores question semantics with confirmed=true. ARCH-ORDER / ARCH-SECURE: validate incoming semantic state and dependencies, or restrict publication to lexical metadata; add controlled stale-publication and disjoint-edit regressions.
- **BR-4** [Critical] `grammar-boundary-preservation` Ordinary-fence suppression removes a required reasoning boundary
  lua/parley/document/grammar.lua:202–225 rewrites fenced tool markers to text before reasoning termination. For question, answer, opening fence, reasoning marker, tool-result marker, closing fence, the new core marks the last two rows thinking while the legacy reducer marks them text. ARCH-PURPOSE: preserve original structural boundary semantics separately from tool-section admission and cover both tool-marker kinds across section states.

## Open findings

- **BR-3** [Critical] `semantic-publication-evidence` Local text certificates permit stale confirmed semantic publication
- **BR-4** [Critical] `grammar-boundary-preservation` Ordinary-fence suppression removes a required reasoning boundary
