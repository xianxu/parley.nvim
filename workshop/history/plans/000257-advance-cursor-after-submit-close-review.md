# Boundary Review — parley.nvim#257 (whole-issue close)

| field | value |
|-------|-------|
| issue | 257 — Advance cursor to the next question after submission |
| repo | parley.nvim |
| issue file | workshop/issues/000257-advance-cursor-after-submit.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0b5a2a2af2bfde1cbe9b6b52bdfd22bcbcb8b227..00acc2daa8a288fede4d2670b6a4c7908085b393 |
| command | sdlc close --issue 257 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T09:59:12-07:00 |
| verdict | REWORK |

## Review

Reviewing the diff now — checking how the submitted exchange is resolved versus the index used for the cursor advance.

Still reviewing — locating how to run one spec so I can reproduce a suspected cursor bug.

Running a probe test for a suspected bug (cursor in header submits the last exchange but jumps to question 1).

Probe confirmed the bug. Checking the other callers and the respond-all path.

```verdict
verdict: REWORK
confidence: high
```

The main feature works. One synchronous move at admission, a pure `next_question_cursor` helper, glue in `advance_after_submit`, and a test for nearly every Plan bullet. The Stop picker change is small and has its own test. One correctness bug blocks SHIP, and I reproduced it with a probe spec. When the cursor sits outside every exchange, for example in the header, `start_scoped_response` submits the **last** exchange (`frame.exchange_idx or #parsed.exchanges`). But `respond` passes `exchange_idx or 0` to the advance, so the cursor jumps to **question 1**, an unrelated exchange. The Spec says the cursor should stay put when there is no next question.

Done-when: stale — it does not mention the Stop rule change added in `## Revisions` (with the cursor on no response, one running response in the chat is stopped directly with no picker). That is a new user-visible behavior that no Done-when clause covers.

**1. Strengths**
- `next_question_cursor` (`lua/parley/chat_respond.lua:1971`) is pure, with a direct unit case that covers both the normal prefix and an empty trailing `💬:`.
- The move is one synchronous step after admission (`chat_respond.lua:2196`), so nothing can move the cursor later. The cancel test pins this.
- Follow-cursor precedence needed no new state: the existing `last_cursor` check in `written` (`chat_respond.lua:1886-1891`) stops following once the cursor moves. The no-next-question test confirms following still works.
- Respond-all calls `start_scoped_response` directly (`chat_respond.lua:2269`), so it never advances, as the Plan says.
- The Stop change keeps the picker for two or more running responses, and the stale-picker test was updated to keep exercising it (`chat_stop_generation_spec.lua:69-82`).

**2. Critical**
- `lua/parley/chat_respond.lua:2196`: the advance uses `exchange_idx or 0`, but the exchange actually submitted is `frame.exchange_idx or #parsed.exchanges` (`chat_respond.lua:1552`).
  - **Reproduced:** body `{'💬: first','','🤖: a1','answer one','','💬: second',''}`, cursor at `{1,0}`, `submit()`. The cursor ended at row 5 (`💬: first`). The response is for `second`, which has no next question, so the cursor should have stayed at row 1.
  - **Fix:** have `start_scoped_response` return or record the index it resolved, and pass that to `advance_after_submit`. Add the probe above as a regression test.
  - **Family (`advance-target-diverges-from-submitted`):** this is the only place in the window where the advance works out its own target instead of reusing the submitted one.

**3. Important**
- Done-when is stale for the Stop rule change (Revisions 2026-10-16; `chat_respond.lua:1498-1501`). Add a clause such as: "With the cursor on no running response, Stop stops the single running response directly; two or more open the picker."

**4. Minor**
- ARCH-DRY: `advance_after_submit` (`chat_respond.lua:1990-1994`) repeats the get-lines → `find_header_end` → `parse_chat` sequence. The same sequence is at `chat_respond.lua:1611-1615`, and `parley.chat_context.resolve` already owns it. Reuse one of them.
- The Plan says "one parse per submit, already done on that path" (ARCH-CONSTRAINTS). That is wrong: the advance always adds a full parse of the buffer, and the replaced-answer path already parses a second time.
- Insert-mode submit: `respond` calls `stopinsert`, which only takes effect after the command finishes. Leaving insert mode may then move the cursor one column left, from after the prefix onto the space. No test covers it.

