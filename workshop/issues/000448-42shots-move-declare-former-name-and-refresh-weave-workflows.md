---
id: 000448
status: open
deps: []
github_issue:
created: 2026-10-26
updated: 2026-10-26
estimate_hours:
card_mirror: '68d1fe2cfc14cebe7ebb88411de5271b20286d4b' # card fields mirrored from issue-cards; edit via sdlc
---

# 42shots move: declare former name and refresh weave workflows

## Problem

parley.nvim moved to github.com/42shots/parley.nvim (the 42shots move, phase C). sdlc refuses to match records made before the move unless the repository declares its former name (ariadne#644). Separately, CI on weave pins older than ariadne#641 goes red (ariadne#646), so no landing can pass until the seeded workflows are refreshed.

## Spec

One branch, all local-gates config:
1. Add `.sdlc/repository.json` containing exactly `{"former_names": ["github.com/xianxu/parley.nvim"]}`.
2. Run the weave refresh against current ariadne main (past ee3d24ba) to take ariadne#641's seeded workflows (runs-on from `vars.CI_RUNS_ON`). Keep `.sdlc/weave-compiler-ref` unchanged.

The operator verifies with the `local-gates-verified` label, and the TL then sets CI_RUNS_ON.

## Done when

- `.sdlc/repository.json` is on the branch with exactly that content.
- The workflows are regenerated from ariadne main past ee3d24ba, `.sdlc/weave-compiler-ref` is unchanged, and the diff has been inspected.
- The issue is closed, the PR is open, and the PR number has been sent to the hub for the operator's label.

## Plan

- [ ]

## Log

### 2026-10-26
