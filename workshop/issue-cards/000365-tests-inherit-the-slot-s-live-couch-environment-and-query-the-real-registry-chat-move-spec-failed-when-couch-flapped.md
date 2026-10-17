---
id: 000365
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: high
started: 2026-10-16T17:17:24-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.95
tracker:
    version: 1
    completion:
        token: close-23d65da0c10d
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2999bfba8d35a68d1436e301cc63b61e76ed2f65
        evidence_commit: 0676b17ad605bde0270e880dbebfb1233c736286
---

# Tests inherit the slot's live Couch environment and query the real registry (chat_move_spec failed when Couch flapped)

## Problem

The test suite inherits the running slot's live Couch environment: `COUCH_THREAD_SCOPE`, `COUCH_THREAD_TAG`, `COUCH_STORE_DIR` and `COUCH_ISOLATED_ROOT`. `couch.thread()` then returns a real thread, `agentic_document`'s `namespace()` is non-nil, and every spec that moves or opens a markdown file without its own fake asks the REAL `couch --session-sync` registry. Only `tests/helpers/sidecars.lua` scrubs these variables, and only around its own cases.

Seen on 2026-10-16: `sdlc local-check run --name suite` on #358's 7ff97e39 failed three `chat_move_spec` cases at `:206`, with `move_chat_tree` returning "Invalid registry response". The non-timestamped child goes through `move_membership`'s registry lookup, and the live `couch` was flapping then (the CLI was briefly "command not found"). The spec passes alone, and on main the failure depends only on Couch's health. Log: `~/workspace/parley.nvim/.git/sdlc/test-stats/failed/c4be4a46c8f79f0408c42b10abcd1ed2.log`.

This is worse than a flake. A spec that moves a document the live registry knows can mutate it, by rename or register, and results depend on the operator's real registry state.
