# Boundary Review — parley.nvim#410 (whole-issue close)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6 |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T12:22:23-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared-deadline mechanism and documentation are sound, but pending discovery bypasses confirmed admission when a legacy session-sync controller already exists—the normal setup path for typed session files. This reproduces on both supported runtimes and blocks shipping.

Done-when: current — the existing criteria still cover confirmed first-input protection, shared timing, and safe late-edit reconciliation.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: admission-handoff-covers-existing-controllers
    title: |
      Existing session-sync controllers bypass pending-lookup admission
    detail: |
      lua/parley/session_sync.lua:726 updates an existing controller's identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper's detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.
```

1. **Strengths**

   - Residual-budget arithmetic is pure, with expiry and fractional-boundary tests.
   - Couch subtracts spawn time before waiting and avoids spawning after expiry.
   - The existing admission owner retains lock/history ownership; README and atlas explain the new behavior.

2. **Critical findings**

   - The existing-controller handoff above bypasses acquisition and freshness. Fix the handoff and legacy callback ordering together.

3. **Important findings**

   None separately raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Preferred-runtime session-sync mapping: all 32 files passed.
   - Both runtimes: 12 new native cases and 25 Couch cases passed.
   - Disposable real/fake Couch conformance and corrupted-fake negative control passed.
   - Production-order probes failed as described above. Tracked files remained unchanged; process census was clean.

6. **Architectural notes**

   - **ARCH-DRY: pass** — existing process and admission owners are reused.
   - **ARCH-PURE: pass** — arithmetic is directly tested; IO remains in adapters.
   - **ARCH-PURPOSE: flag** — the existing-controller consumer does not honor the new admission scope.
   - **ARCH-EVOLVE: pass** — no persisted format changes.
   - Core-concept symbols exist at their documented locations; fixture changes were conditional and unnecessary.

7. **Plan revision recommendations**

   Add a `## Revisions` entry explicitly covering existing-controller adoption, legacy InsertEnter ordering, and native regressions with and without outstanding saved edits. Preserve production attachment order in those tests.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"008812c4-feb7-4fd2-9bf7-47e5b2a1a62a","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/eb5b13688580f6b8","reviewed_head":"adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6","slot":"parley.nvim:4","requested_at":"2026-10-22T19:16:34.97545Z"},"phase":"finished","pid":96134,"started_at":"2026-10-22T19:16:35.074286Z","finished_at":"2026-10-22T19:22:16.753209Z","session_id":"01a1650b-338a-7fe3-b6b7-d627a5de240d","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T13:02:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..8f42416fc1223719f4a1de940185280f3f8ea844 |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T13:02:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-1’s confirmed-registration paths are corrected and backed by meaningful regression tests. However, the correction strands deferred legacy edit turns when discovery finishes without registration: existing protection is never restored. This reproducible behavior regression blocks SHIP.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Existing-controller attachment now consumes the input scope and observed edits. Production-order regressions pass on Neovim 0.11.7 and 0.12.5; substituting the pre-correction c8e811f1 modules makes the clean-input, saved-edit, and pre-owned-turn regressions fail.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: admission-handoff-covers-existing-controllers
    title: |
      Deferred legacy edit turns remain unlocked after lookup completes without registration
    detail: |
      lua/parley/session_sync.lua:797-799 records an observed turn and suppresses legacy protection while lookup is pending. Background lookup completion at lua/parley/agentic_document.lua:347-355 has no continuation restoring that protection on absence; only an active InsertEnter waiter resumes legacy behavior. The existing tests/integration/session_sync_spec.lua:411 regression fails at head with a missing .lock, and an isolated check confirms pending=false, no registered identity, and lock=0 after completion. The same test passes with pre-correction c8e811f1 modules. This violates the plan's promise that proven absence restores existing legacy behavior and leaves outstanding edits without their previous protection. ARCH-PURPOSE / ARCH-ORDER: this is the 2nd finding in family admission-handoff-covers-existing-controllers. Earlier rounds fixed instances. Do NOT fix only this test: state and enforce the rule for settling deferred turns across lookup outcomes, normal-mode edits, and completion after input-scope expiry, preserving the original baseline and ownership checks.
