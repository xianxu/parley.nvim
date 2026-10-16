---
id: 000348
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '4b5fe513a991000c043648c94ad23ef4f93e9ef8' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T02:14:02-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "af7551fb", done: "e9782999"}
actual_hours: 0.22
---

# starter welcome lock: a second starter can see the lock dir before its owner file and demand repair

## Problem

`tests/integration/starter_config_spec.lua` "isolated starter runtime waits for
another welcome creator and reopens its sole chat" failed once in a full suite
on the #345 branch (a3777a50, 2026-10-16). It then passed alone 3 times out of 3. Neither
`lua/parley/starter.lua` nor this spec changed on that branch. Failure (line 180):

```
starter.lua:102: Welcome initialization requires repair. Close all Parley instances,
remove …/state/parley/welcome-initializer, and retry.
Expected 0, got 1 (the second starter's exit code)
```

Suspected cause, from reading `welcome()` in lua/parley/starter.lua: the owner
takes the lock with `uv.fs_mkdir(lock)` and writes `lock/owner` afterwards. A
second starter that loses the mkdir and reads the lock between the two steps finds a
directory with no owner file, so `pid` is nil and it raises "requires repair",
although the owner is alive and about to write its pid. Suite load widens that
window. Not verified. Reproduce it first, for example by delaying the owner write
in the spec's hold hook.

## Spec

Two windows, not one. The owner `mkdir`ed the lock and wrote `owner` afterwards,
and cleanup's `vim.fn.delete(lock, 'rf')` removed `owner` before the
directory. The failing case is the second window: the waiter polls every
100 ms while the first starter is held after its owner write.

The lock is now complete or absent to a waiter:
- `take_lock` writes the owner record into an `fs_mkdtemp` staging directory and
  `fs_rename`s it to the lock; a loser's rename fails on the non-empty lock.
- `retire_lock` renames the lock to a unique retired name, then deletes that.
- A waiter's missed read counts as garbage only if the same lock (inode and
  device) is still there afterwards, since an owner can retire it between reads.

## Core concepts

| Concept | Meaning |
|---|---|
| `take_lock` | publishes the lock by renaming a staging dir that already holds the owner record |
| `retire_lock` | renames the lock away before deleting it |

## Done when

- [x] The race is reproduced deterministically (or the suspected cause is disproved, with a measurement).
- [x] A live owner that has not yet written its pid is waited for, not reported as needing repair. The dead-owner and garbage-lock repair paths still raise.
- [x] The case passes under a loaded full suite.

## Plan

- [x] `take_lock` and `retire_lock` in `lua/parley/starter.lua`; the waiter re-checks the lock's identity.
- [x] Red first: `STARTER_OWNER_GATE` and `STARTER_RETIRE_GATE` hooks in `tests/packaging/starter_launch.lua`, and two spec cases.
- [x] Atlas: `infra/starter.md` recovery notes.

## Log

### 2026-10-16
- 2026-10-16: closed — Red: owner/retire gate cases fail on old code with requires repair. BR-1: STARTER_READ_GATE case; a mutation removing the identity re-check fails it. starter_config_spec 22/22, earlier 21/21 in 6 concurrent runs; other starter specs pass; luacheck clean.; review verdict: SHIP

- Taken by parley.nvim:3. Red: both gate cases failed on the old code with
  "requires repair" at :196, deterministically. Green: starter_config_spec
  21/21, and 21/21 in each of 6 concurrent runs. The other starter specs pass
  (1, 4, 20, 6, 7, 7). luacheck clean. Added in self-review: the waiter re-checks
  the lock's identity, because an owner retiring it between the waiter's reads
  is not garbage.
- Close review round 1, BR-1 (Important): the waiter's identity re-check had no
  test. Added `STARTER_READ_GATE`: the waiter pauses between finding the lock
  and reading its owner while the owner retires it. A mutation with the re-check
  removed fails that case. Minor: the gate case names now say the second
  starter is not stopped (under rename it takes its own turn), and the atlas
  notes the empty-lock takeover and the mixed-version case. 22/22.
