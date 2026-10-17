---
id: 000375
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '6a367e4358a56a6ad0f831aa46c487dc5f37c431' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-17
