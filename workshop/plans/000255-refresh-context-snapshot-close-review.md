# Boundary Review — parley.nvim#255 (whole-issue close)

| field | value |
|-------|-------|
| issue | 255 — Use previous completed answers in context during refresh |
| repo | parley.nvim |
| issue file | workshop/issues/000255-refresh-context-snapshot.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..325fcf79740b530c52664123dce1bbd64591cc04 |
| command | sdlc close --issue 255 |
| reviewer | codex |
| timestamp | 2026-09-26T19:49:37-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The existing snapshot behavior passes its tests, but the pinned changes introduce a confirmed regression: submitting again during streaming deletes the active answer and revokes its writer. Refresh documentation also contradicts the new behavior.

1. **Strengths**
   - Snapshot substitution preserves structured content, conversation order, and captured-request immutability.
   - Tests exercise controlled streaming, delayed request building, cancellation, reload, and exchange identity.
   - Previous-answer cleanup is covered at both coordinator and request boundaries.

2. **Critical findings**
   - **`lua/parley/chat_respond.lua:1512–1515` — mutation precedes admission.** After a response emits partial text, submitting the same question again overwrites its previous-answer slot and deletes its live output before checking ownership. This revokes the existing writer instead of refusing the duplicate request. **ARCH-ORDER:** perform admission before mutation, with slot publication and deletion governed by the admitted lifecycle. Add regression coverage for duplicate submissions before and after output, preserving both the writer and original snapshot.

3. **Important findings**
   - **`README.md:74–75`; `atlas/chat/transcript_truth.md:59` — refresh documentation is stale.** README promises the old answer remains visible until replacement output arrives; the implementation now deletes it immediately. The atlas inventory omits the new pre-admission pending-slot lifecycle. Update both to describe the corrected behavior.

4. **Minor findings**
   - None.

5. **Test coverage notes**
   - Pinned `make test-spec SPEC=chat/transcript_truth` passed.
   - Previous-answer unit and coordinator suites passed: **18 tests**.
   - A scratch regression test failed on HEAD with “duplicate submission erased live output.” Restoring only `chat_respond.lua` to BASE made that same test pass.
   - Tests used an isolated pinned archive, excluding uncommitted checkout edits. Process-census verification was unavailable because the harness could not access `ps`. The full suite was not run.

6. **Architectural notes**
   - **ARCH-DRY — pass:** snapshot shaping and substitution remain shared.
   - **ARCH-PURE — pass:** snapshot transformations have direct pure tests.
   - **ARCH-PURPOSE — flag:** duplicate submission breaks the concurrent-refresh guarantees.
   - **ARCH-MOCK — pass:** relevant integration tests use controllable stateful transport and editor fixtures.
   - **ARCH-CONSTRAINTS — pass:** no additional blocking capacity issue established.
   - **ARCH-SECURE — pass:** no new trust-boundary defect established.
   - **ARCH-ORDER — flag:** deletion bypasses admission and revokes another active generation.
   - **ARCH-FUNERAL — pass:** slots have explicit finish, cancellation, reload, and detach cleanup.

7. **Plan revision recommendations**
   - Append a dated `## Revisions` entry to issue #255 describing the pending-slot phase, admission-before-mutation invariant, and duplicate-submit regression coverage. Its current Plan describes slots as existing only under live generation grants.

```findings
findings:
  - id: new
    severity: Critical
    family: mutation-before-admission
    title: |
      Duplicate submission erases a streaming answer before ownership admission
    detail: |
      lua/parley/chat_respond.lua:1512–1515 replaces the previous-answer slot and deletes output before admission. A deterministic scratch test fails on HEAD after partial output, but passes with the BASE chat_respond.lua: the duplicate must preserve the active writer and its text. Route mutation through admitted ownership and cover duplicate submissions before and after output (ARCH-ORDER, ARCH-PURPOSE).
  - id: new
    severity: Important
    family: lifecycle-documentation-drift
    title: |
      README and atlas describe the superseded refresh lifecycle
    detail: |
      README.md:74–75 promises old-answer visibility until replacement output, whereas chat_respond.lua:1515 deletes it immediately. atlas/chat/transcript_truth.md:59 omits pending previous-answer ownership before generation admission. Update both passages to match the corrected lifecycle.
```

