---
gate: boundary-review
issue: 248
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-14T08:59:43-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: README still promises visual branching stays in the parent
          detail: README.md:213 says “You stay in the parent,” but lua/parley/init.lua:2527 now schedules opening the child after saving its anchor. Update the branch instructions to describe first-question Insert-mode landing across chat creation paths; README has no update in this range (ARCH-PURPOSE, docs update gate).
          family: user-docs-match-behavior
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T09:02:12-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:213 removes the parent-focus promise, and README.md:221–223 describes first-question Insert-mode landing across chat cases. This matches open_branch_question at lua/parley/init.lua:2300 and its three call sites. The pinned correction is prose-only; existing behavioral tests pass.
          round: 2
      blocked: false
---

# Gate ledger — parley.nvim#248 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T08:59:43-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `user-docs-match-behavior` README still promises visual branching stays in the parent
  README.md:213 says “You stay in the parent,” but lua/parley/init.lua:2527 now schedules opening the child after saving its anchor. Update the branch instructions to describe first-question Insert-mode landing across chat creation paths; README has no update in this range (ARCH-PURPOSE, docs update gate).

## Round 2 — 2026-09-14T09:02:12-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — README.md:213 removes the parent-focus promise, and README.md:221–223 describes first-question Insert-mode landing across chat cases. This matches open_branch_question at lua/parley/init.lua:2300 and its three call sites. The pinned correction is prose-only; existing behavioral tests pass.

## Open findings

(none — every finding has been disposed)
