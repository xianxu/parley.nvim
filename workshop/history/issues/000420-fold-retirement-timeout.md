---
id: 000420
status: done
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '88bc24c2d308e3f7ae87ab8cb7bf566c07d930cf' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T09:28:51-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e5e0b872", done: "241b8a59"}
actual_hours: 0.46
---

# Investigate embedded fold-retirement timeout under native suite load

## Problem

A complete recorded #410 integration suite passed its preferred runtime but failed one suspended-fold retirement case on installed Neovim 0.11.7. A subsequent isolated run of the exact same case and product code passed. The precise hang cause is unproven; this is linked to the #412/#414 native timing-under-load family for investigation, not asserted to share their root cause.

## Spec

Current deliverable: bounded evidence capture in both native retirement fixtures, preserving their single RPC, callback order, request deadline and original fold/view assertions. The historical timeout could not be reproduced on demand. Its unresolved root cause and active flake registration are tracked by unclaimed #424; see the scope revision below.

Failing file: tests/integration/document_fold_uncertainty_retirement_spec.lua, line10. Exact case: native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty.

Recorded full suite on d74f24b15ae4fa9d9393e4bf1b5b166335887eb1: attempt c2c4dbbdbfc2dc8a8b8a35131c503fb2; suite make exit2 after5m34s, outer command exit1. Installed0.11.7 child did not answer nvim_exec_lua within27862ms; embedded helper killed child PID5505. This was the only failed file. Preferred runtime and both session_sync_native runs passed; every process census was clean. Immutable failure log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/c2c4dbbdbfc2dc8a8b8a35131c503fb2.log, SHA256 e285308fc37374072ff54fbc702679242ce1531654f8c600095dfaa61eb20068, failure lines1718–1735. No per-case load or elapsed stage trace was captured;27862ms is the helper's load-scaled request bound, not a diagnosis.

One bounded isolated reproduction on unchanged product code and installed0.11.7: PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim make test-spec SPEC=diagnostic/fold-retirement MAP_FILE=/Volumes/TestScratch/parley-410-fold-timeout.d7zvmrdd/map.yaml. The scratch map selects only the original unmodified spec. Result exit0, exact case1 success/0 failed/0 errors, clean process census. Log /Volumes/TestScratch/parley-410-fold-timeout.d7zvmrdd/repro.log SHA256165369195576e88f03dc03378508b12d342850cb7835e0dbedd75d0ce42738b4. Individual duration/load was not recorded by this targeted runner. The fixture, tests/helpers/embedded_nvim.lua and lua/parley/tool_folds.lua are unchanged from integrated main bbf1294da084d456cb82b2de78aeea2fd30e3e4a; no product/test/timeout fix between failure and pass. Later #410 commits contain only Log evidence.

#415 typed Lua adapter is not adopted here, so the recorded suite classifies this as unattributable-failure; no supported Lua resume path is claimed. TL authorizes one evidenced same-code full-suite rerun for #410, and stop/report if the case repeats. Keep this issue unclaimed; do not block on adapter adoption.

## Done when

- Both native retirement fixtures report bounded last-stage, runtime, load, elapsed wall/CPU and counted-work evidence; reuse the existing JIT profile reporter.
- Capture evidence before teardown on a failed RPC, preserving original errors when the snapshot is missing or malformed; clean the owned scratch folder afterward.
- Preserve one RPC, operation/event order, request deadlines and the original fold preference/view assertions.
- Verify bounded progress writes, actual child-kill capture and cleanup, and both supported runtimes. Record the completed bounded replay without claiming a root-cause fix.
- File the unresolved root cause as an unclaimed follow-up and keep the exact timeout case registered as a flake there.

## Plan

- [x] Instrument both original single-request fixtures through one shared test-only reporter, reusing existing lifecycle and profile owners (ARCH-DRY, ARCH-ORDER).
- [x] Verify evidence survival, unusable-snapshot error preservation, cleanup and logarithmic progress writes with deterministic controls.
- [x] Complete one bounded nine-file/eight-worker replay on each runtime and classify the historical cause as unknown when it does not reproduce.
- [x] Revise the deliverable at hub direction; file unclaimed #424 and register the exact unresolved flake there. Preserve historical investigation evidence below.


## Log

### 2026-10-22

Filed unclaimed at hub direction be6c21ea-6e38-4fe8-9e3d-3a2481a5da1a after #410's integration suite completed. Related #412 and #414 concern native timing under load; no shared root cause is proven. No code change, blanket budget increase, or automatic flake registration made.

