---
id: 000392
status: done
created: 2026-10-18
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-18T20:51:22-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.48
tracker:
    version: 1
    completion:
        token: close-6197bc1424ef
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2302826c8848bb0eac245f1009d759112adb9d5d
        evidence_commit: 6d811d540394adbaa1d5233a91c954f7ca885aac
        landed_commit: 7041bccd208dbfff3f7144194ac26e641f99dda2
kind: feature
---

# attention finder opens on the oldest unread entry

## Problem

The attention finder (Alt+Space) opens with the cursor at the top of the list (since #390's tree layout). The operator (2026-10-18): "attention finder upon open, should focus on oldest unread item": the cursor should land where the next thing to read is.
