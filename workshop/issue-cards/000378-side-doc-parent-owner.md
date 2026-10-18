---
id: 000378
status: codecomplete
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T14:45:11-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.69
tracker:
    version: 1
    completion:
        token: close-74c71ed14eed
        repository: github.com/xianxu/parley.nvim
        reviewed_head: d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb
        evidence_commit: 3b391eb6e5891c28850b471c34db865e61c7f16f
---

# Side documents inherit parent ownership

## Problem

Alt+o opens a side document from a registered parent but does not register the child with the parent's effective owner. The navigation therefore loses the ownership relationship; a later submit can instead select the current pane's actor.

Found during #373's required registration audit, independently of moving files.
