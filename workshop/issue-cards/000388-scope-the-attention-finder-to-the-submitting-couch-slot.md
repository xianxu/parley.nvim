---
id: 000388
status: done
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
started: 2026-10-18T12:01:44-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.21
tracker:
    version: 1
    completion:
        token: close-c2ced4118c48
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 8bd03ed0d49c1f3d2c037d83523134dc0e344487
        evidence_commit: 14c224b06e424558ad333bc1ff5063e385efda65
        landed_commit: 735b922bc48b04b8745372d4763669a72ac0f9b5
kind: feature
---

# Scope the attention finder to the submitting Couch slot

## Problem

Every editor shares attention.json, so a Couch pane currently lists submits made from other slots.