**5. Test coverage**
- Done-when names normal, insert and visual submission. Normal and visual have tests; insert has none.
- The "deleting or inserting exchanges around the handoff" clause is backed only by the mid-chat resubmit test. Nothing tests a cursor outside any exchange, which is how the Critical bug got through.
- Reload has no test. The synchronous design makes a late move impossible, so this is acceptable.

**6. Architecture**
- **ARCH-PURE: pass.** The logic is in a pure helper with a thin glue function around it.
- **ARCH-DRY: flag (Minor),** the repeated parse described above.
- **ARCH-PURPOSE: flag,** via the Critical: the advance must use the same exchange the submission actually used. Once `start_scoped_response` exposes its resolved index, the advance cannot drift from it.

**7. Plan revisions**
- Add to `## Revisions`: "The advance uses the exchange index that `start_scoped_response` resolved (including the default to the last exchange), not the index found under the cursor." Correct the ARCH-CONSTRAINTS parse-count claim.
- Add the Stop rule clause to `## Done when`.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: advance-target-diverges-from-submitted
    title: |
      Cursor outside any exchange: submit answers the last exchange but the cursor jumps to question 1
    detail: |
      chat_respond.lua:2196 passes `exchange_idx or 0` to advance_after_submit, but start_scoped_response (line 1552) submits `frame.exchange_idx or #parsed.exchanges`. Reproduced: body {'💬: first','','🤖: a1','answer one','','💬: second',''}, cursor {1,0}, submit leaves the cursor on row 5 ('💬: first') instead of row 1. Fix: pass the index start_scoped_response resolved and add this case as a regression test. This is the only instance in the window.
  - id: new
    severity: Important
    kind: defect
    family: done-when-covers-revisions
    title: |
      Done-when does not cover the Stop rule change from Revisions
    detail: |
      Revisions 2026-10-16 changes stop_at_cursor (chat_respond.lua:1498-1501): with the cursor on no running response, one running response is stopped without a picker, and two or more still open it. No Done-when clause covers this user-visible behavior. Add one.
  - id: new
    severity: Minor
    kind: defect
    family: arch-dry-chat-parse-sequence
    title: |
      advance_after_submit repeats the lines, header, parse sequence owned by chat_context.resolve
    detail: |
      chat_respond.lua:1990-1994 repeats chat_respond.lua:1611-1615 and parley.chat_context.resolve. The Plan's claim of one parse per submit (ARCH-CONSTRAINTS) is also wrong: the advance always adds a full parse.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-clause-both-modes
    title: |
      Insert-mode submission path has no test
    detail: |
      Done-when names normal, insert and visual paths, but only normal and visual are tested. Because stopinsert takes effect after the command, leaving insert mode may shift the cursor one column left onto the space after the prefix.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2fd79742-b523-4252-8b0b-90d491214d60","repository":"github.com/xianxu/parley.nvim","issue_id":"000257","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e9d81bb657f94a7f","reviewed_head":"00acc2daa8a288fede4d2670b6a4c7908085b393","slot":"parley.nvim:3","requested_at":"2026-10-16T16:57:01.347265Z"},"phase":"finished","pid":30975,"started_at":"2026-10-16T16:57:01.716646Z","finished_at":"2026-10-16T16:58:59.667685Z","session_id":"cdee0a18-2be4-441e-976a-ef36fc27d3af","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T10:26:39-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 257 — Advance cursor to the next question after submission |
| repo | parley.nvim |
| issue file | workshop/issues/000257-advance-cursor-after-submit.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0b5a2a2af2bfde1cbe9b6b52bdfd22bcbcb8b227..d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1 |
| command | sdlc close --issue 257 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T10:26:39-07:00 |
| verdict | SHIP |

## Review

I'm checking how the insert-mode respond keymap is wired, to confirm the Insert-mode cursor fix is reachable.

Running the two touched spec files to confirm they pass at head.

The system make is too old for `--eval`, so I'm writing a small makefile wrapper to run the specs instead.

```verdict
verdict: SHIP
confidence: high
```

All four findings from round 1 are fixed, and I confirmed each fix with a check that runs. For BR-1, one value (`submitted`, chat_respond.lua:2197) now picks both the exchange that gets answered and where the cursor goes. When I put back the old `exchange_idx or 0`, the new regression test failed. For BR-4, removing the Insert-mode column adjustment made the new Insert-mode test fail. I also added temporary tests that copy the real `<C-g><C-g>` handlers (the `:ParleyChatRespond` command, then `stopinsert`, then `<Esc>`) in both Normal and Insert mode. Both landed the cursor right after `💬: `, and I deleted those tests afterwards. Both changed spec files pass at head (`chat_respond_spec` and `chat_stop_generation_spec`). The two new findings are Minor and neither blocks.

