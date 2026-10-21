---
id: 000408
status: open
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
github_issue:
started: 2026-10-21T12:06:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# session-sync: fence insert admission and reload after lock acquisition

## Problem

Follow-up to #404, requested by the operator through the hub (Couch 61805ff7-ac98-4fcf-9a32-9a8215d5b878). #404 takes a local sidecar lock on InsertEnter, but samples mtime before acquisition and defers reconciliation; the current native race test expects a clobbered copy and preserves the old buffer. A queued first edit can therefore apply before freshness is reconciled.
