# Boundary Review — parley.nvim#282 (whole-issue close)

| field | value |
|-------|-------|
| issue | 282 — Make each answer one undo history entry |
| repo | parley.nvim |
| issue file | workshop/issues/000282-answer-single-undo.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3c8f38df329673c1830b36489428a1913b6edc6..b213dcf583a7dec4e248e6c0d9a5fc94ffcd895b |
| command | sdlc close --issue 282 |
| reviewer | claude |
| timestamp | 2026-09-28T21:36:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The fix is small and aimed at the right place. The editor already grouped one answer into a single undo block through its private receipt, and the diff removes the two things that were clearing that receipt without changing any text. First, a `:write` changes changedtick, so the editor now accepts the new tick on `BufWritePost` as long as the native undo sequence has not moved. Second, the receipt is now recorded as soon as the writer's own patch lands, before the post-write authority check. I traced the "keep the receipt for a fully-landed plan" rule, and it is safe. Any unexpected or nested edit goes through `observe`, which clears the receipt. If that edit arrives before the patch lands, the loop breaks before `landed` is set. A revoke is only set inside our own `observe`, and the receipt is recorded after that. Nothing here blocks the close. What remains is some missing coverage the Spec asks for, an atlas sentence that overstates the behaviour, and a small autocmd leak.

**Strengths**
- `lua/parley/document/editor.lua:271-283`: the receipt is recorded after the writer's own `observe` and before the revoke check. The final clear at line 296 still drops the receipt for a partial or refused plan and on error, so the existing partial-operation contract holds.
- The save watcher only adopts the new tick when `sequence` is unchanged; otherwise it drops the receipt. Together with `observe` clearing the receipt on any text event, format-on-save and user edits still land as separate undo entries.
- `tests/integration/answer_undo_spec.lua` drives real answers through `chat_respond` with the stateful fixture transport and counts `u`. That is real integration evidence, not mocks. The log also records mutation checks: removing the save watcher turns 4 save cases red, and removing the early receipt turns the tool-round case red.
- ARCH-DRY: `tool_use_sse` moved into `tests/helpers/respond_fixture.lua` instead of being copied into the new spec.
- The sweep-matcher fix for `function X:m` comes with a self-test case.

**Critical:** none.

**Important**
1. **Two cases the Spec names have no tests (ARCH-PURPOSE).** The Spec says "Cover answer replacement, errors, stop/cancel, reload and concurrent chats." Errors, cancel and reload between answers are covered. Answer replacement (regenerating an existing answer) and concurrent chats (two buffers streaming at once, each with its own editor and receipt) are not. The Done-when clause about reload is also only tested between answers, not with a reload in the middle of a stream.
2. **The two new editor rules are only tested end-to-end.** `tests/integration/document_edit_spec.lua:150-176` already tests `can_join_undo` directly against a real buffer. Adding cases there is cheap and would pin:
   - a plan whose after-phase validator revokes returns `stale` and `can_join_undo` is still true;
   - a partial plan (patch 2 of 2 refused) returns false;
   - `:write` keeps it true;
   - `:write` after an undo returns false.

   The integration spec depends on `vim.wait(20)` timing and was flaky once. The Plan row said "unit coverage … if it has one", and this harness is where it belongs.

**Minor**
- `atlas/chat/document.md:128-130` says the receipt "survives refusals and suspensions". The code at `editor.lua:296` clears it on any refused plan where `landed < #patches`, including a no-op refusal of the first patch. The claim is true only for suspensions that happen after a fully-landed plan. Sites in the same family:
  - that atlas sentence;
  - the commit subject of 348f5e92 ("keep the receipt across no-op refusals");
  - Plan item 2, which describes the intent correctly.
- `editor.lua:167`: the `BufWritePost` autocmd is created before `driver.attach`. If attach fails (`:176`), the autocmd leaks, and a retried `attach` adds a second one. Create the watch after a successful attach, or remove it on the failure path.
- The "two answers" test puts a user edit (the new `💬:` line) between the answers, so it does not show that two answers stay separate without an edit in between. Generation/grant separation is probably what guarantees it; a test with no edit between answers would pin that.

