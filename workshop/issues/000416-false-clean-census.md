---
id: 000416
status: codecomplete
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours: 2.68
collaboration-mode: collaboration
card_mirror: '51807bcab9fec54bc033f4974a1d0bab75022304' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T16:14:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
actual_hours: 1.88
---

# Test census reports clean while an orphaned embedded Neovim survives

## Problem

A completed targeted #405 native test run reported `clean: no surviving test processes` while an embedded Neovim from that exact run remained alive for about six hours, orphaned under PID 1. A clean census is currently capable of giving false assurance.

Related: #409, the test-lease and orphan-reaper work that protects active targeted runs. This is the complementary false-negative case: a completed run's survivor must be detected without touching a live or foreign run.

## Spec

Investigate why the census missed the surviving embedded editor from the 2026-10-22 08:55 #405 red run. Make the run's cleanup and terminal census agree about owned process lifetime: a surviving owned child cannot produce a clean result. Preserve #409's exact run/lease ownership and active-run protections; do not broaden cleanup into an unproven PID or process-group sweep.

Evidence observed on 2026-10-22 around 14:57–14:58 America/Los_Angeles:

- PID 69636, native start time `Thu Oct 22 08:55:00 2026`, PPID 1; exact executable `/opt/homebrew/Cellar/neovim/0.12.5_1/bin/nvim`, argv `--clean --embed --headless -i NONE`.
- Working directory `/Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim`; stdin/stdout/stderr all `/dev/null`.
- `lsof` showed an open temporary directory and Unix socket under `/Volumes/TestScratch/parley-405-runtime-fixture-red/tmp/nvim.xianxu/LFa2op/`, socket `nvim.69636.0`. This identifies the completed historical run, not the individual test case.
- Run log `/Volumes/TestScratch/parley-405-runtime-fixture-red.log` exercised `tests/arch/embedded_rpc_spec.lua`, `tests/integration/embedded_nvim_spec.lua`, `tests/integration/remote_runtime_fixture_spec.lua` and `tests/integration/remote_runtime_spec.lua`. The fixture/default-getter red assertions failed, and the run exited nonzero, but its final census still printed `clean: no surviving test processes`.
- After rechecking the exact PID/start/PPID/argv/cwd, SIGTERM failed to end it within five seconds. The same identity was checked again, SIGKILL sent to that PID only, and native `ps` then confirmed absence. No process group, other PID or runtime directory was removed.

The leaked run predates the later #405 fixture and parent/child cleanup changes. Establish whether those changes address the escape and whether the independent terminal census still has the blind spot; do not claim the historical leak is reproduced by current code without evidence. The individual leaking case is presently unknown.

## Done when

- A deterministic native regression creates a run-owned embedded child that survives its caller and ignores TERM, and proves the terminal census cannot report clean while that exact process remains alive.
- The root cause of the historical false clean result is documented; cleanup observes joined death or reports an explicit surviving/unknown outcome and fails the run.
- Active targeted-run, foreign-process, PID-reuse and uncertain-ownership controls preserve #409's protection contract; no cleanup claims success from a signal alone.
- The affected regression and ownership controls pass on Neovim 0.12.5 and the supported 0.11.7 compatibility runtime.

## Plan

- [x] Implement the approved design in [the durable plan](../plans/000416-false-clean-census-plan.md), with native red/green coverage before changing cleanup.
- [x] Verify exact ownership, observed death, refusal paths, both supported runtimes, and #409 serialization; prepare the corrected pushed head for recorded suite and close review.

## Revisions

### 2026-10-22 — proposed design after native false-clean reproduction

Extend the existing spec-job birth ledger through the terminal census, scoped to the existing checkout lease. Retain PID plus native start identity; join exact children on every runner return and let the independent census verify retained records. Unknown observations fail visibly and preserve evidence. See the durable plan for the state table, alternatives and bounds. This is proposed to the TL; implementation has not started.

## Log

