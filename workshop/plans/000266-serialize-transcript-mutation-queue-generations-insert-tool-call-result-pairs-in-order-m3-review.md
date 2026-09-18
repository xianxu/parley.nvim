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
