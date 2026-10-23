---
id: 000429
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'fd0d1dbb62cec197fff2e95121634b16f22fdb36' # card fields mirrored from issue-cards; edit via sdlc
---

# Registry gate: comment overclaim for rows 1/5 and unsaved move timeout

## Problem

These are the two advisory findings from #414's close review (round 2) on the registry gate in `tests/integration/agentic_document_spec.lua`. The TL left both for the next person who touches the gate.

1. **The comment overclaims.** The gate comment (around :103) says every synchronous wait gets an answer before it gives up. In rows 1/5 (submit timeout 1000) the rename deadline is 3 × 1000 = 3000 ms, equal to GATE_MS, and other requests get 1000 ms (document_registry.lua:26, :34). A wait cut off there leaves no answer record, so those rows rely on the operation-pending check (#414 control E).
2. **The move timeout isn't saved.** `gate_couch` sets `config.agentic_move_timeout_ms` without saving the old value. It is restored only because every caller runs `with_timeouts` first. A gated row without `with_timeouts` would leak the 6 s timeout into later cases.

## Spec

## Done when

- `gate_couch` enforces (or the comment states exactly) the rule that GATE_MS is below every deadline in force in a gated row: the move timeout, the submit timeout, and 3 × the submit timeout. Any row that falls back to the pending check is named.
- `gate_couch` saves and restores the move timeout itself (or calls `with_timeouts`).
- agentic_document_spec passes, and #414's negative controls still fail their rows.

## Plan

- [ ]

## Log

### 2026-10-23
