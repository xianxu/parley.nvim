---
id: 000431
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '922188ffb7293c2baaaaf6fda6ee1c66edc913bf' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-new/before-restore (#404), lua:tests/integration/session_sync_native_spec.lua#session-sync native edits detaches without unlocking and preserves user option overrides]
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "736a12ff", done: "63bf4436"}
---

# Native release-journal test intermittently loses its setup lock

## Problem

The native session-sync test retained release journal respects current intent at after-new/before-restore (#404) intermittently cannot open status.md.lock while setting up its asserted journal/intent state. The original error is line1238, Error executing lua: io.open/assert: No such file or directory. This is a separate case from the8-turn release failure being classified for #418.

## Spec

Identify whether fixture setup races a valid clean release or production loses required protection, then correct the owning event/order. Keep the before-restore current-intent protection invariant and the normal native adapter; do not replace it with a longer fixed sleep or weaker existence assertion.

## Done when

- Each folded case (#431's journal and pre-detach cases, #433, #437) has a causal reproduction that fails without the fix and passes with it; those cases are unregistered, and #433 and #437 close with this issue. #432 split back out (Revision 2).
- No vim.system call that passes a timeout can run on a stale loop clock: one helper refreshes it, and a tests/arch lint refuses a raw one.
- The original missing-lock ordering has deterministic reproduction coverage.
- The native journal/intent setup proves its required lock and the test exercises the intended production transition.
- All current-intent journal variants pass on both supported Neovim runtimes, including repeated native qualification.

## Plan

- [x] Causal reproduction per case: loop_clock.block before the acquire or release in each failing ordering (#431 journal setup and pre-detach payload, #432 eight-turn release, #433 synthetic-move baseline, #437 lock-reminder window close). Separately, measure the fake's operator-acquire latency under capped load (4 procs) to tell a stale-clock early kill from a real 500 ms overrun.
- [x] Fix the class (ARCH-PURPOSE, ARCH-DRY): one helper.system that refreshes the loop clock before vim.system, used by every call that passes vim.system a timeout (couch.run, couch.operator_lock, issue_tracker git, clipboard_image, cliproxy lsof probe, remote_process ps). If the overrun is real, operator_lock gets our own deadline started through helper.start_deadline instead of vim.system's timer.
- [x] tests/arch lint: refuse a vim.system call that passes a timeout outside helper.lua.
- [x] One regression per case ordering; negative controls reverting the fix; fixtures not testing the budget use arrival.MS.
- [ ] Both nvims (0.11.7, 0.12.5); 20 reps under capped load; then the suite. Unregister the four cases and close #432, #433 and #437 with this issue.
- [x] Keep the standalone Neovim repro (vim.system timeout after a blocked loop) for a possible upstream report.

## Log

2026-10-23: independent discovery in TL-authorized #418 failure classification, not a #418 code change. Exact pure-main head28526aa8eefe4da49b28bac04456f56e564ecaf2, Neovim0.11.7, full targeted tests/integration/session_sync_native_spec.lua with original before_each/assertions/after_each: runs1/2/3 all144 pass; run4 has143pass/1fail in this case; run5 all144 pass again on unchanged code. All censuses clean, no source edits, artificial load or changed timeouts. The original8-turn case passed every one of these runs; do not conflate the cases.

Evidence /Volumes/TestScratch/parley-418-native-ltjs_uc3/main-full-4.log plus main-full-1.log through main-full-5.log, full-results.json and run-full.py. Main/integrated session_sync implementation and this test file are byte-identical. The failing excerpt is: session-sync native edits retained release journal respects current intent at after-new/before-restore (#404); tests/integration/session_sync_native_spec.lua:1238; embedded_nvim.exec line61; fixture Lua line8 cannot open status.md.lock. Same-head run5 is the clean pass after failure. Filed unclaimed for repair; no work on it is stacked into #418.

### 2026-10-23 — separate pre-detach setup observation, association unproven

During #322's recorded full suite on b9135976daa17a4a2986cb1fd1b8e02fd4708e9d, compatibility Neovim0.11.7 fails a different exact case: session-sync native edits detaches without unlocking and preserves user option overrides. The failure is line983 locked()->payload line30: expected complete status.md.lock payload, observed nil, before detach executes. Native file143pass/1fail; all remaining suite tests finished with clean censuses. The same suite also hits the independently registered #430 startup case. Official suite attempt2f462d85c36ec3d495801235b68a6e90 remains unattributable-failure,5m35s, log SHA256 prefixbad51e771dcc in .git/sdlc/test-stats/failed/2f462d85c36ec3d495801235b68a6e90.log.

TLd28a162c authorized exactly10 isolated executions of this original native case on basec50641e7c54bc648d0e3e2b5c3e7ab398343c25f and10 on the tested branch, no whole-spec repeat. Results: base10pass/0fail/0error, branch10pass/0fail/0error;0/20 failures. Each run proves one exact original case, original setup/teardown once, before/after process census and terminal clean. Both detached source trees remained clean at pinned heads. Source test and session_sync implementation are byte-identical across the heads. These samples do not establish base intermittency, a cause, or the same cause as the original release-journal observation. Retain them as an explicitly unproven association in this repair issue, not a production diagnosis.

Evidence /Volumes/TestScratch/parley-322-detach.wFHlYs/{HARNESS.md,summary.json,results.json,commands.json,metadata.json,run.py} and20 rawlogs. Copied36 evidence files outside RAM scratch to .git/sdlc/diagnostics/322-detach-classification. Original full failure remains separate from targeted passes. TL84474907 explicitly authorizes registration of the exact new case as an unreproduced exception (same policy as #432), followed by one full #322 retry; do not infer classification from an incidental later pass. No product or test-source correction is made under #322. This issue stays unclaimed for its owning repair work.

### 2026-10-23 — root-cause hypothesis and standalone Neovim repro (parley.nvim:1)

- Neovim's vim.system arms its timeout with a raw uv timer right after the synchronous spawn (runtime lua/vim/_system.lua:265, timer_oneshot, no update_time). libuv measures that timer from the cached loop clock. Measured standalone (`nvim --clean --headless -l vimsystem_stale.lua`): after a 1200 ms busy-block of the loop, vim.system({'sleep','0.2'},{timeout=500}):wait() returns code 124 (killed) after 0.9 ms on 0.11.7 and after 1.6 ms on 0.12.5. Calling uv.update_time() right before the spawn gives code 0 at about 207 ms. vim.wait and a bare :wait(N) are unaffected (they measured 528 ms for a 500 ms wait after the same block).
- couch.operator_lock is exactly that call: vim.system(couch operator-acquire/release, timeout 500):wait(500). An early kill means acquire or release is not confirmed, which matches every failing case: a missing status.md.lock in setup and a nil lock payload (#431), a clean release not observed (#432), a baseline assertion after acquire (#433), and a turn never taken so no pulse (#437).

### 2026-10-23 — reproduction, fix and measurements (parley.nvim:1)

- Real overrun ruled out: operator-acquire plus operator-release through tests/fixtures/fake_couch_operator.py, 80 calls each, took p50 29 ms / max 31 ms quiet and p50 32 ms / p95 39 ms / max 49 ms under 3 CPU spinners plus an fsync dd loop. None came near 500 ms. The cause is the stale-clock early kill alone, so operator_lock keeps vim.system's timeout, now measured from a refreshed clock.
- Class fix (ARCH-PURPOSE): helper.system refreshes the loop clock and calls vim.system. Every call that passes a timeout uses it: couch.run (which carries attention and the registry transport), couch.operator_lock, issue_tracker git, clipboard_image, the cliproxy lsof probe, the remote_process ps batch, fd_watchdog (found by the new lint) and image_shrink (it forwards its caller's options). tests/arch/deadline_timer_spec.lua refuses a raw vim.system with a `timeout =` field near it, or one forwarding an options variable. tests/arch/spawn_seam_spec.lua counts calls through helper.system at their own call sites, so its census is unchanged.
- Regressions, each blocking the loop 1200 ms right before the call: couch_spec (operator_lock's child exits normally); lock_leave_reminder (#437: the turn is taken and the pulse comes); native #431 pre-detach acquire; native #431 journal at after-new/before-restore; native #433 synthetic-move release. In the native child, stall_next_lock wraps couch.operator_lock with a one-shot block.
- Negative control (helper.system without the refresh, in a disposable clone): all five fail. Alternating native-spec runs in that clone: reverted 3 of 3 failed exactly the three native regressions; fixed 3 of 3 passed.
- #432 does not fit. With the stall before its Esc release, the release comes back unavailable (vim.system reports 124 once its timer has fired), yet the lock is removed within the wait, so this mechanism does not produce #432's retained lock. Its regression was dropped and the case stays registered on #432 (Revision 2).
- The #427 notice, identified on the side: in native fixtures the outside-pane registry lookup gets 'Invalid registry response' (the fake exits 2 with no FAKE_COUCH_REGISTRY), about 100 ms after open, and posts 'Remote view unavailable' asynchronously. Whether an undo/redo case's notifications == {} assertion sees it is a race. Two green session_sync mapping runs hit it five times (four of those in one run), the clone's three fixed native-only runs never did, and the earlier red mapping run did not. Reported to the TL for #427, not fixed here.
- Standalone Neovim repro, for a possible upstream report (vim.system's timeout counts time the loop spent blocked before the spawn); run with `nvim --clean --headless -l repro.lua`:

```lua
local uv = vim.uv
local function block(ms) local t = uv.hrtime() while (uv.hrtime() - t) / 1e6 < ms do end end
uv.update_time(); block(1200)
local t0 = uv.hrtime()
local r = vim.system({ "sleep", "0.2" }, { timeout = 500 }):wait()
print(r.code, r.signal, (uv.hrtime() - t0) / 1e6) -- 124 15 ~1ms on 0.11.7 and 0.12.5; 0 0 ~205 with update_time() before the spawn
```

### 2026-10-24 — load reps (parley.nvim:1)

- 20 reps per Neovim of the native spec, lock_leave_reminder and couch_spec (disposable clone, 3 CPU spinners plus an fsync dd loop, hard-capped, trap cleanup): each of the five regressions passed 40 of 40, on 0.11.7 and 0.12.5. Every failing rep failed only #427's undo/redo cases (once also #404 BR-1's Ctrl-C case): 11 of 20 reps on 0.11.7, 14 of 20 on 0.12.5.
- That #427 rate is load, not this fix. A sequential red run (helper.system without the refresh) looked lower on 0.11.7 (1 of 8), but the machine's load differed between the runs (load average 29 from other slots). Alternating red and green under the same load, 6 pairs on 0.11.7: red failed #427 cases in 3 of 6 reps (12 case failures), green in 3 of 6 (9).

## Revisions

### 2026-10-23 — fold #432, #433 and #437 (TL approved)

- Reason: same hypothesized cause, a native lock acquire or release through couch.operator_lock killed by vim.system's stale-clock timeout. Delta: this issue carries all four cases, and fixes the vim.system timeout class across its six call sites, with a lint. A case whose causal reproduction shows a different cause splits back out to its own issue.

### 2026-10-23 — #432 splits back out

- Reason: its causal reproduction shows a different outcome (lock removed, not retained), so the TL's split rule applies. Delta: #432's case stays registered on #432 and is not closed here; Done when names the three folded issues' cases only.
