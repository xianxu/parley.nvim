# Boundary Review — parley.nvim#266 (milestone M1)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 0f6ee4d4d50869803bc41664548dd1bbdeabea69..29e317b747445741636c24dad9746842004686c1 |
| command | sdlc milestone-close --issue 266 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-17T19:53:17-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 is a large, unusually well-executed piece of work: the write turn is a genuinely pure decision (`write_turn.lua`) driven by the reducer, `draining` and `gap` are enumerated states rather than boolean pairs, the release matrix is exercised across four real-runner interleavings plus a self-scheduled wake, the held-output budget is measured (n=359) and its item-cap gap was found by driving the test at the provider's real SSE granularity, and the undo-coherence test was made to fail without the mechanism. Atlas is rewritten across seven pages and the target carries a Revision narrowing "in the order the reader sees them" honestly. What blocks SHIP is one ordering defect the plan itself predicted and then dropped: `release_turn` travels as a queued effect, and `generation_runner.lua:411`/`:433` dispatch `pause` from *inside* `execute` and then park the same effect in `s.pending` — so on the documented stale-input tool-continuation flow the paused holder keeps the document's write turn indefinitely, blocking every other generation's writes until the operator resumes or stops it, while the waiter's status line says "(writing)". I verified the suite: `chat/ownership` (27 files), `chat/lifecycle` (61 files) and `chat/document` (32 files) are all 0 failed / 0 errors when run sequentially; a `make -k test JOBS=4` run aborted `perf_chat_typing_spec`, `perf_document_spec` and `document_fold_batches_spec` with no assertion output, and all three pass under their sequential keys — the known parallel-load flake, not a regression.

## 1. Strengths

- **`lua/parley/document/write_turn.lua:15-26`** — the turn decision is a genuinely pure function with a no-IO unit spec, including the numeric-vs-lexical ordering case that guards the `'g'..serial` assumption three plan revisions carried. Textbook ARCH-PURE.
- **`tests/integration/generation_turn_spec.lua:295-342`** — the undo-coherence test alternates *single* runner steps and asserts no entry mixes generations and none is a partial slice. The `## Log` records that its first version was vacuous under batched steps and was reworked until it failed without the turn; that counterfactual discipline is exactly right and is now a lesson (`workshop/lessons.md`).
- **`lua/parley/generation.lua:264-283` + `generation_runner.lua:26-34,216-238`** — output coalescing. The plan's byte budget alone would have killed a held answer after a paragraph (256-item cap × one item per SSE delta); finding that by driving 600 real deltas, then bounding by bytes with a parts list joined once on read, is the strongest ARCH-CONSTRAINTS work in the diff.
- **`lua/parley/document/init.lua:357-366`** — notifying on the turn *value* rather than an event-kind list, with `State.turn` added as an O(1) accessor so the comparison does not double an already-expensive `copy`. `document_turn_wake_spec.lua:53-64` pins the `finish_generation` case a per-event list would have silently excluded, and `:76-97` pins reentrancy for the first notify ever fired from inside `M.transition`.
- **`lua/parley/generation.lua:39-53`** — one `may_write` predicate gating all three write-producing emissions (output, `reserve_round`, `finalize`), so the deferred gap cannot be outrun by any of them. `tests/unit/generation_spec.lua:700-790` covers each of the three independently.

## 2. Critical findings

**C1 — `lua/parley/generation_runner.lua:411` (and `:433`): `release_turn` is head-of-line blocked by the effect that caused the pause, so a paused generation holds the write turn indefinitely.**

`execute` dispatches `{type='pause'}` and then returns `true,'waiting'`, so `M.step` (`:551`) sets `s.pending=effect`. The machine's `pause` handler (`generation.lua:409-410`) emits `release_turn`, which `dispatch` appends to the tail of `s.queue`. Every subsequent `M.step` takes `s.pending` first (`:551`), re-enters the `continue_round` branch, hits `if phase=='paused' then return true,'waiting'` (`:415`), and parks again — so the queued `release_turn` is never reached.

Concrete failure: user submits Q1 (tool-using); while its tools run they edit an earlier question; the round completes, `continue_round` sees `stale_input` with no stale policy and pauses (the flow README documents at lines 55-61). The user then submits Q2. Q2's provider request starts, but every Q2 write is refused `'waiting'` until Q1 is resumed or stopped — Q2's output accumulates toward the 1 MiB budget and can `overflow`. The waiting note reads *"Waiting for the answer to line N (writing)"* because `chat_presentation.lua:51-52` has no `paused` entry, so the user is not told that the block needs `:ParleyChatResumeResponse`.

This is the exact hazard the plan named ("Release must not travel as a queued effect… a parked effect head-of-line-blocks the whole FIFO… **Issue release synchronously from `sync`**", plan line 434). That step is marked `[x]`; the prescription was dropped when the operator decision removed the *suspension* release rows, but the stale-continuation pause row still parks.

A second, subtler consequence: when the operator finally resumes, `resume_validated` emits `request_turn` behind the still-queued `release_turn`, so the sequence executes as release-then-request *after* the generation is already writing again — handing the turn to a waiter mid-round and splitting the resumed generation's contiguous run, which is the guarantee `workshop/targets/transcript-is-the-whole-truth.md` was just revised to defend.

Fix sketch: apply `release_turn`/`request_turn` outside the write FIFO (e.g. in `M.step`, drain queued turn effects before `s.pending`, or call `D.transition` directly at the pause site), **preserving revoke-before-release** — `stop()` (`generation.lua:79-80`) deliberately emits `revoke` first and `generation_spec` pins that order, so an unconditional "apply turn effects at enqueue" would reintroduce the `'overlap'` regression recorded in the Log. Regression test: two runners, A holding the turn, drive A to a stale-input `continue_round` pause, assert `D.turn(doc)` moves to B and B's held output lands.

