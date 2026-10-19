---
id: 000393
status: codecomplete
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
github_issue:
started: 2026-10-18T21:11:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.10
tracker:
    version: 1
    completion:
        token: close-b9f5ee50f519
        repository: github.com/xianxu/parley.nvim
        reviewed_head: bccb5aa99d44c54ee946f806bc0487d927a0c56f
        evidence_commit: a3c09e3bf4369efc701235615836c4d34b06ac0e
---

# spelling: the Blink corrections menu is off by default (underlines stay on)

## Problem

The operator does not use the spelling suggestion menu (chat_spell.blink, on by default: after a 180 ms pause on a misspelled word, Blink opens a corrections menu) and asked (2026-10-18) to disable it by default in parley. Underlines (chat_spell.enable) stay on.
