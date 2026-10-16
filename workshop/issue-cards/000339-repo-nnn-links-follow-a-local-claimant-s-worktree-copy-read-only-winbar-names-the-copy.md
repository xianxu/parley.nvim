---
id: 000339
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
---

# repo#NNN links follow a local claimant's worktree copy (read-only, winbar names the copy)

## Problem

`repo#NNN` links open the issue's details file in the main checkout, which shows only what has been published. While a
slot works an issue, its live `## Spec`, `## Plan` and `## Log` are in that slot's worktree, often hours ahead of main.
The card (which parley already reads from the card branch head) names the claimant.