### 2026-10-23 — Approved diagnostics in progress
- 2026-10-23: closed — Diagnostics only, revised at hub direction ff4e7f1b-f39a-4575-8ccf-0f9ef5f8b6a6. One bounded nine-file/eight-worker replay passed 63/0/0 on Neovim 0.11.7 and 63/0/0 on 0.12.5; no timeout reproduced. Final controls/guards passed 17/0/0 per runtime, proving killed-child evidence capture before cleanup, original error preservation with unusable snapshots and logarithmic 4/8 repair progress writes. Logs /Volumes/TestScratch/parley420-check.c9bqtj0q/{operator,preferred}-{fanout,guards}.log; lint 853 files clean, diff-check clean. Single RPC, original fold/view assertions, event order and deadlines preserved. Unclaimed #424 owns unresolved cause and exact Lua flake registration. Recorded suite PENDING on pushed 38ebb2a8e6629fa6a50c42c9c3a9fdeccba70a31; must pass before merge. No production correction claimed.; review verdict: SHIP

Hub approved the evidence-gathering plan (delivery ab3693ad-04a0-4e9a-abe8-ac0af78e3bc4). Entered quick change-code. Added a shared test-only reporter and stage/work witnesses in the two original native fixtures; the fixture still uses one RPC and keeps the original fold/view assertions and operation order. The reporter owns a private temporary folder, atomically replaces one bounded stage snapshot, reads evidence before teardown, and reuses jit_watch for bounded VM profile output. It does not change compiler policy or any deadline. Repair progress writes happen at powers of two (at most18 under the existing200000-step cap).

The initial TDD run failed at module load before the reporter existed; this hit the runner's200s watchdog, so it is not evidence of the historical fold defect. The next run waited on the checkout's test lease, then passed2/0/0: unchanged RPC result and actual500ms child-kill evidence survival/cleanup, /Volumes/TestScratch/parley420-check.c9bqtj0q/trace-green.log. Added4/8-repair counted controls for logarithmic progress writes; their verification is next in the bounded fan-out. No root cause or correction selected. Next: one eight-worker, nine-file native cohort per runtime, retaining each spec's full log under the diagnostic root; stop/classify any failure, otherwise report non-reproduction and leave #420 open.

### 2026-10-23 — Bounded replay did not reproduce; issue stays open

Executed exactly one nine-file/eight-worker cohort on each runtime through the existing test environment, checkout lease, embedded request bounds, spec supervisor and process census. Aggregate logs: /Volumes/TestScratch/parley420-check.c9bqtj0q/operator-fanout.log and preferred-fanout.log; each file's full output is retained in the corresponding operator-fanout/ and preferred-fanout/ directories. Both commands exit0, nine files each,63 success/0fail/0error on each runtime; clean censuses.

- Installed0.11.7 target uncertainty retirement:814.62ms request wall,735.40ms CPU,2459 repair steps,126 native fold operations/63 groups. Companion apply retirement:961.83ms wall,774.45ms CPU,2459 repair steps/150 groups. Both reach complete with the original preference/view assertions. Sampled load48.51/54.56/53.67.
- Preferred0.12.5 target:1672.94ms wall,1471.82ms CPU,2459 repair steps,126 native operations/63 groups. Companion:2934.74ms wall,1966.69ms CPU,2459 repair steps/150 groups. Profile samples show compilation activity (target76 flushes at1s, companion290 at2s), but both complete; those samples do not establish an unsafe-allocator stall. Load41.45/52.22/52.86. Installed cases finish before the profiler's first1s sample; the earlier six-child trace-count probe observed0 flushes.
- Classification remains unknown for the historical timeout. This replay shows neither growing repair counts, a native OptionSet stall nor old-runtime compiler thrash. Current scheduling differences do not prove the original request was starved. No mechanism-specific correction or deterministic regression for that original mechanism is claimed.

After replay, corrected diagnostic work-key labels to the existing line_reader aliases (index_nodes_visited/index_entries_visited), rather than treating the replay's unused nodes_visited/entries_visited zero fields as measured index work. Added malformed/missing snapshot handling so evidence formatting cannot replace the original RPC failure. Final serial verification on both runtimes: operator-guards.log and preferred-guards.log in the same root, each17/0/0 (RPC guard2, fixture lifecycle4, original native retirement1+1, docs4, diagnostic controls5). Controls prove actual500ms child-kill evidence survives until parent cleanup, original errors survive unusable snapshots,4/8 repair events produce4/5 total stage writes including completion, and the real Reader work aliases are recorded. Final lint853 files,0warnings/errors; diff-check clean.

Shared reporter/fixture instrumentation and harness documentation are checkpointed, not landed. No production file, compiler policy, request budget, RPC count or original fold/view assertion changed. No recorded full suite, close, PR or merge was started for an unproven fix.

**Exact next step:** report non-reproduction to the hub and leave #420 working/open under this claim. Wait for the hub's decision on further failure capture; do not repeat fan-out, add a guessed guard, raise a deadline or declare the root-cause contract complete. This branch carries usable bounded diagnostics if the next actual failure is captured here.

## Revisions

### 2026-10-23 — Dispatched investigation

The hub lifted the shutdown freeze and explicitly assigned #420 to parley.nvim:2, superseding the filing-time instruction to keep it unclaimed. Investigation does not assume the #412/#414 cause and will not raise the request deadline. Start-plan completed on its own main-based branch; catch-up now defers the seeded workflow update rather than dirtying the checkout.

