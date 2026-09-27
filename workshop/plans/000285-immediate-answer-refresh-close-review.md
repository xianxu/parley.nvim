# Boundary Review — parley.nvim#285 (whole-issue close)

| field | value |
|-------|-------|
| issue | 285 — remove stale answer immediately on re-ask |
| repo | parley.nvim |
| issue file | workshop/issues/000285-immediate-answer-refresh.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..a7745f8074f318c07a79b130b7ccc59dace2e12b |
| command | sdlc close --issue 285 |
| reviewer | codex |
| timestamp | 2026-09-26T16:53:46-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The immediate-removal and concurrent previous-answer behavior is implemented and covered for ordinary text answers. However, the new deep-copy boundary leaves stale tool-call answer blocks in re-ask payloads, causing incorrect provider context and potentially invalid tool-result references.

1. Strengths

- `lua/parley/chat_respond.lua:1502-1514` removes the visible answer before readiness/remote work.
- Pending snapshots remain available through `D.previous_answers(doc)`.
- `lua/parley/chat_respond.lua:1591-1600` clears pending snapshots on terminal completion.
- Existing integration coverage passed for immediate removal and concurrent context (`chat_respond_spec.lua`, 42 cases).
- Atlas/README changes in the broader range cover the unrelated user-facing surfaces introduced there.

2. Critical findings

- `lua/parley/chat_respond.lua:1501,1563-1570,1698-1701` — `input_parsed` is now a deep copy, so `exchange.answer = nil` only clears `parsed`, not the payload source. For a re-asked exchange whose answer contains `content_blocks` with `tool_use` or `tool_result`, `build_messages` includes that stale answer (`chat_respond.lua:959-970`). The replacement request can therefore resend obsolete tool calls/results after the visible answer was removed. Clear the target answer in `input_parsed` too, or construct the input snapshot after the target answer is removed. Add a regression test that fails without the fix.

3. Important findings

- `lua/parley/chat_respond.lua:1591-1600`; `tests/integration/document_previous_answer_spec.lua:44-50` — production cancellation and failed-admission paths are not regression-tested. The current test exercises the helper directly, not the response lifecycle. Add integration cases proving cancellation and admission failure clear the pending snapshot.

4. Minor findings

- None.

5. Test coverage notes

`make test-spec SPEC=chat/transcript_truth` completed the relevant refusal and chat response suites successfully (19 and 42 cases). `SPEC=chat_respond` is not a valid mapping. The broader `chat/document` suite was still running when review concluded.

6. Architectural notes

- ARCH-DRY: Pass.
- ARCH-PURE: Pass; document memory remains separated from response IO.
- ARCH-PURPOSE: Flagged by the critical stale-tool-context finding; ordinary text is covered, but tool-block re-asks are not.
- ARCH-MOCK: Pass; no new external dependency.
- ARCH-CONSTRAINTS: Pass; no unbounded work introduced.
- ARCH-SECURE: Pass; no new credential or untrusted-persistence surface.
- ARCH-ORDER: Flagged; command-time clearing and later payload construction can observe inconsistent answer state.
- ARCH-FUNERAL: Pass; pending in-memory snapshots have terminal cleanup paths.

7. Plan revision recommendations

- Add a `## Revisions` entry documenting the required invariant that the re-ask payload excludes the target exchange’s prior answer, including tool-call content blocks.
- Add explicit production-lifecycle regression coverage for cancellation and failed admission.

```findings
findings:
  - id: new
    severity: Critical
    family: resubmit-capture-excludes-target-answer
    title: |
      Re-ask payloads can retain stale tool-call answer blocks
    detail: |
      `input_parsed` is deep-copied before `exchange.answer = nil`, so target answers containing tool_use/tool_result blocks remain eligible for inclusion in `build_messages`; clear the target answer in the payload snapshot and add a regression test.
  - id: new
    severity: Important
    family: pending-snapshot-terminal-path-coverage
    title: |
      Production cancellation and admission cleanup lack regression coverage
    detail: |
      The new lifecycle cleanup is tested only through direct document helpers, not through response cancellation or failed admission; add integration tests that prove no pending snapshot survives either path.
```

