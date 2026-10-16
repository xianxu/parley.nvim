---
id: 000343
status: done
created: 2026-10-15
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-15T20:29:03-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.24
tracker:
    version: 1
    completion:
        token: close-3af99495e17c
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 10db2bcdc144b82f823a01f020d0e2e0e2fbcff0
        evidence_commit: d3a9efd7527e868abdec6ce5d098854d4d26e142
        landed_commit: be9e449b798f3e75882a16c1ffcacb6d77693eaf
---

# cliproxy_update_spec: 'old proxy outlives the restart' races the fake's 4 s exit delay under load

## Problem

`tests/integration/cliproxy_update_spec.lua` "does not reuse an old proxy that
outlives the restart, and says so" failed once in a full `make test` on the #204
branch (1ba9af6f, 2026-10-15). It then passed alone, in 3 parallel runs, and in
the next full suite. Failure:

```
cliproxy_update_spec.lua:494: Expected objects to be the same.
Passed in: { [2] = 'down' }
Expected:  { [1] = '9.9.4' }
```

The case keeps the old fake serving for a wall-clock `PARLEY_FAKE_EXIT_DELAY_MS
= 4000` after SIGTERM, and then asserts the old proxy STILL answers at the end.
Between the SIGTERM and that final `version_probe` come restart_managed's 2 s
port wait, the update's install and the message, and they can take longer than
4 s on a loaded machine. The old fake exits, the probe reads `down`, and the
assertion fails. Likely root cause: the exit delay is an absolute wall-clock
window the case races, not a state the case controls (cf. #337 lesson BR-1:
control the timing inputs a deadline assertion depends on).

Sibling: the lifecycle restart-timing flake is #340.