1. **Strengths**
   - The submitted exchange and the cursor target come from one value (chat_respond.lua:2197-2204), which rules out the BR-1 kind of mismatch.
   - The re-parse now goes through `chat_context.parse` (chat_respond.lua:1992), so the shared "read lines, find header, parse" sequence still has one owner.
   - `next_question_cursor` is a pure function and has a direct unit test with no IO, covering a next question, an empty `💬:` prompt and no next question.
   - The cursor moves once, in the same step as admission, and nothing schedules a later move. A test checks that cancelling doesn't move it again.
   - The Stop change is tested both ways: one running response is stopped without a picker, and the stale-picker test now runs two and asserts the picker shows 2 items.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Drill-in submissions now move the cursor away from the new turn.** The drill-in path (chat_respond.lua:2111) puts the cursor on the newly inserted turn on purpose, "so … post-stream cursor moves land on the new turn". The advance then moves it to the next question below, which is one of the older exchanges that come after the drill-in, and follow stops. No test covers drill-in plus advance. The fix is to decide which behavior is wanted, then either skip the advance when `branch_handled` is set or pin the current behavior with a test. Within this window, drill-in is the only submission path that sets the cursor before admission.
   - **The Plan's signature doesn't match the code.** The Plan says `next_question_cursor(parsed, index, config)`, but the code is `(parsed, index, lines, prefix)` (chat_respond.lua:1971). This is the only such drift.

5. **Test coverage**
   - The Done-when clauses for normal, insert and visual submission, follow-cursor on and off, and the one-running versus several-running Stop rule are each tested in both states.
   - "Deleting or inserting exchanges around the handoff" is covered by the case where submitting mid-chat removes the old answer. Because the move happens in the same step, no edit can come between admission and the move.

6. **Architecture**
   - ARCH-DRY: pass. The parse sequence goes through `chat_context`.
   - ARCH-PURE: pass. The pure `next_question_cursor` is kept separate from the thin `advance_after_submit` glue.
   - ARCH-PURPOSE: pass. Every `respond` submission path gets the advance, and Resubmit All is excluded as specified. The drill-in question above is a scope decision, not a deferred purpose.

7. **Plan revisions:** add a Revisions entry fixing the `next_question_cursor` signature, and record the drill-in decision.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      chat_respond.lua:2197 one `submitted` index feeds both; reverting to `exchange_idx or 0` turns the new regression test red.
  - id: BR-2
    disposition: addressed
    note: |
      Done-when gained the Stop clause; tested both ways (direct stop with one running, picker with 2 items in the stale-picker case).
  - id: BR-3
    disposition: addressed
    note: |
      advance_after_submit now parses via chat_context.parse; Revisions corrects the one-parse claim.
  - id: BR-4
    disposition: addressed
    note: |
      Insert-mode test added and fails when the adjustment is removed; a temporary copy of the real keymap handler also landed after the prefix.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: advance-target-diverges-from-submitted
    title: |
      Drill-in submissions move the cursor off the new turn, against that path's stated intent; untested
    detail: |
      chat_respond.lua:2111 puts the cursor on the inserted turn so post-stream moves land there; the advance then moves it to an older exchange below and follow stops. Decide: skip the advance when branch_handled is set, or pin it with a test. Only instance in this window.
  - id: new
    severity: Minor
    kind: defect
    family: plan-signature-drift
    title: |
      Plan gives next_question_cursor(parsed, index, config); code is (parsed, index, lines, prefix)
    detail: |
      chat_respond.lua:1971. Add a Revisions entry. Only instance in this window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"26998e50-f281-449b-beaf-6df38f45e6f7","repository":"github.com/xianxu/parley.nvim","issue_id":"000257","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/73dd6a9a8d0e683f","reviewed_head":"d4f4a10f3ed14a1719e822cb26ef28d40ad8e3c1","slot":"parley.nvim:3","requested_at":"2026-10-16T17:23:15.520438Z"},"phase":"finished","pid":18145,"started_at":"2026-10-16T17:23:15.882689Z","finished_at":"2026-10-16T17:26:35.292932Z","session_id":"75e428af-cdd3-4c65-8c60-5a2a5d77986b","outcome":"returned"}] -->
