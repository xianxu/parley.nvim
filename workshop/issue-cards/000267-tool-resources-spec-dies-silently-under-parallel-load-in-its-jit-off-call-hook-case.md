---
id: 000267
status: open
created: 2026-09-18
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T22:17:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# tool_resources_spec dies silently under parallel load in its JIT-off call-hook case

## Problem

`tests/unit/tool_resources_spec.lua` intermittently kills its Neovim process
under parallel load: exit code 1, no failing assertion, output ending right after
"reserves newly freed capacity for older runnable waiters" — i.e. inside the next
case, "bounds pump work for a full queue of maximum-width dependency chains",
which turns the JIT off (`jit.off(); jit.flush()`) and installs a per-call debug
hook around `R.pump`.

Because `make test` runs its phases in sequence, one abort in the unit phase
skips the whole integration phase. It did so twice in four full runs on the
#266 branch, leaving close evidence without integration results.
