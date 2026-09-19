# Boundary Review — parley.nvim#261 (milestone M2)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | fc64a19462482f8a3291023691d2a37f3ae111e4..b9b6f6c73dbaf70dd2a57e8278887e54a1782ac8 |
| command | sdlc milestone-close --issue 261 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-19T01:56:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M2 delivers what #255 asked for. A regenerating exchange's previous answer is held on the document coordinator. It is valid only while its generation holds a live grant, and it is substituted in the same tick the command reads the chat. The same substitution feeds a sub-chat's ancestors, read from the parent's loaded buffer. Only human edits now mark captured input stale.

I checked the work directly rather than trusting the Log:
- **Tests:** the 8 M2 spec files pass, 243 cases. At `JOBS=4` the unit suite passes (213 files). The integration suite passes except `highlighting_spec` and `perf_document_spec`. Both stopped mid-run with no failing assertion, and both pass alone (13 s and 30 s), so they fit the #267 load family the Log already records.
- **Lint:** clean on all 12 touched files.
- **Counterfactuals, in a scratch copy made with `git archive`:** removing the parent substitution turns the sub-chat test red, as claimed.

Two Important findings stop this short of SHIP:
1. A test the plan requires for Task 2.6 was never written. The code it would guard has no coverage: I made `move_chat_tree` ignore loaded buffers entirely, and all 10 specs that reach it still pass.
2. `chat_lines` fixes the `bufnr(path)` partial-match defect at 1 of 5 sites. The 4 left include a confirmed buffer-loss bug in `system_prompt_picker`.

**1. Strengths**
- `lua/parley/previous_answer.lua` is pure and small. One `substitute` serves both the same-chat request and the ancestor chain (ARCH-DRY). It returns the same table when there is nothing to substitute, and resets `answer.line_start` so `build_messages` includes the substituted answer.
- The slot's lifecycle is read off `State.holds` rather than stored as a separate flag, so it cannot drift from grant authority. Every `finish_generation` goes through `D.transition` (verified: `generation_runner.lua:531,593`, `response_topic.lua:37`). Reload and detach wipe the slot table, and `_previous_count` lets a test prove a slot was removed rather than merely filtered out.
- The ordering the plan names as most likely mishandled — lines read mid-stream, `build()` run after the regeneration ends — has a test that holds `build` and calls it after completion. That test controls the interleaving instead of sampling one.
- Reading the raw payload from `input_parsed` fixes a real pre-existing batch-leg bug, and a batch-leg test pins it.
- `document_dependency_affinity_spec` was updated with the reversed rule stated in the test.

**2. Critical findings**
None.

**3. Important findings**
- **The Task 2.6 test for a loaded move target is missing, and the Log doesn't say so** (`lua/parley/init.lua:3800`, `tests/integration/chat_move_spec.lua`).
  - The plan's Step 1 asks for: "the branch-link rewrite at `init.lua:3798`, with the target loaded: the buffer is rewritten, and the file is not written under it." No such test exists.
  - My counterfactual forced `live=false` and `readfile`, which writes the file under the live buffer and never updates the buffer. All 10 specs that reach `move_chat_tree` still pass.
  - The two sub-chat cases also differ from the plan: they call `_collect_ancestor_messages` directly instead of submitting in the child chat C.
  - The Log says "Tasks 2.1–2.6 landed as planned", and its deviation list names neither gap.
  - This is the second finding in family `plan-step-not-as-specified`. The rule that covers both: before `milestone-close`, match every Step-1 test bullet to a named test in the diff or to a Log deviation. A bullet with neither blocks the close. Add that rule to `workshop/lessons.md`, and add the loaded-target test.
- **The `bufnr(path)` defect is fixed at one of five sites** (ARCH-DRY / ARCH-PURPOSE).
  - The plan and `chat_lines`' docstring both say `bufnr(path)` is a file-pattern match and can return the wrong buffer.
  - Only `init.lua:3798` was converted. `init.lua:4405` and `:4428` (the child-topic write after a prune), `outline.lua:407` and `system_prompt_picker.lua:83` still use it.
  - Verified on nvim 0.11.7:
    - `bufnr("…/chat.md")` returns a loaded `chat.md.bak` buffer.
    - `bufnr("parley://system_prompt/foo")` returns the `…/foobar` buffer. `system_prompt_picker.lua:85` then force-deletes it, so opening prompt `foo` discards unsaved edits in `foobar`'s editor.
  - This is the fourth finding in family `enumeration-claims-completeness`. The plan's consumer list for `chat_lines` has no query, although the plan's own header says every enumeration must carry one. The rule that covers all four: any list of sites a change must cover comes from a query recorded next to it. When the class is a primitive, that query becomes an arch guard.
  - Fix:
    - Split the resolved-name lookup out of `chat_lines`, e.g. as `helper.buffer_for(name)`.
    - Route the four sites through it.
    - Add an arch spec, like `json_decode_spec`, that fails any `vim.fn.bufnr(<arg>)` outside the helper.

