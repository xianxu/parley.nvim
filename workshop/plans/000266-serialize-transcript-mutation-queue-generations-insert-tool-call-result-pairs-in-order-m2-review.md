# Boundary Review — parley.nvim#266 (milestone M2)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | f6ebfd8399a5c188b7f0814cae3ad7e8e65c0ece..c2207117a34a3e645803cbedaf94b0cab0af7890 |
| command | sdlc milestone-close --issue 266 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-18T10:27:24-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

M2 does what its Spec asks for. Tool rounds now append `(call, result)` pairs in the declared order. The ordering lives in a pure `ToolSequence`, which the generation machine drives, and the adapter only renders blocks. The machinery that existed only to police slots (capacity tickets, child grants, the reservation lifecycle, `cancel_child`) is gone, and no code reference to it remains. Progress now shows in the presentation layer, and a failed call is written as an error result so the round goes on. Everything I inspected in the pinned range was available. The 10 spec files M2 touched pass in a scratch environment, and two mutation checks turned `generation_spec` red. Three Important findings stand between this and SHIP:
- **Undo claim is false.** The new sentence in the undo-grouping page is unconditional, and a scratch test disproves it. This is the 4th finding in the `invariant-statement-omits-exception` family.
- **Stale atlas lines.** Two atlas pages still say an unknown outcome prevents continuation. One of them is the page M2 rewrote.
- **Retry can hang.** Continuing past an unknown outcome invites the model to retry, but the unknown call's resource claims stay held. A retry on the same path would then queue with no timeout.

## 1. Strengths
- **`tools/sequence.lua` is a clean pure entity.** It is immutable, bounds-checked, and asserts that blocks are written in order. `tests/unit/tools_sequence_spec.lua` covers holding, draining, completion, finality, immutability and bounds.
- **One gate for every write.** `may_write` / `write_due` (`generation.lua:33-58`) now cover `insert_tool` as well as output and finalize. `insert_next` (`:116-124`) holds a block behind staged text, the turn, the deferred gap and the block already in flight. Removing the `bytes>0` gate turned `generation_spec` red.
- **File and wire cannot disagree.** `settled()` (`response_tools.lua:39-45`) feeds both the transcript block and the continuation. A test asserts the model receives exactly the error text the file shows.
- **The ordering tests are strong.** A sweep runs all 24 orderings of {outcome₁, outcome₂, stop, cleanup}, each under both cancel and detach, through the production transition function. It checks a rule stated independently of the code: the file only ever holds an in-order prefix and nothing lands after the stop. A step-bounded test also catches a call block landing inside a result that is written in several slices.
- **The removal is complete.** A grep for the removed symbols finds nothing in `lua/`, `tests/` or `atlas/`. The runner's liveness exemption became the `unscoped` set (`generation_runner.lua:159`). Traceability routing is updated in both directions.

## 2. Critical findings
None.

## 3. Important findings

**I1. The undo sentence for tool rounds is unconditional and false.** `atlas/chat/ownership.md:47-50` ends: "Undo never strands a pair apart from the text that refers to it."
- **Evidence.** In a scratch test (answer text, a one-call round, then a human edit on another line before the result lands), the first undo left `TEXT<call1>`: the result and the text after it went, and the call block stayed with no result. `Editor:observe` clears the undo receipt on any edit (`editor.lua:67`), and typing while tools run is the normal case.
- **Coverage gap.** No test drives undo across a tool round at all, although Done-when asks for "a multi-call tool round".
- **Family escalation.** This is the 4th finding in `invariant-statement-omits-exception`; earlier rounds fixed instances, so this one should be fixed at the rule. The rule: on the undo-grouping page, only a claim that follows from the identity check alone (a different generation cannot join) may be stated without a condition. Every other claim, including new bullets, goes under the Conditional bullet, names the event that splits it on its own path, and ships with a test that drives that event. BR-5's mid-write edit test is the model.
- **Fix.** Move the tool-round bullet under Conditional and state that an edit while tools run splits the round, possibly leaving a call block one step earlier than its result. Add a test that drives that edit. Add another where two generations each run a multi-call round and no undo step mixes them.