**Test coverage notes:** the 7 cases match the Plan's checklist item. The gaps are the Spec's answer-replacement and concurrent-chats cases, and direct editor-level tests of the retention rule and tick adoption.

**Architecture**
- **ARCH-DRY: pass.** The fixture was extracted and nothing is duplicated.
- **ARCH-PURE: pass.** The editor is the IO seam, and the retention decision is one predicate.
- **ARCH-PURPOSE: flag.** See Important #1.

**Plan revision recommendations:** add a `## Revisions` entry that:
- narrows the "keep the receipt across no-op refusals" wording to "fully-landed plans only";
- notes that answer replacement and concurrent chats are either tested or explicitly descoped;
- notes that no fake driver exists, so editor-level coverage goes in `document_edit_spec`.

```findings
findings:
  - id: new
    severity: Important
    family: spec-clause-untested
    title: |
      Spec cases answer replacement and concurrent chats (and mid-stream reload) have no regression test
    detail: |
      Spec says cover answer replacement, errors, stop/cancel, reload and concurrent chats. answer_undo_spec covers errors, cancel and reload between answers only. Missing cases are regenerating an existing answer, two buffers streaming at once, and a reload during a stream.
  - id: new
    severity: Important
    family: contract-pinned-only-end-to-end
    title: |
      Receipt retention (fully-landed stale plan) and BufWritePost tick adoption lack direct editor tests
    detail: |
      document_edit_spec.lua:150-176 already tests can_join_undo directly. Add cases for a revoked-after-last-patch plan (still joins), a partial plan (does not), a write (still joins) and a write after undo (does not). Today only the timing-based integration spec pins these rules.
  - id: new
    severity: Minor
    family: doc-claim-overstates-code
    title: |
      atlas says the receipt survives refusals, but editor.lua:296 clears it on any refused or partial plan
    detail: |
      Instances in this window are the atlas/chat/document.md sentence and the 348f5e92 commit subject. Code keeps the receipt only when every patch landed (suspension after the last patch).
  - id: new
    severity: Minor
    family: resource-leak-on-failed-setup
    title: |
      BufWritePost watch is created before driver.attach and leaks if attach fails
    detail: |
      editor.lua:167 creates the autocmd and :176 returns false without unwatching. A retried attach adds a duplicate. Move the watch after a successful attach.
  - id: new
    severity: Minor
    family: test-confounded-by-setup
    title: |
      two-answers test inserts a user edit between answers, so it does not isolate answer-to-answer separation
```

---

## Re-review — 2026-09-28T21:50:26-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 282 — Make each answer one undo history entry |
| repo | parley.nvim |
| issue file | workshop/issues/000282-answer-single-undo.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3c8f38df329673c1830b36489428a1913b6edc6..cefca4ba14d23e69c0ce0f6582078c12cce80003 |
| command | sdlc close --issue 282 |
| reviewer | claude |
| timestamp | 2026-09-28T21:50:26-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All five findings from round 1 are fixed in `cefca4ba`, and I checked each fix against the code, not the commit message. Regeneration now joins the old answer's deletion through a seeded receipt. The direct editor tests cover the receipt rules that were only pinned end-to-end. The atlas sentence matches the code's rule: the receipt survives only when every patch landed. The save watcher is created only after a successful attach, and detach removes it. The two-answers test now uses a two-question chat, so there is no user edit between the answers.

I ran `answer_undo_spec` three times in a row: 10/10 passed each time. `make test-spec SPEC=chat/document`, which includes `document_edit_spec`, finished with 0 failures and 0 errors. Nothing blocks shipping. Two Minor notes remain.

**Strengths**
- `editor.lua:290-302` records the receipt as soon as the writer's own patch lands, and `:315` keeps it only when `landed == #plan.patches`. The existing partial-operation contract (`document_edit_spec.lua:189`) still holds.
- `can_join_undo` (`editor.lua:215-225`) still requires the native undo sequence and changedtick to match. The seed widens only the grant check, and only for the generation that adopted it. Owner tokens are fresh tables, so one regeneration cannot adopt another's seed.
- The save watcher adopts the new tick only when the undo sequence is unchanged; otherwise it clears the receipt. Detach goes through `lifecycle('detach')`, which unwatches, so it doesn't leak.
- The seed has direct negative tests: not adopted, adopted by the wrong owner, wrong generation, and an edit before the first write.

