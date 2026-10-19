---
id: 000392
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'de5f93bdfbc0cc0b3d5d27927afec2100b653900' # card fields mirrored from issue-cards; edit via sdlc
---

# attention finder opens on the oldest unread entry

## Problem

The attention finder (Alt+Space) opens with the cursor at the top of the list (since #390's tree layout). The operator (2026-10-18): "attention finder upon open, should focus on oldest unread item": the cursor should land where the next thing to read is.

## Spec

On open, place the cursor on the oldest unread entry: state `answered` (an answer arrived and the operator has not seen it since), ordered by its answer time, oldest first; side docs count like any entry, and the tree layout is unchanged (only the cursor moves; the list scrolls to show it). If no entry is unread, keep today's position (the top). Filtering by typing behaves as today once the user types. Per-slot scope (Ctrl+A) applies before the choice: the oldest unread entry within the current scope.

## Done when

- With several answered-unseen entries, open lands on the one answered earliest, in both scopes.
- With none, open lands at the top as today.
- A side doc that is the oldest unread entry is selected inside its tree.

## Plan

- [ ]

## Log

### 2026-10-18
