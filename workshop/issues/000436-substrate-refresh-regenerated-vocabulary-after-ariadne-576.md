---
id: 000436
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
card_mirror: '6aee38301fe49a58644bedbd4f4ea213428b47ed' # card fields mirrored from issue-cards; edit via sdlc
---

# substrate refresh: regenerated vocabulary after ariadne#576

## Problem

start-plan's catch-up runs weave refresh, which regenerates construct/generated/vocabulary/issue.json (and its .weave-sha256) from the newer ariadne: scaffold.collaboration_mode is gone. The regenerated output lands as uncommitted tracked changes on the resting branch, so every parley slot's start-plan and abandon refuse until it is on main.

## Spec

## Done when

- main carries the regenerated construct/generated/vocabulary/issue.json and issue.json.weave-sha256 from current ariadne, and start-plan from a fresh resting branch leaves a clean tree.

## Plan

- [ ] Carry the two regenerated files onto the issue branch, commit, close (docs-only generated output), land.

## Log

### 2026-10-23
