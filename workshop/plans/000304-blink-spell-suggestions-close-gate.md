---
gate: boundary-review
issue: 304
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-29T16:23:27-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Same-buffer window excursions leave stale acceptance tickets valid
          detail: 'lua/parley/spell_blink.lua:241-258 omits window entry/leave invalidation. With pinned real Blink, switching between two windows showing the same buffer and returning during resolution still applied the old correction. ARCH-ORDER: invalidate synchronously on window departure, observe on entry, and add regression tests covering delayed acceptance and resource cleanup across these transitions.'
          family: acceptance-context-invalidation
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#304 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T16:23:27-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `acceptance-context-invalidation` Same-buffer window excursions leave stale acceptance tickets valid
  lua/parley/spell_blink.lua:241-258 omits window entry/leave invalidation. With pinned real Blink, switching between two windows showing the same buffer and returning during resolution still applied the old correction. ARCH-ORDER: invalidate synchronously on window departure, observe on entry, and add regression tests covering delayed acceptance and resource cleanup across these transitions.

## Open findings

- **BR-1** [Critical] `acceptance-context-invalidation` Same-buffer window excursions leave stale acceptance tickets valid
