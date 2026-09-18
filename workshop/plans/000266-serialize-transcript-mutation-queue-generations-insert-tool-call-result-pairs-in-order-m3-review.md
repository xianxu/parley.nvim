# Boundary Review — parley.nvim#266 (milestone M3)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 5a9f43d18ec125283e109194f1a637419c60721b..1e0a8c15e4fbfda27edc00962537b3be672f1cb8 |
| command | sdlc milestone-close --issue 266 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-18T11:58:22-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M3 delivers both operator decisions, and they are built on the right structure. `flushing` is a real phase in the pure generation machine, with its entry and exit transitions written out. A tool whose process has crashed now releases its resource claims when the process ends. The self-quarantine code is gone completely: `resources.lua` and `scheduler.lua` now differ from `main` only in how the release evidence is named. The atlas, README and target were all updated.

What I ran:
- Five spec keys, all exit 0: `providers/tool_use`, `providers/tool_execution`, `chat/response_progress`, `chat/lifecycle` and `chat/ownership`. Together they cover every test file this range touched.
- `make lint`: 0 warnings, 0 errors across 634 files.

One Important finding blocks a clean SHIP. A tool that was queued but never started when Stop landed is written as an **unknown failure** ("it ended without reporting a result, so it may have partly taken effect"). The README, atlas and target all promise a "cancelled by the user" result for that tool. I reproduced this with a scratch spec: the producer started zero tools, yet the transcript recorded that text. No test covers this path. The fix is cheap. The rest is Minor.

### 1. Strengths
- **The phase is explicit (ARCH-ORDER).** `flushing` is a named phase, not a flag (`generation.lua:133-149`, `:205-215`, `:461-468`). Its entry condition is exact: a user's Stop, round not fully written, grant not revoked. Every other Stop stops at once, as before. The walk never waits on a tool, only on the turn, the grant or an in-flight block, so a flush cannot stall on a hung tool. `Seq.waiting` (`sequence.lua:37-44`) keeps "what is the walk blocked on" pure.
- **The permutation sweep checks the new rule directly.** The 24-order sweep now asserts that a result is real if and only if its outcome arrived before the Stop (`response_tools_spec.lua:~400-417`). That is an invariant stated independently of the code, checked across every ordering.
- **The crash-is-failure change is minimal and removes a hidden limit (ARCH-FUNERAL).** The ledger only forgets a record once it is `released` (`operation.lua` `M.forget`). Before M3, an unknown outcome that nobody reconciled never released, so each one permanently used one of the 128 ledger slots in the process. Releasing on process end removes that.
- **A test fake now matches the real seam (ARCH-MOCK).** In `response_session_spec`, the fake producer now answers `cancel` by handing the tool to its supervisor, as `tools/producer.lua:167-174` does.
- **The waiting state is visible.** The flushing note names the answer it is waiting behind. `response_session_spec` asserts it on the real pending extmark, and asserts that nothing is written before the turn arrives.

### 2. Critical findings
None.

### 3. Important findings
- **A tool refused at start during a flush is written as "failed, may have partly taken effect".**
  - **Where:** `generation_runner.lua:306-313` and `response_tools.lua:42-47`.
  - **Cause:** When a `start_child` effect is still queued in the runner at the Stop, the runner refuses it. It sends `cancelled_before_effect` with a bare `true` result blob. `insert_tool` passes that blob on, and `settled()` turns any result without an identity into `failure_text('unknown')`.
  - **How it happens:** The effect can be queued behind a parked write (grant suspended during repair), or still sitting in the queue a few milliseconds after the round was declared. The flushing guard in `start_operation` was added for exactly this case, but what it produces is never rendered correctly.
  - **Reproduction:** Take the `response_tools_spec` harness. Call `req.cb.round(...)` and `req.cb.resolved()`, then `Runner.cancel`, then `drain`. Result: `STARTED=0`, and the result block reads "The tool call failed: it ended without reporting a result…".
  - **Same problem, second instance:** A tool queued behind a resource claim in the scheduler at Stop. `producer.cancel` clears `r.events` (`producer.lua:171`) before `service:cancel`, so the scheduler's known "cancelled before execution" outcome is dropped (`producer.lua:130`). The machine then records the tool as `cancelled='running'` ("while running; it may have partly taken effect") although it never ran.
  - **Fix sketch:** Let the renderer use the outcome kind the machine already knows. Put `outcome` on the `insert_tool` effect and use `failure_text(outcome)` instead of defaulting to `'unknown'`. Or, while flushing, have the machine record a refused start as `cancelled='queued'`. For the scheduler case, have the producer deliver the known not-applied outcome before handing the tool to the supervisor.
  - **Tests:** Add one for each path, asserting the rendered text.

