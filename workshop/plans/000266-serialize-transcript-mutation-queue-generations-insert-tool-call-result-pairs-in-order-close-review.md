# Boundary Review — parley.nvim#266 (whole-issue close)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0f6ee4d4d50869803bc41664548dd1bbdeabea69..21c5f3d042025ba52fa6395a839d85c6851b474c |
| command | sdlc close --issue 266 |
| reviewer | claude |
| timestamp | 2026-09-18T15:17:32-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All nine open findings (BR-7, 8, 12, 14, 20–24) are disposed: eight are fixed at HEAD, and BR-14 is withdrawn because M3 removed its cause. The core design holds up against the code. A pure per-document write turn serializes writes, and a pure `ToolSequence` orders each tool round. The generation machine is one explicit transition function, including the new `flushing` phase. The flush early-exit list in `tool_use.md` matches every `stop()` reachable from `flushing` in `generation.lua`. HEAD passes its own suites:
- chat/ownership: 276 tests, 0 failures.
- `make test-unit JOBS=4`: 213/213 files pass.
- `make -k test-integration JOBS=4`: 161/163 files pass. The two failures, `document_fold_retirement_spec` and `perf_document_spec`, were killed by a timeout under parallel load, with no failing assertion. Both pass when run alone, and neither file is touched by this branch.

There is one new Minor finding, confirmed with a scratch test: an output write erases the tools status note (details below). It doesn't block the gate, but it should be fixed before the close.

**1. Strengths**
- **The disjointness guard is real.** `document_state_spec.lua:110-154` runs 40 seeded runs of 80 real transitions and checks after every step that live grants don't overlap (`tests/helpers/grants.lua`). In a scratch copy I made human edits stop revoking grants (`state.lua:260`), and the test failed. It catches the bug class it guards against, not just the transitions as written.
- **Stop's round-writing is one explicit phase.** `generation.lua:134-151,207-221,474-476`: it cancels on the spot only a tool that never started, and waits for evidence that a started one actually settled. So what gets written reflects what happened, not timing.
- **Both "cancelled before it ran" cases are tested at the transcript.** `response_tools_spec.lua:465-490` drives the runner-refused case and the scheduler-queued case all the way to the rendered result text.
- **The wait-note composer can't produce a note without an exit.** `chat_presentation.lua:57-60` asserts that every note names `:ParleyStop` (a command that ends the wait).
- **The turn-change notification compares the holder's value.** `document/init.lua:329-337` checks the holder before and after instead of listing event kinds, so `finish_generation` can't silently miss a wake-up.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **A text write erases the tools note (4th in family `stall-visibility`).** This is the 4th finding in family `stall-visibility`: the fix belongs at the rule, not this one instance.
  - **Rule:** a wait note is state, not an event. Show it again after anything that clears the status line.
  - **What clears the status line:** output write receipts (`response_session.lua:195-196` → `chat_pending.lua:166-170`, which also drops any pending progress update). Provider progress is already suppressed while a note is set. The playful spinner is inactive once released.
  - **Scratch test:** answer B has text and two tool calls and is held behind answer A. After A finishes, B's text and its first call block land while both tools still run, and no status extmark exists. Re-showing `s.note` after `written` makes "Running tools: 0 of 2 finished" appear.
  - **Worst case:** every outcome arrived while B was held and one cleanup hangs. B holds the turn and shows nothing, while every other answer reads "Waiting for the answer to line N (running tools)".
  - **Docs this contradicts:** `response_progress.md` ("While the round runs, the status line counts them") and `tests/manual/chat-concurrency.md` ("shows only in the pending line").
  - **Test gap:** the BR-17 test exercised the composer's strings, not the composed session.
- The extmark-reading helper `notes()` is copy-pasted three times in `response_session_spec.lua` (:170, :227, :276). Hoist it (ARCH-DRY, test code only).

**5. Test coverage notes**
- Every fix that changes behavior now has a test at the composition level, not only at the seam that changed (BR-22, BR-24).
- BR-20's fix removed code that could never be reached, so it needs no new test.
- The one untested composition is the note described above. The scratch test (held answer with text and tools, note checked after the turn arrives) is the regression test to add.

**6. Architectural notes**

