---
id: 000318
status: working
deps: []
github_issue:
created: 2026-10-12
updated: 2026-10-12
estimate_hours:
card_mirror: 'f04668f7d12395e165153e17376f4915db8346ce' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-12T14:43:43-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# roll out ariadne#309 workflows (local-gates-guard, merge-check on push) to parley.nvim

## Problem

ariadne#309 (PR #203) split local gates from server CI checks. A weave refresh seeded its two workflows into parley.nvim's worktrees: `.github/workflows/local-gates-guard.yml` (new) and `.github/workflows/merge-check.yml` (now also runs on push to main). They have to land once on parley.nvim's main, so the worktrees stop carrying them as drift.

## Spec

Commit both files exactly as weave seeded them, byte-identical to ariadne's `origin/main`. Same rollout as pair#500 (pair PR #287).

## Done when

- `.github/workflows/local-gates-guard.yml` and `.github/workflows/merge-check.yml` on parley.nvim's main are byte-identical to ariadne `origin/main` (`git show origin/main:<path> | cmp`).

## Plan

- [x] Stash the seeded files with a tag, file and claim #318, start-plan, restore the stash onto the branch.
- [x] Verify both files are byte-identical to ariadne `origin/main`.
- [x] Commit the two files (close and merge run as the gates).

## Log

### 2026-10-12
- 2026-10-12: closed — Both workflow files byte-identical to ariadne origin/main (539eb793, #309): git show origin/main:.github/workflows/{local-gates-guard,merge-check}.yml | cmp passes. CI config rollout only, no parley code; --no-atlas: no new parley surface or flow.; review verdict: SHIP
- 2026-10-12: flow upgraded quick → full — 152 added lines in code files (limit 100)

- `sdlc start-plan`'s weave refresh re-seeded the same two files on the resting branch (still identical to the stash); I discarded those copies and restored from the stash on the issue branch.
- `cmp` against ariadne `origin/main` (539eb793 merged #309) passes for both files.
