# Boundary Review — parley.nvim#405 (whole-issue close)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 69657dfa119c3b70cd27dccca42db5c088bdf255..fcde202739ba3364c3015c1d0da9724a6a4f700d |
| command | sdlc close --issue 405 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T23:55:04-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned implementation matches the issue’s Spec and revised Plan. Attachment authority, private listeners, supersession, discovery, and teardown have substantive regression coverage. No blocking findings remain. Real-producer conformance was not independently rerun during this review.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Exact listener handles and queued publication are canceled on retirement; controlled startup-stage, held-acquisition, and queued-register regressions pass.
  - id: BR-2
    disposition: addressed
    note: |
      resource.startup_deadline carries acquisition's absolute deadline through first-listener durability; both delayed-fsync regressions pass.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's Core concepts table names lua/parley/remote_runtime_record.lua, where the implemented codec and cleanup decision reside.
  - id: BR-4
    disposition: addressed
    note: |
      The final-consumer drain automatically closes its runtime; final-detach directory-removal and attachment-during-drain regressions pass.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:214 documents --editor-endpoints --fake-only; that exact invocation passed, including the corrupted-reply control.
  - id: BR-6
    disposition: addressed
    note: |
      The owner normalizes rejected confirmations and the dispatcher reports its accepted result. The regression passes at head and fails against the pre-fix model with confirmed instead of uncertain.
  - id: BR-7
    disposition: addressed
    note: |
      Shared pending/listening validation precedes allocation and activation; rejected-input and constructor cases verify completion, cleanup, subsequent attachment, and close.
  - id: BR-8
    disposition: addressed
    note: |
      Discovery failures share a lifetime-scoped notice owner. Native failure/reopen/stale-callback controls pass; the unavailable-command regression fails against the pre-fix implementation.
  - id: BR-9
    disposition: addressed
    note: |
      README.md:222 supplies the required absolute --bridge invocation, supported by argument validation in scripts/check-couch-registry-conformance.py; adjacent text covers build, PATH, and candidate selection.
```

**1. Strengths**

- The pure attachment model owns accepted authority and returns copied snapshots, preventing transport replies from bypassing ownership validation.
- Listener cleanup checks exact socket identity before `serverstop`, preserving foreign replacements (`lua/parley/remote_runtime.lua:263`).
- Tests control cancellation and acknowledgment ordering, including retirement before publication and late cleanup.
- README, indexed atlas documentation, and traceability mappings cover the new surface.

**2. Critical findings:** None.

**3. Important findings:** None.

**4. Minor findings:** None.

**5. Test coverage notes**

- Mapped suite: **275 passed, 1 failed, 0 errors**. The failure came from review scratch placement inside the checkout; the affected zero-config spec passed **9/9** with external isolated scratch.
- Fake/native endpoint conformance and its corrupted-reply control passed.
- BR-6 and BR-8 counterfactual regressions failed for their expected reasons.
- Final process census was clean; tracked files remain unchanged.

**6. Architectural notes**

| Principle | Result |
|---|---|
| ARCH-DRY | Pass — existing registry transport and lease reused. |
| ARCH-PURE | Pass — both declared pure entities have IO-free logic tests. |
| ARCH-PURPOSE | Pass — parent/side documents, outside-pane discovery, takeover, and teardown delivered. |
| ARCH-MOCK | Pass — stateful external doubles share production seams; native conformance driver provided. |
| ARCH-CONSTRAINTS | Pass — capacity, byte, queue, startup, and exit bounds exercised. |
| ARCH-SECURE | Pass — private directories, validated tuples, exact ownership checks. |
| ARCH-ORDER | Pass — authoritative transitions and controllable event sequences exercised. |
| ARCH-FUNERAL | Pass — ordinary cleanup, bounded residue, and death-proven reclamation defined. |
| ARCH-EVOLVE | Pass — unknown root/nested marker fields survive rewrites; malformed and duplicate fields are rejected. |

**7. Plan revision recommendations:** None. Existing revisions describe the implemented refinements.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4ca3fc2c-873d-4919-b307-bf484900c457","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":8,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/ca7558981ab4af4d","reviewed_head":"fcde202739ba3364c3015c1d0da9724a6a4f700d","slot":"parley.nvim:1","requested_at":"2026-10-23T06:48:40.142714Z"},"phase":"finished","pid":11170,"started_at":"2026-10-23T06:48:40.267884Z","finished_at":"2026-10-23T06:55:03.667126Z","session_id":"01a16784-d44d-7750-a402-32d909052ddc","outcome":"returned"}] -->

---

## Re-review — 2026-10-23T01:55:33-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7f78909ce86d23b84c03dbd32287951818269c5e..09f68966d0df1563130a9a0d485b30ae21ab6456 |
| command | sdlc close --issue 405 |
| reviewer | claude (anthropic; author anthropic,openai) |
| isolation | fenced |
| timestamp | 2026-10-23T01:55:33-07:00 |
| verdict | SHIP |

## Review

Checking how the detached-child option interacts with the branch's parent-death watchdog, then I'll run the helper's specs.

Running the specs gave no output, so I'm checking the raw output.

The helper's specs pass, but `scratch_placement_spec` failed 8 cases. Looking at those failures now.

```verdict
verdict: SHIP
confidence: high
```

Verdict: SHIP. The window is a merge of origin/main into the already-reviewed head. It contains one never-reviewed conflict resolution, in `tests/helpers/embedded_nvim.lua`, plus workshop bookkeeping. The resolution keeps both sides' intent. All eight `tests/helpers/embedded_nvim.lua` cases pass, as do the six census cases that drive detached embedded children. No prior finding is open: BR-1 through BR-9 were all disposed in earlier rounds, so nothing needed disposing here. `## Spec`, `## Revisions` and `## Done when` are unchanged, so scope did not change after close.

