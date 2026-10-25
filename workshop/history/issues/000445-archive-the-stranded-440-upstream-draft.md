---
id: 000445
status: done
deps: []
github_issue:
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
card_mirror: '6de0f1066b3b5ff00f4d466ef8f7648b1058a38d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-25T12:21:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e77ad95", done: "860bbf8a"}
actual_hours: 0.01
---

# Archive the stranded #440 upstream draft

## Problem

#440 landed archived, but its upstream-neovim draft is still active at workshop/plans/000440-a-predicate-wait-doing-child-rpc-never-times-out-plan.side/upstream-neovim-draft.md (2784 bytes, blob 019dc761539e225e0164bb94a882ef50545afbc6, main d1f173bf). The archive step refused the plan side folder because no plan document belongs to it. ariadne#623 fixes that step for the future; this item archives the one stranded file.

## Spec

Move the file byte-for-byte to workshop/history/plans/000440-a-predicate-wait-doing-child-rpc-never-times-out-plan.side/upstream-neovim-draft.md. Fix nothing else: the archived #440 issue's relative link (../plans/…-plan.side/…) resolves to that destination once it exists.

## Done when

- The draft exists only at the history path, with blob 019dc761539e225e0164bb94a882ef50545afbc6.
- The archived #440 issue's link to it resolves on main.

## Plan

## Log


- 2026-10-25: closed — Docs-only move at hub direction, citing ariadne#623. The #440 upstream draft was stranded active at workshop/plans/000440-...-plan.side/upstream-neovim-draft.md, because the archive step refused a plan side folder with no plan document. It is moved byte-for-byte with git mv to workshop/history/plans/000440-...-plan.side/upstream-neovim-draft.md: git ls-tree on the head shows blob 019dc761539e225e0164bb94a882ef50545afbc6, 2784 bytes, the same as on main d1f173bf, and it is the only copy in the tree. The archived #440 issue link (../plans/000440-...-plan.side/upstream-neovim-draft.md) resolves to the new path; test -f confirmed. Nothing else changed.; review verdict: SHIP
Filed at hub direction (cfa12599). Cites ariadne#623.
