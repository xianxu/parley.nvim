---
id: 000346
status: working
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T01:21:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
tracker:
    version: 1
---

# packaging_launcher_spec: await_ready can read the barrier's pid file before it is written

## Problem

`tests/integration/packaging_launcher_spec.lua` "installed launcher preserves killed publisher state until explicit recovery" failed once in the #243 merge suite (c5bf604b, 2026-10-16):

```
packaging_launcher_spec.lua:161: bad argument #1 to 'kill' (number expected, got nil)
```

It passed 3 of 3 runs alone. Likely cause, read from the code: the barrier script writes the pid with `vim.fn.writefile({ pid }, TEST_READY)`, which creates the file before writing its bytes. `await_ready()` waits only for `filereadable(ready)`, then returns `tonumber(readfile(ready)[1])`, so it can read the file while it is still empty and return nil. The same `await_ready` gates 4 cases, but only this one uses the pid.
