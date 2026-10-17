---
id: 000375
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '713d71b8a61de5009d9f8994a876dfff9e6048fc' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T05:45:26-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "cb30f25a", done: "3a08a598"}
---

# single_source_sweeps fails a direct make test on a quick-flow issue branch with no Core-concepts table

## Problem

`tests/arch/single_source_sweeps_spec.lua` "every symbol the Spec and plan tables name exists in the tree" fails in a direct `make test` on any issue branch whose issue and plan have no Core-concepts table. Every quick-flow issue is like that. The failure reads "no Core-concepts row was selected, so this guard checked nothing" (line 366).

`current_issue_docs()` takes the id from the branch name, so the case runs, finds zero rows and asserts rows > 0. `sdlc`'s suite runs in a detached checkout where the branch name carries no id, so the case goes pending there and the defect never shows at landing. It does show to a worker running `make -k test` on the branch, which is what AGENTS §5 asks for before a close.

Seen on #374's branch (000374-spec-sweep-…), 2026-10-17. #374 adds no Core-concepts table, since it is a quick flow.

## Spec

When the current issue's docs carry no Core-concepts table (a quick-flow issue), the case is pending with that reason rather than failing. The rows > 0 floor still holds once a table header is found, so an emptied table still fails.

## Done when

- `make test` on a quick-flow issue branch passes this case as pending.
- A spec covers the case where the docs exist but have no Core-concepts table.

## Plan

- [x] Extract the Core-concepts parser into a pure `concept_rows(body)`, which returns the count of Status-headed tables and their rows.
- [x] The plan-to-code case goes pending when no doc carries such a table. An emptied table (a header with no rows) still fails.
- [x] Spec: "concept_rows tells a body without a table from an emptied one" (no table, emptied, and full).
- [x] On this quick-flow branch the case is pending, and the file passes 28/0. With the pending branch removed, it fails as reported. luacheck is clean.

## Log

### 2026-10-17
