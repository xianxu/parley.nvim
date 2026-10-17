---
id: 000375
status: done
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T05:45:26-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.57
tracker:
    version: 1
    completion:
        token: close-618c109da165
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 847a807c5ffd5ede0730be6f61e19484927db9db
        evidence_commit: 624e8586c111dc1654ebc5e2d88da2abdc73371a
        landed_commit: 61d16c2093801ff39f03d87ea91ec1f0177de0f5
---

# single_source_sweeps fails a direct make test on a quick-flow issue branch with no Core-concepts table

## Problem

`tests/arch/single_source_sweeps_spec.lua` "every symbol the Spec and plan tables name exists in the tree" fails in a direct `make test` on any issue branch whose issue and plan have no Core-concepts table. Every quick-flow issue is like that. The failure reads "no Core-concepts row was selected, so this guard checked nothing" (line 366).

`current_issue_docs()` takes the id from the branch name, so the case runs, finds zero rows and asserts rows > 0. `sdlc`'s suite runs in a detached checkout where the branch name carries no id, so the case goes pending there and the defect never shows at landing. It does show to a worker running `make -k test` on the branch, which is what AGENTS §5 asks for before a close.

Seen on #374's branch (000374-spec-sweep-…), 2026-10-17. #374 adds no Core-concepts table, since it is a quick flow.
