---
id: 000367
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T19:46:30-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.30
tracker:
    version: 1
    completion:
        token: close-80fd3d7ed830
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 5cc88a00812ee8fc93ff67982226cbc540291717
        evidence_commit: 5f498f3ed74a0d00c0dac91e4a70da979a8a0f02
---

# Attention finder: an agent rewrite of a seen or retired side doc brings it back as answered

## Problem

#354's attention finder lists side docs the agent wrote as "answered, not yet seen" until the operator looks. Once seen, or once swept and retired, a side doc stays gone even when the agent writes to it again. Operator decision (TL, on #354): an agent write to a side doc after the operator last saw it brings it back as answered, the same as any other entry the agent answers. The operator's own edits do not. A retired entry stays retired only until the next agent write.