### 4. Minor findings
- **Doc statements of the flush guarantee don't match the code.** This is the 5th finding in family `invariant-statement-omits-exception`; see the findings block for the rule.
  - "Finished by the time its pair is reached gets its real result" (target `:206-208`, `tool_use.md:184`) is not what the full system does. The Stop cancels every running tool, and the cancel cuts off its callbacks, so only an outcome that arrived *before the Stop* is written as real.
  - "The remaining ways to lose a pair are … a second Stop, reload, or an edit that revokes the answer" (target `:212-213`) leaves out a failed write or insert (`generation.lua:342`, `:396`), a failed gap write (`:296`) and an overflow (`:468`).
- **The flushing note says what it waits for but not how to get out.** This is the 3rd finding in family `stall-visibility`. `chat_presentation.lua:59-61` gives no escape, although the answer ahead can hang. The existing waiting note names `:ParleyStop`.
- **`tool_operations.lua` still describes the old quarantine.** This is the 2nd finding in family `behavior-change-sweep-by-claim`. The prompt at `:21` says "Esc keeps quarantine", and the message at `:29` says "Resources remain reserved until cleanup is confirmed". For a crashed tool whose process has ended, neither is true any more.
- **The plan's phase line is stale.** Its ARCH-ORDER phase list (`plan :129-130`) has no `flushing`. The Chunk 3b step checkboxes are all unticked, while the issue shows them done.

### 5. Test coverage notes
- **Covered:** entry into `flushing`; cancelling running tools and starting none; an outcome arriving mid-flush; a stopped answer keeping its place behind another; second Stop, revocation and overflow; supervision during a flush; the permutation sweep; release of a crashed tool at the operation, resource, scheduler, producer and chat levels.
- **Missing:**
  - a `start_child` still queued in the runner when Stop lands (the Important finding);
  - a tool queued in the scheduler when Stop lands;
  - a second `:ParleyStop` driven at chat level (it is only tested in the machine).

### 6. Architectural notes for upcoming work
- **`child.outcome` now mixes two meanings.** It holds the transcript label `'cancelled_by_user'` for a tool whose effect may actually be unknown, and `supervised_children` would report that label as the outcome. No production code reads it yet. Keep the effect's certainty and the label in separate fields before anything consumes the snapshot.
- **The runner decides something the machine should own.** Its start refusal makes up a result blob. A machine-level "never started" event would keep that decision in the pure core (ARCH-PURE) and fix the Important finding at its root.
- **Principle-by-principle:**

  | Principle | Result |
  |---|---|
  | ARCH-DRY | Pass |
  | ARCH-PURE | Pass, except the runner's refusal above |
  | ARCH-PURPOSE | Pass, apart from the `tool_operations` wording |
  | ARCH-MOCK | Pass |
  | ARCH-CONSTRAINTS | Pass: the walk covers at most 32 calls, the flush never waits on tools, no new timers |
  | ARCH-SECURE | Not applicable: no new untrusted input or credentials |
  | ARCH-ORDER | Flagged: known evidence is rendered as uncertain, and the sweep lacks the runner-queued ordering |
  | ARCH-FUNERAL | Pass, and an improvement |

### 7. Plan revision recommendations
- Add a `## Revisions` entry that extends the ARCH-ORDER phase line with `executing_tools → flushing → stopping` and its exits: the walk completes, a second cancel, revocation, overflow, or a write, insert or gap failure.
- Tick the Chunk 3b steps.
- Record the refused-start rendering fix and its two new tests.

