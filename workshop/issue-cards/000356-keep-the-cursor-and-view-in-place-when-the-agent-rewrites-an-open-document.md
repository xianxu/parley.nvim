---
id: 000356
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T11:10:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Keep the cursor and view in place when the agent rewrites an open document

## Problem

When the agent writes a document the operator has open, the reload makes the cursor jump. That covers the session file, QA files and any agentic document. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.
