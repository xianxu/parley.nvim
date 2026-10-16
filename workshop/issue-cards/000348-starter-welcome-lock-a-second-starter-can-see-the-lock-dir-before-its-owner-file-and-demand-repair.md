---
id: 000348
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
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
