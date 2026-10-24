---
id: 000436
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
card_mirror: '33ffbdd185a2a8dcde1c4fefcb2fa7172b955d66' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T21:43:04-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- Weave refresh against ariadne 500f48f1 regenerated both files on main-slot1, and start-plan refused the dirty tree. Saved them aside, restored, reran start-plan (no catch-up the second time), then copied them back here. No stash was used. The regeneration was byte-identical on both runs (cmp). The only content change is that scaffold.collaboration_mode is dropped.
