# Boundary Review — parley.nvim#332 (whole-issue close)

| field | value |
|-------|-------|
| issue | 332 — Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side) |
| repo | parley.nvim |
| issue file | workshop/issues/000332-agentic-documents-alt-return-makes-any-right-pane-markdown-file-a-session-sync-document-universal-agent-input-interface-s1-parley-side.md |
| boundary | whole-issue close |
| milestone | — |
| window | e23163d1bb9f42765fdd899f18951b6f32c6208e..c3b815092d3044a516fb0914f69a95614cdc069e |
| command | sdlc close --issue 332 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T18:17:38-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation delivers substantial coverage, shared turn handling, bounded registry access, and documented recovery. However, two reproduced lifecycle defects break registration/protection or strand submission, and the Core concepts table incorrectly classifies an IO-dependent function as PURE. These need correction before close.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: membership-before-migration
    title: |
      Native rename treats unresolved membership as plain and strands registration
    detail: |
      lua/parley/agentic_document.lua:554-557 returns from BufFilePre when neither coordinator nor legacy identity is attached, including while initial lookup is pending or unavailable. Reproduced with an existing registration and delayed initial lookup: native :saveas succeeded, NEW became plain with no identity or edit lock, and independent registry queries reported OLD registered / NEW absent. ARCH-PURPOSE and ARCH-ORDER: require confirmed absence before allowing the plain rename path; resolve membership or refuse only the migration when membership is unknown. Add controlled-order regressions for native rename during probing and unavailable admission.
  - id: new
    severity: Critical
    kind: defect
    family: async-buffer-lifetime
    title: |
      Lookup completion during buffer unload permanently strands the operation on reopen
    detail: |
      lua/parley/agentic_document.lua:185 discards callbacks when the buffer is unloaded, but line 315 detaches only on BufWipeout. Reproduced by holding initial lookup, running :bdelete, completing lookup while unloaded, then reopening: the controller remained probing with its completed lookup still recorded, and subsequent submit could neither requery nor submit. ARCH-ORDER and ARCH-FUNERAL: invalidate the buffer incarnation and close owned requests/leases on unload, or explicitly model suspended completion and restart admission on reload; preserve uncertain mutation/journal recovery. Add delayed-completion unload/reopen tests across lookup, mutation and migration.
  - id: new
    severity: Critical
    kind: defect
    family: core-concept-purity-contract
    title: |
      Core concepts declares not_chat PURE despite editor and filesystem dependencies
    detail: |
      workshop/plans/000332-agentic-documents-plan.md:38 labels not_chat PURE, but lua/parley/init.lua:1845 resolves configured chat roots and line 1856 reads buffer contents when supplied_lines is omitted. Its existing tests/integration/not_chat_spec.lua creates directories, writes files and constructs buffers. This contradicts the required Core concepts classification and ARCH-PURE. Promote this wrapper to INTEGRATION, or extract a value-only classifier and classify/test that separately; record the correction under Revisions.
```

1. **Strengths**

   - Explicit JSON-null validation prevents malformed or failed lookups from proving absence.
   - Migration uses kernel leases, atomic no-replace renames, persisted witnesses, and forward recovery.
   - Submission receipts and rapid-resend authorization live in the pure lifecycle controller.
   - README, atlas, and traceability updates cover the new user-facing surface.

2. **Critical findings**

   - [agentic_document.lua:554](lua/parley/agentic_document.lua:554): unresolved membership bypasses native migration protection.
   - [agentic_document.lua:185](lua/parley/agentic_document.lua:185): unload discards completion without retiring the pending operation.
   - [Plan:38](workshop/plans/000332-agentic-documents-plan.md:38): `not_chat` purity classification contradicts production code and tests.

   Fix sketches and reproduction evidence appear in the findings block.

3. **Important findings**

   None additional.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make test-spec SPEC=modes/session_sync` passed all 12 mapped spec files, with no surviving test processes. Fake-registry conformance and its corrupted negative control also passed.

   Separate controlled-callback probes reproduced both runtime defects. Existing tests miss those event orderings. I did not rerun the full repository suite or real-Couch conformance.

6. **Architectural notes**

   - **ARCH-DRY — pass:** admission reuses the existing turn engine and checked writer.
   - **ARCH-PURE — flag:** incorrect `not_chat` classification; the new lifecycle/projection modules otherwise separate logic from IO.
   - **ARCH-PURPOSE — flag:** native migration loses agentic identity during unresolved admission.
   - **ARCH-MOCK — pass:** production transport and tests share a stateful executable fake; a conformance driver exists.
   - **ARCH-CONSTRAINTS — pass:** requests, queues, caches, journals, and side scans have explicit bounds.
   - **ARCH-SECURE — pass:** inspected registry/journal readers validate external data, and subprocess calls use argv arrays.
   - **ARCH-ORDER — flag:** pending lookup/rename and unload/completion interleavings remain incorrect.
   - **ARCH-FUNERAL — flag:** unload does not retire coordinator requests and operation ownership as planned.

