---
gate: boundary-review
issue: 281
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T11:48:58-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Minor
          title: Done-when clause 3 names result inspection, but the Log's coverage note does not address it for design A
          detail: 'The Log item (3) covers the transcript format, id pairing, context rebuild, lifecycle and compatibility. It never states how a user inspects a call''s arguments, result, status or errors under A (implied: unchanged folded inline blocks). Add one line to the coverage note.'
          family: done-when-clause-coverage
          round: 1
        - id: BR-2
          severity: Minor
          title: '#290 cites dispatcher.lua:261-266, but two dispatcher.lua files exist; the budget logic is in lua/parley/tools/dispatcher.lua'
          detail: Use the full path so the follow-up's implementer lands on the right file. Every other citation in the window names an unambiguous file.
          family: ambiguous-source-citation
          round: 1
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#281 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T11:48:58-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `done-when-clause-coverage` Done-when clause 3 names result inspection, but the Log's coverage note does not address it for design A
  The Log item (3) covers the transcript format, id pairing, context rebuild, lifecycle and compatibility. It never states how a user inspects a call's arguments, result, status or errors under A (implied: unchanged folded inline blocks). Add one line to the coverage note.
- **BR-2** [Minor] `ambiguous-source-citation` #290 cites dispatcher.lua:261-266, but two dispatcher.lua files exist; the budget logic is in lua/parley/tools/dispatcher.lua
  Use the full path so the follow-up's implementer lands on the right file. Every other citation in the window names an unambiguous file.

## Open findings

- **BR-1** [Minor] `done-when-clause-coverage` Done-when clause 3 names result inspection, but the Log's coverage note does not address it for design A
- **BR-2** [Minor] `ambiguous-source-citation` #290 cites dispatcher.lua:261-266, but two dispatcher.lua files exist; the budget logic is in lua/parley/tools/dispatcher.lua
