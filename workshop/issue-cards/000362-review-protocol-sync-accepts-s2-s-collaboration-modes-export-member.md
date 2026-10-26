---
id: 000362
status: done
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-16T16:04:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 6.98
tracker:
    version: 1
    completion:
        token: close-310b594e5597
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 8be9bfde97b0618704bcdd4c035550c30bea6791
        evidence_commit: bf4bf6058ed9f56ba737ce8c8e30909b084288e0
        landed_commit: 6ea6fc8b7853625c407629637627291faf7de0bd
kind: feature
---

# Review-protocol sync accepts S2's collaboration-modes export member

## Problem

S2 M1 (ops `universal-agent-input-interface/design.side/01-s2-section-modes.md`, db130ac0) adds a member to ariadne's universal-review `export.json`, still version 1: role `collaboration-modes`, path `collaboration-modes.md`. #319's `scripts/sync-review-protocol.py` is strict and refuses any role outside {round, grammar, adapter, mode} ("invalid member role"). So the next sync after ariadne:2 lands M1 fails until parley accepts the role.
