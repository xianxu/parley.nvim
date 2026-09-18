---
id: 000266
status: working
deps: []
github_issue:
target: transcript-is-the-whole-truth
created: 2026-09-17
updated: 2026-09-17
estimate_hours: 13.17
started: 2026-09-17T11:06:53-07:00
---

# Serialize transcript mutation: queue generations, insert tool call/result pairs in order

## Problem

Transcript mutation is concurrent today, and the resulting edit history is not
something a user can reason about. Up to four generations may write one document
(`document/state.lua:190`, `if count(s.generations)>=4 then return reject('generation limit')`),
and within a single tool round every call block plus every `(Tool result pending)`
placeholder is appended in one write, after which results fill their reserved
slots **in completion order** (`response_tools.lua:137-170`):

```lua
for i in ipairs(calls)do
    append('

')
    local first=length
    append('(Tool result pending)')
    slots[i]={first=first,last=length}
end
```

So the buffer's undo chain carries entries from unrelated exchanges interleaved,
and holes that fill out of document order. Undo rewinds someone else's answer;
the user cannot predict what a keystroke restores. That unreasonable history is
the reason a bespoke restore sidecar existed beside the file at all — see
[[transcript-is-the-whole-truth]] and parley#261. Fixing the history is what lets
the sidecar be deleted rather than replaced.

This issue knowingly **reverses a #254 decision**. `atlas/chat/ownership.md:8`
currently promises "Disjoint generations may write separate answers while the
human edits the next question." That was a reasonable throughput choice; it is
being traded for a history a person can hold in their head. The atlas must be
rewritten, not merely appended to.

## Spec

**The invariant: concurrency belongs in scheduling and execution, never in
mutation.** Requests run in parallel; tool calls execute in parallel; writes land
one at a time, in the order the reader sees them.

### 1. Generations — concurrent execution, serialized writes

Operator decision: option (b), not full queuing. A second generation's provider
request *starts* while the first is still streaming; its output is **held** until
the first generation's writes are complete, then applied in full. One writer per
document at any instant.

Consequences to design:

- `document/state.lua:190`'s limit of 4 concurrent generations becomes a limit on
  concurrently *admitted* generations, with exactly one holding write authority.
  The write turn is a queue, ordered by admission.
- Held output needs an explicit byte bound and a defined behavior at the bound
  (ARCH-CONSTRAINTS). A held generation can be waiting behind a long tool chain,
  so this is not a small buffer. Name the budget, its basis, and what happens
  when it is exceeded — the existing staging limits (`generation_runner.lua:75`,
  1 MiB per generation / 16 MiB process-wide) are the precedent to reuse or
  supersede, not to duplicate (ARCH-DRY).
- Cancellation, revocation and staleness must be expressible for a generation
  that is *complete but not yet written*. That is a new lifecycle state; enumerate
  it explicitly rather than encoding it as a boolean pair (ARCH-ORDER).

### 2. Tool rounds — concurrent execution, serialized `(call, result)` insertion

Replace the bulk upfront reservation with monotonic ordered append: insert tool
call 1's block and its result, then call 2's block and its result, and so on in
call order — even when call 2's result returns first. The transcript grows
forward and never fills a hole.

Consequences to design:

- The reserved-slot mechanism and the child-grant machinery that exists to police
  those slots both become unnecessary. Removing them is part of the deliverable,
  not a follow-up (ARCH-PURPOSE); a serialized append that still carries the slot
  bookkeeping is the easy subset.
- Progress visibility must not regress. Today the user sees all calls in a round
  immediately. After this change the transcript shows only what has landed, so
  concurrent progress belongs in the **presentation** layer — `chat_pending`
  extmarks, which by contract never become Markdown, undo entries, saved text or
  request context (`atlas/chat/response_progress.md`). Presentation may stay as
  concurrent as it likes precisely because it is not the transcript.
- A tool whose result never arrives must not stall the ones behind it forever.
  Define the ordering guarantee against an unresolved call (skip-with-marker,
  bounded wait, or explicit failure), and cover it — an unknown outcome is
  already the hardest case in the batch model.

### 3. Atlas

`atlas/chat/ownership.md` and `atlas/providers/tool_use.md` state the current
disjoint/ordered-slot model as fact. Both are consumers of this decision and must
derive from the new one, not restate the old (ARCH-PURPOSE shadow-sweep).

## Done when

- One writer mutates a transcript at any instant; a second generation's output is
  held and applied whole, in admission order.
- A tool round appends `(call, result)` pairs in call order regardless of result
  arrival order; no placeholder text is written and later overwritten.
- The reserved-slot and child-grant machinery that only existed to police
  out-of-order fills is deleted.
- Undo over a session with two concurrent generations and a multi-call tool round
  walks backwards in document order, and a test asserts that ordering rather than
  only asserting final content.
- Held-output byte budget is declared with its basis and its behavior at the
  bound, and a test drives the overflow path.
- An unresolved tool call has a defined, tested effect on the calls behind it.
- `atlas/chat/ownership.md` and `atlas/providers/tool_use.md` describe the
  serialized model; no page still promises disjoint concurrent answer writes.
