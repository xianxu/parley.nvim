---
id: 000353
status: codecomplete
created: 2026-10-16
updated: 2026-10-17
estimate_hours: 4.54
github_issue:
started: 2026-10-16T09:59:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: N/A
tracker:
    version: 1
    completion:
        token: close-9c42e463acae
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 4142a92604182a9b5dfb4bbe35f88416b15f9e12
        evidence_commit: f0e0bce60129614d786d7038ac1bf083a880e7a0
---

# Breadcrumb winbar: the Alt+o / Alt+Shift+O file trail beside a fixed-width lock cell (one bar with #332's renderer)

## Problem

Moving through a tree of documents with Alt+o (into a link) and Alt+Shift+O (back up), the operator loses track of
where they are. Operator design, 2026-10-16 (ops QA `teams/devinfra/qa/xian-xu/2026-10-16-03-breadcrumb-winbar.md`):
show the trail in the winbar, combined with the Couch/parley lock bar. Part of ops project
universal-agent-input-interface.