### 2026-10-22 — filed unclaimed at the TL's request
- 2026-10-22: closed — Recorded suite attempt 2860f355bbfcb10eb13f3286c4489019 failed only the generated-readiness arrival guard on old code; this reproducible branch defect is corrected by passing arrival.MS by value and adding the existing guard to the harness mapping. Guard (2 cases) plus native census (6 cases) pass on Neovim 0.12.5 and 0.11.7; changed-file luacheck and diff checks pass. Authenticated TL delivery 449567de-e97e-430a-bf38-92d7935a6287 explicitly defers the new suite and merge until tomorrow after maintenance; stopped the queued merge, no active checks remain, exact restart step logged. (fixed-then-ship); review verdict: SHIP
- 2026-10-22: closed — Round 3 disposed all capacity-family findings and confirmed 6 native lifecycle, 7 policy, 19 registry and 9 scope cases on Neovim 0.12.5 and 0.11.7, including counterfactual RED. New BR-4 fixture-alias regression failed before canonical base correction; all 27 lease tests now pass with physical TMPDIR=/Volumes/TestScratch and aliased TMPDIR=/tmp, including explicit scratch-symlink subprocess coverage of context/ownership and legacy census. Python census 15 and lint 829 files previously pass; final diff clean. Single final-code recorded suite queued on this pushed head; actual pass required before landing.; review verdict: SHIP

Historical survivor reported by ops:0, attributed through native process identity and its open run-specific socket by parley.nvim:1, and removed after exact revalidation. #405 records this incident at commit 36027746. This issue tracks the false clean census separately; no fix or new reproduction is claimed here.


### 2026-10-22 — investigation and proposed plan

Claimed and started on main-based branch `000416-false-clean-census`. The selector requires the checkout's `tests/` substring before considering any process, so the historical bare embedded command is categorically invisible. Current `spec_runner.execute` deletes the per-spec jobs directory after an ordinary exit without reconciling recorded jobs; `embedded_nvim.stop` ignores its wait result. #405's unlanded branch adds on-exit/join proof for fixture deletion but leaves the independent census classifier blind. Its exact historical leaking test remains unknown; no claim is made that the same test still leaks.

A disposable native probe on Neovim 0.12.5 spawned the historical exact argv, sent an RPC that published readiness then spun, and let its launcher exit. Native ps observed PID 48080 with PPID 1; TERM left it alive. The current signal-free census on that real captured snapshot returned 0 and `clean: no surviving test processes`. The probe's finally block sent KILL only to its own created child. Evidence: `/Volumes/TestScratch/parley416-census-d93c83gn/{owner.py,ps.txt,ready}`. Regression must record the new PID/start at birth rather than treating these historical numbers as authority.

`start-plan` refreshed the base and encountered ariadne#557's generated workflow change. Saved its exact diff to `/Volumes/TestScratch/parley416-seeded-jnnx_p97/merge-check.patch`, restored only that seeded file, then reran start-plan successfully. The separate pre-#409 named stash remains untouched. ARCH-DRY motivates reusing the existing native identity reader and spec-job ledger; ARCH-PURPOSE requires an independent terminal check, not only a nicer stop helper.


### 2026-10-22 — approval, coordination and plan-quality refinement

TL approval delivery 68e17798-f625-46d7-bd8c-956b912807d2 permits the retained registry under this checkout with explicit bounds/pruning. Parley.nvim:1 confirmed #405 owns Child on_exit/joined fixture cleanup, not spec_jobs/spec_runner/identity/census; preserve callbacks exactly once and install recording explicitly in clean embedded children. Neither branch stacks; whichever lands second integrates main. Full-flow plan-quality was explicitly requested because the scripts/native bridge exceed the quick shell. Round 1 raised PQ-1 (spawn-before-publication crash window) and PQ-2 (function-level test strategy); the plan now specifies durable pending tickets before spawn and names each risky function with an adversarial strategy. Both exact Neovim 0.12.5 and installed 0.11.7 runtimes are available. No implementation has started.


## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. Calibration is tagged stale by sdlc, so provisional. Two focused Lua components cover retained registry/native observation and runner/census integration; the shell context is a cross-cutting refactor, with docs and one close review. Existing LuaJIT native reader, libuv, JSON, make and flock provide the substrate; no novel external library is required. Thorough approved plan discounts the midpoint Lua design (2h) to 0.4h per component; impl uses the upper 1.5h x 40% = 0.6h per component. Familiarity is 1.0 and thorough-plan design buffer 15%.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: cross-cutting-refactor design=0.1 impl=0.2
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 2.68
```


### 2026-10-22 — retained ownership implemented; focused verification

Full change-code passed: plan-quality has no open findings (PQ-1/PQ-2 addressed); estimate-quality INFO accepted the model but noted optimistic integration/verification coverage. Those checks are included in the two Lua integration components and the existing close-review allocation; measured actual will resolve the calibration.

Implemented checkout-local `.test-processes/run-*` context reuse under the validated descriptor; strict context checks and owned empty-directory pruning are covered by 25 direct lease tests (all pass, 14.659s). The delegated policy's seven tests pass. Shared native reconciliation now consumes durable pre-spawn pending tickets, atomically published PID/start records, and old jobs ledgers. Unknown/corrupt evidence stays; exact PID effects require an immediately matching native identity and records retire only after observed original-incarnation death plus unchanged evidence bytes. The terminal Python census requires positive completion from the same native Lua verifier before printing clean.

Five native regressions pass: ordinary-success detached leak, independent terminal orphan/TERM resistance with a same-argv foreign control and signal-free snapshot, launcher death inside birth publication, clean embedded grandchild recording, and callback/fast-child ownership. The callback test first failed because an already-reaped native job was treated as an unconfirmed birth; the wrapper now chains on_exit once, recognizes joined death, and installs once. Storage regressions first caught dropped future JSON nulls, retirement of replaced birth bytes, and writable-directory admission; all fifteen registry tests now pass after correcting those classes. Native/policy/registry run log `/tmp/parley416-storage-green.log`; original native RED `/tmp/parley416-native-red.log`; callback RED/GREEN `/tmp/parley416-callback-{red,green}.log`. Python predicate/observation tests: 14 pass, including a silent exit-zero observer that must remain unknown. Focused Lua lint and diff checks pass.

The first broad mapped harness run correctly failed the new JSON-null check and the existing embedded-RPC architecture guard. Native probes now use the central Embedded helper's optional detach and notification support, keeping the guard intact; no guard exception was added. Parley.nvim:1 was informed of these small helper additions so its #405 native on_exit/joined fixture cleanup remains authoritative when either branch integrates main.

Next: finish broad mapped tests on preferred 0.12.5 and affected regressions on installed 0.11.7, check retained-tree allocation/pruning bounds and late-publication controls, then push and queue one recorded suite before close. No full-suite result for #416 exists yet; no close/PR/landing claimed.


### 2026-10-22 — two-runtime verification checkpoint

`make test-spec SPEC=infra/test_harness` passed after the storage fixes and central-helper probe wiring; final census verified/clean. Log `/tmp/parley416-harness-fixed.log`. The affected lifecycle mapping (architecture guard, embedded helper, native spec runner, fixture reaper, registry and Python/lease controls) also passed with `PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim` (Neovim 0.11.7), log `/tmp/parley416-compat.log`. `make lint`: zero warnings/errors across 828 files; standalone Lua verifier lint also clean.

A final native-width regression first showed that persisted out-of-pid_t identifiers could reach observation/retirement. Native identity and record decoding now share a signed-32-bit `MAX_PID` boundary, including legacy job reads, preventing C argument wrap. The complete focused map then passed on both exact runtimes: 6 native lifecycle cases, 7 pure policy cases, 18 registry cases; logs `/tmp/parley416-final-focused.log` (0.12.5) and `/tmp/parley416-final-compat.log` (0.11.7). Registry coverage includes generated future structures/null/empty-container preservation, changed evidence before unlink, late scopes during cleanup, explicit absence, refusal and counted linear probes. The running public spec asserts its retained context is under this checkout and its own native birth is published, so a silently stripped context cannot pass vacuously.

All targeted checks and diff/lint checks passed. Next: push this checkpoint and queue one recorded full suite on that exact pushed head, then the binary-owned close review. No #416 recorded full-suite pass or close verdict exists yet.


### 2026-10-22 — Git metadata placement correction before close

Native directory churn under the working tree reproduced the #202 walk race: real `find .` failed on iteration 3 while an owned scope retired. The authoritative plan Revision moves this same registry into the checkout’s own Git metadata (an approved location), retaining the no-Git fallback and legacy-path census. Per-worktree placement and legacy-unknown migration tests failed before the fix and now pass. All 26 lease tests and 15 Python census tests pass. The source-search injection case now walks immutable source rather than mutable Git/test metadata. Recorded suite `lease-2698737677` on the old pushed head was cancelled through `sdlc local-check cancel` before execution; it provides no passing evidence. One replacement will be queued on the corrected pushed head after two-runtime checks. Hub report receipt 3dd06741-69b4-4629-b2c4-df562fd3e65c is submitted.


Both runtime focused mappings passed after placement correction: `/tmp/parley416-placement-native.log` (0.12.5), `/tmp/parley416-placement-compat.log` (0.11.7), covering 6 native lifecycle, 7 pure policy, 18 retained-registry and 4 find safety cases each. A native 100-walk probe passed while private scopes churned in this linked checkout's Git metadata; the old source-tree placement failed at walk 3. Lint remains clean across 828 files (`/tmp/parley416-placement-lint.log`).


The broader harness mapping passed after Git metadata placement (`/tmp/parley416-placement-harness.log`), including native runner deadlines, Python/lease controls and terminal verified/clean census. PR #336 is updated. The single replacement suite is queued as `lease-3515239873` on code head `cb8aef34`, session 35471, inflight log `sdlc/test-stats/inflight/ce8e0b7283668633eb0eeabb471a86d6/run.log` in the Git common directory. Initial FIFO position 16; no full-suite result yet. Per tl-worker's permitted overlap, request the fresh close review while this exact-head check waits. Landing requires its actual pass; code fixes require a new final-head run.


### 2026-10-22 — close round 1 REWORK

The fresh review confirmed the main native purpose and both runtimes, but reproduced two blocking classes: BR-1 lossy unknown numeric publication, BR-2 non-atomic scope-capacity admission. Applying the authoritative plan Revision for raw unknown-member preservation and atomic bounded scope slots, with independent numeric-text and deterministic concurrent-admission regressions. Cancelled queued `lease-3515239873` through the supported control before it ran; it supplies no suite pass. A single replacement must use the fixed code head. The review's own broad harness encountered eight scratch-placement failures caused by its TMPDIR being inside its disposable checkout; the actual slot harness passed with external scratch.


BR-1's exact numeric-text regression failed before the fix (`/tmp/parley416-number-red.log`) and passes after raw-member publication (`/tmp/parley416-number-green.log`). BR-2's controlled native-scan barrier regression admitted both callers before the fix (4 failing scope cases), and now only one caller reserves the last atomic slot (4 passing scope cases, `/Volumes/TestScratch/parley416-scope.UiVDoH/` test map). No extra lock is introduced. Combined affected mapping passes on 0.11.7 (`/tmp/parley416-reviewfix-compat.log`); focused lint is clean across 829 files. Preferred-runtime combined verification is in progress.

Preferred Neovim 0.12.5 combined verification also passed (`/tmp/parley416-reviewfix-native.log`): 6 native lifecycle, 7 policy, 19 registry, 4 scope-admission and 4 source-find cases. Both runs end in a verified/clean terminal census; these results cover the complete review-fix interdiff.


### 2026-10-22 — close round 2 REWORK: full admission/retirement family

Review independently confirmed BR-1 and BR-2 addressed (including counterfactual RED against preceding code), 209 preferred-runtime harness cases and 36 compatibility cases passing, and retained-census native purpose satisfied. BR-3 reproduced normal scope retirement between enumeration and lstat being rejected before launch. The authoritative plan now states every allocation/allocation, allocation/retirement, retirement/reuse and unreadable-entry outcome around the single mkdir/rmdir occupancy resource. Fix the full family with controlled ordering tests; explicit ENOENT permits continued reservation, other probe failures remain unknown/refused. Cancelled queued `lease-1756206107` through supported cancellation before execution; no recorded suite pass exists. Requeue only after the revised concurrency behavior clears review, avoiding another stale-code queued run.


TL delivery 8b571a27-33e8-4e42-bc71-f22e040ebc34 authenticated and accepted the full-family re-plan. New constraint: if a third capacity-family finding appears at review, stop and send the hub a re-plan before patching. Current BR-3 regressions first produced 7 pass/2 fail; explicit ENOENT-only handling makes all 9 scope and 19 registry cases pass, with clean census. The tests cover both stale allocators, retirement before metadata lookup, reuse after stale identity observation, EACCES/EIO/unclassified probe failure, malformed and writable entries. No count-based acquisition or secondary lock exists.

Combined final targeted mapping passes after BR-3 on both Neovim 0.12.5 (`/tmp/parley416-retirement-native.log`) and 0.11.7 (`/tmp/parley416-retirement-compat.log`): 6 native lifecycle, 7 policy, 19 registry, 9 scope-interleaving and 4 find cases each, verified/clean terminal census. Changed helper/spec lint and git diff checks pass. Full suite remains unrun pending this close verdict.


### 2026-10-22 — close round 3 REWORK: fixture alias portability

All capacity findings are disposed, so the TL's third-capacity-finding stop condition did not trigger. Review confirmed 7 policy, 19 registry, 9 scope and 6 native cases on both runtimes, including BR-3 counterfactual RED. New BR-4 is test-only fixture-path identity: four new lease cases fail under macOS TMPDIR=/tmp because expectations and ownership fakes use unresolved aliases while production resolves checkout paths. Native rerun reproduced the four context/ownership failures plus two legacy-census assertions using the same unresolved fixture base (six failures, `/tmp/parley416-alias-red.log`). Add an explicit symlink-TMPDIR child-process regression, canonicalize the single shared fixture base, and verify physical plus aliased scratch. Cancelled queued `lease-3271573758` before execution through supported cancellation; no full suite result exists.

BR-4 GREEN: all 27 lease tests pass with TMPDIR=/tmp (`/tmp/parley416-alias-green.log`, 13.080s) and physical TMPDIR=/Volumes/TestScratch (`/tmp/parley416-physical-green.log`, 13.125s). The new normal-suite alias regression runs the four context/ownership cases plus both phases of legacy census in a fresh Python process under an explicitly created symlink. The initial alias regression failed before canonicalizing the shared fixture base. Diff checks pass; no runtime behavior changes are required for this test-fixture correction.


### 2026-10-22 — SHIP, recorded suite retained

Close round 4 returned SHIP with no open findings; BR-1 through BR-4 are disposed, and the card is codecomplete bound to evidence commit 20e14388f324. Review independently passed the external-scratch preferred harness, compatibility lifecycle cases, 27 lease tests and the alias counterfactual. Acceptance adopted measured actual 1.88h. The final-code suite was queued before this close under tl-worker's allowed overlap (superseding the earlier intent to wait until review clears): `lease-2425142827` on code head `8548f3b6`, terminal session 98117, disposable worktree `/Volumes/TestScratch/local-checks/sdlc-local-320274851`, common-Git inflight log `sdlc/test-stats/inflight/2860f355bbfcb10eb13f3286c4489019/run.log`. It remains queued, initially position 13. No recorded full-suite pass exists yet; retain this one runner. Close descendants change only issue/review records, and the inspected merge CI gate explicitly reuses ancestor records across docs-only descendants. PR #336 is ready; next action is merge readiness, then retain/check the suite through its actual result before landing. No manual integration of newer main before merge's landing turn; preserve #405 on integration if it lands first.


### 2026-10-22 — recorded-suite failure; authorized test-only fix, landing deferred

Recorded suite `lease-2425142827` finally admitted after 4364s waiting. It found `tests/arch/arrival_budget_spec.lua`: the spinner helper generates `vim.wait(10000, predicate)` instead of deriving readiness from `arrival.MS`. Other waits added here already use arrival; the explicit forever-false wait is the deliberate interruption seam. Fix the generated child source by passing the shared budget by value, and map the existing architecture guard under infra/test_harness so targeted preflight covers the class. The current full run remains running and will finish; no passing suite evidence is claimed.

Maintenance notice bc25bef7-e045-41fa-a322-d8466710c728 and subsequent directive 449567de-e97e-430a-bf38-92d7935a6287 authenticated. The latter supersedes the earlier permission to finish tonight: fix/review this short correction, commit/push and log the exact next step, then defer the new suite and landing until tomorrow after restart. The queued owned merge (session 33143, pid 74105 from its own landing record, confirmed command identity) was interrupted with SIGINT and exited 130; it held no landing turn. No new merge will start tonight. The old-head suite session 98117 is still running in its pinned disposable checkout.


The old-head suite completed with exit 2 after 2m25s execution: only `tests/arch/arrival_budget_spec.lua` is listed as failed, and terminal census verified/clean. Saved attempt `2860f355bbfcb10eb13f3286c4489019`, log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/2860f355bbfcb10eb13f3286c4489019.log`. The suite parser calls this unattributable-failure because it lacks a typed case name, but the static guard's named file/assertion attributes it to this branch's generated readiness literal. It is reproducible, not a flake; do not register it as one or resume the unchanged failed head. Compatibility as a full-suite phase was not reached.

Corrected target map `/tmp/parley416-arrival-map.yaml` passes on Neovim 0.12.5 (`/tmp/parley416-arrival-native.log`) and 0.11.7 (`/tmp/parley416-arrival-compat.log`): 2 arrival-guard cases and all 6 native census cases each, final census verified/clean. Changed-file luacheck and diff checks pass. The existing arrival guard is now in the infra/test_harness mapping. Request the narrow post-close fix review, then push its evidence. No active recorded check or merge remains.

**Next step after tomorrow's maintenance restart:** verify the pushed branch/card and review binding with `sdlc state`; retain any real completed exact-head evidence if it exists, otherwise run one `sdlc local-check run --name suite` on the corrected pushed tip. The previous suite is red on old code and cannot count. Resolve any new failure by name (not a blind passing retry), then resume `sdlc merge --yes` for authoritative main integration and landing. Do not stack #405; if it lands first, preserve its Child callback/joined fixture authority during main integration. Do not start the new suite or merge tonight per TL delivery 449567de-e97e-430a-bf38-92d7935a6287.