- No regression in batch sequencing, cancellation, or reload/detach retirement.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

**Revised twice on 2026-09-17 by the estimate-quality judge: 14.74 → 10.74 → 13.17.**
Pass 2 corrected an inflated design share; pass 3 corrected the over-correction on
the implementation side. Pass-3 changes: `item:` lines added for Task 1.7
(held-output budget — a Spec-gated deliverable with six steps including a p50/p95/p99
re-measure) and Task 1.9 (undo coherence — net-new test authoring, since undo
ordering is unasserted anywhere in the tree today); M1's visibility work
(Task 1.6 Step 4) itemized for symmetry with M3's progress edge, which was already
counted; M3's removal split into its two actual tasks (3.2a tickets, 3.2b
reservation lifecycle) rather than one row; M4's sweep reslugged
`cross-cutting-refactor` → `lua-neovim`, because `cross-cutting-refactor`'s
40%-scaled impl range is 0.08–0.2 and cannot carry Chunk 4, and because removing
`open_first`/`open_last` from `overlaps`/`contains`/`writable` is semantic rather
than a mechanical rename; atlas design discounted ×0.2 to 0.04 (Task 1.10 names
the exact pages *and* which not to touch — the textbook Step 3 case); and a fifth
`milestone-review` for M4's own `milestone-close`, which the `Mx` tag commits to
ahead of the issue close.

