---
id: 000391
status: open
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
started: 2026-10-18T20:36:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it

## Problem

The breadcrumb winbar (#353, atlas/ui/breadcrumb.md) shows the navigation trail Alt+o recorded: the path the operator actually followed. For side-doc trees that is wrong. With A > B1 > C1 and A > B2 > C2, if the operator is at C2 and follows a link to C1, the winbar shows A > B2 > C2 > C1; it should show A > B1 > C1, C1's place in the tree. Operator, 2026-10-18 (ops session file, Operator instructions item 3).