---

## Re-review — 2026-09-26T17:00:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 285 — remove stale answer immediately on re-ask |
| repo | parley.nvim |
| issue file | workshop/issues/000285-immediate-answer-refresh.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..e712650097a98fd5182e260a1c3bd9000632a28f |
| command | sdlc close --issue 285 |
| reviewer | codex |
| timestamp | 2026-09-26T17:00:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The primary refresh behavior and cancellation cleanup are implemented and focused tests pass, but the boundary is not ready: prior findings BR-1 and BR-2 lack the required regression evidence, and pending snapshots are not safely owned across overlapping re-asks.

1. Strengths

- Immediate answer removal occurs before readiness/remote work in `lua/parley/chat_respond.lua:1496-1514`.
- Concurrent context preservation is exercised by existing integration coverage.
- Cancellation cleanup is tested through the production path in `tests/integration/chat_respond_spec.lua:151-159`.
- The document lifecycle helper correctly removes pending slots on explicit cleanup and detach/reload.
- Focused tests passed: chat response suite, 43 cases; document previous-answer suite, 9 cases.

2. Critical findings

- `lua/parley/chat_respond.lua:1511`, `lua/parley/chat_respond.lua:1597-1599` — pending snapshots are keyed only by entity, and cleanup clears any `generation == nil` slot. If re-ask B starts while re-ask A is still active, B overwrites the entity’s pending slot; when A completes, A’s `release()` can clear B’s snapshot before B is admitted. Give each pending capture an owner/token and clear only the matching owner. `ARCH-ORDER`, `ARCH-FUNERAL`.

3. Important findings

None beyond the unresolved prior findings below.

4. Minor findings

- `lua/parley/chat_respond.lua:1516` computes `footer` and immediately overwrites it at line 1529; remove the dead assignment. This also causes the repository lint warning.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The target answer is cleared from input_parsed, but no regression test exercises a re-ask containing tool_use/tool_result blocks; the required behavior-changing evidence is absent.
  - id: BR-2
    disposition: not-addressed
    note: |
      Production cancellation now has integration coverage, but failed-admission cleanup still has no regression test, so the finding is only partially addressed.
findings:
  - id: new
    severity: Critical
    family: pending-snapshot-generation-ownership
    title: |
      Overlapping re-asks can clear another attempt's pending snapshot
    detail: |
      The pending slot is stored by entity with generation=nil and release clears by entity plus nil generation; an earlier response can therefore retire a later response's snapshot before its generation adopts it. Add per-attempt ownership/token matching and an overlapping re-ask regression test. ARCH-ORDER, ARCH-FUNERAL.
  - id: new
    severity: Minor
    family: dead-intermediate-assignment
    title: |
      Footer result is overwritten before use
    detail: |
      The assignment at lua/parley/chat_respond.lua:1516 is overwritten at line 1529; remove it to restore a clean lint run.
```

5. Test coverage notes

`make test` did not reach the test suite because lint failed on the dead assignment warning. Direct focused runs passed: chat response, 43 cases; document previous-answer, 9 cases. No regression tests cover tool-block exclusion or failed admission cleanup.

6. Architectural notes for upcoming work

- ARCH-DRY: Pass.
- ARCH-PURE: Pass; document lifecycle logic remains separated from response IO.
- ARCH-PURPOSE: Flagged by the missing BR-1/BR-2 evidence; the committed fixes do not fully prove the stated lifecycle contract.
- ARCH-MOCK: Pass; no new external dependency seam.
- ARCH-CONSTRAINTS: Pass; no new unbounded fan-out identified.
- ARCH-SECURE: Pass; no new trust or credential boundary.
- ARCH-ORDER: Flagged; pending ownership is not explicit across overlapping response events.
- ARCH-FUNERAL: Flagged through the same ownership race; cleanup can retire the wrong pending artifact.

7. Plan revision recommendations

Add a `## Revisions` entry documenting:

- pending snapshot ownership per response attempt, including overlapping re-asks and late completion ordering;
- regression coverage for tool-call payload exclusion;
- regression coverage for failed admission cleanup.

---

