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
    - "n": 2
      timestamp: "2026-09-29T16:28:17-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: lua/parley/spell_blink.lua:256 invalidates synchronously on window transitions and schedules entry observation. Controller regressions verify cleanup and re-observation; real Blink regressions cover delayed resolution across departure and return. Both profiles pass, and removing this handler in memory makes the return-to-origin regression fail at tests/packaging/spell_compatibility.lua:175.
          round: 2
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#304 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T16:23:27-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `acceptance-context-invalidation` Same-buffer window excursions leave stale acceptance tickets valid
  lua/parley/spell_blink.lua:241-258 omits window entry/leave invalidation. With pinned real Blink, switching between two windows showing the same buffer and returning during resolution still applied the old correction. ARCH-ORDER: invalidate synchronously on window departure, observe on entry, and add regression tests covering delayed acceptance and resource cleanup across these transitions.

## Round 2 — 2026-09-29T16:28:17-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — lua/parley/spell_blink.lua:256 invalidates synchronously on window transitions and schedules entry observation. Controller regressions verify cleanup and re-observation; real Blink regressions cover delayed resolution across departure and return. Both profiles pass, and removing this handler in memory makes the return-to-origin regression fail at tests/packaging/spell_compatibility.lua:175.

## Open findings

(none — every finding has been disposed)
