---
id: 000445
status: open
deps: []
github_issue:
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
card_mirror: '7669b3e6178da5701d1ca1c8b061fbc93bdc68b7' # card fields mirrored from issue-cards; edit via sdlc
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

Filed at hub direction (cfa12599). Cites ariadne#623.