**I2. The atlas still says an unknown outcome prevents continuation.** (ARCH-PURPOSE shadow sweep)
- `atlas/providers/tool_use.md:195-199` says "an `unknown` outcome prevents continuation … A later known outcome and positive cleanup can settle it". That contradicts step 4 on the same rewritten page.
- `atlas/providers/architecture.md:46` says "an unknown effect prevents continuation".
- Leftover wording, same class:
  - `tool_use.md:185` still says "known results"; continuation now carries error results too.
  - `atlas/providers/tool_execution.md:5` still says "transcript slot".
  - `lua/parley/tools/serialize.lua:6` still says "result slots".
  - Plan Core concepts line 113 still describes the ToolAdapter `begin_round` + pump design.
  - Plan line 86 says the sequence lives on "the adapter's round state"; it lives on the machine's round.
- **Rule.** Sweep by grepping the old claim's wording across `atlas/`, README, code comments and the plan's Core concepts, not only the pages the plan named.

**I3. Continuing past an unknown outcome can walk the model into a stall.** (ARCH-ORDER, uncertain outcomes)
- **Before M2.** An unknown outcome paused the round and could not continue on its own.
- **Now.** `generation.lua:390-399` resolves a tool on cleanup whatever its outcome. The error text tells the model the effect "may or may not have taken effect", and the operator's intent is that the model tries another way.
- **The resource service still holds the claims.** `tools/operation.lua:103-105` releases claims only for `outcome_known`, `cancelled_before_effect` or `rejected`. `scheduler.lua:107` marks the unknown call's record `unknown`. `resources.lua:84-92` `available()` treats any non-queued record as holding its claims and counting toward `per_generation<4` / `per_document<8`. Reconciliation polling stops after 5 s.
- **Failure scenario.** An unknown `write_file` on path P is cleaned up, so the round continues. The model retries `write_file` on P. The retry queues with no timeout, the round never continues, and the generation keeps the document's write turn until `:ParleyStop`. Every other answer in the chat is blocked behind it.
- **Fix.** When the only blocker is a quarantined claim, fail the call fast with an error result naming the held resource instead of queueing it. Otherwise, record an operator decision and state the limitation in the error text. Either way, add a test: unknown with cleanup done, round continues, same-path retry gets an error result rather than hanging.

## 4. Minor findings
- **The target narrowing needs the operator's sign-off.** The revision in `workshop/targets/transcript-is-the-whole-truth.md` (execution before record: Stop drops pairs whose tools already ran) is logged as "to raise with the operator". Get an explicit acknowledgment before the issue closes.
- **The progress note can mislead.** "Running tools: N of N finished" also shows while the round waits on a tool's cleanup, or on writes held behind a call that never reports. That makes the stall look mysterious, which M1's visibility principle meant to avoid. Consider a distinct "waiting for cleanup" note.
- **Wrong stop reason on detach.** If `insert_tool` runs while the runner is detached but before the machine knows, the stop reason is `insert_failed` rather than the detach.

## 5. Test coverage notes
- All 10 touched spec files pass in a scratch environment: `tools_sequence`, `generation`, `chat_presentation`, `response_tools`, `generation_turn`, `generation_sequences`, `response_session`, `chat_async_tools`, `chat_stop_generation`, and `arch/document_ownership`.
- **Mutation checks, in a throwaway copy of the tree:**
  - Dropping the check that refuses an outcome while its result is in flight (`child_outcome`) fails "lets an unknown outcome be confirmed only until its result is on its way".
  - Dropping the staged-bytes gate fails "holds tool blocks behind the text staged before them". Only the unit test catches it; `response_tools_spec` stays green.
- **Gaps:**
  - undo across tool rounds (I1);
  - a same-path retry after an unknown outcome (I3);
  - the start-child adapter throwing, where `cb.failed` records an unknown outcome with no resolution, so the round can never continue. It is reachable only through internal invariant violations, and it was stuck before M2 too.

## 6. Architectural notes for upcoming work
- **ARCH-DRY: pass.** `settled()`, the `unscoped` set, and one write predicate for three emissions.
- **ARCH-PURE: pass.** The sequence and the machine are pure; the adapter is a thin renderer.
- **ARCH-PURPOSE: flag (I2).** Otherwise the slot and child-grant removal is delivered, not deferred.
- **ARCH-MOCK: pass.** The fake runner's `insert_tool` records order, and the real adapter runs against a scripted producer.
- **ARCH-CONSTRAINTS: pass.** At most 32 calls per round, bounded work per transition, and tools of waiting generations are capped by the existing resource limits.
- **ARCH-SECURE: pass, with a note.** Adapter error strings now reach the transcript and the provider; they are bounded by `result_evidence.publish`.
- **ARCH-ORDER: flag (I3).** The sequence is an explicit pure model and the sweep controls ordering. But "continue while unconfirmed" conflicts with the quarantine's reconciliation rule.
- **ARCH-FUNERAL: pass.** `s.rounds` is cleared at continuation and at close, and a test asserts it. Tickets are gone.
- **M3:** `resume_original` still loops over `s.grants`, which now only ever holds the main grant (plus preparation grants). Fold that into the residual sweep.

