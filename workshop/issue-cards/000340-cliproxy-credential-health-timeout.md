---
id: 000340
status: codecomplete
created: 2026-10-15
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-15T23:44:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.40
tracker:
    version: 1
    completion:
        token: close-d71f7ffe0632
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 0c2547f885692b5335c041c7f82c76114c3e3372
        evidence_commit: 0d0bed342e862a1e397be319d4f80b838acb5d1a
---

# Credential-health persistent-404 test times out in the required suite

## Problem

The required suite for #332 completed every recipe but failed one unchanged cliproxy lifecycle case. First seen 2026-10-15 in run acebcf70a6676a7e2e96ef8c6624e95a, on pushed code b5de7d2b4c3d336679135d016baeb58654f262aa. This is independent of the agentic document changes and should be fixed from main.