```findings
findings:
  - id: new
    severity: Important
    family: result-text-weaker-than-evidence
    title: |
      A tool refused at start during flushing is written as an unknown failure, not as cancelled by the user
    detail: |
      generation_runner.lua:306-313 answers a start_child still queued when Stop lands with cancelled_before_effect and a bare `true` blob. insert_tool passes it on, and response_tools.lua:42-47 settled() renders any result without an identity as failure_text('unknown'). Scratch reproduction with the response_tools_spec harness (round declared, Runner.cancel, then drain): producer started 0 tools, yet the transcript reads "The tool call failed: it ended without reporting a result, so it may have partly taken effect." This contradicts the README, atlas/chat/ownership.md:65, tool_use.md:184 and the target, which all promise a "cancelled by the user" result. Same class, second instance: a tool queued in the scheduler at Stop. producer.cancel clears r.events (producer.lua:171) before service:cancel, so the known "cancelled before execution" outcome is dropped (:130), and the machine writes "Cancelled by the user while running; it may have partly taken effect" for a tool that never ran. Fix the class in one round: render from the outcome kind the machine records (put outcome on the insert_tool effect) instead of defaulting to unknown, and carry never-started evidence through the supervisor handoff. Add a test for each path.
  - id: new
    severity: Minor
    family: invariant-statement-omits-exception
    title: |
      Flush guarantee statements describe the machine alone, and the "remaining ways to lose a pair" list is incomplete
    detail: |
      This is the 5th finding in this family, so fix the rule, not the instance. Target :206-208 and tool_use.md:184 say "a tool finished by the time its pair is reached gets its real result". In the full system the Stop cancels every running tool, the producer cuts off its callbacks (producer.lua:171, response_tools maybe_resolve), and only outcomes that arrived before the Stop are real, which matters most for a stopped answer waiting behind another. Target :212-213 says the remaining ways to lose a pair are "a second Stop, reload, or an edit that revokes the answer". Every stop() reachable from flushing also includes a failed write (generation.lua:342), a failed insert (:396), a failed gap write (:296) and an overflow (:468). Rule: a sentence stating what a mechanism guarantees, or listing how it can fail, must be derived from the composed system's enumeration (every stop() reachable from the phase, plus the adapter's cancel semantics), marked as non-exhaustive, or point to the one place that enumerates. Measured prevalence: 5 findings across M1 rounds 2-5, M2 and this M3 round.
  - id: new
    severity: Minor
    family: stall-visibility
    title: |
      The flushing note names the answer it waits behind but not what ends the wait
    detail: |
      This is the 3rd finding in this family. The M2 round already stated the rule: every indefinite wait a generation can sit in is named in presentation with what it waits on AND what ends it. chat_presentation.lua:59-61 flushing_message omits the escape (a second :ParleyStop drops the rest, or stop the answer ahead), although waiting_message names :ParleyStop and the answer ahead can hang. Fix at the rule: build every wait note from one composer that requires an escape clause, and add a unit test that walks each phase the session presents while blocked (waiting, running tools, cleanup, flushing, paused) and asserts that an escape is named.
  - id: new
    severity: Minor
    family: behavior-change-sweep-by-claim
    title: |
      :ParleyToolOperations still speaks of quarantine that M3 removed for crashed tools
    detail: |
      This is the 2nd finding in this family. tool_operations.lua:21 prompts "Esc keeps quarantine" and :29 says "Resources remain reserved until cleanup is confirmed". A crashed tool whose process has ended (listed until its generation closes) holds nothing, and its cleanup is already confirmed. The M2 rule swept atlas, README, code comments and the plan. It must also cover user-visible strings (prompts, notifications, model-facing results): `git grep -i quarantin lua/` finds this one. Measured: 1 residual site (2 strings) after the M3 sweep.
  - id: new
    severity: Minor
    family: design-enumeration-lags-code
    title: |
      The plan's ARCH-ORDER phase line omits flushing; Chunk 3b steps are unticked
    detail: |
      Plan :129-130 still lists preparing, requesting, executing_tools, draining, finalizing and terminal, plus stopping; it has no executing_tools to flushing to stopping arrow, although that section calls itself "the design". Chunk 3b's step checkboxes are all unticked while the issue marks the work done. Add a Revisions entry extending the phase line with flushing's entry and exits, and tick the steps.
```

---

