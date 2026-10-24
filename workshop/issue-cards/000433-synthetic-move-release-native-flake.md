---
id: 000433
status: wontfix
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline]
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
tracker:
    version: 1
    abandoned: {}
---

# Synthetic move release native test intermittently fails its baseline assertion

## Problem

The native case session-sync native edits releases synthetic move protection only at the unchanged acquisition baseline intermittently fails its embedded assertion at session_sync_native_spec.lua:1415 (fixture Lua line11). This reproduced on pure main, independently of #418's parser-only code.