**Judge's unit caveat, recorded:** v3.1's 0.40 impl scale was fit on rows where
within-session fan-out compressed wall-clock below a sequential sum. This plan is
near the worst case for that discount — strict TDD red→green per step, `make test`
gated between removals, and an explicit ordering constraint forbidding
parallelization in M4. Expect impl to land high rather than low (`baseline-v3.1.md`
open question #3).

**Original pass-2 rationale (14.74 → 10.74).** The
first derivation reconciled arithmetically but mis-allocated: design was 76% of
the pre-buffer total against a ledger mean of 0.35, and Σdesign 10.1 would have
been the largest design figure in the ledger's history. Its stated justification
("six revisions and six reviews, inside the measured window") is measurable, and
`sdlc actual --issue 266` reads **4.32h** for a window that already contains all
six revisions and all six reviews — so 11.6h post-buffer implied ~7h of *further*
design dialogue on a plan carrying a `## Decisions taken, so they are not
re-opened` section written to prevent exactly that.

Corrections applied:

1. **v2 Step 3 now applied, not skipped.** The first pass took full top-of-range
   design *and* v2.1 Step 6's +15% thorough-plan buffer — the credit claimed on
   the buffer and denied on the hours. Design for plan-resolved primitives is
   discounted ×0.2; `issue-spec` is not discounted, since its design *is* the
   spec authoring.
2. **Design anchored to measurement.** Σdesign 5.2 × 1.15 = 5.98, against 4.32h
   already spent plus modest in-flight design across four milestones.
3. **Implementation decomposed.** `lua-neovim` is the table's "single, focused"
   feature; M1 and M3 are each several. M1 splits into the turn module + reducer,
   the coordinator guard + six caller predicates, and the `draining` phase +
   release matrix. M3 splits into `ToolSequence` + ordered pump, the `⏳:` marker
   + 24-permutation sweep, the reservation/ticket/child-grant removal, and the
   tool→pending progress edge.
4. **Atlas counted three times**, matching the three rewrites the plan schedules
   (`chat/ownership.md` and `providers/architecture.md` in Task 1.10,
   `providers/tool_use.md` in Task 3.6). These are rewrites, not appends.

Familiarity 1.0 — the document subsystem is well understood after the #261
audit, but intricate enough that no discount is warranted.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: issue-spec                design=1.5  impl=0.12
item: lua-neovim                design=0.6  impl=0.6
item: cross-cutting-refactor    design=0.2  impl=0.2
item: lua-neovim                design=0.6  impl=0.6
item: lua-neovim                design=0.2  impl=0.3
item: lua-neovim                design=0.2  impl=0.3
item: lua-neovim                design=0.2  impl=0.3
item: milestone-review          design=0.0  impl=0.2
item: lua-neovim                design=0.4  impl=0.4
item: milestone-review          design=0.0  impl=0.2
item: lua-neovim                design=0.6  impl=0.6
item: lua-neovim                design=0.4  impl=0.5
item: cross-cutting-refactor    design=0.15 impl=0.2
item: cross-cutting-refactor    design=0.15 impl=0.2
item: lua-neovim                design=0.2  impl=0.3
item: milestone-review          design=0.0  impl=0.2
item: lua-neovim                design=0.4  impl=0.5
item: milestone-review          design=0.0  impl=0.2
item: milestone-review          design=0.0  impl=0.2
item: atlas-docs                design=0.04 impl=0.08
item: atlas-docs                design=0.04 impl=0.08
item: atlas-docs                design=0.04 impl=0.08
total: 13.17
```

Item order — **M1**: turn module + reducer; coordinator guard + six caller
predicates; `draining` phase + release matrix; held-output budget (Task 1.7);
undo coherence (Task 1.9); blocking-exchange visibility (Task 1.6 Step 4);
boundary review. **M2**: preparation-write deferral; boundary review. **M3**:
`ToolSequence` + ordered pump; `⏳:` marker + 24-permutation sweep; capacity-ticket
removal (3.2a); reservation-lifecycle removal (3.2b); tool→pending progress edge;
boundary review. **M4**: residual exclusion sweep; its `milestone-close`; the
issue close. Then three atlas rewrites.

Reconciliation: Σdesign 5.92 × 1.15 = 6.808; Σimpl 6.36 × 1.0 = 6.36; total 13.168 → 13.17.
Design share 48%, against a ledger mean of 0.35 — still above, deliberately: six
review rounds are already spent and in-window (`sdlc actual` reads 4.32h).


**Read 13.17 as a floor, not a midpoint.** The estimate-quality judge's closing
position across three passes: v3.1's 0.40 impl scale was fit on work with
within-session fan-out, and this plan has almost none available — strict TDD
red→green per step, `make test` gated between removals, and M4's explicit
"remove only after Task 4.1 is green" ordering constraint. Two rows also still
bundle more than one task (`ToolSequence` + ordered pump is Tasks 3.1 + 3.2c;
M4's sweep is Tasks 4.1 + 4.2 + 4.3). Both point the same way. At close, compare
actuals against this expectation rather than treating an overrun as a planning
miss — it is the scale that is under test here (`baseline-v3.1.md` open
question #3, ariadne#127).

Calibration caveat recorded by `sdlc estimate-source`: the v3.1 ledger is newer
than the doc, so per-primitive hours are provisional (ariadne#127).

## Plan

Durable plan: `workshop/plans/000266-serialize-transcript-mutation-plan.md`
(six revisions, six fresh-context reviews).

- [~] M1 — the write turn **and** the preparation-write deferral. One boundary,
      not two: the turn alone leaves nine end-to-end tests red purely because a
      second generation's request never starts, and the deferral is what removes
      that. A milestone that cannot go green on its own is not a review boundary
      (AGENTS.md §3), so these close together.
      - [x] `WriteTurn` pure entity
      - [x] turn state in the document reducer
      - [x] coordinator passthrough + notify-on-turn-change
      - [x] `draining` phase and `turn_status` mirror
      - [x] `'waiting'` refusal at the coordinator and in `Replacement.step`
      - [x] defer preparation's write until there is output (restores option (b))
      - [x] release/re-request matrix + end-to-end wake + waiter visibility
      - [x] held-output budget message; writer-enumeration verification
      - [x] undo coherence assertion
      - [ ] atlas rewrite + `milestone-close`
- [ ] M2 — ordered `(call, result)` append; removes capacity tickets, the round
      reservation lifecycle, and child grants.
- [ ] M3 — residual exclusion sweep (`exclude`, parent-slot carving, the
      half-open seam flags, the ancestor walk).

## Log

### 2026-09-17

Split out of parley#261 during its planning. #261 (delete the external answer
recovery store, rely on in-session memory) depends on this: removing a targeted
restore is only safe once the undo history it falls back to is linear and
document-ordered. Sequencing is this issue first or alongside, never after.

Operator framing: "this presents a linear history user understands, while
allowing concurrent scheduling of things to happen."

### 2026-09-17 — mechanical digests (design inputs)

Three fresh-context digests: generation write path, tool round insertion, test
harness. Findings that change the design, all verified against the tree.

#### The target format already works end-to-end

`tests/fixtures/transcripts/two-round-tool-use.md:11-26` is **already** laid out
`🔧 A / 📎 A / 🔧 B / 📎 B`. `chat_parser.lua:833-852` imposes **no pairing, no
adjacency and no id-matching** between a call block and a result block — each
marker at depth 0 simply closes the previous block. `tests/unit/chat_parser_tools_spec.lua:194`
asserts the interleaved layout parses to
`{"text","tool_use","tool_result","tool_use","tool_result","text"}`. So M2 is not
introducing a new transcript shape; it is making the writer emit the shape the
reader and the goldens already accept. Large de-risk.

#### But interleaving changes the RESUBMIT wire shape (open decision)

The ordering invariant lives in the wire builder, not the parser:
`chat_respond.lua:636-651` flushes the assistant message on the **first** matched
`tool_result`. So `call₁ result₁ call₂ result₂` builds **four** messages
(assistant[tool_use a] / user[result a] / assistant[tool_use b] / user[result b])
where today's batched layout builds two. `tests/unit/build_messages_spec.lua:1189-1192`
already pins that:
`{"system","user","assistant","user","assistant","user","assistant","user"}`.

The **live** round is unaffected — `response_tools.lua:220-239 continue_round`
rebuilds from the frozen `s.rounds[ctx.round]` record and always batches all
`tool_use` blocks into one assistant message (`:230`) and all results into one
user message (`:231`). Only a later re-parse/resubmit of the saved transcript sees
the interleaved shape. Consequence: after M2, reopening a chat and resubmitting
presents parallel tool calls to the provider as sequential turns rather than one
parallel turn. Needs an operator decision — see `## Open decisions`.

#### M1 — the real obstacle is a conflated predicate

Holding output needs **no new buffer**: `generation.lua:107-116 pump` only
dequeues items whose grant passes `writable`, so a generation without the turn
already accumulates in `s.queue`. But:

- `stage()` refusal **destroys the generation**. `generation_runner.lua:160` on
  refusal does `issue(s,'staging overflow')` + `dispatch{type='cancel'}`, which
  reaches `response_provider.lua:88-90` and kills the provider process. There is
  no third behavior at the bound, so the 1 MiB per-generation cap
  (`generation.lua:163`, `generation_runner.lua:464`) and the cancel-on-refusal
  must both be superseded for a queued writer, not inherited.
- **`staged(s)==0` means both "my writes drained" and, implicitly, "I may write."**
  It gates round continuation (`generation.lua:123`, `:129`) and finalize (`:149`).
  A held generation has `bytes>0` forever and never advances. Teaching those three
  sites the difference between "queue non-empty because mid-stream" and "queue
  non-empty because it is not my turn" is the central task of M1; a naive
  implementation deadlocks here.
- `suspended` cannot be reused as the "not my turn" signal: it means structural
  uncertainty (`state.lua:328,338`) and `reconcile` (`:329-340`) flips it back to
  `valid` on the next confirmed proof.
- The generation slot is freed at **terminal**, not at provider-complete —
  `generation_runner.lua:436` is the only `finish_generation` caller.

Seam candidates: (A) `document/state.lua` reducer + `M.resolve` — single
chokepoint for all authority, `gid` is already monotone by admission so the queue
key is free; cost is that `reject(reason)` strings are read as control flow in
three places (`generation_runner.lua:275-276`, `document/init.lua:535-536`,
`generation.lua:227-230`) that would misread a new `'waiting'` as revocation.
(B) `generation.lua:32-39 writable` + a turn flag; needs the turn to ride in
`D.snapshot`, which today exposes only
`{epoch,attached,generations,grants,capacity_tickets,max_dependencies}`.
(C) `generation_runner.lua:259 write()` declining — cheapest (~3 lines, `M.step`
already supports `'waiting'`) but holds the *effect* not the output, so the 1 MiB
cap still bites and `s.inflight` stays occupied, reproducing the same deadlock.

#### Coarse undo falls out for free

`document/editor.lua:194-202 can_join_undo` already requires `plan.generation`
**and** `plan.grant` to match the previous receipt. Two concurrent generations
invalidate each other's receipt on every write (identity mismatch at `:199`, plus
`:67` on each other's observed edit), so **today every 4096-byte chunk is its own
undo entry**. Serializing writes makes `can_join_undo` succeed for runs of the
same generation with **no change to that function** — undo becomes one entry per
generation run, not merely ordered. This is a larger UX win than linearity itself.

#### Paths that bypass the runner and still need the turn

- `response_topic.lua:141-147` registers a **second generation** on the same
  document from inside an already-running response (`chat_respond.lua:1657`,
  finalize adapter) and writes via `D.apply` at `:165-166`, bypassing
  `generation_runner` entirely.
- `response_preparation.lua:90,101,108` and `response_completion.lua:63,71` write
  as `manual_append`/`manual_replace` (`generation_runner.lua:357-358`).
- `apply_user` (`document/init.lua:432`) is the human path and is **correctly not
  subject to the turn**; the guarantee is ordering *between generations*, not
  absolute.

#### M2 — what becomes dead

Serialized append-only insertion removes the need for child grants entirely (each
write is an append at the parent grant's tail — no sub-regions, no exclusion).
Unreachable afterwards: the whole capacity-ticket subsystem
(`state.lua:170-180,199-212,253-256`; only consumers are `response_tools.lua:164,23`),
`exclude` (`state.lua:147-159`, sole call site `:239`), the parent-slot carving and
`'parent slot limit'` (`:237-241,252`), the `open_first`/`open_last` half-open
handling in `overlaps`/`contains`/`writable` (`:32-45`), `'outside parent'`/`'parent'`
rejections (`:226-236`), the ancestor walk + `g.tail_lost` (`:291-311`),
`'delegated parent'` (`:99-101`, `init.lua:528-529`), `'active child'` in
`reclaim_tail` (`:265-268`), `response_tools.lua:21-26,36-68,154-161,183-187,240`,
`generation.lua:54-72,131-134,289-316`, `generation_runner.lua:329-354,382-389,404-434`.

Already dead with **zero readers** in `lua/` or `tests/`: `receipt.markers`
(`response_tools.lua:66`), `children[i].call_block` and `children[i].result_slot`
(`generation.lua:293`).

Execution concurrency is independent of insertion and stays: fan-out cap 4
(`generation.lua:84`), scheduler admission `running<16 / per_document<8 /
per_generation<4` (`tools/resources.lua:82-90`) with real path-scoped claims
(`tools/async_builtin.lua:248-267`).

#### Unresolved calls today: the round stalls, nothing synthesizes a result

No timeout produces a result. A producer that never calls `outcome` leaves the
machine in `executing_tools`; the only reaction is a diagnostic notice after a
5000 ms deadline (`tools/operation.lua:112-122` → `tools/producer.lua:50-56`,
`vim.notify(... WARN)`). `outcome='unknown'` pauses the generation
(`generation.lua:332-334`) and requires a later `'known'` plus an explicit
`Runner.resume`. At batch level `batch.lua:91-94` latches `s.unknown` and `:99`
refuses resume **permanently**. Buffer fallback exists only on a later build:
an unmatched `🔧:` becomes `"(tool call did not complete — no result recorded)"`
(`chat_respond.lua:604,617-630`).

#### Presentation is confirmed extmark-only

`grep` for `nvim_buf_set_lines|nvim_buf_set_text|D.append` over `chat_pending.lua`,
`response_status.lua`, `chat_presentation.lua` → zero hits. The channel for tool
progress is `session:progress(event)` (`chat_pending.lua:160-165`), which already
accepts an `event.tool` key (`chat_presentation.lua:58`). **There is no tool →
pending edge today** (`response_session.lua:100-101` feeds only provider stream
progress), so M2 must add it. Caveat: `session:written(row,col)`
(`chat_pending.lua:166-171`) is called from `response_session.lua:180-183` on every
write receipt and tears the progress line down — serialized insertion writes more
often, so that interaction needs care.

#### Harness facts that constrain the plan

- Branch **must** be named `000266-<slug>`: `tests/arch/single_source_sweeps_spec.lua:713`
  only enforces "every spec this branch added is routed in `atlas/traceability.yaml`"
  when the branch matches `^%d%d%d%d%d%d%-`; otherwise it passes as `pending`.
- **Never run a spec bare.** `workshop/lessons.md:1280` — a raw
  `nvim --headless -c PlenaryBustedFile` overwrote the operator's real
  `~/.local/share/nvim/parley/cliproxy/config.yaml`. `make` owns the sandbox.
  `make test-spec SPEC=chat/ownership` takes an **atlas key**, not a path.
- `--verified` evidence must be a full `make test` (lint runs first);
  `workshop/lessons.md:792` records a close where green specs masked a red lint.
- Fully synchronous pump for ARCH-ORDER coverage:
  `D.repair_step(doc); Runner.step(runner); adapter.step()` in a bounded loop
  (`tests/integration/response_tools_spec.lua:7-57`). An 8-order × 2-mode
  cartesian sweep already exists at `:261` to copy for the unresolved-call matrix.
- Undo ordering is **unasserted anywhere today** — only final content. The tool is
  `vim.fn.changenr()` via `nvim_buf_call` (`document/editor.lua:13`). Since
  `can_join_undo` behavior changes, add a seed to the randomized oracle
  `tests/integration/document_native_history_spec.lua` (seeds `{1,17,254,4099}`)
  rather than writing a bespoke spec.
- Tests to invert, not delete: `response_tools_spec.lua:141` (`assert.is_true(a<b and b<ra and ra<rb)`)
  and `chat_scoped_response_spec.lua:47` ("runs two disjoint answers while the
  next question is edited").

## Open decisions

- ~~**Resubmit wire shape.**~~ **RESOLVED 2026-09-17 — accept the four-message
  shape.** A resubmitted interleaved transcript presents parallel tool calls as
  sequential turns. Accepted because (a) it is already a tested, supported path
  (`tests/unit/build_messages_spec.lua:1189-1192` pins it as correct), (b) a wire
  that faithfully reflects the file is the point of
  [[transcript-is-the-whole-truth]] — coalescing would rewrite the file's meaning
  on the way out, and (c) the alternative requires writing **round identity into
  the transcript**, which is exactly the hidden coupling the target exists to
  prevent. Cost accepted: a resubmit no longer records that the model issued the
  calls in one parallel turn.

- **Undo ordering claim in `## Done when` is overstated — corrected during
  planning.** Generations write to *different regions* (different answers), so
  serializing by admission order does not make successive undo steps monotonic in
  document position: regenerating Q3 then Q1 writes Q3's region first, so undo
  removes Q1's text before Q3's. What serialization actually guarantees, and what
  the tests must assert, is that **each undo step removes exactly one coherent
  unit** — one generation's contiguous contribution, or one `(call,result)` pair —
  with no interleaving inside an entry and no partial-chunk entries. Document
  order *is* guaranteed within a single generation's tool round, where insertion
  is monotonic at the tail.

### 2026-09-17 — M1 ships over-serialized; option (b) postponed to M2

Planning surfaced a conflict between the turn's acquisition point and the
operator's option (b). The turn is taken at `start`, i.e. in `preparing`, so a
second generation's preparation writes (`response_preparation.lua:90,101,108`)
are turn-blocked. `Preparation` then never retires `'applied'`, `cb.prepared`
(`response_session.lua:131-133`) never fires, and `generation.lua:103-105` never
advances `preparing → requesting` — so **the second generation's provider request
never starts**. That is full queuing (option (a)) where the Spec chose option (b).

**Decision (operator, 2026-09-17): do the right thing rather than satisfy the
gate.** Two paths were on the table:

- *(i)* exempt preparation writes from the turn, restoring option (b) inside M1.
  **Rejected** — it leaves a write path outside the invariant and splits a
  generation's undo run with a foreign gap, and it would have been adopted to
  make a milestone green rather than because it is right.
- *(ii)* defer preparation's write until there is output to write, so nothing is
  exempt. **Chosen**, and **postponed to M2** rather than folded into M1, which
  already carries the turn, the phase and the release matrix.

M1 therefore ships **stricter** than the target, never looser: writes are
serialized *and* requests are queued. No transcript can be corrupted by
over-serialization; the cost is latency until M2 lands.

Test consequence: `tests/integration/chat_scoped_response_spec.lua:47` asserts
two concurrent provider dispatches. M1 changes it to assert the queued shape with
a comment naming the plan's "Deliberate over-serialization in M1" section; M2
Task 2.3 restores the concurrent assertion and deletes that section.

### 2026-09-17 — M1 Task 1.1 done; and a harness flake worth knowing

`WriteTurn` landed pure with 8 passing cases, routed under `chat/document`.
Added two cases beyond the plan: numeric-not-lexical ordering (guards the
`'g'..serial` assumption three plan revisions carried before `state.lua:6-7` was
actually read) and non-mutation of the caller's table.

**Harness flake, pre-existing, not a regression.**
`tests/integration/document_fold_batches_spec.lua` aborted the whole
`chat/document` target twice in a row — four tests green, then
`make: *** [test-spec] Error 1` with no assertion failure and no summary. It
reproduced on a **clean tree** (changes stashed), so it is not #266's. The
casualty is its 5th case, `'suspends broad cleanup above fifty thousand rows…'`.
A third run passed it, and a `make -k` run reported 0 Failed / 0 Errors across
all 32 files (325 successes) — so it is a **timeout flake on the 50,000-row
corpus under parallel load**, not a broken test. `tests/helpers/spec_runner.lua:7-14`
already grants it `timeout=180000, sequential=true` for exactly this reason; the
default `JOBS=8` still gets it sometimes on this machine.

Consequences to remember:
- A single flaky spec **aborts the whole target**, so unrelated specs after it in
  the run never execute — twice this hid whether `document_write_turn_spec` had
  even run. When verifying one spec inside a large key, use `make -k test-spec
  SPEC=<key>` so a flake elsewhere cannot mask the result.
- Close evidence (`make test`) can flake for this reason. If it does, re-run
  before treating it as a failure — and say in `--verified` which run is being
  cited.

### 2026-09-17 — M1 progress checkpoint (Tasks 1.1–1.5 landed)

Commits: `b2644342` WriteTurn · `9e55df1a` reducer · `7c5c0dde` notify ·
`431afd98` draining + turn mirror · `b6a4034b` coordinator guard.

**Green:** `document_write_turn_spec` (8), `document_state_spec` (24),
`document_turn_wake_spec` (6), `generation_spec` (39), `generation_turn_spec` (7),
`generation_sequences_spec` (32), `response_session_spec` (4/6),
`response_topic_spec` (10), `document_append_spec` (11/12),
`document_replacement_spec` (14/16), `document_coordinator_spec` (16),
`document_capacity_spec` (6), `document_ownership_spec` (7).

**Outstanding, all the same class — tests asserting the disjoint concurrent-writer
model this issue reverses.** Task 1.9 already schedules their inversion:
- `document_write_plan_spec`: 7 failures, every one a "two writers independent"
  case.
- `document_replacement_spec`: 2. `document_append_spec`: 1.
  `response_session_spec`: 2 (`'composes disjoint native writers…'` and the
  sibling-cancellation case).

**Three findings worth keeping:**

1. **Ownership must be decided before the turn.** The first guard checked the turn
   first, so a writer whose plan was *stale* got `'waiting'` — which means retry —
   and would have spun forever. `M.append` now resolves the grant first, and
   `M.apply` / `Replacement.step` only apply the turn to a writer that owns the
   grant. Caught by the two-writer plan tests, not by anything I wrote.
2. **`response_topic`'s release must fire inside its `s.writing` guard.** The
   release notifies subscribers; topic's own subscriber then re-checks its captured
   regions against the buffer the write just changed and stops the job. Releasing
   after `s.writing=false` turned two passing tests into `'cancelled'`.
3. **A test I wrote was vacuous and I nearly shipped it.** The
   replacement-continuation case had early `return`s for a setup that always
   failed (both generations acquired overlapping regions), so it passed without
   exercising the guard. It now opens a cursor, steps it *successfully* under the
   turn, and only then asserts `'waiting'` — so a later pass cannot come from a
   cursor that never worked. Setup shape copied from `document_replacement_spec`:
   the entity is the marker row, the region a later body row.

**Deviation recorded (Task 1.5):** the machine defaults `turn_status='held'`
rather than `'waiting'`. The coordinator is the enforcement point and is
fail-closed, so a turnless write is refused regardless; a fail-closed machine gate
would buy no correctness and would require every existing generation unit test to
hand the machine a turn it never needed.

### 2026-09-17 — fail-closed reversed, and a sequencing problem with the M1 way-station

**Fail-closed was reversed on measurement (`99db5af2`).** Refusing every writer
when nobody holds the turn broke **96** document-layer tests that legitimately
exercise writes without caring about turns. The invariant is now enforced
jointly: (a) every generated writer requests the turn before writing —
`generation.lua:214` (start), `:367` (resume), `response_topic.lua:169`, pinned by
`generation_spec` — and (b) the coordinator refuses anyone who is not the holder.
Given (a), the turn is always held while any generation is live, so a second
writer is always refused; an unheld turn means nothing is writing. That took the
sweep from 96 failures to 9.

**Remaining failures — all one class, all "two concurrent generations":**
- `chat_scoped_response_spec` (2): `'runs two disjoint answers…'`,
  `'admits the next captured question while a preceding answer continues streaming'`
- `chat_stop_generation_spec` (4): all four scoped-Stop cases
- `batch_lifecycle_spec` (2)
- `chat_async_tools_spec` (1)

They fail only because M1 takes the turn in `preparing`, so the second
generation's provider request never starts (the documented over-serialization).

**Sequencing problem worth deciding before grinding through them.** The plan has
M1 rewrite these to the queued shape and M2 rewrite them back — two rounds of
churn on nine tests. Worse, `chat_stop_generation_spec` exists to verify Stop
targets one generation among several *concurrent transports*; a way-station
version would have only one transport and would verify materially less. The same
applies to `chat_async_tools_spec`, whose point is overlapping tool processes.

**Proposal: do M2 before finishing M1's test inversions.** M2 (defer
preparation's write until there is output) restores concurrent request start, so
these nine tests keep asserting what they were written to assert and are never
rewritten at all. M1's mechanism is already complete and green on its own specs;
what is outstanding is only the consequence M2 removes. Nothing in M2 depends on
the inversions — it depends on M1's turn, which has landed.

### 2026-09-17 — M1 and the preparation deferral share one boundary

Operator decision: push the nine concurrency-test inversions to the preparation
deferral rather than rewriting them twice. Consequence, followed through: the
deferral is no longer a separate milestone. M1's turn mechanism cannot produce a
green suite by itself — nine end-to-end tests fail purely because a second
generation's provider request never starts — and per AGENTS.md §3 an `Mx` row
commits to its own `milestone-close`. A milestone that cannot close is not a
boundary, so the former M1 and M2 are now one, and the later milestones shift up.

This also protects coverage rather than only saving churn: `chat_stop_generation_spec`
verifies Stop targeting one generation among several **concurrent transports**,
and `chat_async_tools_spec` verifies overlapping tool processes. Way-station
versions of those would assert materially less while M2 was pending.

### 2026-09-17 — preparation deferral landed (Chunk 2); option (b) restored

The machine now owns a deferred gap (`generation.lua` `s.gap`: `none` →
`deferred` → `writing` → `none`). `prepared{gap=true}` starts the request at
once; `write_gap` is emitted immediately before the generation's first write of
**any** kind — output, round reservation or finalize — and only while it holds
the turn. One predicate, `may_write`, gates all three. The session hands the
runner a writer that starts `Preparation` on demand; the prepare operation stays
unresolved until it retires, so cancellation needs no new plumbing. Mechanism
recorded in the plan's `## Revisions`.

Visible consequences: a regenerate no longer deletes the old answer at submit
(it survives until replacement bytes exist, so a request failing before its
first byte leaves it intact — useful to parley#261); a cancel before any output
leaves the transcript byte-identical; the answer header appears with the first
output rather than at submit.

**The nine concurrency failures did not all share the cause the plan assumed.**
Deferral fixed four outright. The other five, traced one at a time:

1. **`batch_lifecycle_spec` single retry ×2 — an effect-order regression from M1
   itself.** `stop()` emitted `release_turn` *before* `revoke`. The runner executes
   one effect per step and the machine can report `terminal` in the same
   transition, so an immediate regenerate saw the old grant still live and was
   refused `'overlap'`. Confirmed against a `main` worktree (10/10 there). Fixed by
   revoking first; pinned by `generation_spec` "revokes its grant before yielding
   the turn when it stops".
2. **`chat_scoped_response_spec:75`, `chat_stop_generation_spec:190` — a
   regeneration's recovery snapshot hit a transiently suspended grant.** Another
   generation's first write (its gap, a structural replacement) now lands while a
   regeneration is still building, leaving its grant `suspended` ("structural
   uncertainty") until repair re-proves it. `chat_recovery`'s `admitted()`
   requires `valid`, so the regeneration failed for good. A suspended grant is
   still owned, so `chat_respond`'s build now waits for the `repair`
   notification instead of failing (scoped to `replacing_answer`, the only path
   that reads the live answer). Those two specs are the regression tests.
3. **`chat_stop_generation_spec:190` (again) and `chat_async_tools_spec:166` —
   they assert the concurrency this issue reverses.** Both need a second
   generation to *write* (a tool round's call block) while the first still holds
   the turn, which the lifetime-held turn (operator decision) forbids. Restated,
   not deleted:
   - the stop case now completes b before asserting a continues, and keeps its
     named invariant — b's writes below a never make a's input stale;
   - the async case moves "a disjoint path runs while a conflicting path waits"
     into **one** round (one conflicting call, one disjoint call). That is the
     path-scoped admission property itself, without cross-generation writes, so
     it holds in M1 and after M2. **M2 must re-add a cross-generation execution
     assertion** once tool execution no longer needs a reservation write.

Also moved: `capture_topic_parent` from the session's `requesting` hook to
`finalize` — at request time there is no header yet (or, when regenerating, the
*old* one). The hook then had no caller and was removed. Three header/geometry
timing assertions updated to check what they are named for
(`chat_onboarding_capture_spec` ×2, `chat_respond_spec:229`).

Side-quest `cb4960d9`: `tools_builtin_grep_spec` asserted a repo-wide grep never
contains the bare word "missing"; this plan's own line 7 tripped it.

**Pre-existing, not this change:** `perf_document_spec` times out at Plenary's
50 s default on this machine at `HEAD` without these changes too (50.19 s);
`document_semantic_spec` flakes under parallel load and passes alone.

Task 1.4 Step 5's anti-spin concern largely dissolves: preparation no longer
starts until its generation holds the turn, so B's preparation no longer waits
through A's whole stream.

Supersedes the "M1 ships over-serialized" entry above: option (b) is restored
and the over-serialization section of the plan is marked resolved.

Commits: `4e117512` revoke before release · `bb620943` regeneration waits for
proof · `8cbd6973` the deferral · `cc9d9439` two specs restated ·
`01749159` side-quest: `refresh_goldens` writes normalized payloads.

### 2026-09-17 — Task 1.6: suspension holds the turn; matrix, wake, visibility

**Operator decision:** a holder whose grant is transiently suspended keeps the
turn. Asked as "which gives the clearest linear history?": suspension is routine
(any edit the structure cannot classify at once), and releasing would queue the
holder behind the next generation's whole lifetime — `A… | edit | B | …A`.
Holding keeps each generation's writes one run; a long suspension is a fourth
visible stall shape. This drops the plan's `suspend`, `suspend_preparation` and
`waiting_head_of_line` rows and the `WriteTurn.should_release` abstraction
(it would have had one caller).

Everything that releases the turn was already implemented; the matrix
(`generation_turn_spec`: terminal/stop/detach/reload × 4 interleavings) and the
self-scheduled wake passed on first run and would fail without the turn
machinery. The waiter now shows "Waiting for the answer to line N (streaming |
running tools | preparing | finishing); :ParleyStop there stops it" on its
pending extmark (`78b521ea`, `076b8828`).

Measured while checking for overhead: `perf_ownership_spec` runs 30–41 s alone
on both `HEAD` and the working tree (run-to-run variance, no regression), so its
and `document_fold_retirement_spec`'s timeouts under `make test`'s parallel load
are the same pre-existing load flake as `perf_document_spec`.

### 2026-09-17 — Tasks 1.7–1.10: held budget, writers, undo, atlas

**Task 1.7 found a real gap.** Output arrives one SSE delta per `cb.output`, and
each was one machine queue item; a held generation hit the 256-item cap after a
few hundred deltas — a paragraph — far below the 1 MiB byte budget, and the
machine's per-transition state copy made a long held queue O(n) per event.
Consecutive output of one operation now extends the last queued item, so held
output is one item bounded by bytes. Re-measured over 359 answers in the sibling
repos (p50 573 B, p95 16.5 KB, p99 36.4 KB, max 116.7 KB): budget unchanged.
Both overflow sites now end as `overflow` with a reason naming the answer the
generation waited behind, shown by `chat_respond` (`e0f4fa79`).

**Task 1.8:** enumeration grep matches the table; the extra `D.apply_user` hits are
the recovery restore (human path). Added refusal tests for `replace_new`,
`insert_released_new`, `apply`, and the topic waiting then writing (`3c239a79`).

**Task 1.9:** one undo step per generation run on a real buffer, never mixed,
never a partial slice (`ec7a9370`). Its first version was vacuous (batched steps
hid interleaving); it now alternates single steps and fails without the turn.
Correction to the "Coarse undo falls out for free" digest above: the guarantee is
one undo entry per **(generation, grant)** run — a run through preparation grants,
the main grant and a completion grant is several entries, none mixing generations.

**Task 1.10:** atlas rewritten (`chat/ownership`, `chat/lifecycle`,
`chat/response_progress`, `chat/document`, `providers/architecture`,
`providers/tool_use`, `providers/tool_execution`); the target gains a Revision
making "in the order the reader sees them" precise; the plan's Core-concepts
rows now name module files so the arch table sweep passes; Chunk 1's checklist
reconciled (three steps struck as superseded, with reasons). Five lessons added.

