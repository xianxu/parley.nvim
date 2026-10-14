---
id: 000326
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '8083f61ce3efd86eb05a73a0af5e42f78f9c28f0' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T09:57:13-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "574d76e4", done: "92bf68d1"}
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

- [ ] Confirm stale vocabulary with make -k check-vocabulary, regenerate through weave compile, and verify parity (ARCH-DRY).
- [ ] Explain cold-checkout ownership versus live upstream generation in Log; file the upstream class fix without changing CI gates here (ARCH-SECURE/PURPOSE).
- [ ] Run pushed-head suite, close review, publish/merge through SDLC and verify main merge-check green.

## Log

### 2026-10-14

- Hub reprioritized #326 ahead of #325. Started from main 62a35b2aeb4a849cee910062a35ea02f0b5dba29, using private Ariadne 407e48a39057503fab7cdecaf6c69ce338ce7631.
- Before regeneration, make -k check-vocabulary fails: issue vocabulary content drift. Current delta is the actual_hours setter adding sdlc issue correct-actual, beyond the earlier #348 category additions already present in this main.
