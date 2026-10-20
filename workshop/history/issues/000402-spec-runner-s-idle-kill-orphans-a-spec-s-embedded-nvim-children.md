---
id: 000402
status: done
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: '5d08292026d32a290bc9a51d19d2a67ef155df7c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T21:37:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6cf6ecd0", done: "49d8cdf7"}
actual_hours: 0.54
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

- 2026-10-19, close review round 1 (FIX-THEN-SHIP):
  - The plan's red check "without `detach`, the idle case fails" was wrong. That case's grandchild is a `jobstart` job, which the registry kills either way. A new case gives the spec a `vim.system` grandchild, which only the spec child's own group reaches. It's red without `detach`.
  - The spec child's group is now signalled under the same identity guard (`spec_jobs.may_signal`) and the same group-else-pid fallback (`spec_jobs.signal_group`) as each job.
  - A pid no process holds is still signalled, because its group can outlive it and the kernel reuses no pid while the group exists. Only a pid now naming another process is skipped.
  - The TERM, grace, KILL escalation is one function, given its wait.
  - The docs say the wrapper covers `vim.fn.jobstart` only.

## Log

### 2026-10-19
- 2026-10-19: closed — Round-1 fixes in 1be85079. Important: a new case gives the spec a vim.system grandchild that only the spec group reaches; it passes, and fails with detach removed (verified, survivor self-killed). The plan red-check line is corrected under Revisions. Minor: the spec child group uses the same start-time guard (spec_jobs.may_signal: the same process or no holder signals, a reused pid skips and logs) and the group-else-pid fallback as each job; the TERM, grace, KILL escalation is one function given its wait; the docs say only vim.fn.jobstart is wrapped. Earlier evidence holds: the idle, runner SIGTERM and runner SIGINT cases go red without the registry or watchers; the reused-pid unit and live tests go red without the guard. infra/test_harness, modes/session_sync and chat/document green. Full suite recorded via local-check. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

### 2026-10-19 (implementation)

- `proc_pidinfo(PROC_PIDTBSDINFO)` through LuaJIT's FFI gives a start time and pgid on macOS (136-byte struct, checked against the running nvim); Linux reads field 22 of `/proc/<pid>/stat`. No `ps`, which the sandbox denies.
- Red then green: with only the group kill, all three process-group tests failed (the embedded nvim survived). With the registry, they pass: the idle deadline, the runner's SIGTERM, and the runner's SIGINT.
- Red checks:
  - Without the identity match, the reused-pid tests fail, both the unit test and the live-process one.
  - Without the runner's signal watchers, both runner-killed tests fail.
- Every case SIGKILLs any surviving embedded child itself, so no red run left a spinner.
- Targeted runs green: `infra/test_harness`, `modes/session_sync`, `chat/document`.
- Stress respected the hub's cap: each case runs at most four nvims at once.
- Round-1 fixes verified: the new `vim.system`-grandchild case passes, and fails with `detach` removed (its cleanup killed the survivor). `infra/test_harness` green.

