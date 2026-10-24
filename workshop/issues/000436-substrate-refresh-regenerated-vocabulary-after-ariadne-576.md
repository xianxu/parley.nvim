---
id: 000436
status: codecomplete
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
card_mirror: '32b71ac65e3784cc7084daf949ba77c56693b1b3' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T21:43:04-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "96ef3248"}
actual_hours: 0.02
---

# substrate refresh: regenerated vocabulary after ariadne#576

## Problem

start-plan's catch-up runs weave refresh, which regenerates construct/generated/vocabulary/issue.json (and its .weave-sha256) from the newer ariadne: scaffold.collaboration_mode is gone. The regenerated output lands as uncommitted tracked changes on the resting branch, so every parley slot's start-plan and abandon refuse until it is on main.

## Spec

## Done when

- main carries the regenerated construct/generated/vocabulary/issue.json and issue.json.weave-sha256 from current ariadne, and start-plan from a fresh resting branch leaves a clean tree.

## Plan

- [x] Carry the two regenerated files onto the issue branch, commit, close (docs-only generated output), land.

## Log

### 2026-10-23
- 2026-10-23: closed — Generated output only: construct/generated/vocabulary/issue.json and its weave-sha256 as weave refresh wrote them against ariadne 500f48f1. Two independent regenerations were byte-identical (cmp), and the diff is one removed key, scaffold.collaboration_mode. After the commit the resting-branch start-plan path is clean: the files no longer differ from what weave writes.; review verdict: SHIP

- Weave refresh against ariadne 500f48f1 regenerated both files on main-slot1, and start-plan refused the dirty tree. Saved them aside, restored, reran start-plan (no catch-up the second time), then copied them back here. No stash was used. The regeneration was byte-identical on both runs (cmp). The only content change is that scaffold.collaboration_mode is dropped.

- Pre-close suite on a703d593 failed one unrelated case, lock_leave_reminder "cancels on window close and ignores a late tick", now registered on #437 with its evidence. Rerunning the suite on this new head.
