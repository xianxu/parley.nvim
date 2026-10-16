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