7. **Plan revision recommendations**

   Add `## Revisions` entries that:

   - Require confirmed plain membership before bypassing native migration.
   - Specify unload/reload transitions, handle cleanup, and uncertain-mutation recovery, with controllable completion-order tests.
   - Reclassify `not_chat` as INTEGRATION, or identify an extracted PURE classifier separately.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d005ac77-a86e-4347-b2ad-c31155e637f7","repository":"github.com/xianxu/parley.nvim","issue_id":"000332","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/62e82e6231b05a0c","reviewed_head":"c3b815092d3044a516fb0914f69a95614cdc069e","slot":"parley.nvim:2","requested_at":"2026-10-16T01:14:21.24309Z"},"phase":"finished","pid":37967,"started_at":"2026-10-16T01:14:21.619261Z","finished_at":"2026-10-16T01:17:38.290309Z","session_id":"01a14246-3e92-7491-ac90-0ed30b7f1e45","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T19:05:11-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 332 — Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side) |
| repo | parley.nvim |
| issue file | workshop/issues/000332-agentic-documents-alt-return-makes-any-right-pane-markdown-file-a-session-sync-document-universal-agent-input-interface-s1-parley-side.md |
| boundary | whole-issue close |
| milestone | — |
| window | e23163d1bb9f42765fdd899f18951b6f32c6208e..2fee90247e1fef6cddb9402f80b828cbbb29ba45 |
| command | sdlc close --issue 332 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T19:05:11-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The three prior findings are addressed, with regressions that fail without the coordinator fixes. The pinned implementation passes all 13 mapped session-sync spec files and isolated real/fake Couch conformance. No blocking findings remain; one minor Plan discrepancy should be corrected.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Native and public migration preflight now require confirmed membership and recheck activity after waits. Controlled regressions in agentic_document_spec.lua:595 onward pass at HEAD and fail with the pre-fix coordinator.
  - id: BR-2
    disposition: addressed
    note: |
      True BufUnload retires the incarnation, cancels requests and releases migration leases; managed rereads defer completions. Lifetime regressions cover lookup, register, rename and send across unload/reopen; restoring the pre-fix coordinator produces five failures.
  - id: BR-3
    disposition: addressed
    note: |
      Plan line 38 now classifies not_chat as INTEGRATION, with the correction explained under Revisions at line 252. This matches configured-root resolution and optional buffer reads in init.lua:1845-1856 and its existing integration tests.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: plan-runtime-traceability
    title: |
      Plan still promises lease-file cleanup that the implementation deliberately omits
    detail: |
      workshop/plans/000332-agentic-documents-plan.md:113 promises opportunistic cleanup after forgetting/completed recovery. document_lease.lua:76-79 only closes descriptors, and atlas/modes/session_sync.md:170-172 explicitly documents permanent allocation without automatic GC. Under ARCH-FUNERAL, align the Plan with the implemented 4096-entry bound and overflow refusal.
```

1. **Strengths**

   - Membership preflight covers native and public move doors, including submits starting while bounded waits pump editor events.
   - Buffer lifetime tests control actual subprocess completions across unload, reopen and managed reload.
   - Registry parsing distinguishes explicit absence from malformed, unavailable and uncertain outcomes.
   - README, atlas and traceability document the new submission, feedback, offline and migration surfaces.

2. **Critical findings**

   None.

3. **Important findings**

   None.

4. **Minor findings**

   Plan line 113 should describe permanent, bounded lease allocation consistently with code and atlas.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/session_sync`: all 13 files passed; no surviving test processes.
   - Disposable-checkout negative checks using the supported Neovim and pre-fix coordinator produced 11 admission failures and five lifetime failures.
   - Isolated real/fake registry conformance passed, including rejection of the deliberately corrupted fake.
   - Range whitespace check passed. The full repository suite was not independently rerun during this review.

6. **Architectural notes**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass: shared turn engine, process seam and atomic writer are reused. |
   | ARCH-PURE | Pass: lifecycle/projection modules use value inputs; the corrected catalog identifies IO wrappers. |
   | ARCH-PURPOSE | Pass: admission, routing, protection and both move doors deliver the documented purpose. |
   | ARCH-MOCK | Pass: production transport exercises a persisted fake; real/fake conformance passed. |
   | ARCH-CONSTRAINTS | Pass: request, queue, cache, journal and scan bounds have enforcement and coverage. |
   | ARCH-SECURE | Pass: replies and persisted state are validated; subprocess arguments remain structural. |
   | ARCH-ORDER | Pass: incarnation guards, post-wait checks and controlled completion tests address the temporal defects. |
   | ARCH-FUNERAL | Pass with the minor documentation flag: handles retire, completed journals disappear, and retained leases are capped. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry stating that lease files remain permanently allocated, automatic GC is not implemented, and new allocations refuse at the 4096-entry namespace limit. Correct line 113 accordingly.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"573a6836-0896-4182-985f-202f9ccb5fff","repository":"github.com/xianxu/parley.nvim","issue_id":"000332","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f20b0868a22e44d9","reviewed_head":"2fee90247e1fef6cddb9402f80b828cbbb29ba45","slot":"parley.nvim:2","requested_at":"2026-10-16T02:00:24.7537Z"},"phase":"finished","pid":6635,"started_at":"2026-10-16T02:00:25.015296Z","finished_at":"2026-10-16T02:05:09.978746Z","session_id":"01a14270-6835-7b32-ac76-31c411029d5d","outcome":"returned"}] -->