## Re-review — 2026-09-26T20:25:17-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 285 — remove stale answer immediately on re-ask |
| repo | parley.nvim |
| issue file | workshop/issues/000285-immediate-answer-refresh.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..f77163e9b3dbd997c3c4a66041a7f6ba9b72e347 |
| command | sdlc close --issue 285 |
| reviewer | codex |
| timestamp | 2026-09-26T20:25:17-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The four prior findings are addressed, with regression evidence. Immediate removal, concurrent context, and duplicate protection work in the focused tests. Two Important issues remain: an unregistered refusal token and an existing test that still expects asynchronous duplicate rejection. The lifecycle test command fails.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      chat_respond_spec.lua:160 verifies stale tool calls/results are absent. Removing the payload-snapshot clearing in memory makes this regression fail at line 174.
  - id: BR-2
    disposition: addressed
    note: |
      Production cancellation and source-edit admission rejection have coverage. Removing pending cleanup in memory makes the rejection regression fail at chat_respond_spec.lua:190 with one orphaned snapshot.
  - id: BR-3
    disposition: addressed
    note: |
      Owner checks prevent mismatched clearing/adoption; duplicate submissions are rejected before mutation across five tested phases. Disabling owner matching in memory makes document_previous_answer_spec.lua:70 fail.
  - id: BR-4
    disposition: addressed
    note: |
      The initial footer value now bounds deletion before reassignment. make lint passes with zero warnings and errors across 656 files.
findings:
  - id: new
    severity: Important
    family: refusal-producers-use-shared-vocabulary
    title: |
      New refusal token is absent from the shared vocabulary
    detail: |
      lua/parley/chat_respond.lua:1534 emits exchange identity unavailable, which lua/parley/refusal.lua does not register. tests/arch/refusal_vocabulary_spec.lua:117 fails. Reuse the existing question identity unavailable token or register actionable wording. ARCH-DRY.
  - id: new
    severity: Important
    family: regression-tests-follow-public-contract
    title: |
      Existing duplicate-submission test contradicts the new admission contract
    detail: |
      tests/integration/chat_scoped_response_spec.lua:63 requires a non-nil second session and later cancellation, but chat_respond.lua:1504 now rejects synchronously. Update the expectation to immediate refusal while retaining assertions that no second provider call occurs and the original writer completes.
```

1. **Strengths**

   - Payload clearing covers structured tool content, with a regression that demonstrably fails without the fix.
   - Duplicate tests preserve output and previous-answer memory during waiting, streaming, and question movement.
   - README and lifecycle atlas describe immediate removal and pending ownership.
   - Launcher tests exercise competing launch/reset operations deterministically.

2. **Critical findings:** None.

3. **Important findings:** The two failures above must be resolved before rerunning the boundary review.

4. **Minor findings:** None raised.

5. **Test coverage**

   - Response integration: **52 passed**.
   - Previous-answer document integration: **10 passed**.
   - Launcher: **8 passed**.
   - Lint: **passed**.
   - `make test-spec SPEC=chat/lifecycle`: **failed**, including both reported failures.
   - Three in-memory mutation checks made the corresponding BR-1/BR-2/BR-3 regressions fail; repository source remained unchanged.
   - Process census was unavailable because the harness could not use `ps`.

6. **Architecture**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | **Flag:** refusal producer bypasses the shared vocabulary. |
   | ARCH-PURE | **Pass:** formatting logic remains separate from editor and transport effects. |
   | ARCH-PURPOSE | **Pass:** immediate removal and concurrent previous-answer context are delivered. |
   | ARCH-MOCK | **Pass:** response ordering uses controllable transport fixtures; launcher races use stateful fixtures. |
   | ARCH-CONSTRAINTS | **Pass:** no new unbounded background concurrency identified. |
   | ARCH-SECURE | **Pass:** launcher ownership/path checks and isolated test storage remain intact. |
   | ARCH-ORDER | **Pass:** owner matching and pre-mutation duplicate rejection have ordering coverage. |
   | ARCH-FUNERAL | **Pass:** pending snapshots and reservations have terminal cleanup paths. |

7. **Plan revisions:** No scope revision needed. Update verification evidence after correcting both failures and rerunning the lifecycle tests.