## 3. Important findings

**I1 — plan/code drift on the turn guard's polarity and on the release mechanism, both marked `[x]`.** `workshop/plans/000266-serialize-transcript-mutation-plan.md:401-405` still prescribes `return generation~=nil and turn~=generation -- FAIL-CLOSED` and argues for it in bold; `:434` still prescribes `s.turn_status='waiting'` and a synchronous release from `sync`. The code is fail-*open* (`document/init.lua:39-41`, `turn~=nil and turn~=generation`), defaults `turn_status='held'` (`generation.lua:211`), and queues the release. The reversals are recorded in the issue `## Log` but not in the plan's `## Revisions`, and the steps are ticked. Chunks 3-4 will be executed from this plan.

**I2 — `lua/parley/response_session.lua:136-145`: the deferred-gap writer can return without settling `done`, leaving the machine's `gap` permanently `'writing'`.** Two paths: `if not op then failed(reason);return end` never calls `done`; and `Preparation`'s `retire(s,'cancelled',…)` (`response_preparation.lua:44-63`) calls neither `cb.prepared` nor `cb.failed`, so `done('applied')` never fires. `may_write` is then false forever — no output, no round, no finalize, and no error. Today every such path also stops the generation, so this is latent rather than live; the cost of closing it is one `done('cancelled')` on the `not op` branch and passing `done` through the cancelled retire.

**I3 — no test pins "a provider failure before the first byte leaves the transcript unchanged."** `generation.lua` `pump` emits `write_gap` (line 144-147) and *then* `stop(…,'provider_failed')` (line 157) in the same pass; the header is only spared because `generation_runner.lua:448` re-checks `phase=='stopping'` before invoking the writer. The issue `## Log` advertises this as a visible consequence useful to parley#261, and `response_session_spec.lua:117` covers only the *cancel* variant. Move the `write_due` gap check below the `provider_failed` stop, or add the failure variant of that spec.

**I4 — cross-generation tool *execution* is now serialized behind the holder's full lifetime, and the obligation to restore it is recorded only in prose.** `pump` gates `reserve_round` on `may_write` (`generation.lua:173-176`), so a second generation's tools cannot start until the first terminates — the Spec says "concurrency belongs in scheduling and execution, never in mutation" and "tool calls execute in parallel". The deferral is declared (plan Revisions, issue Log, `atlas/providers/tool_execution.md:32-34`), but the issue's `## Plan` M2 row says only "ordered `(call, result)` append; removes capacity tickets…" — the "M2 must re-add a cross-generation execution assertion" obligation, and the `tool_execution.md` sentence that must be reverted with it, are not checklist items anywhere. Add them to M2 (ARCH-PURPOSE: a follow-up that is part of the stated purpose needs a place that will be checked).

**I5 — `lua/parley/document/init.lua:521-525`: `M.apply` pays a full `State.snapshot` deep copy per write chunk to evaluate an O(1) guard.** `M.replace_new` (`:475`), `M.insert_released_new` (`:490`) and `Replacement.step` (`replacement.lua:143-148`) all test the O(1) `State.turn` first; `M.apply` — reached once per ≤4096-byte append, the hottest write path — does the snapshot unconditionally and only then the cheap test. `state.lua:15-30`'s `copy` is a recursive visitor with per-field assertions. Swap the order: `if turn_waiting(s,plan.generation) then <snapshot to confirm ownership> … end`. (No measured regression — `perf_ownership_spec` passes — but the diff itself establishes the convention and this is the one site that breaks it.)

## 4. Minor findings

- `atlas/providers/tool_use.md:291` still reads "disjoint draft edits **and sibling generations** can continue" — true about invalidation scope, but a reader takes it as concurrent writes; the issue names this page in its shadow-sweep.
- `chat_presentation.lua:51-52` `waiting_reasons` has no `paused` entry, so a paused holder renders as "(writing)" — the one stall shape that needs a different verb (`:ParleyChatResumeResponse`, not `:ParleyStop`). See C1.
- `generation_runner.lua:120-126` `overflow_reason` rebuilds the "the answer to line N" phrasing that the plan assigned to `chat_presentation.waiting_message`, and duplicates the `marker.start_row+1` derivation done in `response_session.lua:198-200` (ARCH-DRY).
- Three variants of the same "owns the grant and holds the turn" predicate: `init.lua:39-41` (turn only), `init.lua:521-524` (ownership then turn), `replacement.lua:145-147` (inline, ownership-aware). One helper on `State` would serve all three (ARCH-DRY).
- The waiting note shares `chat_pending`'s single progress slot with provider detail and is latched by `note~=s.note` (`response_session.lua:202`), so once a reasoning delta overwrites it the note is never re-asserted. The stall cases that matter (holder hung, waiter in `draining`) are unaffected.
- `init.lua:560-562`: `append` tests the turn before confirming the grant belongs to `intent.generation`, unlike `M.apply`; a mismatched pair would get a retryable `'waiting'` instead of an ownership rejection. Unreachable today, but it is the exact failure the `## Log`'s finding #1 describes.
- `tests/integration/generation_turn_spec.lua:334`: `assert.is_nil(D.turn(doc)==…generation or nil)` is an obfuscated way to assert a boolean is false.
- README.md's concurrency paragraph (lines 50-71) is unchanged; users will now observe a second answer's text arriving in one batch after the first finishes, the answer header appearing with the first output rather than at submit, and a regenerated answer surviving until replacement bytes exist. One or two sentences there would close the gate cleanly (no new command or flag, so this is a Minor, not the README gate proper).

## 5. Test coverage notes