```

1. **Strengths**

   - Existing and newly created controllers share attachment completion through `s.complete_attach` at `lua/parley/session_sync.lua:835`.
   - The pure owner’s `legacy_release` continuation preserves history through failure and retry at `lua/parley/operator_admission.lua:49`.
   - Residual process budgets account for spawn time and avoid spawning after expiry.
   - README and atlas changes document the shared deadline and retained unknown-period behavior.

2. **Critical findings**

   - The finding above requires a completion path for deferred legacy turns when discovery establishes absence. Preserve outstanding history and settle protection without requiring another edit or insert entry.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - All 17 issue-specific native cases passed on both Neovim 0.11.7 and 0.12.5.
   - Owner and Couch unit suites passed, 25 cases each. Isolated real/fake Couch conformance and its corrupted-fake negative control passed.
   - Three BR-1 regression tests failed with the previous implementation substituted in memory.
   - The legacy fallback regression failed at head and passed with the previous implementation.
   - The mapped suite was unsuccessful: it exposed that regression and stalled during the full native file. An overlapping harness preparation also reaped one mapped process, so this run cannot establish a complete suite pass. Focused reruns passed; the checkout remains unchanged.

6. **Architectural notes**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass — shared admission entry and attachment completion. |
   | ARCH-PURE | Pass — history transitions remain pure and directly tested. |
   | ARCH-PURPOSE | **Flag** — deferred legacy fallback is incomplete. |
   | ARCH-MOCK | Pass — production seams use stateful fakes; conformance passed. |
   | ARCH-CONSTRAINTS | Pass — focused deadline and counted-work tests passed. |
   | ARCH-SECURE | Pass — witness and exact-proof checks remain enforced. |
   | ARCH-ORDER | **Flag** — non-registration completion does not settle deferred turns. |
   | ARCH-FUNERAL | Pass — scopes have explicit cleanup; no new durable family. |
   | ARCH-EVOLVE | Pass — no persisted-format change. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining how deferred legacy turns settle for confirmed, absent, and unavailable lookup outcomes, including normal-mode edits and completion after scope expiry. Require regression coverage for those transitions while preserving the original dirty or autosaved baseline.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c6e20723-aa74-4785-b71b-c902edaa45df","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/8442cc1717c71343","reviewed_head":"8f42416fc1223719f4a1de940185280f3f8ea844","slot":"parley.nvim:4","requested_at":"2026-10-22T19:52:00.202536Z"},"phase":"finished","pid":37065,"started_at":"2026-10-22T19:52:00.430149Z","finished_at":"2026-10-22T20:02:13.374958Z","session_id":"01a1652b-a28f-7062-b338-c0e1748750b7","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T13:55:43-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..199c3b90373e3007fc023d50a8f00652588aec93 |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T13:55:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation matches the revised RETIRE contract and addresses BR-2 through S1 ownership from opening. Shared deadlines, late-edit reconciliation, old-proof refusal, and standalone recovery are validated. One inexpensive documentation correction remains.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      S1-first setup and guarded legacy attachment preserve the correction; queued-first-input tests pass for parent, side, and directly attached documents on both runtimes.
  - id: BR-2
    disposition: addressed
    note: |
      The approved RETIRE revision explicitly replaces legacy restoration with editable, visibly unprotected S1 ownership. Pending/absent/unavailable regressions fail against pre-correction modules and pass at head; late saved-edit reconciliation and explicit old-turn completion also pass.
findings:
  - id: new
    severity: Important
    kind: defect
    family: recovery-guidance-names-launch-context
    title: |
      Standalone recovery documentation omits required environment conditions
    detail: |
      README.md:98 and atlas/modes/session_sync.md:119 say to open nvim outside Couch but omit the scope/tag condition explicitly required by workshop/plans/000410-pending-lookup-admission-plan.md:303. Couch context is inherited through environment variables (lua/parley/couch.lua:202); the successful restart regression explicitly clears both variables at tests/integration/session_sync_native_spec.lua:335. Add `env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md` to both recovery passages so readers can reach the advertised standalone release route. ARCH-PURPOSE: complete the agreed recovery workflow.
```