## Re-review — 2026-09-18T12:32:53-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 5a9f43d18ec125283e109194f1a637419c60721b..b6cfcd9760627ab80e014d43101a120318bffa78 |
| command | sdlc milestone-close --issue 266 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-18T12:32:53-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 2 of the M3 gate. All five prior findings are genuinely disposed, and the Important one (BR-15) is fixed at the class rather than the site: the decision "did this tool actually run?" moved out of the runner's timing and into the pure machine, which now cancels on the spot only a child it never started and otherwise waits for the settlement that proves what happened (`generation.lua:145-149`, `:209-223`), while `producer.cancel` stops erasing the scheduler's own "cancelled before execution" evidence (`producer.lua:167-181`). I verified each half by reverting it in a scratch worktree and watching a named test go red, and the full suite is green in the pinned tree (lint 0 warnings / 0 errors across 634 files; unit 213/213; integration 163/163, run as separate phases). Nothing new is Critical or Important. Three Minors remain, the sharpest being that one of the three mechanisms the plan credits for the BR-15 fix — carrying `outcome` on the `insert_tool` effect and rendering from it — has no reachable consumer: with it reverted and an assertion planted in the branch, 213 unit + 161 integration spec files run without ever entering it.

### 1. Strengths

- **The fix landed where the prior round said it should.** Round 1's architectural note was "the runner decides something the machine should own." `cancel_child` (`generation.lua:145-149`) now keys on `child.started`, and the flushing walk (`generation.lua:209-223`) cancels only a never-started child, so the transcript label is derived from a machine-held fact instead of from when the walk happened to look (ARCH-PURE).
- **Both instances of the class were swept, not just the named one.** The runner-refusal path (`generation.lua:418-419`) and the scheduler-queued path (`producer.lua:177-178`) were fixed in the same round, each with its own test. Scratch reverts confirm: dropping `found.cancelled='queued'` reds `generation_spec` "records a tool refused before it ran during the flush…"; restoring the old `producer.cancel` body reds `tool_producer_spec` "settles a cancelled tool that never started by its own outcome."
- **The stall-visibility rule got structural enforcement, not a third patched string.** `wait_note` (`chat_presentation.lua:57-60`) asserts its escape clause, so a new wait note cannot be written without one, and `chat_presentation_spec` walks every note shown while an answer waits. Reverting `flushing_message` to a bare string reds two tests.
- **The "one statement" is accurate.** I enumerated every `stop()` in `generation.lua` and checked reachability from `flushing`: `gap_result` (:304), `write_result` revoked/uncertain (:350), `grant_revoked` (:363), a failed `inserted` (:404) and the second-Stop/overflow cancel (:478) — exactly the list in `atlas/providers/tool_use.md:214-219`. `prepare_failed`, `provider_failed`, `round_capacity` and `finalize_failed` are all unreachable from the phase.
- **The quarantine sweep is complete for `lua/`.** `git grep -i quarantin lua/` now returns one hit, `tools/operation.lua:105`, a comment that says "not a quarantine." The two remaining atlas hits are the file-descriptor quarantine, a different concept M3 never touched.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

- `lua/parley/generation.lua:129` / `response_tools.lua:43,144` / `generation_runner.lua:521` — the `outcome` plumbing has no reachable consumer; `continue_round` (`response_tools.lua:193`) still calls the same `settled` without it, so the function's own "the transcript and the wire cannot differ" comment no longer holds.
- `README.md:73-77` — paraphrases what a Stop writes instead of pointing at the single statement it now has; the scheduler-queued case is written as "Tool cancelled before execution", not "cancelled by the user", and "a second `:ParleyStop` drops the rest" is one of four early exits.
- `atlas/providers/tool_use.md:203` (row "queued in the scheduler, never run") — asserted only at the producer seam, never as transcript text.
- `lua/parley/tool_operations.lua:30` — `value.physical_resolved` is read from the `producer.list()` snapshot taken before two async `vim.ui` prompts, so the notification can describe stale state. Advisory text only; cheap to re-read via `producer.list()` at notify time.

### 5. Test coverage notes