---

## Re-review — 2026-09-26T20:24:55-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 255 — Use previous completed answers in context during refresh |
| repo | parley.nvim |
| issue file | workshop/issues/000255-refresh-context-snapshot.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..f77163e9b3dbd997c3c4a66041a7f6ba9b72e347 |
| command | sdlc close --issue 255 |
| reviewer | codex |
| timestamp | 2026-09-26T20:24:55-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior findings are addressed. Duplicate submissions now preserve active output and snapshot ownership, and the documentation matches that lifecycle. However, the broader lifecycle suite has four failures requiring two small corrections before close.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      chat_respond.lua:1494–1505 rejects duplicates before snapshot publication or deletion. All five duplicate regressions pass on HEAD and fail when this guard is removed in a scratch copy.
  - id: BR-2
    disposition: addressed
    note: |
      README.md:74–78 now describes immediate removal on accepted refresh and preservation on duplicate submission. atlas/chat/transcript_truth.md:59 documents pending ownership, adoption, and cleanup, matching chat_respond.lua and document/init.lua.
findings:
  - id: new
    severity: Important
    family: refusal-vocabulary-registration
    title: |
      New identity refusal bypasses the shared refusal vocabulary
    detail: |
      lua/parley/chat_respond.lua:1534 introduces "exchange identity unavailable", which refusal.lua does not recognize; it falls through to the generic unexpected-error message. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing "question identity unavailable" token or register an appropriate explanation and recovery action (ARCH-DRY).
  - id: new
    severity: Important
    family: regression-suite-contract-drift
    title: |
      Existing lifecycle tests still assume the superseded submission timing
    detail: |
      tests/integration/chat_onboarding_capture_spec.lua:43 uses a row removed by immediate refresh, and :105 deletes the following question because its fixed range is now stale. tests/integration/chat_scoped_response_spec.lua:63 expects duplicates to return a session, although they now return nil immediately. All three fail on HEAD and pass with BASE chat_respond.lua restored in scratch. Resolve fixture rows from current content and assert immediate rejection while retaining the writer-preservation checks.
```

1. **Strengths**
   - Duplicate regressions cover waiting, streaming, movement, and marker-boundary edits.
   - Snapshot tests preserve structured answers, exchange identity, and immutable captured context.
   - Pending-answer cleanup covers cancellation, rejected admission, and owner-specific adoption.

2. **Critical findings:** None.

3. **Important findings:** The unregistered refusal and three stale lifecycle tests detailed above.

4. **Minor findings:** None raised.

5. **Test coverage**
   - Lifecycle mapping: **1,015 passed, 4 failed**, across 72 spec files.
   - Transcript-truth mapping passed.
   - Previous-answer tests: **9 pure + 10 integration passed**.
   - Launcher suite: **8 passed**.
   - Removing the duplicate guard caused **all five regressions to fail**.
   - Process-orphan verification was unavailable because the harness could not access `ps`.

6. **Architecture**
   - **ARCH-DRY — flag:** reuse/register the shared refusal vocabulary.
   - **ARCH-PURE — pass:** snapshot transformation remains pure.
   - **ARCH-PURPOSE — pass:** previous-answer substitution covers the intended consumers.
   - **ARCH-MOCK — pass:** controllable stateful transport and proxy fixtures.
   - **ARCH-CONSTRAINTS — pass:** no additional blocking issue identified.
   - **ARCH-SECURE — pass:** launcher ownership checks and isolated fixtures.
   - **ARCH-ORDER — pass:** duplicate admission and cleanup have deterministic sequence coverage.
   - **ARCH-FUNERAL — pass:** pending snapshots have explicit cleanup paths; demo profiles have explicit removal.

7. **Plan revision recommendation:** Append a `## Revisions` entry recording the vocabulary correction and migration of existing lifecycle tests; rerun the lifecycle mapping before close.
