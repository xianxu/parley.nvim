---
id: 000340
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'af21ff4c8fd71344670571388dc762da8a45dea4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T23:44:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d29b3132", done: "d73583ba"}
---

# Credential-health persistent-404 test times out in the required suite

## Problem

The required suite for #332 completed every recipe but failed one unchanged cliproxy lifecycle case. First seen 2026-10-15 in run acebcf70a6676a7e2e96ef8c6624e95a, on pushed code b5de7d2b4c3d336679135d016baeb58654f262aa. This is independent of the agentic document changes and should be fixed from main.

## Spec

Investigate tests/integration/cliproxy_lifecycle_spec.lua, credential_health case “does not restart twice — a persistent 404 is reported, not looped”. Its first await at line 778 exceeded the shared 8000 ms case budget, failing tests/helpers/await.lua:30 with “async call timed out”. Distinguish a short budget from a lost callback or fixture teardown race. Preserve the single-restart/persistent-404 contract; derive any budget change from the actual repair path rather than increasing it blindly. Use controlled scheduling/fixture completion so the cause is reproducible.

## Done when

- The persistent-404 case deterministically proves one restart attempt, reports unknown after failed restart, and leaves the second keyless proxy alive.
- A controlled regression reproduces the observed cause and passes after the fix, with explicit callback completion or a derived budget covering the real bounded path.
- Focused lifecycle and the required suite pass, with no weakened assertions, skips or blind deadline increase.

## Plan

Measured 2026-10-16. The scratch harness wraps cliproxy's stages and runs 8 copies in parallel, like the suite's 8 jobs; the CPU burners did NOT reproduce it.
The slow stage is the "is the old proxy down?" detection after `stop()`. Each slow case shows TWO
health probes of about 2,020 ms, one in `wait_port_released` and one in `ensure_running`'s
reuse check. Each ends in curl exit 28 with `time_connect=0`, and a raw libuv connect from the same
nvim is also still pending 4 s later. The SYN to the just-closed port gets neither a SYN-ACK nor a
reset, although `kill(pid, 0)` already reports the old pid gone. So "down" is learned only from
`--max-time`, twice: about 4 s of an 8 s await before the respawn even starts. Plain Python
(burst connects, killed listeners, the real fake killed 8-way, curl as the client) is always
refused within 30 ms, so the kernel-level reason is not pinned (`netstat` is denied in the
sandbox). The fix does not depend on it.

Fix: wait on actual state, the exit of the processes `stop()` signalled, never a longer deadline.

- [x] `M.stop()` also returns the pids it signalled (the count stays the first return).
- [x] `wait_port_released` polls those pids' liveness (`uv.kill(pid, 0)`) and calls released the moment all have exited, with no port probe. At `PORT_RELEASE_MS` it probes once, so a proxy still answering is reported as before (#237 BR-8). With no pids it falls back to today's probe loop.
- [x] After a release confirmed by exit, `restart_managed` spawns directly through the extracted down-branch of `ensure_running` (`start_managed`), skipping the reuse probe that can stall the same way (ARCH-DRY: one spawn path).
- [x] Regression test: wrap `health_probe` to answer `down` only after a 3 s stall, emulating the dropped SYN. Assert that a restart of an exited proxy makes NO probe between the kill and the spawn, and that both credential_health cases pass under the stall.
- [x] The REPAIR BUDGET table is still an upper bound: the fallback path is unchanged.

## Log


- 2026-10-16: closed — Full suite green on 0e240eea (sdlc-local/suite, main merged). Measured cause: under 8-parallel load, probes of the just-killed proxy port reached down only by curl max-time, about 2 s each, twice per repair, while kill(pid,0) already reported the process gone. Fix: wait on the signalled pids exiting, then spawn without a reuse probe; the deadline probe fallback is unchanged. 8-parallel harness after the fix: 72 awaits, median 338 ms, max 917 ms (before: max 4470 ms). Regression: a probe in the stop-to-spawn window answers down after 5 s; the repair must make 0 window probes. Mutation: probe-only release fails 3 cases; with the direct spawn removed, 2 fail. update, command, dispatch, conformance, auth_login and budget specs are green.; review verdict: SHIP
- First seen 2026-10-15 in #332 PR241. Code b5de7d2b4c3d336679135d016baeb58654f262aa; this file and production cliproxy code are unchanged by #332. The previous #337 full suite passed this file. Current suite: 442 passed spec files, one failed; this file 53 successful cases/1 failure/0 errors in 64 s. Full run took 3m11s after a 2043 s machine-cap queue; all recipes finished, no surviving test processes. Earlier #336/#337 failures passed in this run.
- Full retained log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/acebcf70a6676a7e2e96ef8c6624e95a.log; SHA256 e330d2ee07a369850bc8d6bb9233559fa4b86a510c95acd6cef89e06672a5548. Local status sdlc-local/suite is failure on the exact code head. A single focused same-code reproduction is pending; no clean full-suite or live acceptance is claimed.
- 2026-10-16 (parley.nvim:4): measurement and fix, as in ## Plan.
  - With the fix, the 8-parallel scratch harness ran 72 awaits: median 338 ms, max 917 ms (before: max 4470 ms). The slowest probe was 110 ms, and none timed out.
  - The regression emulates the measured window: a probe between stop() and the next spawn() (or a re-bound listener) answers "down" after 5 s.
  - Mutation: with the pids ignored (probe-only release), 3 cases fail. With the direct spawn removed, both credential_health cases fail.
  - Unchanged and green: cliproxy_update_spec ("old proxy outlives the restart" still takes the probe-at-deadline path), command, dispatch, conformance, auth_login and budget specs.
  - Coordinated with parley.nvim:3 (#343): this branch does not touch fake_cliproxy's signal handling.

