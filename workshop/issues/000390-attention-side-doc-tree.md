---
id: 000390
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '09aa64bce4b4a1155506ea38a5ca2089b5bd3957' # card fields mirrored from issue-cards; edit via sdlc
---

# Show side-document trees in the attention finder

## Problem

The attention finder presents side docs as a flat list, obscuring which request each response belongs to.

## Spec

Group side docs beneath their listed parent, recursively, with two spaces indentation per level. Keep top-level entries newest-submit-first; a missing/filtered parent makes a side doc top-level. Keep current-slot scope and Ctrl+A unchanged. Search must find children and show their parent above each match (including ancestor context for nested matches).

## Done when

- Parent/child/grandchild rows render in tree order with two spaces per level, preserving existing top-level ordering.
- Missing or slot-filtered parents leave their children at top level; malformed parent cycles terminate without losing or duplicating entries.
- Searching a child retains its ancestor context in tree order; unrelated branches are excluded.
- Scope toggling, selection, query retention and late refresh keep their existing behavior; tests cover the real picker.

## Plan

- [ ]

## Log

### 2026-10-18
