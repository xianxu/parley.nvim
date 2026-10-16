---
id: 000349
status: done
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T03:39:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.41
tracker:
    version: 1
    completion:
        token: close-8133e82cadaa
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 5f72682db64c82b47452ac2f7dcbde6a1c85a1ab
        evidence_commit: 4602e8c812b8faa90323131d81eb9066fab871c3
        landed_commit: 9d2df08e326b86797cfc85422e756e5bb9a2b7dd
---

# One chat tree walker: exporter, delete-tree and outline derive from chat_tree

## Problem

The chat tree is walked by five copies of the same logic. There are three root-finders that follow `parent_link` upward: `exporter.find_tree_root`, `init.find_tree_root_file` and outline's copy. There are two downward walkers: `exporter.collect_tree` and `init.collect_tree_files`. #233 adds `lua/parley/chat_tree.lua` as the walker for request context; split out of #233 (M2) per the TL.
