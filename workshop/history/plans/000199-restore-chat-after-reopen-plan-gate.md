---
gate: plan-quality
issue: 199
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-18T15:27:45-07:00"
      agent: codex
      blocked: false
      protocol_error: no valid findings block
    - "n": 2
      timestamp: "2026-08-18T15:29:14-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: The teardown step does not specify how to avoid clearing state on BufUnload
          detail: The existing classification teardown is one autocmd registered for both BufDelete and BufUnload at lua/parley/highlighter.lua:1120. Adding the marker clear there as written would violate the negative-case requirement. Amend the plan to condition on event.event == "BufDelete" or split out a BufDelete-only teardown, preserving BufUnload behavior (ARCH-PURPOSE).
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-08-18T15:30:02-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The revised implementation step explicitly guards on event.event == "BufDelete" and preserves the prepared marker for BufUnload.
          round: 3
      blocked: false
content_hash: 5d4131e65eaa62613afc23ae651f50b05691d5ad9364a903ca93ff365a1b3806
---

# Gate ledger — parley.nvim#199 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-18T15:27:45-07:00 (codex) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 2 — 2026-08-18T15:29:14-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] The teardown step does not specify how to avoid clearing state on BufUnload
  The existing classification teardown is one autocmd registered for both BufDelete and BufUnload at lua/parley/highlighter.lua:1120. Adding the marker clear there as written would violate the negative-case requirement. Amend the plan to condition on event.event == "BufDelete" or split out a BufDelete-only teardown, preserving BufUnload behavior (ARCH-PURPOSE).

## Round 3 — 2026-08-18T15:30:02-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The revised implementation step explicitly guards on event.event == "BufDelete" and preserves the prepared marker for BufUnload.

## Open findings

(none — every finding has been disposed)
