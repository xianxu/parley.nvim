---
id: 000406
status: codecomplete
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
github_issue:
started: 2026-10-20T21:34:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.13
tracker:
    version: 1
    completion:
        token: close-c498addd0e16
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 790a2dbdd6de6d878cfe6816d5521bdcfdae1919
        evidence_commit: 5fd69d52f47b6abad1e76b9d1c5409b23572bd2c
---

# MarkdownPreview throws 'Cannot read properties of undefined (reading refreshPage)' on session.md and side docs

## Problem

On 10-20 at 21:33 the operator's MarkdownPreview stopped working on the hub session file and side docs (in
`~/workspace/ops/session.md` and `session.side/*.md`), with the error in the nvim message line:
`TypeError: Cannot read properties of undefined (reading 'refreshPage')`. Screenshot:
`ops/assets/session/2026-10-20.21-33-40.545.png`. Those files are written frequently from outside nvim (Couch
session-sync writes by the TL), and they moved today from `teams/devinfra/tl-status-*.md` to the repo root
(`session.md`, `session.side/`, ariadne#504). parley.nvim also had several landings today.