Coverage is strong and mostly asserts real behavior rather than restating implementation: `document_state_spec` covers the reducer's turn algebra including hand-over, re-queue, unknown generation and snapshot-copyability; `generation_spec` covers the machine's emissions, the `draining` edges, coalescing refusals and the whole gap lifecycle; `generation_turn_spec` covers coordinator refusal per entry point, the release matrix across four interleavings on real runners, the self-scheduled wake (the only shape that can observe a *missing* wake), the byte budget with its message, and undo coherence on a real buffer; `response_session_spec` covers the composed deferral end to end including "the transcript is byte-identical when cancelled before output".

Gaps, in priority order: (a) the C1 interleaving — nothing drives a pause *from a parked effect* and asserts the turn actually moves at the document; `generation_spec` asserts only that the machine *emits* `release_turn`, which is precisely the oracle ARCH-ORDER warns about (a green machine-level test that reports no coverage of the runner's FIFO); (b) I3's provider-failure-before-first-byte; (c) the three pause rows in the turn matrix are covered at machine level only, with the comment at `generation_turn_spec.lua:176-179` deferring them to `chat_async_tools_spec`/`chat_stop_generation_spec` — both of which were *restated* in this diff to avoid cross-generation writes, so neither still exercises a pause while another generation waits for the turn.

Two restatements reduce coverage in ways worth tracking: `chat_stop_generation_spec.lua:196-201` now completes b before asserting a continues (b is no longer a concurrent transport, which was the point of the spec), and `chat_async_tools_spec.lua:180-196` collapses two rounds into one (path-scoped admission within a round, not across generations). Both are declared, and both are the M2 obligation in I4.

## 6. Architectural notes

- **ARCH-DRY** — flag (Minor): three spellings of the turn predicate; the "answer to line N" wording duplicated between the runner and `chat_presentation`. Otherwise good: `turn_status` mirrors the document exactly as `grant_status` already did, and `WriteTurn` is one source for the holder decision.
- **ARCH-PURE** — pass. The decision is pure (`write_turn.lua`), the reducer is pure, `may_write`/`write_due` are pure, and the IO shell (`blocker`, `present`, `overflow_reason`) sits in the runner. `waiting_message` is pure and unit-tested. No "pure" entity needs a mock to run.
- **ARCH-PURPOSE** — flag (I4). M1 fulfils the generation half of the Spec including option (b) — the operator explicitly rejected the cheaper "exempt preparation from the turn" and took the deferral instead, which is the right call on this axis. The shadow-sweep over atlas consumers is done except `providers/tool_use.md:291`. The deferred piece (cross-generation tool execution) is a real property of the Spec, not a separable extension, and needs a checklist home.
- **ARCH-MOCK** — pass. No new external dependency; existing stateful doubles reused (`fake_generation_runner`, `fake_document_editor`, `fake_process` for the end-to-end path), and production and test flows share the same boundary.
- **ARCH-CONSTRAINTS** — mostly pass, one flag (I5). The budget is declared with a measured basis (p50 573 B / p99 36.4 KB / max 116.7 KB over n=359) and a defined behavior at the bound that a test drives; the 16-runner × 1 MiB = 16 MiB ceiling is stated rather than hand-waved; the item-cap discovery is exemplary. The unbounded stall is operator-mediated and the plan accepts that *only because it is visible* — C1 plus the `paused` verb gap weaken that justification precisely where it matters.
- **ARCH-SECURE** — pass. `N/A` is correctly claimed and holds: no new parsing of input the process did not produce, no credential path, no new external surface. The turn is an in-memory ordering decision.
- **ARCH-ORDER** — flag (C1, I2). This is the entry the issue is about and most of it is done well: `draining` and `gap` are tagged enumerations with transitions tested from each state (cancel, revoke, stale from `draining`; failure and never-written from `gap`), production state changes go through the reducer, and the wake test uses a real scheduler so it can observe an ordering the author did not choose. Two flags: the machine's `turn_status` defaults to `'held'` before `request_turn` has executed — a representable state that contradicts its name, safe today only because `start` emits `request_turn` ahead of the `prepare` effect in the same FIFO; and the queued-release defect in C1, which is the "error/cancellation path that unwinds the sequencing but drops the in-flight effect" case verbatim.
- **ARCH-FUNERAL** — pass. `turn_wanted` is weak-keyed beside the state (with the reason documented) and collected by `finish_generation`, `release_turn` and the shared reload/detach branch; `op.tail`/`b.parts` die with their blobs; preparation grants left live by the deferral are revoked by `finish_generation`'s sweep over the generation's grants. Nothing durable is created. The one watch item is `chat_respond.lua:1555-1563`'s `operation.unproved` subscription — removed on proof and on cancel, but it is a new document subscriber whose removal depends on one of two callbacks firing.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000266-serialize-transcript-mutation-plan.md` (timestamp + reason + delta) covering, at minimum:

1. **"Fail-closed reversed to joint enforcement."** Tasks 1.4 Step 3 and 1.5 Step 3 still prescribe `turn~=generation` and `s.turn_status='waiting'` with a bold rationale for fail-closed; the code is `turn~=nil and turn~=generation` with `turn_status='held'`. State the measurement (96 → 9 failures), state the joint invariant (a) every generated writer requests before writing + (b) the coordinator refuses non-holders, and name the residual assumption so a later reader knows what breaks it.
2. **"Release travels as a queued effect, not synchronously from `sync`."** Task 1.5 Step 3's synchronous-release prescription was dropped with the suspension rows, but the stale-continuation pause at `generation_runner.lua:411`/`:433` still parks. Record the decision *and* the remaining hazard (C1) — or, if C1 is fixed by restoring the synchronous release, record that instead and re-tick the step accurately.
3. **"M2 obligations."** Promote to the issue's `## Plan` M2 row: re-add a cross-generation tool-execution assertion, and revert `atlas/providers/tool_execution.md:32-34`'s "first waits for the write turn" sentence when `begin_round` stops writing.
4. **Housekeeping:** Task 1.10's final `[x] sdlc milestone-close --issue 266 --milestone M1` is ticked even though the merged-boundary decision moved that close to Chunk 2 Task 2.3, which also pre-ticks it. One of the two should be struck with a reason, per the convention already used for the superseded steps.

---

## Re-review — 2026-09-17T20:16:37-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 0f6ee4d4d50869803bc41664548dd1bbdeabea69..62ed365f7cc271544dc5a33e9bac8760a59420d9 |
| command | sdlc milestone-close --issue 266 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-17T20:16:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 does what it says: one generation writes to a document at a time, and requests still run in parallel. The round-1 REWORK items are fixed, and each behavior fix has a regression test at the right level. I re-ran the evidence myself. `chat/ownership` and `chat/lifecycle`, run one file at a time, are both exit 0 with no failures. `make -k test JOBS=4` gave lint 0 warnings / 0 errors across 633 files and 375 of 376 spec files passing. The one failure was `perf_ownership_spec`, which aborted after its first case with no assertion output. It passes 3/3 when run alone inside the `chat/lifecycle` run, which matches the parallel-load flake already recorded in the Log. I also re-ran the plan's writer-enumeration grep: every generated write goes through the turn, and every `apply_user` hit is a human path. One cheap thing is left. The atlas and the target now say more than the code does: that each generation's writes are one contiguous run and one undo step. The code (on purpose) hands the turn over on pause, and undo only merges writes that share the same generation *and grant*.

## 1. Strengths
- **`generation_runner.lua:551-573` (`next_control`)** fixes C1 as a class. Every effect that changes authority rather than text (`revoke`, `request_turn`, `release_turn`) now runs ahead of work that is parked, and these effects stay in order among themselves, so `stop()` still revokes before it releases. I checked the other effect types: each one resolves itself once the generation is `stopping`, so none is left stuck behind parked work.
- **`generation_turn_spec.lua:280-303`** checks the C1 fix where it matters: the waiting generation actually gets the turn and finishes. It does not just check that the machine emitted `release_turn`, which the old code already did. It fails without the fix: the parked `continue_round` would re-park on every step, and the queued release would never run.
- **`State.waits_for_turn` (`state.lua:99-104`)** replaces three versions of the same check with one constant-time predicate, used at all five generated write paths. Ownership is checked before the turn, and the unit case "a non-owner is an ownership failure, not a wait" pins that order.
- **`generation.lua:157-165`**: the gap is only written after the provider-failure check, so a provider that fails before sending anything leaves the transcript untouched. `generation_spec:765` pins this.
- **`generation_turn_spec.lua:378-424`** tests undo on a real buffer. It alternates single steps, fails without the turn, and asserts that no undo step removes text from both generations or leaves part of one.

## 2. Critical findings
None.

## 3. Important findings
**The atlas and the target claim writes stay together more than the code guarantees** (`atlas/chat/ownership.md:12-13`; `workshop/targets/transcript-is-the-whole-truth.md:117-121`).
- The atlas says each generation's writes "stay one contiguous run and one undo step". The target says a generation's run "is never split around another's".
- **Pause splits a run.** The turn is released on pause (`generation.lua:97`, `:404`, `:412`), and the C1 fix is what makes that release take effect. So if an answer pauses on a stale input between tool rounds (the flow the README describes) while a second answer is waiting, its writes end up in two runs with the other answer's run between them.
- **Undo is not one step per generation.** Undo only merges writes with the same `(epoch, generation, grant)` (`document/editor.lua:196-199`). An answer written through its main grant and then a completion grant is already several undo steps. The plan's own "Target reconciliation" section and the Log correction say exactly this.
- These statements are what parley#261 will build on.
- **Fix:** say it the way the code behaves:
  - No undo step ever mixes two generations.
  - Writes are contiguous for as long as a generation holds the turn without interruption.
  - After a pause, the resumed writes start a new run.
  - Undo entries are per (generation, grant) run.
  - Sweep every statement of this claim; I found exactly these two. The README's "never mixes two answers" is correct.
  - Optionally, add a pause-then-resume variant of the undo test that asserts no step mixes generations.

## 4. Minor findings
- **Snapshots taken before cheap checks on a hot path** (`generation_runner.lua:67-68`, `:110`). This is the same pattern as round-1 I5, which was fixed at the coordinator but appears again here in the same diff.
  - `blocker()` calls `G.snapshot(s.machine)` before checking `s.turn_status~='waiting'`.
  - `sync` now calls `present(s)` every time, and `present` snapshots before comparing its key.
  - The result is two machine snapshots on every sync: every step, every provider delta (through `alive`), and every document notification. That includes the turn holder, which is never blocked.
  - Rule: on per-chunk paths, run the constant-time checks before any snapshot or copy.
  - No measured regression; `perf_ownership_spec` passes alone.
- **Core-concepts table**: the `response_tools — ToolAdapter` row (plan line 103) and the `response_session — PendingProgress` row (line 105) say `modified` but describe M2 behavior. The `sequence` row marks the same situation as *(M2)*. At this boundary neither behavior exists. This is Minor rather than Critical because the rows are clearly scoped to a later milestone and only the tag is missing.
- `response_topic.lua:182`: the `applied.status=='waiting'` branch can't be reached, since the turn was just confirmed held and `D.apply` is synchronous. If it ever were reached, the topic's own subscriber is suppressed by `s.writing` at the moment its release notifies, so nothing would wake it.

## 5. Test coverage notes
Round-2 fixes, each checked against its regression test:

| Finding | Regression test |
|---|---|
| C1 | `generation_turn_spec` pause matrix |
| I2 | `response_session_spec:149` |
| I3 | `generation_spec:765` |
| I5 | `document_state_spec:284` |
| Status-slot Minor | `response_session_spec:165`, which sends a reasoning delta while the answer is held |

The prose-only fixes are also in place: I1 in the plan's Revisions, I4 as items on the issue's M2 row, and the rewording of README and `tool_use.md:291`.

What stays uncovered: splitting across a pause (see the Important finding), and ordering of control effects among themselves after the reorder. The ordering is covered end to end only by `batch_lifecycle_spec`'s retry cases.

## 6. Architectural notes

| Principle | Result | Notes |
|---|---|---|
| ARCH-DRY | pass | One `waits_for_turn` check; `chat_presentation` owns the wording; `blocked.line` is worked out in one place. |
| ARCH-PURE | pass | `WriteTurn`, the reducer, `may_write` and `write_due` are pure; `blocker` and `present` sit in the IO layer. |
| ARCH-PURPOSE | flag | Every writer and every atlas page was checked. The contiguity claim is the one statement not brought in line (Important). |
| ARCH-MOCK | pass | No new external dependency; production and tests use the same fakes at the same seam. |
| ARCH-CONSTRAINTS | pass, with the Minor above | The budget is measured (n=359; p99 36.4 KB) and the overflow path is tested at both sites. |
| ARCH-SECURE | pass | N/A holds: no new untrusted input and no credentials. |
| ARCH-ORDER | pass | `draining` and `gap` are proper named states, and the turn changes only inside the reducer. The machine's `turn_status='held'` default is recorded and harmless, because `request_turn` now runs before any other effect. |
| ARCH-FUNERAL | pass | `turn_wanted` is a weak side table cleared on finish, release, reload and detach. `op.tail` is guarded by `s.blobs`. Preparation grants are collected by `finish_generation`. The `unproved` subscription is removed on proof or on cancel. |

M2's recorded obligations still stand:
- Re-assert tool execution across generations.
- Restore the cross-generation cases in `chat_stop_generation_spec` and `chat_async_tools_spec`.
- Revert the turn sentence in `tool_execution.md`.

## 7. Plan revision recommendations
- Add a `## Revisions` entry to the plan and to the target: "a pause yields the turn and the resumed writes start a new run; undo entries are per (generation, grant) run". Update `atlas/chat/ownership.md:13` in the same change.
- Tag the `response_tools` and `response_session — PendingProgress` rows in Core concepts *(M2)*, the same way `sequence` is tagged.

```findings
dispose:
  - id: BR-1
    disposition: withdrawn
    note: |
      Overtaken by execution. Tasks 1.1 and 1.2 are done, so their inline bodies are sunk cost, and rewriting executed tasks would break the append-Revisions-don't-overwrite rule (AGENTS.md section 1). Chunks 3-4 already carry signatures and strategy lines, not bodies, and the facts section now tells readers to verify before trusting.
findings:
  - id: new
    severity: Important
    family: invariant-statement-omits-exception
    title: |
      Atlas and target say each generation's writes are one contiguous run and one undo step; pause releases the turn and undo merges only per (generation, grant)
    detail: |
      atlas/chat/ownership.md:13 and transcript-is-the-whole-truth.md:117-121. Release on pause (generation.lua:97, :404, :412), now effective through the C1 fix, splits a resumed generation's writes around another generation's run. editor.lua:196-199 merges undo only within one (epoch, generation, grant), so a main grant plus a completion grant is already several steps; the plan's Target reconciliation section says so. Restate as: no undo step mixes generations; contiguous while held without interruption; a pause starts a new run. Sweep every statement of the claim.
  - id: new
    severity: Minor
    family: cheap-guard-before-copy
    title: |
      blocker() and present() snapshot the machine before their cheap checks, on every sync
    detail: |
      generation_runner.lua:67-68 snapshots before checking turn_status, and :110 calls present(s) unconditionally, which snapshots before comparing its key. That adds two snapshots per step, per provider delta and per document notification, including for the turn holder. Same rule as round-1 I5, which was fixed only at the coordinator: run constant-time checks before any snapshot or copy on per-chunk paths.
  - id: new
    severity: Minor
    family: table-row-milestone-scope
    title: |
      Core-concepts rows for response_tools and response_session PendingProgress describe M2 behavior without the (M2) tag
    detail: |
      Plan lines 103 and 105 are marked modified with append-only insertion and the tool-to-pending edge, neither of which exists at M1. The sequence row already uses the (M2) tag for this situation.
```

---

## Re-review — 2026-09-17T20:30:15-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 0f6ee4d4d50869803bc41664548dd1bbdeabea69..12594edc129d62ddca79af208358ce8c65bd8174 |
| command | sdlc milestone-close --issue 266 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-17T20:30:15-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All three open findings are fixed as stated. The pause and per-grant exceptions now appear wherever the contiguity claim was made. The runner's per-sync path checks the cheap conditions before any copy. The two plan rows carry their *(M2)* tag. I re-ran `chat/ownership`: 27 files, 278 cases, 0 failed, 0 errors. One cheap thing is left, and it is the same kind of problem as BR-2. While restating the invariant, the fix added a new claim that is also too strong. The target now says no undo step "is a partial slice of a larger write. This holds unconditionally." That is false in the README's main use case: typing the next question while an answer streams. I confirmed this with a scratch spec on a real buffer. One generation writes 9,000 bytes, and a disjoint human edit lands between its first and second 4 KiB slices. Undo then removes 4,904 bytes and leaves a 4,096-byte partial slice. The cause is that `Editor:observe` clears `undo_receipt` on every observed edit (`document/editor.lua:67`). The fix is prose-only.

## 1. Strengths
- **`generation_runner.lua:72-74`**: `blocker` now checks `turn_status` and `doc.turn` before reading anything else, and reads phases through the new O(1) `G.phase` (`generation.lua:218`). The turn holder, which is the common case, returns after two field reads.
- **`generation_runner.lua:43-45, 116-117`**: `blocked_key` is pulled out once and used by both `present` and `sync`, so the dedup key and the change test cannot drift apart (ARCH-DRY). Behavior is unchanged: `present` was already deduplicated by key, and machine changes still present through `dispatch`.
- **`generation_turn_spec.lua:305-317`**: the order of control effects is now pinned at the runner. The revoke lands one step before the turn moves. Before this, that order was covered only end to end through `batch_lifecycle_spec`.
- **`response_topic.lua:182`**: removing the unreachable `'waiting'` branch is correct. The turn is confirmed a line earlier, `D.apply` is synchronous, and the commit message explains why the branch could never have woken anyway.

## 2. Critical findings
None.

## 3. Important findings

**N1 — `workshop/targets/transcript-is-the-whole-truth.md:145-146`: "none is a partial slice of a larger write. This holds unconditionally" is false whenever a human edit lands mid-write.**
- **This is the 2nd finding in family `invariant-statement-omits-exception`.** BR-2 fixed the pause and per-grant instances, and the fix itself introduced this one. The lesson added in this round already states the rule: "list every event that ends the grouping, and check each against the code that emits it." It was not applied to the new sentence.
- **Do not just delete the word "unconditionally".** Derive every undo-grouping statement from the predicate that decides grouping. `Editor:can_join_undo` (`editor.lua:194-202`) joins only when:
  - the epoch, generation and grant all match the last receipt, and
  - the native undo sequence and tick are unchanged since that receipt.
- The receipt is also cleared by every observed edit (`:67`, human typing and undo/redo included), by lifecycle transitions (`:132`, `:179`), and by any write that is not `applied` (`:268`).
- The only property that survives all of those events is: **no undo step mixes two generations.** Everything else is conditional on no human edit landing mid-run:
  - one step per (generation, grant) run;
  - no partial slice.
- Sweep every site that makes the claim:
  - the target, `:145-146`;
  - the target's first Revision, `:120` ("never a partial 4 KiB slice", not struck);
  - the plan's Target reconciliation, `:717-718` ("holds unconditionally");
  - `atlas/chat/ownership.md:15` ("Undo groups per (generation, grant) run" implies one step per run).
- `README.md:52` ("never mixes two answers") is already exact.
- Optionally, pin the exception: a human edit between two slices splits one run into two steps, and neither step mixes generations. The scratch shape above takes about 15 lines.
- This matters beyond wording: parley#261 plans to delete the recovery sidecar on the strength of this target's undo guarantees.

## 4. Minor findings
- **N2 — plan milestone labels are stale after the M1/M2 merge renumbered the milestones.** The plan's `:669` has Chunk 3 (now M2) close with `--milestone M3`. `:675` says "after **M3** (Task 3.2b)" where it means M2. `:690` commits as `#266 M4:` for Chunk 4 (now M3), and `:510` says "M2–M4". **This is the 2nd finding in family `table-row-milestone-scope`.** The rule: every milestone reference in the plan must match the issue's current `## Plan` tags. After any renumbering, grep `M[0-9]` across the whole plan and reconcile every hit, not only the rows a review names. (The Estimate section's item order is a historical record and should stay as written.)
- The pause-then-resume undo test (`generation_turn_spec.lua:446`) says it asserts that a's text leaves "in two runs, around b's". But the stale-input edit (`nvim_buf_set_text` at `:470`) also sits between a's runs, so `seen={3000,0}` would split even if the pause yielded nothing. The key assertion (no step mixes generations) and the proof that b wrote during the pause (`:474`) do hold.

## 5. Test coverage notes
- **BR-2** is a prose finding. The corrected text matches the code:
  - release on pause: `generation.lua:97, :407, :415`;
  - per-grant undo keys: `editor.lua:196-199`.
  - The new test at `generation_turn_spec.lua:446` supports it.
- **BR-3** changes performance only, not observable behavior, so no regression test was expected. The presentation test "reports the holder … clears it on handover" (`:360`) still passes and pins that the waiting note clears on handover.
- **Suite:** `make -k test-spec SPEC=chat/ownership` ran 27 files with 0 failed and 0 errors.
- **Uncovered:**
  - a human edit mid-run, which is what N1 is about;
  - `document/init.lua:539`: `append` still snapshots before `waits_for_turn`. The snapshot was already there at base, and the waiting path is rare because the machine gates writes on `may_write`, so I am not raising it.

## 6. Architectural notes

| Principle | Result | Notes |
|---|---|---|
| ARCH-DRY | pass | `blocked_key` has one source; `G.phase` is an accessor rather than a second snapshot. |
| ARCH-PURE | pass | Unchanged since round 3. |
| ARCH-PURPOSE | flag (N1, N2) | Both are cases of fixing the instance a finding named while its siblings remained. |
| ARCH-MOCK | pass | No new external dependency. |
| ARCH-CONSTRAINTS | pass | BR-3 is fixed. The per-sync snapshots that remain were all present at base: `sync`'s `D.snapshot` (`:95`), `alive` (`:122`), and `present` via `dispatch`. The new snapshot sites (`:243`, `:269`, `:461`) run once per event. |
| ARCH-SECURE | pass | N/A holds: no new untrusted input and no credentials. |
| ARCH-ORDER | pass | Control-effect order is now pinned at the runner with controllable stepping. |
| ARCH-FUNERAL | pass | This round creates nothing durable. |

## 7. Plan revision recommendations
- Add a Revision to the target, the plan's Target reconciliation, and `atlas/chat/ownership.md`: "unconditional: no undo step mixes two generations. Conditional on no human edit landing mid-run: one step per (generation, grant) run, and no partial slice."
- Reconcile the plan's milestone references (`:510`, `:669`, `:675`, `:690`) with the issue's M1/M2/M3 numbering.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      Pause and per-grant exceptions are now carried at atlas/chat/ownership.md:12-17, the target's Revision 2 and the plan's Decisions entry; README:52 was already exact. Supported by generation_turn_spec.lua:446. The new "unconditionally" sentence is raised separately below in the same family.
  - id: BR-3
    disposition: addressed
    note: |
      blocker checks turn_status and doc.turn first (generation_runner.lua:72); phases read via O(1) G.phase (generation.lua:218); sync presents only when blocked_key changes (:116-117). Behavior-preserving since present was already key-deduped. Remaining per-sync snapshots were present at base.
  - id: BR-4
    disposition: addressed
    note: |
      Plan rows at :103 and :105 now carry the (M2) tag. Stale milestone references elsewhere in the plan are raised separately below in the same family.
findings:
  - id: new
    severity: Important
    family: invariant-statement-omits-exception
    title: |
      Target says no undo step is a partial slice "unconditionally"; a human edit between 4 KiB slices splits one write
    detail: |
      2nd finding in this family; the BR-2 fix introduced it. transcript-is-the-whole-truth.md:145-146 and :120, plan :717-718, atlas/chat/ownership.md:15. editor.lua:67 clears undo_receipt on every observed edit, and a scratch spec confirmed it: 9000 bytes plus a disjoint human edit after the first slice undoes as 9000 to 4096 to 0. Rule to apply: derive undo-grouping claims from can_join_undo (editor.lua:194-202) and every undo_receipt clear (:67, :132, :179, :268). Only "no undo step mixes two generations" is unconditional; one step per run and no partial slice both require that no human edit lands mid-run. Sweep all four sites.
  - id: new
    severity: Minor
    family: table-row-milestone-scope
    title: |
      Plan milestone references are stale after the M1/M2 merge renumbered them
    detail: |
      2nd finding in this family. Plan :669 closes Chunk 3 (now M2) with --milestone M3; :675 says "after M3 (Task 3.2b)" but means M2; :690 commits as "#266 M4:" for Chunk 4 (now M3); :510 says "M2-M4". Rule: every milestone reference in the plan must match the issue's current Plan tags. After a renumbering, grep M[0-9] across the whole plan and reconcile each hit; leave the Estimate section's historical item order as written.
```

---

## Re-review — 2026-09-17T21:02:59-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 0f6ee4d4d50869803bc41664548dd1bbdeabea69..9d65fea9c1ff8de840dff4d0cde9bbdf378b9abc |
| command | sdlc milestone-close --issue 266 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-17T21:02:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both open findings are fixed at every site they named. The undo-grouping rule now has one statement, in `atlas/chat/ownership.md:28-43`, and it matches the code. I checked it against `Editor:can_join_undo` (`editor.lua:194-202`) and each place the undo receipt is cleared (`:67`, `:132`, `:179`, `:268`), and it is accurate. The target now defends only the property that holds unconditionally, and a new test pins the exception. Twelve stale milestone labels in the plan were reconciled. Each finding has one leftover in the same class, and both are Minor. Two plan sentences and one README clause still state turn or undo grouping without their exceptions. One plan sentence still uses the old milestone numbering. All of these are cheap to fix, and none blocks. The tests I ran are green (details in section 5); I did not run a full `make test`.

## 1. Strengths
- **One statement, derived from the predicate.** The undo-grouping section in `atlas/chat/ownership.md:28-43` names every event that splits a run, and I confirmed each one in `editor.lua`. The target's round-3 Revision (`transcript-is-the-whole-truth.md:157-171`) defends only "no undo step mixes two generations" and points to the atlas. It tells parley#261 to cite the atlas, not the target. That stops the paraphrase drift that produced BR-2 and BR-5.
- **The exception has a test.** `generation_turn_spec.lua:509` writes 9000 bytes on a real buffer with a disjoint human edit between slices, then asserts that undo comes back in at least two pieces. The pause-then-resume test's comment (`:446-450`) no longer claims more than the test proves.
- **Earlier text was struck, not rewritten.** Revisions in the target and plan follow the append-don't-overwrite rule, so the history stays auditable.
- **Every writer handles `'waiting'`.** A grep of every generated-writer call site in `lua/` shows each one does: `response_preparation.lua:90,101,108`, `response_completion.lua:63,71`, `generation_runner.lua:365,400,405`, and `response_topic.lua:175`, which takes the turn around its single synchronous apply.

## 2. Critical findings
None.

## 3. Important findings
None.

## 4. Minor findings
- **N1 (new, `invariant-statement-omits-exception`, 3rd in family).** Three live sentences outside the atlas still state grouping without the exceptions:
  - `plan:709-711` says that holding the turn for a generation's lifetime makes its output contiguous. A pause yields the turn.
  - `plan:714-715` says "So the guarantee is **one undo entry per (generation, grant) run**". That holds only while nothing intervenes.
  - `README.md:50-52` says a later answer "appears in full once the earlier one finishes". A pause hands the turn over first. The README's next paragraph documents that pause, and `generation_turn_spec` tests the handover.
  - The rule and its measured prevalence are in the findings block.
- **N2 (new, `table-row-milestone-scope`, 3rd in family).**
  - `plan:461` says "…and it is why M2 exists". That meant the preparation deferral, which is now Chunk 2 of M1. The current M2 (ordered append) does not bound this latency.
  - `plan:459` says "Under M1 the normal waiter is a generation parked in `preparing`". That describes the M1 before the merge; it is false for the merged M1.
- `plan:565` ticks "Remove the 'Deliberate over-serialization in M1' section", but the section is still at `:189`, retitled "— resolved". Reword the item to "marked resolved".
- The plan's WriteTurn ARCH-FUNERAL bullet (`:79`) calls `s.turn_wanted` a reducer field. It is actually the module-level weak map at `state.lua:9`. The lifetime is the same; only the location is misstated.

## 5. Test coverage notes
- **`chat/ownership`:** 27 files, 0 failed, 0 errors. `generation_turn_spec` ran 34 cases, including the three undo-coherence cases.
- **`chat/lifecycle`:** 61 files, all green.
- **`providers/tool_use`:** 32 files, all green.
- **`chat/document`:**
  - The first run stopped after 8 files with no assertion failure. That matches the `document_fold_batches_spec` load flake recorded in the issue Log.
  - The rerun passed: 32 files, exit 0.
- **Arch sweeps:** `infra/packaging` and `infra/test_harness` are green.
- **Lint:** 0 warnings, 0 errors across 633 files.
- **BR-5 was a prose fix.** The new test pins the behavior the corrected atlas describes. If receipt clearing at `:67` were removed, the native undo-sequence check in `can_join_undo` would still split the run. So the test pins the documented outcome, not one particular mechanism, which is the right thing to pin.

## 6. Architectural notes

| Principle | Result | Notes |
|---|---|---|
| ARCH-DRY | pass | One `State.waits_for_turn` covers all five entry points. `may_write` is the single gate in the machine. `blocked_key` has one source. Both host messages live in `chat_presentation`. |
| ARCH-PURE | pass | `WriteTurn` is pure. The reducer and machine are unit-tested without IO. The runner is the IO shell. |
| ARCH-PURPOSE | flag (N1, N2) | The named sites were fixed. Siblings of the same class remain in live plan and README text. |
| ARCH-MOCK | pass | No new external dependency. Turn tests use FakeRunner adapters against the real coordinator on real buffers. |
| ARCH-CONSTRAINTS | pass | Budget is 1 MiB per generation and 16 MiB process-wide, based on measured answer sizes, and the overflow path is tested. One note, not raised as a finding: `contents()` can re-join a held item it is still extending, once per 4 KiB slice. The worst case is bounded by the 1 MiB budget, and the measured p99 is 36 KB. |
| ARCH-SECURE | pass | N/A holds: the change only reorders in-process writes, with no new untrusted input and no credentials. |
| ARCH-ORDER | pass | The turn is explicit reducer state; the release matrix covers 4 interleavings with controllable stepping; control-effect order is pinned at the runner. |
| ARCH-FUNERAL | pass | Nothing durable. The `turn_wanted` weak map is cleared by finish, release, reload and detach. Blob parts are released with their blobs. |

**Forward note for M2:** once `(call, result)` pairs append at the parent grant's tail, they share one generation and one grant. `can_join_undo` will then merge them into the surrounding answer text's undo step whenever nothing intervenes. The issue's Open decisions expect one undo step per `(call, result)` pair. Getting that needs a deliberate undo break per pair, and the change belongs in the atlas's "Undo grouping" section, not in a restatement elsewhere.

## 7. Plan revision recommendations
- **Target reconciliation (`:709-721`):** strike the "lifetime → contiguous" and "the guarantee is one undo entry per (generation, grant) run" sentences, and point to the atlas "Undo grouping" section instead.
- **Task 1.6 Step 4 (`:459`, `:461`):** strike the "Under M1…" sentence, and change "why M2 exists" to name Chunk 2, the preparation deferral.
- **Task 2.3 (`:565`):** change "Remove the section" to "Mark the section resolved".
- **Add a Revision for M2:** record the undo-grouping consequence of appending pairs at the parent grant tail (see the forward note above), and say where it will be decided.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      Target :120 and :145-146 struck; round-3 Revision defends only "no undo step mixes two generations" and points to atlas/chat/ownership.md:28-43, verified against editor.lua:194-202 and clears :67/:132/:179/:268; plan :717-718 struck; exception pinned at generation_turn_spec.lua:509. Sibling sentences at plan :709-715 and README :50-52 raised separately.
  - id: BR-6
    disposition: addressed
    note: |
      Plan :510, :669, :675, :690 and eight more references now match M1 = Chunks 1-2, M2 = Chunk 3, M3 = Chunk 4. Two stale referents at :459/:461 are raised separately.
findings:
  - id: new
    severity: Minor
    family: invariant-statement-omits-exception
    title: |
      Plan Target reconciliation and README still state turn/undo grouping without the pause and intervening-edit exceptions
    detail: |
      3rd finding in this family. Rule: turn handover and undo grouping are each stated once, in atlas/chat/ownership.md; every other live (non-Revisions) sentence states only an unconditional property ("answers are written one at a time", "no undo step mixes two answers") or names the exceptions or points there. Enforce with one grep over workshop/plans, workshop/targets, atlas and README for undo (entry|step), contiguous, one run, partial (slice|chunk), per (generation, grant), lifetime and finishes; each hit must be unconditional, a pointer, or struck. Measured at HEAD: about 20 hits, 3 live residuals. Plan :709-711 says lifetime-held means contiguous (a pause yields the turn). Plan :714-715 says "the guarantee is one undo entry per (generation, grant) run" (only while nothing intervenes). README :50-52 says a later answer appears "once the earlier one finishes" (a pause hands the turn over first; the README's next paragraph documents that pause).
  - id: new
    severity: Minor
    family: table-row-milestone-scope
    title: |
      Plan Task 1.6 Step 4 still uses the milestone numbering from before the merge
    detail: |
      3rd finding in this family. Plan :461 says "it is why M2 exists", meaning the preparation deferral, now Chunk 2 of M1; the current M2 (ordered append) does not bound that latency. Plan :459 says "Under M1 the normal waiter is a generation parked in preparing", which describes the M1 before the merge. Rule: when plan prose refers to a milestone's content, name the chunk or task (those ids stay stable); M-labels renumber. After a renumbering, check what each M[0-9] hit refers to, not only its spelling. Measured: about 40 M-hits outside Revisions, 2 with stale referents.
```
