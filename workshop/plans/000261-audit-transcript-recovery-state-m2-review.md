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

---

## Re-review — 2026-09-19T02:12:56-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | fc64a19462482f8a3291023691d2a37f3ae111e4..9549f86333f886cf19890f2be4516fbea57d98b8 |
| command | sdlc milestone-close --issue 261 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-19T02:12:56-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All five prior findings are fixed, but the test that replaces BR-25's withdrawn bullet claims something false. M2 does what #255 asked: a regenerating exchange's previous answer is held on the document coordinator, substituted into same-chat and sub-chat context, and only human edits now mark captured input stale. Four of the five fixes check out, including the BR-26 sweep, which I confirmed goes red when reverted. The BR-25 withdrawal itself is sound: the move rewrite really can't fire, and #270 now tracks it. The stand-in test, "a tree move leaves a loaded chat's unsaved text and its file alone", only passes because its buffer is a scratch `nofile` buffer that can't be written. With a real file-backed chat buffer the claim is false. The move saves the buffer first, parley's save hook renames the file to its topic slug, and `move_chat_tree` then aborts with ENOENT. The fix is cheap and doesn't block the gate. Note: I accidentally detached HEAD with a `git checkout` of the head commit and reattached the branch right away; no files changed.

**1. Strengths**
- **BR-26 fixed for every site.** `helper.buffer_for` (`lua/parley/helper.lua:696`) is now the one exact-name lookup, and all five sites use it.
  - I grepped `lua/` for every function that matches buffer names as patterns (`bufname`, `bufwinnr`, `bufwinid`, `getbuf*`/`setbuf*`, `vim.call`, `vim.fn[...]`). `vim.fn.bufnr(<name>)` was the only one in use, so the sweep is complete.
  - Counterfactual: restoring `vim.fn.bufnr(buf_name)` in `system_prompt_picker.lua` turns both P4 and `tests/arch/buffer_lookup_spec.lua` red.
- **Continuation rounds can't mix answers.** `continue_round` copies the frozen `ctx.previous_input.messages` (`response_tools.lua:186-205`) and never re-reads the buffer. A tool-using request's later rounds therefore carry the same Q1 context as round 1, as the new atlas rule says.
- **Row matching is safe.** Batch legs re-read and re-parse the buffer in the same tick as `start_scoped_response` (`chat_respond.lua:1958-1977`), so substitution rows always match the document's current rows.
- **BR-27's wording now matches the code.** In `state.lua`, `owner` is nil unless its grant is valid and contains the edit, which is the "inside its own grant" rule `lifecycle.md` now states.
- **Checks I ran:**
  - Every M2 spec passes (chat_respond 42/42, generation_turn 36/36, plus the outline, ancestor, topic_gen and affinity specs).
  - luacheck is clean on all 12 touched files.
  - `buffer_for` costs about 0.11 ms per call over 200 buffers, so the new outline use is fine.

**2. Critical findings**
None.

**3. Important findings**
- **The BR-25 stand-in test pins a property of its fixture, not of production** (`tests/integration/chat_move_spec.lua:121-135`).
  - `create_chat` builds the "loaded chat" with `nvim_create_buf(false, true)`, a scratch buffer. `sync_moved_chat_buffers` (`init.lua:3146`) runs `silent! write` on a modified chat buffer before moving it. On a scratch buffer that write fails silently, so the file looks "left alone".
  - Reproduced with the same test, only swapping in `bufadd` + `bufload`:
    - the write fires;
    - parley's save hook renames `…_tree-root.md` to `…_move-test.md`;
    - `os.rename` fails with "No such file or directory", and the tree move aborts.
  - Without the edit, the move succeeds.
  - That abort predates this window, but the new test asserts the opposite of it.
  - This is the second finding in family `stateless-double-at-stateful-seam`. The rule covering both: a test's stand-in must have every behavior the code under test branches on. A chat buffer is a file buffer: `write` succeeds on it and fires parley's hooks. Build stand-ins the way production does, not with a named scratch buffer.
  - How common it is: 14 spec files name a scratch buffer as a chat, but only `chat_move_spec` also runs a code path that writes.
  - Fix:
    - Use a file-backed buffer in this test.
    - Record the ENOENT repro in #270, or file a new issue.
    - Either assert what the move actually does, or delete the stand-in so no test claims this property. Also correct the Log line "a characterization test stands in".

**4. Minor findings**
- The guard's regex catches only the first `vim.fn.bufnr(` on a line, and only when the call fits on one line. That's acceptable given there are no offenders today.
- P4 restores the window layout and deletes its buffers after its assertions, so a failure leaks a split window. This matches P1 and P2 in the same file and restores no stub.

