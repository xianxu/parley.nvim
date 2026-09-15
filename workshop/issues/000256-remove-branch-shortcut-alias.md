---
id: 000256
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
---

# Remove conflicting branch shortcut alias

## Problem

The default branch shortcut includes `<M-S-CR>`, which conflicts with Pair's
pane-level shortcut. Another agent prepared removal; the operator requested
committing the non-chat changes after inspection.

## Spec

Remove `<M-S-CR>` from both shipped configuration and registry fallback. Retain
`<M-i>` as primary and `<C-g>i` as the legacy alias. Update help expectations,
comments and atlas descriptions without changing branch submission behavior.

## Done when

- Both default key sources contain only `<M-i>` and `<C-g>i`.
- Help and documentation agree with the bindings; branch regression tests pass.

## Plan

- [x] Inspect the existing code, test and documentation changes.
- [x] Verify keybindings, pure branch submission and native child creation.
- [ ] Complete the publish review when these local commits are shipped.

## Log

### 2026-09-15

Operator authorized committing existing non-chat edits. Keybindings75,
branch_submit17 and branch_child62 tests pass (154 total, zero failures/errors).
Corrected a malformed explanatory comment before committing. Chat transcripts
are excluded. The unrelated SVG prompt instruction is a separate local commit.
