---
id: 000405
status: done
created: 2026-10-20
updated: 2026-10-23
estimate_hours: 5.41
github_issue:
started: 2026-10-22T04:55:52-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 14.03
tracker:
    version: 1
    completion:
        token: close-1cd689f8ea69
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 09f68966d0df1563130a9a0d485b30ae21ab6456
        evidence_commit: 6510dc20ee276ebda9ea525025f7af36f0e2a5b8
        landed_commit: 8f1f3bccf898d63e39a32f44c886f577e26e2488
---

# remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch

## Problem

Project remote-session (ops `teams/devinfra/projects/remote-session/`, operator-approved 10-20) makes the phone a
remote view of the live nvim buffer for each hub's session file and side docs. Couch needs to reach the nvim that has
the file open, without the operator starting nvim with special flags.