**5. Test coverage notes**
- Every Step-1 bullet in Tasks 2.1–2.6 now maps to a named test or a recorded deviation: the helper-lift, the `_collect_ancestor_messages` seam, and the withdrawn loaded-target bullet.
- BR-28's two-entry case passes its entries out of order, so it also pins conversation order.
- The Task 2.5 integration test could also assert that `calls[3]` still carries `old one`. That holds by construction, since continuations copy the frozen input.

**6. Architectural notes for upcoming work**
- **ARCH-DRY: pass.** `buffer_for` is the one lookup and `chat_lines` builds on it. A single `substitute` serves both the same-chat and ancestor paths.
- **ARCH-PURE: pass.** `previous_answer` and `holds` are pure and tested without IO.
- **ARCH-PURPOSE: flag.** This is the Important finding above: the BR-25 stand-in is the easy subset of what it replaces. Every #255 Done-when clause is otherwise covered.
- **ARCH-MOCK: pass.** No new external dependency.
- **ARCH-CONSTRAINTS: pass.** The `buffer_for` cost is measured and negligible.
- **ARCH-SECURE: pass.** No new untrusted input or secrets.
- **ARCH-ORDER: pass.** The slot has two states and its validity is derived at read time. There is one test per table row, and the capture-then-late-build test controls the ordering itself.
  - Carried forward: `set_previous_answer`'s `false` is still dropped (harmless today).
  - Carried forward: a stopped but hung runner keeps serving the old answer until M3/M4.
- **ARCH-FUNERAL: pass.** Slots live only in memory, at most one per exchange. A revoked slot's copy lingers only until the next read, reload or detach.
- The class of pattern-matching buffer lookups is wider than `bufnr`. The guard can't check the others statically, because their number-argument forms are legitimate.

**7. Plan revision recommendations**
- Amend the 2026-09-19 M2 revision:
  - the stand-in characterization holds only for a scratch buffer;
  - a real chat buffer with unsaved text is saved before the move, and a save that triggers the slug rename aborts the move with ENOENT;
  - point to where that defect is tracked.

```findings
dispose:
  - id: BR-25
    disposition: addressed
    note: |
      Bullet withdrawn with a verified reason (a timestamped ref resolves to the moved file, so ref_abs==old_abs never matches), parley#270 filed, sub-chat seam deviation logged, lessons rule added. The stand-in test is raised separately.
  - id: BR-26
    disposition: addressed
    note: |
      All 5 sites use helper.buffer_for. A grep for every bufname-style primitive finds no other offenders. Reverting the picker lookup turns P4 and the arch guard red.
  - id: BR-27
    disposition: addressed
    note: |
      lifecycle.md now states the rule for every generated write and why an earlier capture is final. This matches state.lua, where owner must be a valid grant containing the edit.
  - id: BR-28
    disposition: addressed
    note: |
      A pure two-entry substitute test with out-of-order entries now pins conversation order.
  - id: BR-29
    disposition: addressed
    note: |
      The resolve_remote_references stub is restored after a pcall-wrapped wait. No other stub in this window's tests is restored outside a protected call.
findings:
  - id: new
    severity: Important
    family: stateless-double-at-stateful-seam
    title: |
      The BR-25 stand-in test passes only because its chat is a nofile scratch buffer; with a real chat buffer the tree move saves it and aborts with ENOENT
    detail: |
      chat_move_spec create_chat uses nvim_create_buf(false, true), so the silent! write in sync_moved_chat_buffers (init.lua:3146) fails silently and the file looks untouched. Reproduced with bufadd plus bufload: the write fires, the save hook slug-renames tree-root.md to move-test.md, and os.rename fails with No such file or directory, aborting move_chat_tree. That abort predates this window, but the new test asserts the opposite. Second in this family. Rule: a test stand-in must have every behavior the code under test branches on; build chat buffers the way production does, not as a named scratch buffer. Prevalence: 14 spec files name a scratch buffer as a chat, and 1 (chat_move_spec) also runs a writing path. Fix: use a file-backed buffer, record the ENOENT repro in parley#270 or a new issue, and either assert the real behavior or delete the stand-in. Also correct the Log line saying a characterization stands in.
  - id: new
    severity: Minor
    family: enumeration-claims-completeness
    title: |
      buffer_lookup_spec matches only the first vim.fn.bufnr call on a line, and only when the call fits on one line
    detail: |
      There are no offenders today. The wider class of name-matching functions (bufwinnr, bufwinid, bufname, getbufvar) cannot be checked statically, because their number-argument forms are legitimate. The rule is the BR-24 one: a guard selects members by the class property. Here the property can only be checked by spelling, so record that limit in the guard's header comment.
```
