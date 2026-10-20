---
id: 000402
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: '119e66969113431ec1f7f60ed24a6792dfc3ba14' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T21:37:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6cf6ecd0", done: "49d8cdf7"}
---

# spec_runner's idle kill orphans a spec's embedded nvim children

## Problem

`tests/helpers/spec_runner.lua` ends a stalled or expired spec by sending SIGTERM to the spec child it started (`child:kill(15)` on its `vim.system` handle). It doesn't signal the child's process group. An embedded nvim that the spec started (`tests/helpers/embedded_nvim.lua`, `--clean --embed`) survives: its parent dies, it's reparented to pid 1, and a child spinning in Lua never reads its closed stdin. On 2026-10-19 three such children, started 18:36–18:55, spun at 100% CPU each for about 2.7 hours, ignored SIGTERM, and drove machine load to 130 until the hub SIGKILLed them. The source was #401's red check, which ran a wedged-child fixture through the runner with the idle-budget handoff removed.

Confirmed red: a fixture spec starts an embedded child, writes its pid, and runs `while true do end` in it. Its `REQUEST_MS` is 600000, so only the runner's idle kill can end it. Through `Runner.execute` (3 s budget) the case ends `stalled`, and the child's pid is still alive afterwards.

## Spec

The runner ends the whole tree it started: run the spec child as its own process-group leader, and on a deadline (and on any unobserved exit) signal the group, TERM then KILL, so no embedded or other grandchild outlives it. `embedded_nvim` children inherit the group.

## Done when

- The red test passes: after the runner's idle kill, the embedded child's pid is gone. The test SIGKILLs any survivor itself, so a red run never leaves a spinner.
- A spec that ends normally is unaffected: its children are still reaped by its own teardown.

## Plan

Measured (2026-10-19), with an nvim that starts a detached `sh` whose `sleep` grandchild records its pid:
- A libuv signal watcher installed in an nvim runs on SIGTERM and SIGINT before nvim's own deadly-signal exit. With a watcher that signals the child's group, the grandchild is gone; with no watcher, it's alive (both signals).
- A spinning nvim never returns to its event loop, so it ignores SIGTERM (the three the hub killed). A group therefore gets SIGKILL after a short grace.
- `vim.system{detach = true}` passes `detached` to `uv.spawn` on both runtimes, so the child becomes a process-group leader (pgid = pid) and keeps its pipes.

Steps:
- [x] `spec_runner.execute` starts the spec child with `detach = true`, so the child and everything it starts (embedded nvims inherit the group) form one group the runner owns.
- [x] On the deadline, and when the child's exit isn't observed: SIGTERM to the group, a grace of `GRACE_MS` (1 s) for the child to exit, then SIGKILL to the group. Survivors are killed even if the leader exits on TERM.
- [x] While a spec runs, the runner watches its own SIGTERM and SIGINT. On either, it sends TERM to the group, sleeps `GRACE_MS`, then sends KILL, and nvim's own handling then ends the runner. The watchers close when `execute` returns.
- [x] Tests in `spec_runner_native_spec`, each recording the embedded pid through a file and SIGKILLing any survivor itself:
  - Idle kill: a fixture spins an embedded child that only the runner can end; after `execute` reports `stalled`, the child is gone.
  - Runner killed: an outer nvim runs `execute` on the same fixture; the test sends it SIGTERM, then (in a second case) SIGINT, and the embedded child is gone.
  - Red checks: without `detach`, the idle case fails; without the watchers, the runner-killed cases fail.
- At most 4 test processes at once (the hub's cap); each case uses three.

## Revisions

- 2026-10-19, design delta 1 (approved by the hub): the red tests failed against the group kill. Measured: Neovim's `jobstart` starts every job in its own process group (pgid = the job's pid) on both runtimes, out of reach of a signal to the spec child's group.
  - Kept: `detach` for `vim.system` and `uv.spawn` descendants.
  - Added: a per-spec `jobstart` registry, installed from one place (`tests/minimal_init.vim`) in spec children only. It records each job's pid with its start time.
  - The runner signals a recorded job's group only while the start time still matches; a reused pid is skipped and logged. The hub's guard, with its own test.

## Log

### 2026-10-19

### 2026-10-19 (implementation)

- `proc_pidinfo(PROC_PIDTBSDINFO)` through LuaJIT's FFI gives a start time and pgid on macOS (136-byte struct, checked against the running nvim); Linux reads field 22 of `/proc/<pid>/stat`. No `ps`, which the sandbox denies.
- Red then green: with only the group kill, all three process-group tests failed (the embedded nvim survived). With the registry, they pass: the idle deadline, the runner's SIGTERM, and the runner's SIGINT.
- Red checks:
  - Without the identity match, the reused-pid tests fail, both the unit test and the live-process one.
  - Without the runner's signal watchers, both runner-killed tests fail.
- Every case SIGKILLs any surviving embedded child itself, so no red run left a spinner.
- Targeted runs green: `infra/test_harness`, `modes/session_sync`, `chat/document`.
- Stress respected the hub's cap: each case runs at most four nvims at once.

