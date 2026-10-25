---
id: 000441
status: codecomplete
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
started: 2026-10-24T14:26:28-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.24
tracker:
    version: 1
    completion:
        token: close-50cb5ad0d82c
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 475638abdc2bd0cb6de83318df9720a9bfb1572e
        evidence_commit: 84fa9c04c4fafdf802b86fe917d5b0ad2dc96a87
---

# Standalone review: forced tool choice rejected by claude-sonnet-5-5; expose upstream failure reason

## Problem

During parley.nvim#419's operator acceptance on 2026-10-24, standalone review in a plain-terminal Neovim failed twice (10:40:15 and 10:40:24), while inside-Couch review passed. The existing skill request forces a named tool, which claude-sonnet-5-5 rejects through CLIProxy API 8.0.12. This request construction is unchanged on main; TL b532446a classified it as a separate pre-existing defect.

Both upstream responses are HTTP 400, invalid_request_error, with the exact message:

`tool_choice: type "tool" and "any" are not supported for this model.`

The requests reached the local `/v1/messages` endpoint and upstream provider; the 142-byte rejection is not a missing credential or endpoint failure. The transport-error callback fires before the proposal/deferral validator. The operator saw `review: unchanged :messages` and `Parley.nvim: skill review transport error`, which hide the actionable upstream reason.
