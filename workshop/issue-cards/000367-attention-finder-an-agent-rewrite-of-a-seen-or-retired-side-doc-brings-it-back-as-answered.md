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
actual_hours: 0.27
tracker:
    version: 1
    completion:
        token: close-bfb8f84726c0
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 108f5a7f689d16d3c2e9e999867538e577c3eba6
        evidence_commit: d30cd73a121928fd772c642f1e709a4121884262
---

# Attention finder: an agent rewrite of a seen or retired side doc brings it back as answered

## Problem

#354's attention finder lists side docs the agent wrote as "answered, not yet seen" until the operator looks. Once seen, or once swept and retired, a side doc stays gone even when the agent writes to it again. Operator decision (TL, on #354): an agent write to a side doc after the operator last saw it brings it back as answered, the same as any other entry the agent answers. The operator's own edits do not. A retired entry stays retired only until the next agent write.