1. **Strengths**
   - Central attachment and writer guards enforce retirement across existing callers.
   - One absolute deadline reaches acquisition, with exact-scope cleanup and stale-witness rejection.
   - Old tokenless proof/history survives refusal; explicit completion and validated journal recovery retain separate authority.

2. **Critical findings:** None.

3. **Important findings:** Document the standalone launch prerequisites above. This requires a prose correction; existing native tests validate the advertised behavior.

4. **Minor findings:** None.

5. **Test coverage**
   - Focused #410 native cases: **23 passed on each supported runtime**.
   - Full preferred-runtime native file: **165 passed**.
   - Full session-sync mapping: **853 passed, 1 timing failure, 0 errors**. The existing registered-`:saveas` test exceeded its 500 ms assertion; an isolated rerun at head passed. The mapped run is therefore not wholly green.
   - Couch tests: **25 passed**; admission architecture checks: **7 passed**.
   - Real/fake conformance and corrupted-fake negative control passed.
   - Lint: **822 files, zero warnings/errors**. No surviving test processes; disposable substitution checkout removed.

6. **Architectural notes**
   - **ARCH-DRY — pass:** central writer guard and shared acquisition seam.
   - **ARCH-PURE — pass:** arithmetic, warning projection, and admission transitions remain pure.
   - **ARCH-PURPOSE — flag:** recovery documentation omits an agreed prerequisite.
   - **ARCH-MOCK — pass:** stateful fake shares production boundaries; conformance passed.
   - **ARCH-CONSTRAINTS — pass:** residual deadlines and 4/8-entry bounds are exercised.
   - **ARCH-SECURE — pass:** exact proof and unknown-lock handling remain conservative.
   - **ARCH-ORDER — pass:** controlled completion, expiry, stale events, and recovery sequences are covered.
   - **ARCH-FUNERAL — pass:** input scopes retire explicitly; no new durable artifact family.
   - **ARCH-EVOLVE — pass:** persisted formats remain unchanged; existing journal compatibility is retained.

7. **Plan revision recommendations:** None. Deliver the documentation already required by the active revision.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"0fed17ef-288e-441c-a375-0134179812d4","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/97c94788183d1112","reviewed_head":"199c3b90373e3007fc023d50a8f00652588aec93","slot":"parley.nvim:4","requested_at":"2026-10-22T20:48:03.329318Z"},"phase":"finished","pid":42890,"started_at":"2026-10-22T20:48:03.550171Z","finished_at":"2026-10-22T20:55:36.231223Z","session_id":"01a1655e-f47d-7e60-afe8-4a65966e1e03","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T14:06:38-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..bca7cf786a290f84c66037f358cd20b2475515da |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T14:06:38-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation matches the active RETIRE plan. BR-3 is addressed: both recovery passages now specify the required environment-clearing launch command. No new findings. Runtime regressions, conformance, and lint passed.

```findings
dispose:
  - id: BR-3
    disposition: addressed
    note: |
      The pinned documentation diff adds env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md at README.md:103 and atlas/modes/session_sync.md:124. This matches couch.thread() at lua/parley/couch.lua:202 and the restarted standalone recovery fixture at tests/integration/session_sync_native_spec.lua:335. The recovery regression passed on both runtimes; this correction changes prose only.
```

1. **Strengths**

   - S1-first setup and central attachment/write guards enforce tokenless retirement across callers (`lua/parley/init.lua:3190`, `lua/parley/session_sync.lua:740`).
   - Exact lookup witnesses and one absolute deadline carry through adoption and acquisition (`lua/parley/agentic_document.lua:474`).
   - Native tests cover queued-input freshness, late autosaved edits, retained old proof, and actual standalone restart recovery.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Neovim 0.12.5 session-sync mapping: **854 passed**, 32 files, zero failures/errors.
   - Neovim 0.11.7: **23 focused native cases and 25 Couch tests passed**. The opt-in live actor test was pending.
   - Disposable real/fake registry conformance and corrupted-fake negative control passed.
   - Lint: **822 files**, zero warnings/errors.
   - Process censuses were clean; tracked checkout remained unchanged.
   - Recorded-suite and copied-profile acceptance remain separate workflow steps.