### Investigation checkpoint

- Original immutable failure excerpt confirms the only location is the single nvim_exec_lua at spec line10; no inner stage trace exists. Current installed runtime is Neovim0.11.7/LuaJIT2.1.1741730670; preferred0.12.5/LuaJIT2.1.1788856981. Machine load sampled09:29 local47.22/36.81/30.33, not original-failure load.
- Read-only peer trace finds native deletion bounded128 operations and guarded detach ownership. Initial D.drain permits200000 synchronous steps; anonymous fixture loops are outside the module-level jit_tuning protections. Both are hypotheses until stage/profile evidence distinguishes them. Next: bounded temporary probe with stage witnesses inside the same RPC; no product/test changes yet.

### 2026-10-23 — Evidence and next investigation plan

The timeout is not yet reproduced; no product or test correction is justified by these passing probes. The unchanged target fixture and product document/tool-fold/native/JIT modules are byte-identical to the failed d74f24b15ae4fa9d9393e4bf1b5b166335887eb1 revision. The embedded helper has since gained fixture ownership/cleanup, so current probes do not establish behavior of the old helper's complete environment.

Temporary stage probe: /Volumes/TestScratch/parley420-probe.t96o2lo2. It preserves the original one-RPC ordering and all fold/view assertions. Installed0.11.7 completed in658.79ms (initial drain639.02ms); fixture-chunk interpreter protection comparison723.09ms (drain645.54ms), so that comparison shows no allocator stall. Preferred0.12.5 completed1278.93ms. These1/0/0 runs are diagnostics, not exact-head historical flake evidence or a fix. No deadline changed.

Six fresh installed0.11.7 children: /Volumes/TestScratch/parley420-jit.kjte5ml5/run.log; all6/0/0, clean process census. Fixture elapsed718.12–818.56ms, all six had0 trace flushes (5–7 aborts,5–6 completed traces). Every stage witness reached suspension, OptionSet detach enter/exit and retirement; initial document drain dominates. Sampled machine load09:33 was98.38/71.50/47.53. High current load alone did not reproduce the timeout; original failure-time load remains unknown. A near-identical reconstruction-retirement fixture and bounded native walk provide controls, not proof of a root cause.

Proposed next plan to hub, before code:

1. Add bounded stage/cost witnesses to the target and companion single-RPC native retirement fixtures, preserving callback order and the original foldenable/view assertions. On a failed request, report the last completed stage, current runtime/JIT, elapsed time, repair/native operation counts and machine load. Keep evidence readable before teardown removes child-owned fixtures. Do not split the RPC, run synthetic machine-wide load or increase any deadline.
2. Run a bounded diagnostic replay through the normal native fan-out on the operator runtime and compare with preferred runtime. Distinguish (a) advancing/overgrown setup, (b) native OptionSet retirement stall, (c) compiler allocation thrash, and (d) process scheduling/starvation using actual captured evidence. Do not apply interpreter protection or a budget change just because it is plausible.
3. Only after a mechanism is established, write its deterministic reproducer/negative control and fix the owning code or fixture. Preserve both native retirement assertions and both runtime checks. If the instrumented replay still does not reproduce, keep #420 open and send the evidence to the hub for a decision; no guessed fix or SHIP claim.

No correction has been selected; stage diagnostics are the proposed investigation work, not completion of the root-cause contract. ARCH-DRY: retain embedded_nvim and existing fold/document owners. ARCH-ORDER: avoid event-loop turns between stages and retain OptionSet reentrancy. No operator state, storage format or production hot path change is proposed. Diagnostics are bounded per test case and removed after evidence is reported; no new durable production artifact family.


### 2026-10-23 — Scope revised to land bounded evidence capture

Hub decision ff4e7f1b-f39a-4575-8ccf-0f9ef5f8b6a6 supersedes the original root-cause completion contract: land the diagnostics, with no more reproduction reruns. The original Done-when required an established cause, a deterministic regression/correction and verification of that correction; those requirements now belong to unclaimed #424. The original uncompleted hypothesis/fix plan steps are superseded by the active evidence-capture Plan above. Historical Log entries remain unchanged.

The deliverable is bounded evidence capture in both native retirement fixtures. No product correction, timeout increase or claim of reproducibility is included. Both completed replay cohorts passed63/63; final controls passed17/17 on each runtime and lint passed853 files. The next recurrence must use the captured last-stage evidence to guide #424; no additional blind replay is planned.

### 2026-10-23 — Follow-up and registration

Filed unclaimed #424, fold retirement timeout: root cause from captured evidence. The registry initially listed only #421 identities, so the target identity was not actually registered. Registered it on #424 through sdlc flake register with explicit historical evidence, without asserting a typed exact-head pass: lua:tests/integration/document_fold_uncertainty_retirement_spec.lua#native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty. The historical immutable failure and unchanged-fixture targeted pass are recorded in both issue bodies. The follow-up remains open and the flake remains registered. Required recorded suite and close review are pending for this diagnostics landing.
