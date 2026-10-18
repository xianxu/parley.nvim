---
id: 000385
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '10051facccb5d6d1fc4c0d07bc6c8f90503df64d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T06:48:17-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# side-quest: skill_render dismiss comment names the agent round it keeps

## Problem

## Spec

#383 made the agent's round its own diagnostic kind, cleared only by a confirmed submit, by design (the hub, 2026-10-18). `skill_render.clear_decorations` keeps it, and so does `M.dismiss`, its alias. But the dismiss doc comment still says it dismisses "the live round decorations", which now reads as if it also clears the agent's round. Fix the comment only: dismiss clears the review skill's decorations, and the agent's round stays until the confirmed submit.

## Done when

- The `M.dismiss` doc comment in `lua/parley/skill_render.lua` says it clears the review skill's decorations, and that the agent's round (#383) stays until the next confirmed submit.

## Plan

- [ ]

## Log

### 2026-10-18