- **Covered and verified red-without-the-fix:** the runner-refused start (machine + end-to-end, `response_tools_spec` asserts `#f.producer.started==0` and the rendered text); the scheduler-queued cancel at the producer seam, driven through the real `Scheduler` with a fake tool; every wait note's escape clause.
- **The 24-permutation sweep changed shape.** Round 1's biconditional ("real iff its outcome came before the Stop") is now a forward implication plus `content == expected or content contains "Cancelled by the user"`. The weakening is correct — an outcome arriving mid-flush is now legitimately written as real — and the replacement still fails on an unknown-failure rendering, which is the class BR-15 shipped. Worth keeping in mind that it no longer pins *which* of the two renderings a given order produces.
- **The `drain()` helper now returns at quiescence** (`response_tools_spec.lua:37-43`) rather than after a fixed 2000 steps. This is the right change now that a flush waits on external events, and the tests compensate by driving the settlement explicitly — but it does mean a spurious `waiting` would end a drain early, so assertions in this file should stay positive ("this text is present") rather than relying on the drain to have exhausted work.
- **Still uncovered:** a second `:ParleyStop` driven at chat level (machine-level only), and the scheduler-queued row end-to-end.

### 6. Architectural notes for upcoming work

- **The flush's termination condition changed hands this round.** Round 1's walk could not stall on a tool; it now waits for each started tool's cancellation to settle, while holding the write turn. I traced all three real `producer.cancel` outcomes — refused (synchronous `done`), never-started (`physical_resolved`, outcome delivered on the next scheduled tick), running (synchronous `done({supervised=true})`) — so production always settles, and a second Stop is the documented escape. The property to defend from here on is that **every** producer path settles: a `producer.cancel` that returns without either invoking `done` or guaranteeing an outcome delivery wedges a flushing generation *and* the document's write turn. That invariant deserves a line in `tool_use.md` next to the table, since it is now load-bearing.
- **`child.outcome` still mixes certainty with label** (`cancel_child` writes `'cancelled_by_user'` into the same field that carries `'known'`/`'unknown'`). Round 1 raised this as a forward note and it is still true; `supervised_children` would report the label as the outcome. Separate the effect's certainty from its transcript label before anything consumes that snapshot.
- **ARCH walk:** ARCH-DRY pass (one `wait_note` composer, one `failures` table, the flush reuses `insert_next`/`Seq`); ARCH-PURE pass, improved (the started/never-started decision moved into the machine); ARCH-PURPOSE flagged (finding 1: a claimed mechanism with zero consumers; finding 2: the rule stated this round was not applied to README in the same round); ARCH-MOCK pass with a note (the real `Scheduler` is exercised behind the producer seam; the never-started cancel behaviour has no fake above it — finding 3); ARCH-CONSTRAINTS pass (walk bounded at 32 calls, no new timers, the new wait bounded in production as above); ARCH-SECURE N/A (no new untrusted input or credentials; `failures[outcome]` is a guarded lookup that degrades to `'unknown'`); ARCH-ORDER pass (the new wait is a machine transition, driven in tests through `operation_supervised`/`child_outcome` with controllable ordering across 24 permutations); ARCH-FUNERAL pass and an improvement (unchanged from round 1).

### 7. Plan revision recommendations

- Amend the `2026-09-18 — M3 boundary review round 1` entry: bullet **(3)** ("`insert_tool` carries the recorded outcome kind and `settled()` renders from it") changes no behavior — the branch is unreachable because a `cancelled_before_effect` during a flush already sets `child.cancelled='queued'`, which routes to `ctx.failure`, and every other blob that reaches `settled` carries identity. Record whether the plumbing is being deleted or made reachable, and do not leave the bullet claiming a delivered mechanism.
- Add to the same entry that the invariant rule stated this round applies to `README.md` as well as atlas and the target, and name the sweep that was run.

