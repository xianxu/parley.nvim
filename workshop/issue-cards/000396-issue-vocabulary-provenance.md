---
id: 000396
status: open
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-19T00:29:25-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Repair issue vocabulary provenance

## Problem

Every parley PR merge-check fails during Prepare dependencies and compile composition: apply: preserving authored replacement at construct/generated/vocabulary/issue.json. The hub traced the onset to ariadne#394 (8461dcf1), whose issue.cue adds the flake_tests card field. This blocks #391 and later landings; pair main still passes.