| Principle | Result |
|---|---|
| ARCH-DRY | Pass, apart from the test-helper nit |
| ARCH-PURE | Pass: `write_turn` and `sequence` are pure and unit-tested without IO |
| ARCH-PURPOSE | Pass: the slot list, `writable`, nesting and capacity tickets are gone, and an arch guard keeps them out |
| ARCH-MOCK | Pass: the fake producers sit behind the real producer seam |
| ARCH-CONSTRAINTS | Pass: 1 MiB held-output budget from measurement, coalesced items, cheap checks run before snapshots |
| ARCH-SECURE | N/A: no new untrusted input or secrets |
| ARCH-ORDER | Pass: the `flushing` transitions go through the machine and the 24-permutation sweep covers them. The note lifecycle in `response_session` is the one piece of event-driven state that isn't modelled, which is exactly where the finding lives |
| ARCH-FUNERAL | Pass: the turn-wanted weak map is cleared on finish, release and reload; frozen rounds are cleared by `continue_round` or `close` |

**7. Plan revision recommendations**
- A `## Revisions` entry for the close round recording the note-persistence fix and its test. Nothing else: the plan matches the code.

```findings
dispose:
  - id: BR-7
    disposition: addressed
    note: |
      README:50-52 now says "finishes or pauses"; plan Target reconciliation strikes the lifetime/undo-entry sentences with a pointer to ownership.md; the family grep over README, atlas and target finds no live residual.
  - id: BR-8
    disposition: addressed
    note: |
      Plan :459 struck with its Chunk-2 note, and :461 now reads "why Chunk 2 (the preparation deferral) exists".
  - id: BR-12
    disposition: addressed
    note: |
      Operator decision logged 2026-09-18 ("Stop flushes the tool round, it does not drop it"), implemented in M3; the target revision "the gap closed" replaces the narrowing.
  - id: BR-14
    disposition: withdrawn
    note: |
      Overtaken by M3's operator decision: an unknown outcome releases its claims once its process ends (operation.lua:103-108, scheduler.lua:80-87), the self-quarantine refusal text is gone, and every tools note names :ParleyStop via wait_note. A new visibility gap in the same family is raised separately.
  - id: BR-20
    disposition: addressed
    note: |
      insert_tool carries no outcome (generation.lua:125-127), the runner passes only ctx.failure/ctx.result (generation_runner.lua:518-522), settled() takes two parameters, and plan mechanism (3) is struck by a Revision.
  - id: BR-21
    disposition: addressed
    note: |
      README:73-77 now points at tool_use.md#stop-during-a-tool-round instead of paraphrasing what a Stop writes.
  - id: BR-22
    disposition: addressed
    note: |
      response_tools_spec:479-490 drives the queued-in-scheduler case through the runner and asserts the rendered "Tool cancelled before execution" result text.
  - id: BR-23
    disposition: addressed
    note: |
      Plan :88 struck with a pointer to the M4 Revision; no `parent` identifier remains in generation_runner, response_tools or state; lessons.md:3137-3152 states the sweep scope once, with terms taken from the diff.
  - id: BR-24
    disposition: addressed
    note: |
      document_state_spec:110-154 checks disjointness after each of 80 steps over 40 seeds. In a scratch copy, planting "human edits revoke nothing" at state.lua:260 made it fail; document_write_plan_spec gains the same assertion.
findings:
  - id: new
    severity: Minor
    family: stall-visibility
    title: |
      An output receipt erases the tools note, so an answer that gets the turn after being held shows no status while its tools run or clean up
    detail: |
      This is the 4th finding in family stall-visibility, so the fix is the rule, not the instance. Rule: a wait note is state, not an event; re-show it after anything that clears the status line. What clears it: output write receipts (response_session.lua:195-196 calls s.pending:written, which hides the extmark and drops any pending progress update, chat_pending.lua:166-170); provider progress is already suppressed while s.note is set, and the playful spinner is inactive once released. changed() re-presents only when the note string changes (response_session.lua:211), so s.note stays set while nothing shows. Confirmed with a scratch integration test: answer B (text plus two tool calls) held behind A; after A finishes, B's text and its first call block land, both tools still run, and the parley_chat_pending namespace has no extmark. Re-showing s.note after written makes "Running tools: 0 of 2 finished" appear. Worst case: all outcomes arrived while B was held and one cleanup hangs; B holds the turn and shows nothing while every other answer reads "Waiting for the answer to line N (running tools)". This contradicts atlas/chat/response_progress.md ("While the round runs, the status line counts them") and tests/manual/chat-concurrency.md ("a tool still running shows only in the pending line"). The BR-17 test exercised the composer's strings, not the composed session; add the held-answer case to response_session_spec as the regression test.
```
