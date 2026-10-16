---
id: 000351
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T07:20:42-07:00
tracker:
    version: 1
    release:
        by:
            operator: Xian Xu
            machine: 4716879978a7b90f6b583da1716fd0e9
            machine_name: MacBook Pro
            workspace: parley.nvim:4
            worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            repository: github.com/xianxu/parley.nvim
---

# Retry transient provider errors (429, 529/overloaded, 5xx) with bounded backoff

## Problem

parley has no retry for transient provider errors. A 429 (rate limit), 529 or
`overloaded_error` (Anthropic), or a 5xx ends the request at once as a
failure. Measured during #242's inventory (2026-10-16): the only restart in
`lua/parley/dispatcher.lua` is cliproxyapi's `adapter.recover_query`, which runs
once on `attempt == 0` and only for auth-class errors (`dispatcher.lua:810-844`).
No 429/overloaded path exists anywhere in `lua/`.

#242 tests HTTP errors as surfaced failures carrying the API's message. Retrying
them is a feature, and was split out here by TL decision.
