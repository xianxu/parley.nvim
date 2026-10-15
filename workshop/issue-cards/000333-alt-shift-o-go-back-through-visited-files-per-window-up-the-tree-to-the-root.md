---
id: 000333
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T11:08:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Alt+Shift+O: go back through visited files (per window), up the tree to the root

## Problem

The universal-agent-input-interface project (ops `teams/devinfra/projects/universal-agent-input-interface/`) turns
markdown files into a connected tree: the session file → an answer or side doc → a link inside it → … The operator
navigates down with Alt+o (parley#327) and needs to come back **up the tree, file by file, to the root** (e.g. the
session file). `Ctrl-o` walks every cursor position, so it takes many presses per file; `Ctrl-^` toggles only between
two files; `:bp` follows buffer-list order, not visit order.
