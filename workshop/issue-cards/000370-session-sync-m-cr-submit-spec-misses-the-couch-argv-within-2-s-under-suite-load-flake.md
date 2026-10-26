---
id: 000370
status: done
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T02:49:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.09
tracker:
    version: 1
    completion:
        token: close-720425fb5e4e
        repository: github.com/xianxu/parley.nvim
        reviewed_head: d0d574ff658a3cf5a0f513957cd91564857f72dd
        evidence_commit: 8c3f8e03bbfadfdfc17d0fc4f7ff3d467ab983d0
        landed_commit: 186894acdf9e68286a1ddada2609cc5877c104fd
kind: bug
---

# session_sync M-CR submit spec misses the couch argv within 2 s under suite load (flake)

## Problem

`tests/integration/session_sync_spec.lua` failed once in a full suite: "session-sync buffer <M-CR> saves, deletes the lock, leaves the buffer editable and sends one couch message (#315)", at line 205. `vim.wait(2000, …)` for the fake couch's argv file returned -1 (a timeout): the submit's couch call didn't record its argv within 2 s.

- First seen: 2026-10-16 23:57, during #360's full suite on head b824c4695487fed80b979bbdd177368ec40edd79. That branch changes only `tests/helpers/ready_port.lua` and four cliproxy specs, nothing on the session-sync path.
- The run passed 457 other spec files with lint clean; this was its only failure.
- Retained log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/ce404b3086f731fa89502659bcac6231.log`.
- Three same-head focused runs of the spec passed 63/63 each.
