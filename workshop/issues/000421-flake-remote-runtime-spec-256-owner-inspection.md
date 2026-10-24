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
- [x] #430 (revision): gate both absolute-deadline cases on the fake's held publication; controls S (slow startup) and J (no join).
- [x] Root cause (revision 2): deadline timers through helper.start_deadline; blocked-loop regressions; arch lint; controls R1, R2.
- [x] 20 reps under capped load (endpoint, remote_process, remote_runtime, lint); remote_session mapping.
- [x] One suite.

## Revisions

- 2026-10-23, TL-approved scope revision: fold #430 into #421. Three recorded suites on this branch failed only on #430's cases (a fixed 200 ms absolute deadline racing real Python startup and publication), and parley cannot resume past a registered Lua flake (#415). Same family, same technique. Delta: hold the absolute-deadline timer in editor_endpoint_registry_spec and fire it only after the fake has published and holds its acknowledgment (a new PATH.held marker from fake_couch_editor.py) and the deadline has really passed. This covers both #430 cases (line 199, and the :204 teardown). Negative controls, 20 reps under load, one suite; close #430 with #421 and unregister its cases.
- 2026-10-23, TL-approved: the registered pair's root cause is a product bug, superseding the Spec's "stall, cause not established". remote_runtime's transaction armed its hrtime deadline with raw timer:start, and libuv measures that from the loop's cached clock. After synchronous work (case 1 seeds 256 directories; case 2 follows case 1's synchronous delete of them), a loaded disk leaves that clock stale by more than the budget, so the deadline fired at once. Delta: remote_runtime.lua and remote_process.lua (the only other hrtime-deadline timer) arm through helper.start_deadline (#382), with one blocked-loop regression per site and a tests/arch lint (deadline_timer_spec) refusing a raw deadline-timer start. Deadline values are unchanged. UI debounce and periodic timers stay as they are; a stale clock only makes one of their ticks early.

## Log

### 2026-10-22

### 2026-10-23

- Measured: see Spec. The registered pair's only remaining explanation is a whole-process stall over 15 s with no system-log trace (no jetsam or memory-pressure event 23:08 to 23:13 on 10-22), not reproducible in 10 runs under capped load. Per the TL, close unregisters the pair: if it recurs, the registry rerun shows it and a new issue gets that evidence.
- Fix (tests only, product deadlines unchanged): the two shared-deadline cases hold the durability fsync and release it only after resource.startup_deadline has passed; the fresh-budget case starts s2 only after the startup deadline has passed, with no injected delay. The acquisition budget under test is STARTUP_MS=1000, 1 s below a later listener's fixed 2 s, so a wrong-budget listener visibly outlives it. delayed_acquire's 800 ms burn is gone. Every acquire whose deadline is not under test passes timeout_ms=arrival.MS (await_start's default, await_default, the held-startup cancel, both inspection-change cases, the finalization cases, the child editor).
- Remaining exposure: a shared-deadline case needs acquire plus reaching the held fsync within STARTUP_MS (measured single-digit ms); later listen/stop/close keep their fixed, non-injectable 2 s budgets.
- Negative controls (one at a time in a disposable clone, restored after): C1 listen ignores the startup deadline: both shared-deadline cases fail, nothing else. C2 the startup deadline is never cleared after publication: the fresh-budget case fails, nothing else.
- Verified: remote_runtime_spec 44/0/0 on nvim 0.12.5 and clean on 0.11.7; 20/20 under capped load (3 CPU spinners plus an fsync dd loop, 1500 s cap, trap cleanup). Before the fix the same load failed the fresh-budget case 1 in 10.

- Recorded suite on a462c2c2 (attempt 44226e05): every spec ran; remote_runtime_spec passed; the one failure was the registered #430 flake (editor_endpoint_registry_spec, 'joins an admitted absolute deadline while retaining a possibly published binding'). Resume refused it as unattributable (parley declares no Lua flake runner; #415), so the head advances with this Log entry and the suite reruns.
- Correction to the first 2026-10-23 entry: the "whole-process stall" explanation was wrong. With editor_endpoint_registry_spec mapped first, the 256-owner case failed 5 of 20 under capped load (0 of 30 with remote_runtime_spec alone). One timed failure returned runtime deadline 0.35 ms after acquire, against a 15 s budget: the timer had fired from libuv's stale cached clock (see Revisions). The registered pair is unregistered at close because the root cause is fixed.
- #430 fold: fake_couch_editor.py writes PATH.held (published, acknowledgment held); both absolute-deadline cases hold the deadline timer through the helper.start_deadline seam and fire it only once .held exists and the deadline has really passed. Controls in the clone: S (fake sleeps 0.5 s before its PID write): the old spec reproduces both registered shapes (line 199 failure plus the describe-level teardown error), the new spec passes 12/12. J (expiry finishes without joining the child): both cases fail, plus the fixed-deadline join case.
- Root-cause controls: R1 (remote_runtime back to raw timer:start): its blocked-loop case and the lint fail, nothing else. R2 (remote_process likewise): its blocked-loop case and the lint fail, nothing else.
- Verified idle on nvim 0.12.5 and 0.11.7: deadline_timer_spec 1/0/0, editor_endpoint_registry_spec 12/0/0, remote_process_spec 20/0/0, remote_runtime_spec 45/0/0.

- First 20-rep load run of the four specs after the root-cause fix: 19/20; the failure was my fresh-budget case at STARTUP_MS=1000. Its acquire plus s1's full publication (about six real fsyncs) overran 1 s under the fsync load. Wrong-budget detection there does not depend on the budget's size, so that case now acquires with 3*STARTUP_MS; C2 still fails it. The shared-deadline cases keep 1 s, which keeps C1 deterministic against a later listener's fixed 2 s; they reach their hold after two to four fsyncs.
- Second 20-rep load run: 19/20. The failure was a third race in the same fake: 'joins a canceled running request' polls registry.json.editor-pid until it is readable, then reads it, but write_text creates the file before writing it, so the PID read back nil. fake_couch_editor.py now writes editor-pid, editor-argv and .held through a per-process temp file and os.replace. A first version shared one temp name, and the four concurrent children in occupy_slots then crashed on each other's replace (8 failures in the remote_session mapping); per-process names fixed that. The launches log stays append-only: short single writes read whole.
- remote_session mapping (all reply-gate users): 278/0/0 on nvim 0.12.5 and 0.11.7.
- Third 20-rep load run on the final code (deadline_timer, editor_endpoint_registry, remote_process, remote_runtime specs; 3 CPU spinners plus an fsync dd loop, 2400 s cap, trap cleanup): 20/20.
- Recorded suite on bbe93c63 (attempt 36c10d10): every spec ran; the one failure was session_sync_native 'undo releases acquisition baseline, redo retakes: watch autosave=true' at :1593 ('Remote view unavailable'), the #427 signature. It passed 4/4 in targeted runs on unchanged session-sync code; registered onto #427 per the flake rule. The head advances with this entry for the rerun.