**Critical:** none.

**Important:** none.

**Minor**
- `document_edit_spec.lua` ("does not join across an undo followed by a save"): the `undo` already clears the receipt in `observe`, so this test can't fail if the watcher's `else self.undo_receipt=nil` branch is removed. This is the 2nd finding in family `test-confounded-by-setup` (BR-5 was the 1st). The rule covering both: a regression test for rule X must fail when only X's code is removed. The setup must not trigger a different mechanism that produces the same outcome. For this case, force a sequence mismatch on the save path only, e.g. a fake driver whose `undo_state` sequence advances.
- `atlas/traceability.yaml:280` maps `answer_undo_spec` under `chat/lifecycle`, but the contract it pins is written in `atlas/chat/document.md`. As a result, `make test-spec SPEC=chat/document` doesn't run it; I confirmed it's missing from that run's log.

**Test coverage notes**
- The mid-stream reload test only checks that at most 10 undos get back to the original text. That fits the "does not corrupt" clause, but it doesn't pin how many steps it takes.
- Every Done-when clause is covered in both of its modes: complete, cancelled and errored answers; separate answers and user edits; reload between answers and mid-stream; chunked streams and tool rounds.

**Architecture**
- **ARCH-DRY: pass.** `tool_use_sse` was moved into the shared fixture, and `writer_folds_spec` now uses it instead of its own copy.
- **ARCH-PURE: pass.** The receipt logic stays in the editor and reaches native undo only through the injected driver (`watch_write`, `unwatch_write`, `undo_state`). The unit tests run against that seam.
- **ARCH-PURPOSE: pass.** Regeneration, the tool-round case that motivated the issue, is delivered rather than deferred.

**Plan revisions:** none needed; the Core concepts table matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      answer_undo_spec adds regenerate, two concurrent chats and mid-stream reload cases; the seed fix is exercised by the regenerate case; 10/10 across 3 runs.
  - id: BR-2
    disposition: addressed
    note: |
      document_edit_spec adds revoked-after-last-patch joins, save keeps join, undo-then-save no join, plus seed cases; partial plan is the existing case at line 189.
  - id: BR-3
    disposition: addressed
    note: |
      atlas/chat/document.md now says the receipt survives only a plan whose every patch landed; matches editor.lua (landed < number of patches clears it).
  - id: BR-4
    disposition: addressed
    note: |
      watch_write is created after the `if not ok` return, and the detach lifecycle unwatches it.
  - id: BR-5
    disposition: addressed
    note: |
      The two-answers case now opens a two-question chat and only moves the cursor between answers.
findings:
  - id: new
    severity: Minor
    family: test-confounded-by-setup
    title: |
      undo-then-save test cannot fail without the BufWritePost sequence-mismatch branch
    detail: |
      Second finding in this family. The undo already clears the receipt in observe, so the test passes even if the else branch in the save watcher is removed. Rule: a regression test for rule X must fail when only X's code is removed. Drive a sequence mismatch on the save path alone, e.g. a fake driver whose undo_state sequence advances.
  - id: new
    severity: Minor
    family: traceability-maps-to-wrong-atlas
    title: |
      answer_undo_spec is mapped under chat/lifecycle although its contract lives in atlas/chat/document.md
    detail: |
      make test-spec SPEC=chat/document does not run the spec that pins the undo-grouping section it documents. Map it under chat/document, or under both.
