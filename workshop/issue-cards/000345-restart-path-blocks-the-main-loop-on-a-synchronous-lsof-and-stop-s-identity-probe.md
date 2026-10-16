---
id: 000345
status: working
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T01:01:31-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Restart path blocks the main loop on a synchronous lsof (and stop's identity probe)

## Problem

#340 (PR #254) made an exit-confirmed restart read the port's listeners before
spawning the replacement: `wait_port_released`'s `exit_poll` calls
`pids_on_port(port)` (lua/parley/cliproxy.lua, near line 519). That is a synchronous
`vim.system({ "lsof", … }):wait()` on the main loop. Under the suite-shaped
8-parallel load it took about 1 s (the #340 harness max rose from 917 ms to 1557 ms
with it), and the editor is frozen for that time. That is once per restart:
`:ParleyProxy restart`, update, the credential-health repair and the recovery
ladder's restart rung. The close review recorded it as an advisory
(sync-io-on-main-loop-poll, ARCH-CONSTRAINTS); the TL asked for it as its own issue.

The same path also blocks in `stop()`: `port_holds_cliproxy` is a synchronous curl
probe (up to `--max-time` 2 s), followed by a synchronous `pids_on_port`.
