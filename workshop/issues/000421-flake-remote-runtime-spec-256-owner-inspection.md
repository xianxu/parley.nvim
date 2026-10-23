---
id: 000421
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'd2d93f55f6370ed3ee851a96129dd836d6d3b05b' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T15:07:22-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins]
flow: {kind: quick, provenance: inferred, spec: "75be48b0", done: "a0bbe98b"}
---

# flake: lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins

## Problem

Known flaky tests (#394), registered with same-head fail→pass evidence:

- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.
- lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins: Same exact Git head a63c43605526bec39444f699060047790908366e on nvim0.12.5: focused make test-spec SPEC=modes/remote_session failed these two cases (266PASS/2FAIL/0ERROR, clean census), /Volumes/TestScratch/parley-405-landed-focused-green.log. Follow-up diagnostic make test-spec mapped only the unchanged remote_runtime_spec.lua:44PASS/0FAIL/0ERROR, clean census, /Volumes/TestScratch/parley-405-runtime-diagnostic.log. First case returned runtime deadline despite timeout_ms=arrival.MS; second did not reach fake source read before arrival wait. Native0.11.7 full mapping268PASS on the same head. Evidence is local targeted runs, not recorded-suite or CI evidence. Root cause not yet established; do not increase product deadlines or claim the failing mapping passed.

## Spec

Measured (2026-10-23, nvim 0.12.5, disposable clone; acquire to result / to the first source read):
- Idle: case 1 (256 owners) 525 ms against its 15 s deadline; case 2 (inode change) reaches the fake read in 4 ms against the default 2 s deadline.
- Under capped load (3 CPU spinners plus an fsync dd loop, 10 reps): case 1 288 to 464 ms, case 2 1.3 to 3.6 ms. Neither failed.
- The runtime code is unchanged since the failing head a63c4360. So the 10-22 run needed a filesystem/event-loop stall of at least 15 s spanning both cases (case 1 hit its 15 s deadline; case 2 hit the 2 s default before its first read); the next tests passed. No jetsam or memory-pressure event in the system log for 23:08 to 23:13. The stall's cause is not established and does not reproduce.
- The same family's reproducible flake: under the same load, 1 of 10 reps failed 'gives later listeners a fresh operation budget' with runtime deadline. It injects a 1500 ms fsync delay inside listen's fixed 2000 ms budget, leaving 500 ms for real fsyncs. The two 'shares the acquisition deadline' cases and delayed_acquire (800 ms burned of a 2000 ms acquire) use the same wall-clock margin construction.

Design (test-only; product deadlines unchanged):
- Causal deadline tests: the held fsync callback is released only after the deadline under test has passed (the startup deadline the resource carries; for the fresh budget, the acquisition deadline recorded before the first publication). A regression that uses the wrong budget fails deterministically; no injected delay competes with real IO. delayed_acquire's 800 ms burn goes.
- Tests that do not test a deadline pass timeout_ms=arrival.MS to acquire (await_start's default, and case 2's direct acquire), so a stall shorter than the suite's arrival budget cannot fail them (#370 doctrine). Later listen/stop/close keep their fixed 2000 ms product budgets; those are not injectable and stay as today.

## Done when

- The root cause is fixed (never a retry loop or a longer timeout); closing this issue unregisters the tests.

## Plan

- [x] Rewrite the three margin tests causally (hold fsync until the deadline under test has passed); drop the 800 ms burn.
- [x] await_start and case 2 acquire with timeout_ms=arrival.MS where the deadline is not under test.
- [x] Negative controls: listen reusing the startup deadline for s2, and listen ignoring the startup deadline, each fail their row.
- [x] Both nvim versions; 20 reps under capped load; then the suite.

## Log

### 2026-10-22

### 2026-10-23

- Measured: see Spec. The registered pair's only remaining explanation is a whole-process stall over 15 s with no system-log trace (no jetsam or memory-pressure event 23:08 to 23:13 on 10-22), not reproducible in 10 runs under capped load. Per the TL, close unregisters the pair: if it recurs, the registry rerun shows it and a new issue gets that evidence.
- Fix (tests only, product deadlines unchanged): the two shared-deadline cases hold the durability fsync and release it only after resource.startup_deadline has passed; the fresh-budget case starts s2 only after the startup deadline has passed, with no injected delay. The acquisition budget under test is STARTUP_MS=1000, 1 s below a later listener's fixed 2 s, so a wrong-budget listener visibly outlives it. delayed_acquire's 800 ms burn is gone. Every acquire whose deadline is not under test passes timeout_ms=arrival.MS (await_start's default, await_default, the held-startup cancel, both inspection-change cases, the finalization cases, the child editor).
- Remaining exposure: a shared-deadline case needs acquire plus reaching the held fsync within STARTUP_MS (measured single-digit ms); later listen/stop/close keep their fixed, non-injectable 2 s budgets.
- Negative controls (one at a time in a disposable clone, restored after): C1 listen ignores the startup deadline: both shared-deadline cases fail, nothing else. C2 the startup deadline is never cleared after publication: the fresh-budget case fails, nothing else.
- Verified: remote_runtime_spec 44/0/0 on nvim 0.12.5 and clean on 0.11.7; 20/20 under capped load (3 CPU spinners plus an fsync dd loop, 1500 s cap, trap cleanup). Before the fix the same load failed the fresh-budget case 1 in 10.

- Recorded suite on a462c2c2 (attempt 44226e05): every spec ran; remote_runtime_spec passed; the one failure was the registered #430 flake (editor_endpoint_registry_spec, 'joins an admitted absolute deadline while retaining a possibly published binding'). Resume refused it as unattributable (parley declares no Lua flake runner; #415), so the head advances with this Log entry and the suite reruns.