1. **Strengths**
   - `tests/helpers/embedded_nvim.lua:92-113`: the resolution is a true union of both sides, not a pick of one:
     - **Main side:** the `detach = options.detach` jobstart option and the `require('tests.helpers.spec_jobs').install()` bootstrap.
     - **Branch side:** the `state`/`on_exit` exit tracking, the `owned[child]` registration, and the runtime fixture install with cleanup capture.
   - The spec_jobs bootstrap runs before the fixture chunk, so the child's job registry is in place before the fixture does any work.
   - The base still had literal conflict markers. The head removes all of them (none remain in that file), and `Child:notify` from main survives with its ownership comment.
   - `workshop/lessons.md`: the merge only moves entries. The #405 dated block goes to the top and the #405 one-liners move under the #413 entries. No lesson text was lost or changed.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none.

5. **Test coverage notes**
   - I ran `make test-spec SPEC=infra/test_harness` at the pinned head. Results:
     - `embedded_nvim_spec`: 8/0/0.
     - `test_process_census_spec`: 6/0/0, including the detached `start({ detach = true })` spinner and launcher-death cases.
     - `spec_jobs_spec`: 3/0/0, and `fixture_lifecycle_spec` passed.
     - The census and orphan checks reported clean.
   - The target still exited 2, because `tests/arch/scratch_placement_spec.lua` failed 8 cases. Every failure says the test env's TMPDIR, HOME and XDG directories resolve under `.sdlc-review/tmp` inside the checkout. The review sandbox puts them there; the window does not touch that spec or its inputs.
   - Main's detached children now also get the branch's parent-death watchdog and fixture. The census spinners still behave as main intended: their busy loop blocks the event loop, so the watchdog can't fire, and the census tests stay green.

6. **Architectural notes (interdiff only)**
   - **ARCH-DRY: pass.** No duplicated logic; the resolution joins the two bootstrap chunks without copying either.
   - **ARCH-PURE: pass.** No business logic is added; this is test-harness glue only.
   - **ARCH-PURPOSE: pass.** Both sides' purposes are kept: main's detachable, job-registered children and the branch's fixture-owned cleanup.
   - **ARCH-EVOLVE: pass.** No persisted format changes.

7. **Plan revision recommendations:** none.

