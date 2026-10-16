---
id: 000343
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T20:29:03-07:00
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
