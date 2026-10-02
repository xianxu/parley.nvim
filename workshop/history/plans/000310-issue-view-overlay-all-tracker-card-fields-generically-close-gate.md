---
gate: boundary-review
issue: 310
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-02T10:12:19-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: missing() blank-card-value skip has no test reaching it
          detail: All fixtures with blank card values (estimate_hours, github_issue) already have a local line, so `present` filters them first; deleting the `not blank(value)` guard at issue_cards.lua:284 leaves every test green. Add a case with a details file lacking a key whose card value is blank (scalar and empty block).
          family: done-when-case-untested
          round: 1
        - id: BR-2
          severity: Minor
          title: overlay tracker_stale now also flags fields absent from the details
          detail: Harmless today (render paints only status/title/github_issue), but a comment on tracker_stale would stop a future consumer from treating it as a stale count.
          family: field-semantics-undocumented
          round: 1
        - id: BR-3
          severity: Minor
          title: view_lines shows no card fields when names is nil
          detail: Acceptable since the tracker is off without a vocabulary; worth one line in the doc comment.
          family: field-semantics-undocumented
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-10-02T10:15:46-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: New case at tests/unit/issue_cards_spec.lua:200 (details lack the keys; card values "", {}, nil); scratch-copy mutation removing `not blank(value)` turns it red.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Overlay doc comment now states tracker_stale is a per-field paint set that includes fields the details lack, not a stale count.
          round: 2
        - id: BR-3
          disposition: addressed
          note: view_lines doc comment now states nil names shows no fields (tracker off without a vocabulary); matches the `names or {}` loop.
          round: 2
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#310 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-02T10:12:19-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `done-when-case-untested` missing() blank-card-value skip has no test reaching it
  All fixtures with blank card values (estimate_hours, github_issue) already have a local line, so `present` filters them first; deleting the `not blank(value)` guard at issue_cards.lua:284 leaves every test green. Add a case with a details file lacking a key whose card value is blank (scalar and empty block).
- **BR-2** [Minor] `field-semantics-undocumented` overlay tracker_stale now also flags fields absent from the details
  Harmless today (render paints only status/title/github_issue), but a comment on tracker_stale would stop a future consumer from treating it as a stale count.
- **BR-3** [Minor] `field-semantics-undocumented` view_lines shows no card fields when names is nil
  Acceptable since the tracker is off without a vocabulary; worth one line in the doc comment.

## Round 2 — 2026-10-02T10:15:46-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — New case at tests/unit/issue_cards_spec.lua:200 (details lack the keys; card values "", {}, nil); scratch-copy mutation removing `not blank(value)` turns it red.
- BR-2 — addressed — Overlay doc comment now states tracker_stale is a per-field paint set that includes fields the details lack, not a stale count.
- BR-3 — addressed — view_lines doc comment now states nil names shows no fields (tracker off without a vocabulary); matches the `names or {}` loop.

## Open findings

(none — every finding has been disposed)
