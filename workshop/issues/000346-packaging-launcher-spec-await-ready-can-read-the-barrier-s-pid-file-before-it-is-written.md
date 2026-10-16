---
id: 000346
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '919c72b3596018ec372f8e7f09258c371db9147c' # card fields mirrored from issue-cards; edit via sdlc
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

- `await_ready` waits on the state it needs (a parsed pid), or the barrier publishes the file atomically (write a temp file, then rename), so an empty read cannot return.
- A test reproduces the empty-file read and fails on the old code.

## Plan

- [ ]

## Log

### 2026-10-16
