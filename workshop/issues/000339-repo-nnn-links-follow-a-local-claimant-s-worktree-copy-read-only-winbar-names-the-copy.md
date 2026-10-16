---
id: 000339
status: open
deps: [parley.nvim#332]
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '9726f8b8acbf2d13c26a0ad0a4effec64e417579' # card fields mirrored from issue-cards; edit via sdlc
---

# repo#NNN links follow a local claimant's worktree copy (read-only, winbar names the copy)

## Problem

`repo#NNN` links open the issue's details file in the main checkout, which shows only what has been published. While a
slot works an issue, its live `## Spec`, `## Plan` and `## Log` are in that slot's worktree, often hours ahead of main.
The card (which parley already reads from the card branch head) names the claimant.

## Spec

- Resolution: read the card's claimant (e.g. `pair:3`). If that slot is on this machine, map it to its worktree with
  the same slot-to-path rule `sdlc` uses, and check the worktree is on the issue's branch and holds the details file.
  If so, open it there; otherwise (claimant elsewhere or absent, worktree missing or resting, file absent) open main's
  copy as today.
- Winbar names the copy: "live: pair:3's worktree (branch 000579-…)" or "main"; one key opens the other copy.
- The worktree copy opens **read-only by default** (an agent may be editing it); the operator comments through 🤖
  markers and Alt+Return to that slot (agentic documents, #332).

## Done when

- Tests: claimant local and on branch → worktree copy, read-only, winbar "live"; each fallback case → main; the
  switch key toggles copies.

Operator go 2026-10-15; schedule after #332 (builds on its document identity).

## Plan

- [ ]

## Log

### 2026-10-15
