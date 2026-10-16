---
id: 000345
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '873389301284629eec9329beab4904b1c1bd6432' # card fields mirrored from issue-cards; edit via sdlc
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

## Spec

Make the restart path's listener read asynchronous (a `vim.system` callback), so
the wait no longer blocks the main loop, and keep #340's contract:
- release is confirmed by the signalled pids exiting AND no listener being left;
- a leftover listener, or a read that fails, falls back to the probe;
- a proxy still answering at the deadline is reported (#237 BR-8).

Decide at planning: whether `stop()`'s synchronous identity probe and lsof move too.
`stop()` is public and returns a count to `:ParleyProxy stop`. An async variant for
the restart path, with the sync command kept, is one option.

## Done when

- [ ] No synchronous lsof (or curl) runs on the main loop in an exit-confirmed restart, or each one that remains is named and justified in ## Log.
- [ ] A test proves the main loop stays responsive during the listener read, e.g. a deferred tick fires while a slow fake lsof runs.
- [ ] #340's regressions (the stall window, the peer left on the port) still pass, with the full suite.

## Plan

- [ ]

## Log

### 2026-10-16