```findings
findings: []
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e893a895-9eaf-460f-be72-d88d49e4e8da","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"fix-review","round":9,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/77084eba0235e637","reviewed_head":"09f68966d0df1563130a9a0d485b30ae21ab6456","slot":"parley.nvim:1","requested_at":"2026-10-23T08:49:33.491705Z"},"phase":"finished","pid":33231,"started_at":"2026-10-23T08:49:33.591834Z","finished_at":"2026-10-23T08:51:56.475028Z","session_id":"7f9e16a3-073c-4544-974a-c299bbabde4c","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"e91cabdc-a4d1-4b98-b62f-f32574efb81b","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"fix-review","round":9,"attempt":2,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/77084eba0235e637","reviewed_head":"09f68966d0df1563130a9a0d485b30ae21ab6456","slot":"parley.nvim:1","requested_at":"2026-10-23T08:51:58.32783Z"},"phase":"finished","pid":70359,"started_at":"2026-10-23T08:51:58.430975Z","finished_at":"2026-10-23T08:55:33.308787Z","session_id":"ed0717a2-e052-4928-99ab-8431cc712a1d","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "Conflict resolution keeps both sides textually; now running main's detach-dependent census spec against the merged helper to check the watchdog interaction.\n\nThe tests pass. One last check: whether the plan-file additions change scope.\n\n```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThe only code in this fix-review window is the merge-conflict resolution in `tests/helpers/embedded_nvim.lua`, and it keeps both sides. Main (#416) added `detach = options.detach` and the `spec_jobs.install()` bootstrap. This branch (#405) added the `on_exit` exit witness, the `owned[child]` state, and the fixture install for remote-runtime, discovery-registry and parent-death cleanup. All of these now sit in the same `jobstart` call and setup sequence. The setup order also still works: the `package.path` chunk from main runs before the branch's `require('tests.helpers.remote_runtime_fixture')`. There are no leftover conflict markers in non-Markdown files. The other changes are SDLC records: the close-gate and close-review records, an issue status change to `codecomplete` with a log entry, and a `lessons.md` reshuffle that keeps every lesson line word for word. Nothing changes `## Spec`, `## Revisions` or `## Done when`. Every prior finding was already disposed, so there is nothing to carry forward.\n\n1. **Strengths**\n   - `tests/helpers/embedded_nvim.lua:94` merges the two `jobstart` option sets into one table instead of picking a side. That keeps #416's detached-probe behaviour and #405's joined-cleanup proof (`join_and_cleanup` relies on `state.exited`).\n   - `tests/helpers/embedded_nvim.lua:104-112` keeps main's `spec_jobs.install()` before the fixture install. Job-birth recording therefore still covers the embedded child's own fixture setup.\n   - Running the specs on the merged helper confirmed it works:\n     - `embedded_nvim_spec`, `remote_runtime_fixture_spec`, `remote_session_native_spec`, `discovery_registry_fixture_spec`, `spec_runner_native_spec`, `remote_session_quit_spec` and `tests/arch/embedded_rpc_spec` all PASS.\n     - The orphan census afterwards reported \"clean: no surviving test processes\".\n     - The `detach=true` and `notify` cases in main's `test_process_census_spec` (unknown-on-interrupted-birth, clean-embedded descendants, TERM-resistant orphan) also PASS.\n\n2. **Critical findings:** none.\n\n3. **Important findings:** none.\n\n4. **Minor findings**\n   - `workshop/lessons.md`: the #405 BR-8, BR-9 and traceability bullets were moved out of the trailing #417 block. They now sit after the #413 entry under a different dated heading instead of the `2026-10-22 (#405)` section at the top. This is cosmetic only and isn't raised as a finding.\n\n5. **Test coverage notes:** One case in `test_process_census_spec`, \"receives its retained checkout context\", failed in my ad-hoc run. It needs `PARLEY_TEST_PROCESS_DIR`, which only the run-lease / `spec_runner` wrapper sets, and my run went around that wrapper. The case doesn't touch `embedded_nvim`, so the failure says nothing about the resolution. It still needs a pass under the real `make test` lease: the issue log says recorded suite lease-3395714002 is still queued, and green there is required before merge.\n\n6. **Architectural notes (interdiff only)**\n   - ARCH-DRY: pass. The resolution adds no duplicated bootstrap, and main's single `package.path` chunk replaced the branch's copy.\n   - ARCH-PURE: pass. This is test-harness glue only, with no business logic.\n   - ARCH-PURPOSE: pass. Both sides' intent is kept, which matches the log's instruction to \"preserve #405 Child joined-cleanup/on_exit with #416 detach/bootstrap/notify changes\".\n   - ARCH-EVOLVE: pass. No persisted format changes in this window.\n\n7. **Plan revision recommendations:** none.\n\n```findings\n```"

truncated: false
retained-bytes: 0000004026
