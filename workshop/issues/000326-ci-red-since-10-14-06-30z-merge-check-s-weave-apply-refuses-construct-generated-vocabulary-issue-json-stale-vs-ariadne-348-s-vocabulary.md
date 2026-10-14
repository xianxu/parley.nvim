---
id: 000326
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '680cb8c981a057afd6686b23cfe90b39dd83bcc4' # card fields mirrored from issue-cards; edit via sdlc
---

# CI red since 10-14 06:30Z: merge-check's weave apply refuses construct/generated/vocabulary/issue.json (stale vs ariadne#348's vocabulary)

## Problem

parley.nvim's `merge-check` workflow has failed on every push to main since 2026-10-14 06:30Z (last success); the operator is getting the failure emails. Each run ends: `Error: apply: preserving authored replacement at /home/runner/work/parley.nvim/parley.nvim/construct/generated/vocabulary/issue.json` after `weave: … make tools`. CI checks out current ariadne main, whose issue vocabulary changed with ariadne#348 (areas/severity, landed 10-13 night), so the regenerated `issue.json` differs from parley's committed copy and weave treats the committed copy as an authored edit. pair and ariadne CI are green.

## Spec

Regenerate parley's `construct/generated/` from current ariadne main (weave refresh/compile on a clean resting branch) and land the regenerated files. Then answer the class question in the issue Log: why does a generated file committed in a consumer repo look 'authored' to weave whenever ariadne's vocabulary moves, and should ariadne#348-style vocabulary changes regenerate consumers (or should CI pin ariadne to the consumer's recorded substrate commit)? File an ariadne issue for the class fix if one is needed.

## Done when

- parley.nvim main's merge-check is green again.
- The class question has an answer in the Log, and an ariadne issue if a change is needed.

## Plan

- [ ]

## Log

### 2026-10-14