6. **Architectural notes**

   - **ARCH-DRY — pass:** central writer guards and existing admission owner are reused.
   - **ARCH-PURE — pass:** arithmetic, warning projection, and admission transitions remain pure; IO stays in existing seams.
   - **ARCH-PURPOSE — pass:** retirement covers opening, pending/absent/unavailable membership, adoption, and explicit compatibility completion.
   - **ARCH-MOCK — pass:** production seams use stateful filesystem fakes; real/fake conformance passed.
   - **ARCH-CONSTRAINTS — pass:** residual deadlines, zero-spawn expiry, and 4/8-entry count tests enforce the declared envelope.
   - **ARCH-SECURE — pass:** old protection requires exact evidence; unknown lock states retain refusal.
   - **ARCH-ORDER — pass:** witnessed transitions, stale completions, late attachment, and interrupted recovery are exercised.
   - **ARCH-FUNERAL — pass:** input scopes close explicitly; discovery retains its existing bounded lifecycle.
   - **ARCH-EVOLVE — pass:** no persisted format change; existing journal recovery remains covered.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"0b20d9e0-06e7-4bfc-8195-438a351cd3a8","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"milestone-review","round":4,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/ee532ee4d33ebdc5","reviewed_head":"bca7cf786a290f84c66037f358cd20b2475515da","slot":"parley.nvim:4","requested_at":"2026-10-22T21:00:30.466242Z"},"phase":"finished","pid":26589,"started_at":"2026-10-22T21:00:30.640011Z","finished_at":"2026-10-22T21:06:37.962134Z","session_id":"01a1656a-5a16-7970-b93a-fb96e742349a","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T16:29:34-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 410 — Bound insert admission across pending registration lookup |
| repo | parley.nvim |
| issue file | workshop/issues/000410-pending-lookup-admission.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7044522d19d0c789c67c7fcbedc1c50c4e571187..7b8452dfc3fa90be1118d1d07aac6c5881cb038b |
| command | sdlc close --issue 410 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T16:29:34-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned interdiff introduces no defects. The README conflict resolution preserves both recovery guidance and registered-file reload documentation. Tracker revisions record verification and integration work without changing scope. BR-1, BR-2 and BR-3 remain disposed.

```findings
{}
```

1. **Strengths**
   - README retains the exact standalone launch command, matching environment detection and the restart fixture (`README.md:103`, `lua/parley/couch.lua:202`, `tests/integration/session_sync_native_spec.lua:323`).
   - The resolution also preserves registered-file reload and conflict guidance (`README.md:111`), consistent with `lua/parley/session_sync.lua:920`.
   - Spec, Done-when and the implementation plan remain unchanged.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes:** Inspected existing recovery and reload regressions. No runtime tests rerun: this window changes no product code, tests or executable instructions. `git diff --check` passed; checkout remained unchanged.

6. **Architectural notes**
   - **ARCH-DRY — pass:** no duplicated implementation introduced.
   - **ARCH-PURE — pass:** no logic or IO boundary changes.
   - **ARCH-PURPOSE — pass:** conflict resolution retains both sides’ documented behavior.
   - **ARCH-EVOLVE — pass:** no persisted-format or reader/writer changes.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"6ca82bf9-94fd-4da9-8fa6-6035a6772d36","repository":"github.com/xianxu/parley.nvim","issue_id":"000410","recipe":"fix-review","round":5,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/60fe1ad57d185b2b","reviewed_head":"7b8452dfc3fa90be1118d1d07aac6c5881cb038b","slot":"parley.nvim:4","requested_at":"2026-10-22T23:28:48.487634Z"},"phase":"finished","pid":13572,"started_at":"2026-10-22T23:28:48.581154Z","finished_at":"2026-10-22T23:29:34.209571Z","session_id":"01a165f2-1ed2-70e1-b043-d3ffcf4bf3e8","outcome":"returned"}] -->
