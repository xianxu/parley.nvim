---
id: 000346
status: done
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: 'ccd5377475d7719cbdaf8db8c5caee2216524eee' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T01:21:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "bedd66df"}
actual_hours: 0.03
---

# packaging_launcher_spec: await_ready can read the barrier's pid file before it is written

## Problem

`tests/integration/packaging_launcher_spec.lua` "installed launcher preserves killed publisher state until explicit recovery" failed once in the #243 merge suite (c5bf604b, 2026-10-16):

```
packaging_launcher_spec.lua:161: bad argument #1 to 'kill' (number expected, got nil)
```

It passed 3 of 3 runs alone. Likely cause, read from the code: the barrier script writes the pid with `vim.fn.writefile({ pid }, TEST_READY)`, which creates the file before writing its bytes. `await_ready()` waits only for `filereadable(ready)`, then returns `tonumber(readfile(ready)[1])`, so it can read the file while it is still empty and return nil. The same `await_ready` gates 4 cases, but only this one uses the pid.

## Spec

## Done when

- [x] `await_ready` waits on the state it needs (a parsed pid), or the barrier publishes the file atomically (write a temp file, then rename), so an empty read cannot return.
- [x] A test reproduces the empty-file read and fails on the old code.

## Plan

- [x] `await_ready` waits on a parseable pid read from the ready file. The
      barrier is unchanged, so the fix is one, at the reader.
- [x] Red first: an empty ready file, with its pid written 100 ms later.

## Log

### 2026-10-16
- 2026-10-16: closed — Red: the new case (an empty ready file, pid written 100 ms later) got nil from the old await_ready. Green: packaging_launcher_spec 11/11 in 6 concurrent runs, luacheck clean. Test-only fix, no architectural surface (no-atlas).; review verdict: SHIP

- Taken by parley.nvim:3. Red: the new case got nil from the old `await_ready`
  (:76, expected 4242). Green: 11/11, in 6 concurrent runs, luacheck clean.