**4. Minor findings**
- `atlas/chat/lifecycle.md` says "A regeneration's writes… never mark them stale". The code (`state.lua` `generated`), `ownership.md` and `document.md` exempt every generation's owned writes, including a first answer's and topic header writes. A request captured while a first answer streams took partial text, and its tool rounds now continue without the stale pause. State the broader rule, and why that capture is also final ("already captured is unaffected").
- The Done-when item "several exchanges regenerating at once each use their own previous answer" is tested only at the coordinator. `substitute` with two entries, and a request carrying both old answers, are untested. The behavior is correct (probed), just not pinned.
- In the "substitutes at capture" test, `Respond.resolve_remote_references` is stubbed and restored outside a protected call. A timeout in `wait_for` would leak the stub into every later test in the file. `with_json_yaml`, just above it, already restores its stub through `pcall`.

**5. Test coverage notes**
- Task 2.3 has one coordinator case per ARCH-ORDER row. The Task 2.4 and 2.5 integration cases drive ordering through the fixture's `output`/`complete` controls.
- The stale-rule test goes red on revert: without the fix, the continuation never arrives.
- The `chat_lines` tests G1–G4 include the partial-name case (G3).
- Gaps: the two noted above (the loaded move target, and multi-entry substitution).

**6. Architectural notes for upcoming work**
- ARCH-ORDER:
  - A slot stays valid for as long as its generation holds a grant. A generation that is stopped, or paused on stale input, keeps serving the old answer until it reaches `terminal`.
  - Before M3/M4, a hung stopped runner therefore keeps serving the old answer indefinitely, while the transcript shows the partial one.
  - M4's end-to-end tests should assert the slot drains once a stopped generation settles.
- `set_previous_answer`'s `false` is dropped at `chat_respond.lua:1546`. That is harmless today, because it can only be false when the generation is already ending. If M3/M4 change when preparation runs relative to acquire, the mid-stream test is the only thing that would catch it.
- Principles with no finding: ARCH-PURE (the core is pure, and tests use no IO or mocks); ARCH-MOCK (no new external dependency); ARCH-CONSTRAINTS (at most 4 slot lookups per submission, one extra deep copy only when a slot exists, and O(buffers) name resolution per ancestor level, off the keystroke path); ARCH-SECURE (no new untrusted input or secrets); ARCH-FUNERAL (slots live in memory, are bounded by live generations, and die with their generation, reload or detach).

**7. Plan revision recommendations**
- Add a `## Revisions` entry for M2 recording:
  - that Task 2.2 did not lift `parsed_chat` into a shared helper;
  - that the Task 2.6 sub-chat tests use the `_collect_ancestor_messages` seam;
  - either the added loaded-target move test, or a withdrawal of that bullet with a reason;
  - that the `chat_lines` consumer list was an enumeration without a query, plus the swept sites and the guard.
- Tick Task 2.1–2.7 steps at close, as M1 did in its close commit.

```findings
findings:
  - id: new
    severity: Important
    family: plan-step-not-as-specified
    title: |
      Task 2.6's loaded-target move_chat_tree test is missing, and the Log claims the task landed as planned
    detail: |
      The plan requires a test that the branch-link rewrite at init.lua:3798, with the target loaded, rewrites the buffer and does not write the file under it. No such test exists. Counterfactual: forcing live=false plus readfile in move_chat_tree (write the file under the live buffer, never update the buffer) leaves all 10 specs reaching move_chat_tree green. The sub-chat cases also call _collect_ancestor_messages instead of submitting in C, and neither gap is in the Log's deviation list. Second finding in this family. Rule: before milestone-close, every Step-1 test bullet maps to a named test in the diff or to a logged deviation, and a bullet with neither blocks the close. Add the test and put the rule in workshop/lessons.md.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      chat_lines fixes the bufnr(path) partial-match defect at 1 of 5 sites; 4 remain, one confirmed to destroy a buffer
    detail: |
      Still using bufnr(<name>): init.lua:4405 and 4428 (child topic after a prune), outline.lua:407 and system_prompt_picker.lua:83. Verified on nvim 0.11.7: bufnr of parley://system_prompt/foo returns the foobar buffer, which line 85 force-deletes, discarding its unsaved edits. The plan's consumer list for chat_lines carries no query, against its own header rule. Fourth finding in this family. Rule: a site list comes from a recorded query, and a primitive-class query becomes an arch guard. Split the exact-name lookup out of chat_lines, route all four sites through it, and add a guard failing any vim.fn.bufnr(arg) outside the helper.
  - id: new
    severity: Minor
    family: rule-statement-scope-drift
    title: |
      lifecycle.md scopes the stale exemption to a regeneration; the code exempts every generation's owned writes
    detail: |
      state.lua exempts any other generation's write inside its own live grant, including a first answer and topic header writes, as ownership.md and document.md say. A request captured mid-stream of a first answer took partial text, and its tool rounds now continue without the stale pause. lifecycle.md's rationale (the previous answer stays valid) does not cover that case; state the broader rule and why that capture is final.
  - id: new
    severity: Minor
    family: done-when-clause-untested
    title: |
      Several exchanges regenerating at once are pinned only at the coordinator, not in substitution or a request
    detail: |
      document_previous_answer_spec lists two slots, but no test runs previous_answer.substitute with two entries, or a request carrying both old answers. The behavior is correct when probed; add one pure two-entry case.
  - id: new
    severity: Minor
    family: stub-restored-outside-finally
    title: |
      The capture-then-late-build test restores its resolve_remote_references stub outside a protected call
    detail: |
      A timeout in wait_for(held) leaks the stub into every later test in chat_respond_spec. with_json_yaml in the same file already restores through pcall.
```
