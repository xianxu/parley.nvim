---
id: 000398
status: codecomplete
created: 2026-10-19
updated: 2026-10-20
estimate_hours:
github_issue:
started: 2026-10-19T21:32:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.63
tracker:
    version: 1
    completion:
        token: close-4aad5233bf20
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 1c11c82768b3a0b8aae34ba504ec62f39ede8c71
        evidence_commit: f90168b4877cc1f509766316b9a7fd43b38e3ab9
---

# CI: build weave from a pinned ariadne commit

## Problem

ariadne#459 reproduced the cold generated-vocabulary failure in published weave
0.1.0, before ariadne#422's shipped-output sidecar ownership. This repository's
active GitHub main merge-check installs the published formula without an exact
source pin. Verified 2026-10-19 against [the exact workflow blob](https://api.github.com/repos/xianxu/parley.nvim/git/blobs/91cfc2012e8f61ff8cfac85b2e7159e0c085711e).
