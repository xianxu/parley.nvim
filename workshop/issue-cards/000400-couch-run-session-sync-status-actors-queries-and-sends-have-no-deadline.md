---
id: 000400
status: done
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
severity: low
started: 2026-10-19T12:01:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.24
tracker:
    version: 1
    completion:
        token: close-26e112a0e9e4
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 0167f8fadbe8886ac18a06c01d006d0c8f4e8126
        evidence_commit: a203fbd2cbb75b1192c449061dd8d5ffed455876
        landed_commit: 070ed106d7a338b345a1278f52dd6d84ded69102
---

# couch.run: session-sync status/actors queries and sends have no deadline

## Problem

Some `parley.couch.run` callers give the child no deadline. `session_sync.probe` runs `couch --session-sync status --json` and `couch --actors --json` through `couch.query` with no `timeout`, and `couch.send` has none either. If `couch` hangs (a wedged supervisor, a blocked socket), the child and its two stdio pipes stay open for as long as it hangs. The probe's `s.probing` flag also stays set, so probing stops for that buffer. `document_registry` (deadline per operation, #382) and `attention` (`PROBE_TIMEOUT_MS`) already bound theirs. Found during #399 (no leak was measured on this path; this is the unbounded-lifetime gap, not the #399 root cause).
