---
id: 000448
status: codecomplete
deps: []
github_issue:
created: 2026-10-26
updated: 2026-10-26
estimate_hours:
card_mirror: '89d951468a2507e1147bf6a73c31af4b4b6aece5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-26T11:00:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/42shots/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "ea281263", done: "677b4229"}
actual_hours: N/A
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
- 2026-10-26: closed — repo move (42shots phase C). .sdlc/repository.json declares former name github.com/xianxu/parley.nvim; construct/deps points at 42shots/ariadne (TL-approved); weave refresh --substrate against ariadne 2e1114ec (past ee3d24ba) seeded merge-check + local-gates-guard byte-identical to ariadne main; TL-run weave compile regenerated issue vocabulary (sha256 sidecar matches) and the side-doc gitignore entry; settings.json unchanged; weave-compiler-ref unchanged. Full suite pass recorded as sdlc-local/suite on ebc189af (6m36s). --no-atlas: local-gates config only, no parley surface.; review verdict: SHIP

### 2026-10-26
- TL approved changing construct/deps to the 42shots URL. The refresh's origin check compares the rewritten (insteadOf) origin, while acquire.checkExisting compares the raw configured origin. Repointed the slot-private ariadne clone's origin to 42shots, which satisfies both checks; the TL is filing the weave follow-up.
- weave refresh --substrate advanced slot ariadne b9452c63→2e1114ec; seeded merge-check/local-gates-guard applied byte-identical to ariadne main (54d0042b); weave-compiler-ref unchanged.
- Compile aborted writing .claude/settings.json (sandbox-protected, untracked). Generators did not run, so construct/generated/vocabulary/issue.json may be stale (issue.cue changed upstream). Asked the hub how to proceed.