```findings
dispose:
  - id: BR-15
    disposition: addressed
    note: |
      Both instances fixed and each pinned by a test that fails without it (scratch-worktree reverts): generation.lua:418-419 + generation_spec "records a tool refused before it ran during the flush"; producer.lua:177-178 + tool_producer_spec "settles a cancelled tool that never started by its own outcome"; plus end-to-end response_tools_spec asserting zero producer starts and the rendered text. Residual: the third claimed mechanism (insert_tool outcome field) is unreachable — raised separately.
  - id: BR-16
    disposition: addressed
    note: |
      atlas/providers/tool_use.md:191-219 now states the flush's per-tool results and its early exits once; I re-enumerated every stop() in generation.lua and the reachable set matches exactly. The target withdraws the two incomplete sentences by Revision and points there, and lessons.md records the composed-system rule.
  - id: BR-17
    disposition: addressed
    note: |
      chat_presentation.lua:57-60 wait_note asserts an escape clause, so a wait note cannot be written without one; chat_presentation_spec walks every note. Reverting flushing_message to a bare string reds two tests in a scratch copy.
  - id: BR-18
    disposition: addressed
    note: |
      tool_operations.lua:21,30 reworded and the resource sentence conditioned on physical_resolved; `git grep -i quarantin lua/` now returns only operation.lua:105, a comment stating it is not a quarantine. The two remaining atlas hits are file-descriptor quarantine, an unrelated concept.
  - id: BR-19
    disposition: addressed
    note: |
      Plan :131-134 adds executing_tools → flushing → stopping with its entry and exits and points at the single statement; Chunk 3b steps are ticked; a Revisions entry records the round-1 response.
findings:
  - id: new
    severity: Minor
    family: fix-without-reachable-consumer
    title: |
      The insert_tool `outcome` field and settled()'s third parameter have no reachable consumer, and the second caller was not updated
    detail: |
      generation.lua:129 adds `outcome` to the insert_tool effect, generation_runner.lua:521 forwards it as ctx.outcome, and response_tools.lua:43,144 renders from it. The branch is unreachable: a cancelled_before_effect during a flush already sets child.cancelled='queued' (generation.lua:419), which routes to ctx.failure, and every other blob reaching settled() carries identity. Evidence - reverting both hunks leaves the whole providers/tool_use key green (617/617); planting an assert in the branch and running the full suite in a scratch worktree fires it in none of 213 unit + 161 integration spec files. The plan's round-1 Revisions entry credits this as mechanism (3) of the BR-15 fix. Separately, continue_round still calls settled(c,ctx.results[i]) with no outcome (response_tools.lua:193), so the function's own comment "One function for both readers, so the transcript and the wire cannot differ" is false the moment the branch becomes reachable. Rule: a mechanism a fix claims must have a consumer a test enters, and a shared renderer that gains an input must gain it at every call site. Either delete the plumbing and correct the plan bullet, or make it the mechanism, pass it from continue_round too, and cover it.
  - id: new
    severity: Minor
    family: invariant-statement-omits-exception
    title: |
      README restates what a Stop writes instead of pointing at the single statement created this round
    detail: |
      This is the 6th finding in this family. Earlier rounds fixed instances; this round finally stated the rule (lessons.md, and atlas/providers/tool_use.md:191-219 "Stop during a tool round"). Do NOT fix this instance by rewording README - apply the rule that was just written. README.md:73-77 says a Stop "writes every call with its result - or a 'cancelled by the user' error" and that "a second :ParleyStop drops the rest". Neither is derived from the composed system the new section enumerates: a tool queued in the scheduler is written with the scheduler's own "Tool cancelled before execution" (tool_use.md:203, verified through producer.cancel -> service:cancel -> cancelled_before_effect -> outcome 'known'), and a second Stop is one of four early exits. The rule's own remedy - "point to the one place that enumerates" - has been applied to ownership.md and the target but not to the one user-facing page. Extend the rule's scope to README and user-visible strings, and sweep. Measured prevalence: 6 findings across M1 rounds 2-5, M2, and M3 rounds 1-2.
  - id: new
    severity: Minor
    family: composed-claim-tested-at-one-seam
    title: |
      The "queued in the scheduler, never run" row is asserted only at the producer seam, never as transcript text
    detail: |
      tool_use.md:203 states a composed-system outcome - a tool the scheduler never started is written into the transcript as "Tool cancelled before execution". The only test is tool_producer_spec "settles a cancelled tool that never started by its own outcome", which asserts the producer callback, not the rendered block; no spec drives that case through response_tools into the buffer. This is the exact case BR-15 named as its second instance, so the fix's end-to-end effect rests on my reading of the composition rather than on an oracle. Rule - a row of a behavior table that states composed-system output needs a test at the composition, not only at the seam whose contract changed. Cheapest fix: in response_tools_spec, a fake producer whose cancel delivers a known "cancelled before execution" outcome instead of the supervisor handoff, asserting the written result text.
```
