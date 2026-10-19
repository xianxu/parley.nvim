---
id: 000391
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'de5ab3608d1a304f77d9aabc1aa63eb4bd247328' # card fields mirrored from issue-cards; edit via sdlc
---

# breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it

## Problem

The breadcrumb winbar (#353, atlas/ui/breadcrumb.md) shows the navigation trail Alt+o recorded: the path the operator actually followed. For side-doc trees that is wrong. With A > B1 > C1 and A > B2 > C2, if the operator is at C2 and follows a link to C1, the winbar shows A > B2 > C2 > C1; it should show A > B1 > C1, C1's place in the tree. Operator, 2026-10-18 (ops session file, Operator instructions item 3).

## Spec

For a document in a side-doc tree (a `.side/` doc with `parent:` frontmatter, or a parent that lists `discussions:`), the winbar displays its tree path: the chain of `parent:` links up to the root, regardless of how the window reached it. The chain is bounded (depth cap, cycle detection, a missing parent ends the chain with a marker) and read from frontmatter only. For a file outside any side-doc tree, today's navigation trail stays. Shift+Alt+O (Back) is unchanged: it walks the window's visit history, not the tree. Labels, collapsing and narrow-window rules stay as they are.

## Done when

- The A > B1 > C1 / A > B2 > C2 case shows A > B1 > C1 after jumping from C2 to C1 (spec test).
- A cycle, a missing parent and a depth over the cap each show a bounded path with a marker, no hang.
- Files outside trees keep today's trail; Back behaves as before.

## Plan

- [ ]

## Log

### 2026-10-18
