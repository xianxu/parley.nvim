---
id: 000344
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '37864511d850cd92030051fe041860b91dfeaecb' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T00:15:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "d45ae54a"}
---

# help-parley omits the make goldens and make perf-finder targets

## Problem

`make help-parley` does not list the `make goldens` and `make perf-finder` targets that #342 added (an advisory Minor from #342's close review).

## Spec

## Done when

- [x] `make help-parley` lists `make goldens` and `make perf-finder`, each with a one-line description.

## Plan

- [x] Add the two lines to `help-parley` in `Makefile.parley`.

## Log

### 2026-10-16

- `make help-parley` now prints `make perf-finder` after `make perf`, and `make goldens` after `make fixtures`. No spec covers the help text.
