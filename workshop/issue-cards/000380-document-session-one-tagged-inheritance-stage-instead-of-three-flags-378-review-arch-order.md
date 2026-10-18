---
id: 000380
status: codecomplete
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T19:05:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.15
tracker:
    version: 1
    completion:
        token: close-af41b5c4c8f4
        repository: github.com/xianxu/parley.nvim
        reviewed_head: e4fd6fb1734bcc2be5546291877c8870dbdf16a6
        evidence_commit: 54cd27156133093f271b47b497f2ca89bd14cac6
---

# document_session: one tagged inheritance stage instead of three flags (#378 review, ARCH-ORDER)

## Problem

The #378 close review (round 4, a Minor under ARCH-ORDER) noted that `document_session` tracks a side doc's inheritance with three flags and an operation kind:
- `state.inherit`, the hint stashed while the attach lookup is out;
- `args.inherit`, on the inherit lookup;
- `args.inherited`, on the inherited register and its re-lookup;
- the `confirm_parent` operation kind.

The legal combinations are not written down anywhere. The settle step and the `admits`/`inheriting` helpers read these flags back to decide whether a held Alt+Return flushes or drops. In the same review, a lookup's or confirm_parent's `not live` branch was noted as practically unreachable, and no fixture enters it.