```

---

## Re-review — 2026-09-28T23:28:01-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 282 — Make each answer one undo history entry |
| repo | parley.nvim |
| issue file | workshop/issues/000282-answer-single-undo.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3c8f38df329673c1830b36489428a1913b6edc6..5ad0ab93d21f3e01c1bbe9f5cfb21bfd4614b333 |
| command | sdlc close --issue 282 |
| reviewer | claude |
| timestamp | 2026-09-28T23:28:01-07:00 |
| verdict | unknown |

## Review

I'll wait for the background test run to notify.

---

## Re-review — 2026-09-28T23:44:02-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 282 — Make each answer one undo history entry |
| repo | parley.nvim |
| issue file | workshop/issues/000282-answer-single-undo.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3c8f38df329673c1830b36489428a1913b6edc6..5ad0ab93d21f3e01c1bbe9f5cfb21bfd4614b333 |
| command | sdlc close --issue 282 |
| reviewer | claude |
| timestamp | 2026-09-28T23:44:02-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

This close gate can pass. Both open findings are fixed, and I found nothing new. The editor change is small and correct. The receipt is now recorded as soon as the writer's own patch lands (`lua/parley/document/editor.lua:274-281`). It is kept only when every patch in the plan landed (`editor.lua:297`). Because `or` binds looser than `and`, the condition reads `not ok or (status~='applied' and landed<#patches)`, which is what's intended. The `BufWritePost` watcher adopts the new tick only when the native undo sequence hasn't moved. It is created only after a successful attach and removed on detach through `lifecycle('detach')`, which `Editor:detach` also calls. The regeneration "seed" is fully gone: nothing in `lua`, `tests` or `atlas` still mentions `seed_undo`, `adopt_undo_seed` or `undo_seed`. The atlas, the `chat_respond.lua` comment, the spec and the revised Done-when all describe the same two-step regeneration undo.

1. **Strengths**
   - Recording the receipt before the post-write authority check (`editor.lua:274-285`) is the smallest fix that covers the tool-block case. It leaves `document_edit_spec`'s partial-plan contract alone.
   - The save watcher uses the native undo sequence to decide, so saving never widens what counts as a join. Every text event still clears the receipt in `observe` (`editor.lua:72`) and in `lifecycle` (`editor.lua:137`).
   - `answer_undo_spec` drives real answers through `chat_respond` with the stateful fixture transport and counts `u` presses. Each Done-when clause gets its own case: saves, tool rounds, separate answers, regeneration in two steps, concurrent chats, reload before and during an answer, cancel, and provider failure.
   - Moving `tool_use_sse` into `tests/helpers/respond_fixture.lua` removes the copy in `writer_folds_spec` (ARCH-DRY).
   - Side fix: two specs no longer write into the repo. `packaging_boot_spec` now checks that the repo's `workshop/parley` is unchanged after launch, and that check fails without the `cwd` fix.

2. **Critical:** none.

3. **Important:** none.

4. **Minor:** none raised. In the issue file, the `## Log` "closed" line still says one `u` restores the old answer after regeneration. The `## Revisions` entry correctly overrides that, and log lines are append-only, so it isn't a finding.

5. **Test coverage**
   - The direct editor cases in `document_edit_spec` cover: joining after a fully-landed plan whose authority was revoked afterwards, joining across a save, and no join after an undo followed by a save.
   - The last of those is now honestly described as covered by `observe`, not by the watcher.
   - The regeneration case checks both undo steps: first the cleared state, then the old answer.

6. **Architecture**
   - **ARCH-DRY: pass.** The SSE builder is shared, and the tick-adoption logic exists in one place.
   - **ARCH-PURE: pass.** The IO sits behind the driver seam (`watch_write`/`unwatch_write` in `native()`), and the join decision stays in `can_join_undo`.
   - **ARCH-PURPOSE: pass.** Every Done-when clause, including the revised regeneration behaviour, is delivered and tested.

7. **Plan revisions:** none needed. The `## Revisions` entry already records the removed seed and the two-step regeneration undo.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      The unreachable else branch was removed from the BufWritePost watcher (editor.lua:195-197). The test comment at document_edit_spec now says observe clearing the receipt and the sequence check in can_join_undo cover it, not the watcher. No watcher branch is left that the test would need to exercise.
  - id: BR-7
    disposition: addressed
    note: |
      atlas/traceability.yaml now lists answer_undo_spec under chat/document (line 424) as well as chat/lifecycle (line 280).
```
