---
id: 000257
status: done
created: 2026-09-15
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T09:10:43-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.77
tracker:
    version: 1
    completion:
        token: close-2f08040461b3
        repository: github.com/xianxu/parley.nvim
        reviewed_head: d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1
        evidence_commit: e8e61009947995de02eda19fe5681979012f00d9
        landed_commit: e366f6a6b10a2a81c15c5422b880b933bc2a15f0
kind: feature
---

# Advance cursor to the next question after submission

## Problem

Submitting a question starts asynchronous response work but leaves the cursor on
the submitted exchange. This makes the normal workflow—submit question 1, then
write or submit question 2—require a manual jump through the transcript.