## 7. Plan revision recommendations
- Mark Core concepts line 113 (ToolAdapter `begin_round`/pump) and line 86 (sequence on "the adapter's round state") as superseded by the 2026-09-18 revision.
- Add a Revision for I1: the tool-round undo claim becomes conditional, plus the rule and its test.
- Add a Revision or decision for I3: what a retry against a quarantined claim does.
- Record the operator's acknowledgment of the target narrowing, or a decision to change Stop.

```findings
findings:
  - id: new
    severity: Important
    family: invariant-statement-omits-exception
    title: |
      Undo-grouping bullet "Undo never strands a pair apart from the text" is unconditional and falsified by an edit while tools run
    detail: |
      This is the 4th finding in family invariant-statement-omits-exception; earlier rounds fixed instances, so fix it at the rule. Evidence: atlas/chat/ownership.md:47-50. In a scratch test (text, one-call round, a human edit on another line before the result), the first undo left TEXT<call1> with its result removed, because Editor:observe clears undo_receipt on any edit (editor.lua:67). No test drives undo across a tool round, although Done-when asks for a multi-call round. Rule: only claims that follow from the identity check alone may be stated without a condition. Every other undo claim, including new bullets, goes under the Conditional bullet, names the event that splits it on its own path, and ships with a test that drives that event (like the BR-5 test). Fix: move the tool-round bullet under Conditional. Add a test with an edit during a round, and one with two generations each running a multi-call round where no undo step mixes them. Measured prevalence: 4 findings across M1 rounds 2-4 and this M2 round.
  - id: new
    severity: Important
    family: behavior-change-sweep-by-claim
    title: |
      Atlas still says an unknown outcome prevents continuation, including on the rewritten tool_use.md
    detail: |
      atlas/providers/tool_use.md:195-199 ("an unknown outcome prevents continuation ... a later known outcome and positive cleanup can settle it") contradicts step 4 on the same page, and atlas/providers/architecture.md:46 repeats it. Leftover wording in the same class: tool_use.md:185 "known results"; tool_execution.md:5 "transcript slot"; tools/serialize.lua:6 "result slots"; plan Core concepts :113 (begin_round/pump) and :86 ("adapter's round state"). Rule: sweep by grepping the superseded claim's wording across atlas, README, code comments and the plan's Core concepts, not only the pages the plan named.
  - id: new
    severity: Important
    family: unconfirmed-outcome-permitted-actions
    title: |
      Continuing past an unknown outcome lets a same-path retry queue forever behind the unknown call's held claims
    detail: |
      generation.lua:390-399 now resolves an unknown tool on cleanup and the round continues. tools/operation.lua:103-105 releases claims only for known, cancelled or rejected outcomes. scheduler.lua:107 marks the record unknown, and resources.lua:84-92 available() still counts it as holding its claims and against per_generation/per_document capacity. A model retrying write_file on the same path therefore queues with no timeout. That is a call that never reports, so the round never continues and the generation keeps the document's write turn until the user stops it. Before M2 an unknown outcome paused instead. Fix: fail fast with an error result when the only blocker is a held claim, or record an operator decision and say so in the error text. Add a test for the retry.
  - id: new
    severity: Minor
    family: target-narrowing-unratified
    title: |
      Target revision now accepts that Stop drops tool pairs whose tools already ran; logged as still to raise with the operator
    detail: |
      workshop/targets/transcript-is-the-whole-truth.md, 2026-09-18 revision. Before M2 a call block was written before its tool started. Now a held pair whose tool has run is lost on Stop. Get explicit operator acknowledgment before the issue closes.
  - id: new
    severity: Minor
    family: stall-visibility
    title: |
      "Running tools: N of N finished" also shows while the round waits on a tool's cleanup or on writes held behind a call that never reports
    detail: |
      tools(s) counts outcomes, but continuation also needs cleanup, so a round stuck on cleanup reads as finished yet never continues. M1 said a stall must be visible, not mysterious; consider a distinct note for waiting on cleanup.
```
