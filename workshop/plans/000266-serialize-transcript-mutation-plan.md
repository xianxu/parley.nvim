# Serialize Transcript Mutation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exactly one generation may mutate a transcript at a time, and a tool round appends `(call, result)` pairs in call order, so the buffer's undo history is a sequence of coherent units instead of interleaved 4 KiB chunks.

**Architecture:** The generation machine gains a **phase** for the situation the issue names — *complete but not yet written* — rather than a boolean bolted beside the existing phases. Revisions 1–3 encoded the turn as `s.has_turn`; the Spec explicitly rejects that ("That is a new lifecycle state; enumerate it explicitly rather than encoding it as a boolean pair (ARCH-ORDER)"), and every unresolved question in those drafts — an unclosable release set, a missing re-request set, ambiguous terminal ordering — was a symptom of having no state to hang them on.

The model:

- **`document/state.lua`** owns the turn (pure `WriteTurn` decision, integer generation ids, ascending by admission).
- **`generation.lua`** gains the phase **`draining`**: the provider has completed, output is staged, and the only remaining work is to write it. It also mirrors the document's turn as **`s.turn_status`** (`'held'` | `'waiting'`) — a guard input exactly like the existing `s.grant_status`, which is mirrored the same way through `sync`. This is deliberately not a new peer of `paused`: `paused` stops work, whereas a turnless generation keeps *receiving* provider bytes (the operator chose concurrent execution with serialized writes).
- **`document/init.lua`** refuses a turnless generated write with a new `'waiting'` status at the five write entry points, plus inside `Replacement.step` — the only place a multi-chunk replacement's generation is knowable.
- **`response_tools.lua`** replaces placeholder reservation with ordered `(call, result)` appends sequenced by a pure `ToolSequence`.

**Why `'waiting'` and not `busy`.** `busy` already carries three unrelated meanings (`document/init.lua:516` append-in-flight, `document/editor.lua:203` re-entrancy, `replacement.lua:55` concurrent replacement on one grant), and it means *retry now* — `generation_runner.lua:274` returns `true`, `M.step` returns `'more'`, and `Deferred` re-arms at 1 ms, so a turn-blocked writer would hot-spin for the whole time another generation streams. `'waiting'` maps to the existing `return true,'waiting'` (`:269`), which parks the timer so the notify wakes it. ARCH-CONSTRAINTS: this is a keystroke-adjacent path; an unbounded 1 ms spin is not acceptable.

**The complete enumeration of generated writers.** Revisions 1–3 each fixed one path and asserted the rest. Produced by `grep -rn "ctx\.append\|ctx\.replace\|D\.append\|D\.apply\|D\.replace_new\|D\.replace_step\|D\.insert_released_new" lua/` — **re-run this before implementing**; if it returns a row not in this table, the table is stale and must be corrected first.

| Writer | Calls | Gated where | Caller must treat `'waiting'` as retry |
|---|---|---|---|
| provider output, tool insertion | `generation_runner.lua:271,305,310` | entry points | **`:274` does NOT handle it today.** It guards only `more`/`busy`; `:275-276` maps every other status to `'uncertain'` → `write_result{status='uncertain'}` → `generation.lua:235-238` `stop()`. A `'waiting'` would **kill the generation**. Must gain a `'waiting'` arm returning `true,'waiting'`. |
| preparation gap | `response_preparation.lua:90,101,108` | entry points | **`:94`** (append statuses), **`:103`** (`replace_new` *reason* set), **`:113`** (`replace_step` statuses) — three sites, not one |
| completion prefix | `response_completion.lua:63,71` | entry points | **`:66`** (reason set), **`:74`** (statuses) |
| automatic topic | `response_topic.lua:165` | `M.apply` | **`:168` has no waiting predicate at all** — `retire(s, applied.status=='applied' and 'applied' or 'failed', …)`. Any non-applied status retires it as *failed*. Must gain one — and a **parking** one: `response_topic.lua:106` is `Deferred.new(function()return M.step(job).status=='more'end)`, the same 1 ms re-arm rejected for `busy`. Topic subscribes at `:107-110`, so a non-`'more'` status parks correctly. |
| multi-chunk replacement continuation | `replacement.lua:180` via `Replacement.step` | **inside `Replacement.step`**, using `c.generation` (`replacement.lua:60`) | **`generation_runner.lua:315` does NOT handle it.** It guards `more` and `suspended`, then `:317` calls `D.replace_cancel` — destroying the cursor this guard exists to protect. Must gain a `'waiting'` arm **before** `:317`. |
| **human edits** | `document/init.lua:432` `apply_user` | **exempt by design** | n/a |

`M.replace_step(doc,cursor)` takes an opaque cursor with no generation in scope at the coordinator, which is why the guard for continuing replacements lives one level down. Without it a cursor created while holding the turn keeps writing 4096 bytes at a time (`replacement.lua:155,165,180`) after the turn has moved — the in-flight hole that revisions 2 and 3 each believed they had closed.

**The wake — one rule at the document, but four subscribers, and two cannot act on it.** `notify()` fires only at `document/init.lua:206,223,232,381,402`, never from `M.transition`, and `Deferred` re-arms only while `step` returns `'more'` (`deferred_work.lua:11-24`). Revision 3 scoped a new notify to `request_turn`/`release_turn`, which structurally excludes `finish_generation` — the *most common* release, since it calls `retune`. Notification alone is not a wake: the subscriber must re-arm its own `Deferred`. Audited, all four:

| Subscriber | Re-arms on notify? |
|---|---|
| `generation_runner.lua:498-501` | **yes** — `sync(s)` + `s.work:request()` |
| `response_topic.lua:107-110` | **yes** — `s.work:request()` at `:110` |
| `response_preparation.lua:147-148` | **no** — body handles only `reload`/`detach` |
| `response_completion.lua:92-93` | **no** — same |

The two that cannot act on it would hot-spin instead: their `Deferred` predicate is `M.step(op).status=='more'` and their park paths (`response_preparation.lua:76-80 waiting(s)`, `response_completion.lua:26-29 repair(s)`) return `s.status` still `'more'`, so `deferred_work.lua:22` re-arms at 1 ms and each iteration runs a real `D.repair_step` — for the entire duration of another generation's stream. Generation B's preparation is turnless for all of A's stream, so this is the central scenario, not an edge. Two changes are needed, and the wake alone is not enough:

1. **Wake:** both subscribers gain `if s.status=='more' then s.work:request() end`.
2. **Stop the spin.** The wake does not stop it — the `Deferred` predicate is `function() return M.step(op).status=='more' end` (`response_preparation.lua:146`, `response_completion.lua:91`) and re-arms at 1 ms whenever true. **`s.status` cannot be flipped to `'waiting'`**: `s.status~='more'` is the retirement/idempotence guard at `response_preparation.lua:46,69,83` and `response_completion.lua:32,73`, and it is the public `M.snapshot(op)` contract. Add a **separate `parked` field** on the value returned by `result(s)` / `repair(s)`, set on the turn-blocked path, and change each predicate to `local r=M.step(op); return r.status=='more' and not r.parked`.

Task 1.4 Step 5's anti-spin assertion is written against **all six writers**, not `M.step` alone.

So: **`M.transition` notifies whenever the turn value differs before and after**, covering `request_turn`, `release_turn` and `finish_generation` in one place — no ordering question for an implementer to resolve. `reload`/`detach` are already covered and need nothing: they never reach `M.transition` (`observe` calls `State.transition` directly at `init.lua:220,231`) and are woken by the pre-existing `notify(s,{kind='reload'})`/`{kind='detach'}` at `:223`/`:232`.


**Issue:** parley#266 · **Target:** `workshop/targets/transcript-is-the-whole-truth.md` · **Blocks:** parley#261

**Branch:** must be `000266-serialize-transcript-mutation`. `tests/arch/single_source_sweeps_spec.lua:732-743` (regex at `:737`) only enforces "every spec this branch added is routed in `atlas/traceability.yaml`" when the branch matches `^%d%d%d%d%d%d%-`; any other name silently downgrades that guard to `pending`.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `write_turn` — WriteTurn: `holder` | `lua/parley/document/write_turn.lua` | new |
| `sequence` — ToolSequence *(M2)* | `lua/parley/tools/sequence.lua` | new |
| `state` — DocumentState: the `turn`, `waits_for_turn` | `lua/parley/document/state.lua` | modified |
| `generation` — GenerationMachine: an O(1) `phase` | `lua/parley/generation.lua` | modified |
| `init` — DocumentCoordinatorStatus: `turn`, the `'waiting'` status | `lua/parley/document/init.lua` | modified |
| `chat_presentation` — the waiting note and overflow report: `waiting_message`, `overflow_message` | `lua/parley/chat_presentation.lua` | modified |

*Name cells lead with the module file, which the arch table sweep
(`tests/arch/single_source_sweeps_spec.lua`) resolves; the concept name follows,
and the public functions the issue adds are named in backticks so the sweep's
code→table direction finds them.*

- **WriteTurn** — pure decision function: given the generation records and which are eligible to write, return the id that holds the turn. Eligibility order is ascending generation id. `state.lua:6-7` is `local function id() serial=serial+1; return serial end` — ids are **bare integers**, monotone by admission, so ordinary `<` is correct and no suffix parsing or separate sequence number is needed.
  - **Relationships:** 1:1 with a document (one turn per document); N:1 with generations (many generations, one holder).
  - **DRY rationale:** First occurrence of a pattern that recurs — M2's tool sequencing is the same "ordered set, one may act" shape, but over calls rather than generations. Kept separate because the eligibility predicates genuinely differ; `ToolSequence` does not reuse this.
  - **Future extensions:** Priority other than admission order (e.g. the focused exchange first) widens the eligibility predicate without changing callers.
  - **Tests:** `tests/unit/document_write_turn_spec.lua`, no IO.
  - **ARCH-FUNERAL:** creates nothing durable. `s.turn` and `s.turn_wanted` are in-memory reducer fields collected by `finish_generation` and by the shared `reload`/`detach` branch (`state.lua:353-356`); they die with the document.

- **ToolSequence** — pure: given declared calls in order and a map of arrived outcomes, return what may be written next (`{kind='call', index=i}`, `{kind='result', index=i}`, or `nil`), plus whether the round is complete.
  - **Relationships:** 1:1 with a tool round; 1:N with calls.
  - **DRY rationale:** Removes the placeholder/slot bookkeeping in `response_tools.lua:154-161` and centralizes "what is writable now" so the adapter is a thin pump.
  - **Future extensions:** A policy field selecting strict order vs. first-ready-wins, if serialization is ever relaxed per-round.
  - **Tests:** `tests/unit/tools_sequence_spec.lua`, no IO.
  - **ARCH-FUNERAL:** creates nothing durable. The sequence record lives on the adapter's round state and dies with it; Task 2.2 must name the collector for the frozen `s.rounds[ctx.round]` record it keeps, since `retire_reservation` (`response_tools.lua:36-68,183-187`) — today's collector — is deleted.

- **DocumentState** (modified) — gains `s.turn` plus `request_turn` / `release_turn` events; `M.snapshot` exposes `turn`. `writable`/`resolve` are **not** changed, deliberately: `M.resolve`'s `reject(reason)` strings are consumed as control flow at `generation_runner.lua:275-276`, `document/init.lua:535-536` and `generation.lua:227-230`, and a new reason there would be misread as revocation.

- **GenerationMachine** (modified) — gains the **`draining`** phase and `s.turn_status`. `writable` (`:32-39`) requires `s.turn_status=='held'`. The release/re-request matrix below replaces the trigger list of earlier revisions.
  - **Relationships:** 1:1 with a runner; N:1 with a document.
  - **DRY rationale:** `s.turn_status` mirrors the document exactly as `s.grant_status` already does through `sync` (`generation_runner.lua:55-61`) — one mirroring pattern, not two.
  - **Future extensions:** a third `turn_status` value (e.g. `'preempted'`) if priority ever overrides admission order.

- **DocumentCoordinatorStatus** (modified) — the `'waiting'` refusal status returned by the five write entry points and by `Replacement.step`. New value in an existing channel; see the Architecture note on why not `busy`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `init` — DocumentCoordinator | `lua/parley/document/init.lua` | modified | reducer event whitelist + snapshot |
| `generation_runner` — GenerationRunner | `lua/parley/generation_runner.lua` | modified | turn polling + turn effects |
| `response_tools` — ToolAdapter *(M2)* | `lua/parley/response_tools.lua` | modified | append-only round insertion |
| `response_topic` — TopicGeneration | `lua/parley/response_topic.lua` | modified | the `D.apply` path that bypasses the runner |
| `response_session` — PendingProgress *(M2)* | `lua/parley/response_session.lua` | modified | tool → `lua/parley/chat_pending.lua` progress edge |

- **DocumentCoordinator** — enforces the turn at the five generated write entry points, adds `request_turn`/`release_turn` to the whitelist at `:323-324`, and notifies on turn movement.
  - **Note:** `tests/arch/document_ownership_spec.lua:69-90` is a forbid-list scoped to `chat_pending.lua` / `chat_presentation.lua`; it does **not** enumerate the coordinator whitelist (`grep -rn "coordinator-owned"` has one hit, `document/init.lua:324` itself). Adding the events breaks nothing there. Do not expect or "fix" a failure.

- **GenerationRunner** — `sync(s)` (`:47-65`) already polls `D.snapshot(s.doc).grants`; it also reads `snapshot.turn` and dispatches a `turn` event into the machine. `execute` gains handlers for the two new effects.
  - **Injected into:** `GenerationMachine`, via the existing dispatch path.

- **ToolAdapter** — `reserve_round` becomes `begin_round` (declare calls, write nothing); a pump driven by `ToolSequence` appends each block via `ctx.append`.
  - **Injected into:** the generation machine through the existing `hooks` table (`response_session.lua:174`).

- **TopicGeneration** — registers a second generation and writes via `D.apply` (`response_topic.lua:141-147,165-166`), bypassing `generation_runner` entirely. It must take the turn like any other writer.

- **PendingProgress** — there is **no tool → pending edge today** (`response_session.lua:100-101` feeds only provider stream progress). M2 adds one so concurrent tool execution stays visible once the transcript no longer lists every call upfront.

### ARCH-ORDER — the lifecycle this issue is about

`N/A` is not available for an issue whose entire substance is ordering. The
enumeration below is the design; Task 1.6 implements it and its tests assert it
independently rather than restating it.

**Phases** (`generation.lua`), with `draining` new and `paused` remaining an
orthogonal overlay via `s.resume_phase` (`:28-31`):

`preparing → requesting → executing_tools ⇄ requesting → draining → finalizing → terminal`,
with `stopping → terminal` reachable from any phase and `paused` shadowing any of them.

**`draining`** — provider complete, staged bytes outstanding, no further provider
work. Entered when a completion event arrives with `staged(s)>0`; exits to
`finalizing` when `staged(s)==0`. This is the state the Spec names: it makes
cancellation, revocation and staleness expressible for a generation that is
complete but not yet written. Today that situation is indistinguishable from
mid-stream `requesting`, which is why the `bytes==0` gates at `:123`, `:129` and
`:149` currently mean two different things at once.

**Turn matrix** — release and re-request are symmetric. Revisions 1–3 listed 11
release triggers and exactly one acquisition trigger, which is a permanent stall
for any trigger not paired.

| Observation | turn_status | Re-request on |
|---|---|---|
| `start`, `'resume_validated'` (`:343-345`) | → `held` (requested) | — |
| *(taking the turn in `preparing` no longer queues the next generation's request: preparation writes nothing until the generation's first write — Chunk 2)* | — | — |
| *(no release while merely idle between chunks — see below)* | — | — |
| `terminal` (`:98`, `:154`) | released | never (generation is gone) |
| `stop` / `phase=='stopping'` (`:40-53`) | released | never |
| pause: unknown child outcome (`:332-334`), `revoke_child` (`:60`), stale input (`:342`) | released | `resume_validated` (`:343-345`) |
| grant suspended, a suspended *preparation* grant, a head-of-line `'waiting'` that is not the turn | **held** — operator decision 2026-09-17 (see `## Revisions`); all three are a holder briefly unable to write | n/a |
| `detach` / `reload` | cleared by `state.lua:353-356` | n/a |

**The turn is held for the generation's lifetime — operator decision, 2026-09-17.**
Taken at `start`, released only by the rows above. There is deliberately **no**
"nothing staged right now" release: `staged(s)` (`generation.lua:23-27`) is empty
between essentially every SSE chunk — a 4096-byte slice drains in one 1 ms
`Deferred` tick while chunks arrive tens of milliseconds apart — so releasing on
it would ping-pong the turn per chunk and reinstate exactly the interleaving this
issue removes. The Spec is explicit: output is *"held until the first
generation's writes are complete, then applied **in full**"*.

**The cost, accepted.** Three stalls now hold the document's turn until the
operator stops the generation, and the Task 1.6 Step 4 message must be able to
describe all three: (a) a provider that hangs without failing; (b) **a tool that
never calls `outcome`** — no timeout synthesizes a result, and
`tools/operation.lua:112-122` only emits a 5000 ms notice, so `executing_tools`
parks indefinitely; (c) **a `prepare` adapter that never completes**, parking
`preparing`. `stop` is already a release row, so the escape exists; the
mitigation is that the block must be **visible** rather than mysterious — see
Task 1.6 Step 4. A timer was considered and rejected: it reintroduces a tunable,
and this plan guessed a tunable wrong three times before measuring settled it.

### ARCH-SECURE

`N/A` — touches neither untrusted input nor secrets. The turn is an in-memory ordering decision over writes the system already performs; no new parsing, no new external surface, no credential path.

### ARCH-MOCK

`N/A` — this issue adds no external binary or service dependency. All doubles already exist and are reused: `tests/helpers/fake_generation_runner.lua`, `tests/helpers/fake_document_editor.lua`, the inline `producer` table at `tests/integration/response_tools_spec.lua:12-16`, and `tests/helpers/fake_process.lua` for the end-to-end path.

### What is deliberately NOT changed

Execution concurrency: `generation.lua:84` fan-out cap of 4, `tools/resources.lua:82-90` admission (`running<16`, `per_document<8`, `per_generation<4`), `tasker.lua:20-21` attempt ceilings, and the path-scoped claims in `tools/async_builtin.lua:248-267`. Human edits via `apply_user` (`document/init.lua:432`) are **never** subject to the turn — the guarantee is ordering between generations, not absolute.

---

## Deliberate over-serialization in M1 — resolved

Resolved by Chunk 2 (2026-09-17). Until then the turn, taken in `preparing`,
blocked a second generation's preparation write and so its provider request —
full queuing where the Spec chose option (b). Preparation now reports its input
without writing and the gap lands immediately before the generation's first
write, so requests run concurrently again and nothing is exempt from the turn.
Mechanism in `## Revisions`.

## Chunk 1 — M1 (part 1 of one boundary): the write turn

**Routing rule for every task below.** `make test-spec SPEC=<key>` runs only files listed under that key in `atlas/traceability.yaml` (`Makefile.parley:113-129` → `scripts/spec_test_map.sh list-tests`). A new spec that is not routed is silently **not run**, so a "watch it fail" step would print green. Every task that creates a spec routes it in the *same* task, before the red step. Existing keys, verified: `tests/unit/generation_spec.lua` → `chat/lifecycle` (`atlas/traceability.yaml:194`); `tests/unit/document_state_spec.lua` → `chat/ownership` (`:307`, key at `:294`) **and** `chat/document` (`:391`); `tests/integration/response_tools_spec.lua` → `chat/lifecycle` (`:201`) and `providers/tool_use` (`:878`); `tests/integration/generation_sequences_spec.lua` → `chat/ownership` (`:314`); `tests/unit/document_capacity_spec.lua` → `chat/ownership` (`:325`). Also route `lua/parley/document/init.lua` and `lua/parley/document/write_turn.lua` under `chat/ownership` `code:`, since `make test-changed` keys off those lists.

### Task 1.1: `WriteTurn` pure entity

**Files:**
- Create: `lua/parley/document/write_turn.lua`
- Test: `tests/unit/document_write_turn_spec.lua`
- Modify: `atlas/traceability.yaml` — route **both** the spec (`tests:`) and `lua/parley/document/write_turn.lua` (`code:`) under `chat/document`, so `make test-changed` on the module runs its own spec

- [x] **Step 1: Route the new spec** in `atlas/traceability.yaml` under `chat/document` — both the spec (`tests:`) and `lua/parley/document/write_turn.lua` (`code:`), matching the `SPEC=chat/document` commands in Steps 3 and 5. Two-space key, four-space `code:`/`tests:`, six-space `- path`; the awk parser is whitespace-strict.

- [x] **Step 2: Write the failing test.** Generation ids are **bare integers** (`state.lua:6-7`), so compare with `<`.

```lua
local ok,W=pcall(require,'parley.document.write_turn')
describe('write turn',function()
    it('provides the module',function()assert.is_true(ok)end)
    if not ok then return end
    it('grants the turn to the lowest eligible generation id',function()
        assert.equals(2,W.holder({[5]={eligible=true},[2]={eligible=true}},nil))
    end)
    it('keeps an existing holder while it stays eligible',function()
        assert.equals(5,W.holder({[5]={eligible=true},[2]={eligible=true}},5))
    end)
    it('reassigns when the holder stops being eligible',function()
        assert.equals(2,W.holder({[5]={eligible=false},[2]={eligible=true}},5))
    end)
    it('reassigns when the holder is gone',function()
        assert.equals(2,W.holder({[2]={eligible=true}},5))
    end)
    it('returns nil when nothing is eligible',function()
        assert.is_nil(W.holder({[2]={eligible=false}},nil))
        assert.is_nil(W.holder({},5))
    end)
end)
```

- [x] **Step 3: Run it and watch it fail.**
  Run: `make test-spec SPEC=chat/document`
  Expected: FAIL — `provides the module` asserts false (`module 'parley.document.write_turn' not found`), and the remaining `it` blocks do not run because of the `if not ok then return end` guard.

- [x] **Step 4: Minimal implementation.** `M.holder(generations, current) -> id|nil` where `generations` maps integer id → `{eligible=boolean}`. Contract: an eligible incumbent keeps the turn; otherwise the lowest eligible id wins; `nil` when none is eligible. Ordinary `<` on the integer ids — no suffix parsing (`state.lua:6-7` returns bare integers). Pure, no upvalues, no IO.

- [x] **Step 5: Run and verify green.** `make test-spec SPEC=chat/document` → all pass.
- [x] **Step 6: Commit** — `#266 M1: add the pure write-turn decision`

### Task 1.2: turn state in the reducer

**Files:**
- Modify: `lua/parley/document/state.lua` (`M.new` `:64`, `M.transition` `:182-357`, `M.snapshot` `:72`)
- Test: `tests/unit/document_state_spec.lua`

**Epoch note.** `M.new` sets `epoch=opts.epoch or id()` (`:68`), and `M.transition` rejects a mismatched epoch at `:186`. Follow the file's existing convention (`document_state_spec.lua:149,189`): construct with `State.new({epoch=100})` and pass `epoch=100`, or omit `epoch` from the event entirely.

- [x] **Step 1: Failing test** — append to `tests/unit/document_state_spec.lua`:

```lua
    it('serializes the write turn by admission order and releases it on finish',function()
        local d=S.new({epoch=100})
        local a=S.transition(d,{kind='register_generation',epoch=100}).generation
        local b=S.transition(d,{kind='register_generation',epoch=100}).generation
        assert.is_nil(S.snapshot(d).turn)
        assert.is_true(S.transition(d,{kind='request_turn',epoch=100,generation=a}).ok)
        assert.equals(a,S.snapshot(d).turn)
        assert.is_true(S.transition(d,{kind='request_turn',epoch=100,generation=b}).ok)
        assert.equals(a,S.snapshot(d).turn,'a keeps the turn while eligible')
        S.transition(d,{kind='finish_generation',epoch=100,generation=a})
        assert.equals(b,S.snapshot(d).turn,'turn passes to the next admitted')
    end)
    it('releases the turn on request so a blocked holder cannot starve the queue',function()
        local d=S.new({epoch=100})
        local a=S.transition(d,{kind='register_generation',epoch=100}).generation
        local b=S.transition(d,{kind='register_generation',epoch=100}).generation
        S.transition(d,{kind='request_turn',epoch=100,generation=a})
        S.transition(d,{kind='request_turn',epoch=100,generation=b})
        S.transition(d,{kind='release_turn',epoch=100,generation=a})
        assert.equals(b,S.snapshot(d).turn)
    end)
    it('re-queues a released generation behind the current holder',function()
        local d=S.new({epoch=100})
        local a=S.transition(d,{kind='register_generation',epoch=100}).generation
        local b=S.transition(d,{kind='register_generation',epoch=100}).generation
        S.transition(d,{kind='request_turn',epoch=100,generation=a})
        S.transition(d,{kind='request_turn',epoch=100,generation=b})
        S.transition(d,{kind='release_turn',epoch=100,generation=a})
        S.transition(d,{kind='request_turn',epoch=100,generation=a})
        assert.equals(b,S.snapshot(d).turn,'b keeps the turn it was handed')
    end)
    it('clears the turn on reload and detach',function()
        local d=S.new({epoch=100})
        local a=S.transition(d,{kind='register_generation',epoch=100}).generation
        S.transition(d,{kind='request_turn',epoch=100,generation=a})
        S.transition(d,{kind='reload',epoch=100})
        assert.is_nil(S.snapshot(d).turn)
    end)
    it('rejects a turn request from an unknown generation',function()
        local d=S.new({epoch=100})
        assert.equals('generation',S.transition(d,{kind='request_turn',epoch=100,generation=999}).reason)
    end)
```

- [x] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/document`
  Expected: FAIL — `S.transition(...).reason == 'unknown event'` (the `else` at `state.lua:357`), so `.ok` is false and `assert.is_true` fails.

- [x] **Step 3: Implement.** Add `local WriteTurn=require('parley.document.write_turn')` at the top of `state.lua` (it currently requires nothing). In `M.new`'s doc table add `turn=nil,turn_wanted={}`. Add a helper beside `capacity_used` (`:170`):

```lua
local function eligibility(s)
    local out={}
    for id in pairs(s.generations) do out[id]={eligible=s.turn_wanted[id]==true} end
    return out
end
local function retune(s,drop)
    if drop then s.turn_wanted[drop]=nil end
    s.turn=WriteTurn.holder(eligibility(s),s.turn~=drop and s.turn or nil)
end
```

Add `request_turn` and `release_turn` branches before the `else` at `:357`. Both reject with `'generation'` when the id is unknown, mutate `s.turn_wanted`, recompute through `retune`, and set `result.turn`. `release_turn` must pass the dropped id so `WriteTurn.holder` is offered `current=nil` when the dropper was the holder — otherwise a release cannot hand over.

In `finish_generation` (`:344-352`) call `retune(s,event.generation)` after the existing cleanup **and set `result.turn=s.turn`** — Task 1.3's wake compares turn values, so every branch that can move the turn must report it. All three (`request_turn`, `release_turn`, `finish_generation`) set it. In the shared `reload`/`detach` branch (`:353-356`) add `s.turn,s.turn_wanted=nil,{}`. `M.snapshot` at `:72` is `copy(state(doc))` and `copy` (`:10-26`) walks the whole table on every call — and `D.snapshot` runs per step in `sync`, `write`, `replace`, `written` and `context`. Expose `turn` but **keep `turn_wanted` out of the snapshot**, or the per-step copy grows with every admitted generation.

- [x] **Step 4: Run and verify green.**
- [x] **Step 5: Commit** — `#266 M1: hold a write turn in the document reducer`

### Task 1.3: coordinator passthrough and the wake path

**Files:**
- Modify: `lua/parley/document/init.lua:320-324` (whitelist), `lua/parley/document/init.lua:19-25` + the transition site (notify)
- Test: `tests/integration/document_turn_wake_spec.lua` (new)
- Modify: `atlas/traceability.yaml` (route the new spec under `chat/ownership`)

**Correction to an earlier draft of this plan:** `tests/arch/document_ownership_spec.lua:69-90` is a *forbid-list scoped to `lua/parley/chat_pending.lua` and `lua/parley/chat_presentation.lua`* — it asserts presentation cannot mint grants. It does **not** enumerate the coordinator whitelist (`grep -rn "coordinator-owned"` has exactly one hit: `document/init.lua:324` itself). Adding the two events does **not** break it. Do not expect or "fix" a failure there.

- [x] **Step 1: Route the new spec**, then write it. **Assert the notification, not the wake.** A wake test cannot be red here: Task 1.3 precedes both the `'waiting'` refusal (1.4) and the machine's `request_turn` (1.5), so nothing yet refuses b's writes — b commits immediately and any `vim.wait(… committed_bytes …)` passes whether or not a notify exists. That is the vacuous-red-step class this plan's own routing rule warns about and the 1.4/1.5 ordering note already caught once.

  Assert instead that a subscriber **receives a `{kind='turn'}` event when the holder's `finish_generation` lands** — red without the notify, and still meaningful after 1.4/1.5 make the wake real:

```lua
it('notifies subscribers when finish_generation moves the turn',function()
    local seen={}
    local off=D.subscribe(doc,function(ev) if ev.kind=='turn' then seen[#seen+1]=ev end end)
    -- a and b both request; a holds. Retire a through finish_generation.
    assert.equals(1,#seen,'no turn notification when the holder finished')
    assert.equals(b_generation,seen[1].turn)
    off()
end)
```

  Add the end-to-end wake assertion (two runners, `schedule=true`, no hand-stepping) in **Task 1.6**, where the refusal and the request both exist and a missing wake is a real hang. `schedule=true` matters there because `Runner.step` calls `sync` on every invocation (`:449`), so a hand-pumped harness structurally cannot observe a missing wake-up.

- [x] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL — `no turn notification when the holder finished` (`#seen==0`).

- [x] **Step 3: Implement.** Extend the whitelist at `:323-324` with `request_turn` and `release_turn`.

  **Notify on the turn *value*, never on an event list.** In the coordinator's transition wrapper, read `State.snapshot(s.authority).turn` **before** delegating and compare with `result.turn` after; `notify(s,{kind='turn',turn=result.turn})` when they differ. This covers `finish_generation` — the most common release, since the holder's terminal at `generation_runner.lua:436` is its only caller — without naming it. A per-event list here is the defect this plan already made twice: it silently excludes `finish_generation`, and a queued generation parked on a `'waiting'` step is then never re-armed, because only `work:request()` from the subscriber at `generation_runner.lua:498-501` can wake it. Silent hang.

  Requires Task 1.2's reducer to set `result.turn` on **all three** branches that can move it (`request_turn`, `release_turn`, `finish_generation`), which is why that step now says so explicitly. One `State.snapshot` read per transition is acceptable: `M.transition:338-339` already performs a full `copy` on every call.

  The runner's existing subscriber already does `sync(s)` + `work:request()`, so no runner change is needed for the wake itself.
- [x] **Step 4: Green.**
- [x] **Step 5: Reentrancy note.** Every existing `notify` site is in `observe`/`repair_step` (`:206,223,232,381,402`); none is inside `M.transition` (`:320-341`). This adds the first, so a runner's `D.transition(release_turn)` synchronously re-enters every subscriber's `sync`. That is safe as written — subscribers only read `D.snapshot` and dispatch into their own machine, and `work:request()` defers via `vim.defer_fn` — but assert it with a test that transitions from inside a subscriber callback. Also note `M.transition:338-339` runs `Replacement.prune` plus a full `State.snapshot` on every one of these new, frequent events.
- [x] **Step 6: Commit** — `#266 M1: notify subscribers when the write turn moves`

### Task 1.4: refuse a turnless generated write with `'waiting'`

> **Ordering: land Task 1.5 first.** 1.4 installs a fail-closed guard, but nothing requests the turn until 1.5 Step 3 creates the `request_turn`/`release_turn` effects and their handlers. Between the two, every generated write returns `'waiting'` forever, so 1.4's own "Step 4: Green" is unreachable — `SPEC=chat/ownership` routes `generation_sequences_spec.lua` (`traceability.yaml:314`), `chat_scoped_response_spec.lua` (`:316`), `response_session_spec.lua` (`:315`) and `chat_stop_generation_spec.lua` (`:317`), all of which drive generations to completion. 1.5 depends only on 1.2's reducer and 1.3's notify, so a straight reorder works. **Execute 1.5, then 1.4.**
>
> Even reordered, Task 1.4 Step 4's `SPEC=chat/ownership` cannot be fully green: that key also routes `chat_scoped_response_spec.lua` (`traceability.yaml:316`), whose `:47` case asserts two *concurrent* generations, and its inversion is deferred to Task 1.9 Step 5. Declare that one spec **expected-red from 1.4 until 1.9**, or move the inversion forward into 1.4.

**Files:**
- Modify: `lua/parley/document/init.lua` — `M.append` `:556`, `M.apply` `:491`, `M.replace_new` `:446`, `M.insert_released_new` `:459` (not `M.replace_step` `:482` — its cursor has no generation; that guard lives in `Replacement.step`, below)
- Modify: `lua/parley/document/replacement.lua` — `Replacement.step` (writes at `:180`, 4096 at a time via `:155,165`), using `c.generation` (`:60`)
- Modify, per the enumeration table in Architecture — **six caller sites**: `response_preparation.lua:94,103,113`; `response_completion.lua:66,74`; `response_topic.lua:168`
- Test: `tests/integration/generation_turn_spec.lua` (new), routed under `chat/ownership` in this task

`M.apply_user` (`:432`) is **not** changed — humans are never blocked.

- [x] **Step 1: Route the spec**, then write the failing test — one case per row of the enumeration table (provider, tool, preparation, completion, topic, and a replacement continuation that begins while holding the turn and must stop when it moves):

```lua
for _,writer in ipairs({'provider','tool','preparation','completion','topic','replacement_continuation'}) do
  it('refuses a '..writer..' write while another generation holds the turn',function()
```

The `replacement_continuation` case is the one revisions 2 and 3 both missed: start a multi-chunk replacement while holding the turn, move the turn, then assert no further bytes land.

- [x] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL on all six — bytes commit immediately; asserted `0`, got the full length.

- [x] **Step 3: Implement.** Beside the existing `append_busy` check (`init.lua:516`), factored once:

```lua
-- NOTE the field is `s.authority`, not `s.state` — see `init.lua:322` and every
-- other `State.snapshot(s.authority)` call site.
local function turn_waiting(s,generation)
    local turn=State.snapshot(s.authority).turn
    return generation~=nil and turn~=generation      -- FAIL-CLOSED: see below
end
```

**Fail-closed, deliberately.** `turn~=nil and …` would admit every writer whenever no one holds the turn, which enforces "nobody writes while someone else holds" rather than the Goal's "exactly one generation may mutate at a time." Require the turn to write. Consequences the implementer must handle, both of which a fail-open guard would have hidden:
- `generation.lua:167` must initialise `s.turn_status='waiting'`, **not** `'held'` — a machine must not emit write effects before it has requested.
- `response_topic` registers its own generation (`response_topic.lua:141-147`) and finishes it (`:37`); it must now `request_turn` and `release_turn` like any other writer, not rely on a permissive branch. **Acquire immediately before `D.apply` (`response_topic.lua:165`) and release straight after** — *not* at registration (`:142-144`). Topic issues its own provider request at `:154` and waits at `:156`; holding the turn across that would block every other write in the document for a network round-trip, and topic runs concurrently with a live response (`chat_respond.lua:1657`). Its write is a single `D.apply`, so the hold is momentary.

**Three return conventions, not one.** `M.append` returns a status table → `return reject('waiting','write turn held elsewhere')`. **`M.apply` (`:491`) cannot use that helper** — `reject` is declared local to `append` at `:514` — so construct `{status='waiting',reason='write turn held elsewhere'}` directly, or hoist `reject` to file scope. `M.replace_new` (`:446-457`) and `M.insert_released_new` (`:459-481`) return `nil,reason` → `return nil,'waiting'` (which is why `response_preparation.lua:103` and `response_completion.lua:66` are *reason* sets). `Replacement.step` must return `'waiting'` through its `result(...)` closure (`replacement.lua:132-135`) **without** calling `stop(c,…)` (`:33-40`), or the cursor is permanently dead.

Then add `'waiting'` to all six caller predicates **and** to the two runner sites above.

- [x] **Step 4: Green.** `make test-spec SPEC=chat/ownership`
- [x] ~~**Step 5: Anti-spin assertion, across all six writers** (not `M.step` alone — `response_preparation` and `response_completion` spin through their own `Deferred`, not the runner's). Add `if s.status=='more' then s.work:request() end` to both subscribers first. Test that each turn-blocked writer performs a bounded number of steps over a fixed wall-clock window — the `busy`-shaped bug is invisible to a correctness assertion and only shows as CPU.~~ — superseded — preparation now runs only while its generation holds the turn (Chunk 2) and finalize only under `may_write`, so neither waits on the turn; the topic parks on its own subscriber (Task 1.8 test)
- [x] **Step 6: Commit** — `#266 M1: refuse turnless generated writes without spinning`

### Task 1.5: the `draining` phase and `turn_status`

**Files:** `lua/parley/generation.lua` — `writable` `:32-39`, initial state `:167`, `M.transition` `:186-376`, the completion paths at `:123`, `:129`, `:149`
**Test:** `tests/unit/generation_spec.lua` (routed `chat/lifecycle`, `atlas/traceability.yaml:194`)

This is the task the Spec's ARCH-ORDER clause asks for. It is not an optimization and must not be deferred: without it, `staged(s)==0` keeps meaning both "my writes drained" and "I may proceed", and the `bytes==0` gates cannot tell a held generation from a streaming one.

- [x] **Step 1: Failing tests.**
  - `turn_status='waiting'` + `output` → no `write` effect; after `{type='turn',status='held'}` → a `write` effect appears.
  - `provider_complete` with `staged(s)>0` → `phase=='draining'`, **not** `finalizing`.
  - from `draining`: `cancel` → `stopping`; `grant_revoked` → expressible; `input_changed` → marks stale without losing staged bytes. These three are the Spec's "cancellation, revocation and staleness must be expressible".
  - `draining` + drain to `staged(s)==0` → `finalizing`.
  - **`provider_failed`** (`generation.lua:266-271`) also does `advance(s,'finalizing')` under the comment "Drain valid writes before failure retirement" — the identical complete-but-unwritten situation. It routes through `draining` too; the phase diagram needs that failure edge.
  - **Paused overlay:** entering `draining` must go through `advance` (`:29-31`) so a paused generation records it in `s.resume_phase`, and the drain-exit must read `phase(s)`, because `pump`'s finalize gate at `:149` reads `s.phase` **directly** — a paused-draining generation would otherwise never finalize.
- [x] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/lifecycle`
  Expected: FAIL — `phase` is `requesting`, not `draining`; a `write` effect is emitted while turnless.
- [x] **Step 3: Implement.** Add `draining` to the phase set and `s.turn_status='waiting'` at `:167` (fail-closed, per Task 1.4). **Create the `request_turn` and `release_turn` effects here** — emitted from the acquisition point and from `resume_validated` (`:343-345`) — and their handlers in `generation_runner.lua`'s `execute`, calling `D.transition(...)`.

**Release must not travel as a queued effect.** `generation_runner.lua:451` is `local effect=s.pending or table.remove(s.queue,1)` and `:454` keeps `s.pending` while `execute` returns `again=true` — so a parked effect head-of-line-blocks the whole FIFO. Two release rows fire *precisely* when the runner is parked: **grant suspended** (`write()` `:269` parks with `true,'waiting'`, then `sync` `:55-61` dispatches `grant_suspended`) and **head-of-line waiting** (`reclaim_tail` `'unconfirmed identity'`, `:347-352`). A queued `release_turn` would sit behind the parked effect and never execute, so the turn is never released and every other writer starves with no idle-release to rescue it. **Issue release synchronously from `sync` via a direct `D.transition{kind='release_turn'}`**, the way the runner already calls `D.transition` elsewhere. The `stopping` rows self-heal (`write()` `:267`, `replace()` `:296-300` resolve the pending effect) which is why this is invisible there. No earlier task creates them; without this step the turn is never requested and nothing writes. `writable` gains `s.turn_status=='held'`. Add a `turn` event branch setting `s.turn_status` then calling `pump`. Route the completion transition through `draining` when `staged(s)>0`. Keep `staged(s)` (`:23-27`) as is. The `bytes==0` gate at `:149` stays **live and required** — it still emits the `finalize` effect; it becomes *redundant as a phase test* once completion routes through `draining`, so add the `draining → finalizing` branch beside it rather than deleting it; `:123` and `:129` are unaffected.
- [x] **Step 4: Green. Step 5: Commit** — `#266 M1: add the draining phase for complete-but-unwritten output`

### Task 1.6: the turn matrix

**Files:** `lua/parley/document/write_turn.lua` (add `should_release`), `lua/parley/generation.lua`, `lua/parley/generation_runner.lua` `sync` `:47-65`
**Test:** `tests/integration/generation_turn_spec.lua`

**ARCH-DRY:** one invariant, one implementation. Put the decision in a pure `WriteTurn.should_release(observation)` beside `WriteTurn.holder`; both the machine and the runner feed it an observation rather than each carrying half the policy.

- [x] **Step 1: Write the matrix** — one case per row of the ARCH-ORDER table, asserting **both** that the waiting generation acquires the turn *and* that the releasing generation re-acquires it when its re-request condition fires. A release without a paired re-request is a permanent stall, which is what an earlier draft shipped. Parameterise interleavings rather than using the fixed round-robin at `generation_sequences_spec.lua:48`:

```lua
local schedules={{'a','a','b','b'},{'a','b','a','b'},{'b','a','b','a'},{'b','b','a','a'}}
for _,row in ipairs({'terminal','stop','pause_unknown','pause_revoke','pause_stale',
    'suspend','suspend_preparation','waiting_head_of_line','detach','reload'}) do
  for _,schedule in ipairs(schedules) do
```

- [x] **Step 2: Run.** `make test-spec SPEC=chat/ownership`
  Expected: FAIL for `suspend` (releases but never re-requests — `grant_resumed` exists at `generation_runner.lua:57-59` and is unwired), `suspend_preparation` (no event carries it), and `waiting_head_of_line` (its release is parked behind `s.pending`, per Task 1.5's synchronous-release note).
- [x] ~~**Step 3: Implement** `WriteTurn.should_release`, wire `grant_resumed`, and add the preparation-suspension observation. **Its mechanism, named:** `sync` dispatches `grant_suspended` for every id in `s.grants`, which includes `preparation_grants` (`generation_runner.lua:55-61,489-491`), but `generation.lua:254-256` rejects it because `event.grant~=s.grant` and no child matches — so add a `preparation` branch there rather than a new event kind.~~ — superseded — operator decision: a transient suspension holds the turn, which removes the rows this step wires and leaves `should_release` one caller (Revisions, 2026-09-17)
- [x] **Step 3b: End-to-end wake.** Two runners on one document, `schedule=true`, b queued with output staged; complete a and assert b drains **without being hand-stepped** (`vim.wait(2000, …)`). This is the assertion Task 1.3 could not make; here the refusal (1.4) and the request (1.5) both exist, so a missing wake is a genuine hang.
- [x] **Step 4: Make the wait visible (operator-required mitigation).** A generation whose writes are held must say so, or a hung provider looks like a frozen editor. Route it through the presentation layer, which is extmark-only and never becomes Markdown: `chat_pending`'s `session:progress(event)` (`chat_pending.lua:160-165`) already accumulates per `detail_key` in `chat_presentation.lua:49-77`. Show the blocking exchange, not just "waiting" — and say *why* it is blocked, covering the three stall shapes above. **Under M1 the normal waiter is a generation parked in `preparing` with no provider stream of its own** (see "Deliberate over-serialization in M1"), not a turn-blocked writer mid-answer, so the message must read sensibly for a generation that has produced nothing yet.

**Latency envelope (ARCH-CONSTRAINTS).** M1's accepted cost has no upper bound: the holder may sit in a tool chain indefinitely, and three stall shapes have no timeout at all. The bound is therefore *operator-mediated* — `:ParleyStop` — which is only acceptable because the wait is visible. That is the whole justification for this step being required rather than optional, and it is why M2 exists. The waiting runner learns the exchange from `D.snapshot(doc)`: `turn` is a generation id, and the exchange is `snapshot.grants[*].entity` for the grant owned by that generation. Test that the message names it and that it clears when the turn arrives.
- [x] **Step 5: Green. Step 6: Commit** — `#266 M1: make turn release and re-request symmetric`

### Task 1.7: held-output budget (ARCH-CONSTRAINTS)

**Files:** `lua/parley/generation.lua:215` and `lua/parley/generation_runner.lua:157` (the two overflow messages, Step 4); no cap value changes. **Test:** `tests/integration/generation_sequences_spec.lua` (routed `chat/ownership`, `atlas/traceability.yaml:314`)

**Workload class:** streaming, keystroke-adjacent — a held generation buffers while the user keeps typing in the same buffer.

**What is bounded.** A held generation cannot continue its round or finalize (`generation.lua:123,129,149` gate on `bytes==0`), so it accumulates **at most one provider response**, independent of how long the chain ahead of it runs.

**Measured, 2026-09-17:**

| source | n | p50 | p95 | max |
|---|---|---|---|---|
| answer blocks in `workshop/parley/*.md` | 20 | 4,473 B | 14,213 B | **116,703 B** |
| request bodies in `stdpath('cache')/parley/query/` | 150 | — | — | 149,371 B |

**Budget: unchanged — 1 MiB per generation (`generation_runner.lua:463-464`, `generation.lua:163`), 16 MiB process-wide (`:75`).** *Basis:* ~9× the largest answer ever observed here. Four generations per document (`state.lua:190`) × 1 MiB = 4 MiB, comfortably inside the 16 MiB process ceiling — no collision, unlike the 8 MiB figure an earlier draft proposed. **Sample caveat: n=20 is small.** Step 1 re-measures against a larger corpus; if p99 exceeds ~100 KiB the number is revisited, and the measurement is recorded here either way.

**Behavior at the bound: unchanged — the generation is cancelled.** `cb.output` returning non-`true` reaches `response_provider.lua:88-90` and stops the transport; there is no SSE backpressure, and returning `true` while dropping bytes would silently discard provider output, which this issue's target forbids. Note there are **two** overflow sites — `generation.lua:215` `stop(…,'overflow')` and `generation_runner.lua:157` `issue`+`cancel` — and the message change below applies to both.

- [x] **Step 1:** Re-measure against a larger transcript corpus; record p50/p95/p99/max here. Change the number only if the data says so.
- [x] **Step 2:** Test with `limits={staged_bytes=8,queued_items=4}` (precedent `generation_sequences_spec.lua:68`): hold the turn elsewhere, exceed it, assert the generation stops **and** that the surfaced message names the exchange holding the turn.
- [x] **Step 3: Run, fail.** `make test-spec SPEC=chat/ownership` — the message assertion fails.
- [x] **Step 4:** Thread the blocking exchange into both overflow messages. **Step 5:** Test the ceiling at both scopes. Four held generations on one document is 4 MiB, fine — but `generation_runner.lua:462` admits **16 runners process-wide**, and held generations are new, so the worst case is 16 × 1 MiB = *exactly* the 16 MiB cap at `:75`. Refusal there reaches `:159`/`:101-102` → `issue('staging overflow')` + `cancel`, destroying a generation. Test the multi-document case or state the bound explicitly. **Step 6: Commit** — `#266 M1: name the blocking exchange when held output overflows`

### Task 1.8: verify every writer in the enumeration

**Files:** verify only. **Test:** `tests/integration/generation_turn_spec.lua`, `tests/integration/response_topic_spec.lua`

- [x] **Step 1: Re-run the enumeration grep from Architecture.** If it returns a writer not in the table, stop and correct the table first — that failure mode cost two review rounds in this plan's history.
- [x] **Step 2:** One test per row. `response_completion.lua:55-58` acquires a *fresh grant* and `response_topic.lua:168` has no waiting predicate — those two are the likeliest to slip.
- [x] **Step 3: Run.** `make test-spec SPEC=chat/ownership`
- [x] **Step 4:** Fix what the enumeration exposes. **Step 5: Commit** — `#266 M1: verify every generated writer honours the turn`

### Task 1.9: undo coherence

**Files:**
- Test: `tests/integration/chat_scoped_response_spec.lua:47` (invert), `tests/integration/generation_turn_spec.lua`

**What to assert, and what not to.** Not "undo steps == generation runs": `can_join_undo` keys on `(epoch,generation,grant)` (`editor.lua:192-199`, identity mismatch at `:199`) and a single run legitimately writes through preparation grants (`generation_runner.lua:488-492`) *and* a completion-acquired grant (`response_completion.lua:55-58`), so a run spans several grants and therefore several undo entries. Not "backwards in document position" either — generations write to different answers, so regenerating Q3 then Q1 writes Q3's region first.

The invariant to assert is the issue's own: **no undo entry mixes two generations, and no entry is a partial chunk.** Within a single tool round, insertion is monotonic at the tail, so document order *is* additionally guaranteed there (assert that in Chunk 2).

- [x] **Step 1:** On a real buffer, run two generations to completion serialized, then loop `vim.cmd('silent undo')` capturing `vim.fn.changenr()` (via `nvim_buf_call`, the idiom at `document/editor.lua:13`) and the buffer text at each step. Assert every removed span lies wholly within one generation's output region, and that no step removes a 4096-byte fragment of a larger contiguous write.
- [x] **Step 2: Run.** `make test-spec SPEC=chat/ownership`
  **Expected: PASS.** This is a *characterization* test, not a TDD red step — by Task 1.9 the serialization from 1.4–1.6 has landed, so undo coherence should already hold and writing a test that fails here would mean writing a test for behavior we just removed. Say so rather than scheduling a red that cannot occur (the vacuous-red-step class, same as Task 1.3's).
  If it *does* fail, the receipt invalidation at `editor.lua:67` is the suspect — a foreign write between two of a generation's chunks.
- [x] **Step 3:** No production change expected. If Step 2 passed, the value is regression protection for M2–M4.
- [x] **Step 4: Green.** Do **not** add a seed to `document_native_history_spec.lua` — that spec drives only human edits, undo and redo (`:51-78`) and never runs a generation, so a new seed would not exercise the writer path of `can_join_undo`.
- [x] ~~**Step 5:** Invert `chat_scoped_response_spec.lua:47` — rename to `'serializes two answers while the next question is edited'`, keep the reverse-order delivery, assert the second answer commits nothing until the first terminates, and keep the existing draft-preservation assertion.~~ — superseded — never inverted; Chunk 2 restored option (b) and the original concurrent test passes
- [x] **Step 6: Commit** — `#266 M1: assert undo entries never mix generations`

### Task 1.10: atlas, routing, milestone close

- [x] Rewrite `atlas/chat/ownership.md:8-9` — "Disjoint generations may write separate answers" is now false. Also `atlas/providers/architecture.md:29`. **Not** `atlas/chat/lifecycle.md:267` or `atlas/chat/inline_branch_links.md:76` — both describe *human* edits, which stay legal under `apply_user`; and not `atlas/chat/response_progress.md:56`, which is a test-file description. Only pages asserting concurrent *generated* writes change.
- [x] Confirm every spec added in Chunk 1 is routed and every new `lua/` file is in the right `code:` list.
- [x] `make test` → exit 0 (lint runs first). `make test JOBS=4`: lint 0/0, 376/376 spec files; two `JOBS=8` runs each lost one file to the known parallel-load abort, each passing alone.
- [x] ~~`sdlc milestone-close --issue 266 --milestone M1`~~ — superseded: the boundaries merged, so M1 closes once, at Chunk 2 Task 2.3

---

## Chunk 2 — M1 (part 2 of the same boundary): defer preparation's write until there is output

Restores the Spec's option (b) — concurrent provider execution with serialized
writes — by removing the reason preparation must write before the request.

**The problem, precisely.** `Preparation` currently writes its gap/scaffolding
(`response_preparation.lua:90` `D.append`, `:101` `D.replace_new`, `:108`
`D.replace_step`) and only then reports `prepared`, which is what delivers the
input snapshot and lets the machine leave `preparing`. So a write gates a
request. Under the turn, that makes the request serial too.

**The change.** Split the two responsibilities: report `prepared` as soon as the
input snapshot is captured and the region is *reserved*, and defer the actual
bytes until the first output arrives, where they land under the turn alongside
the content they make room for.

### Task 2.1: separate `prepared` from the preparation write

**Files:** `lua/parley/response_preparation.lua` (`:44-48` retire, `:76-80`
waiting, `:88-115` the write steps, `:145-149` subscriber);
`lua/parley/response_session.lua:129-134` (`cb.prepared` wiring)
**Test:** `tests/integration/response_preparation_spec.lua`, routed under `chat/ownership`

- [x] **Step 1:** Failing test — a generation whose preparation is turn-blocked still reports `prepared` and still reaches `requesting`.
- [x] **Step 2: Run, fail.** `make test-spec SPEC=chat/ownership`
- [x] **Step 3:** Implement the split. The region reservation (grant acquisition) stays where it is; only the byte-writing defers.
- [x] **Step 4: Green. Step 5: Commit** — `#266 M2: report prepared without writing`

### Task 2.2: land the deferred gap with the first output

**Files:** `lua/parley/generation.lua` (`pump` `:94-157`), `lua/parley/generation_runner.lua` (`write()` `:259-290`)
**Test:** `tests/integration/generation_turn_spec.lua`

- [x] **Step 1:** Failing test — the gap bytes appear exactly once, immediately before the first output bytes, under the same turn, and are absent if the generation is cancelled before any output.
- [x] **Step 2: Run, fail.**
- [x] **Step 3:** Implement. **Step 4: Green. Step 5: Commit** — `#266 M2: write the preparation gap with the first output`

### Task 2.3: restore the concurrency assertions

- [x] ~~Re-invert `tests/integration/chat_scoped_response_spec.lua:47`~~ — never inverted (the operator moved the inversions to this chunk); it passes in its original concurrent form. The two `response_session_spec` way-stations M1 did write are restored byte-for-byte to `main`.
- [x] Assert the full Spec shape end to end: two provider requests in flight, writes strictly serialized, second answer applied whole after the first terminates.
- [x] Remove the "Deliberate over-serialization in M1" section from this plan and correct the issue `## Log` entry that records the postponement.
- [x] `make test` → exit 0. `sdlc milestone-close --issue 266 --milestone M1` (covers both chunks).

## Chunk 3 — M2: ordered append, and the machinery it replaces

**Precondition, live now:** `scripts/refresh_goldens.lua` and 11 golden payloads are modified in the working tree from `f1818ee1` (#218). Resolve before cutting the branch — Task 3.5 regenerates goldens and expects no message-shape change, which that dirt would mask.

**Boundary correction.** An earlier draft deferred child-grant removal to M3 and had M2 rewrite `response_tools.lua` alone. That is impossible: `round_reserved` requires `#event.grants==#round.children`, each identity-valid, distinct and ≠ parent (`generation.lua:306-315`). A `begin_round` that acquires no child grants yields `done(nil)` → `round_reservation_failed` → `stop(s,effects,'reservation_failed')` (`:304`). Switching to ordered append and removing the reservation lifecycle are **one change** and land together.

### Task 3.1: `ToolSequence` pure entity

**Files:**
- Create: `lua/parley/tools/sequence.lua`
- Test: `tests/unit/tools_sequence_spec.lua`
- Modify: `atlas/traceability.yaml` — route under `providers/tool_use`

- [ ] **Step 1: Route the spec.**
- [ ] **Step 2: Failing test.** Signatures: `Seq.new(calls) -> seq`, `Seq.next(seq) -> {kind='call'|'result', index=n} | nil`, `Seq.outcome(seq,index,value) -> seq`, `Seq.written(seq,item) -> seq`, `Seq.complete(seq) -> boolean`; all pure and immutable (each returns a new record). Cases: the first call is offered before anything arrives; a later outcome cannot skip ahead while an earlier result is outstanding; the round drains in declared order once the earlier outcome lands; an unresolved outcome is writable evidence, not a stall.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use` → `provides the module` false.
- [ ] **Step 4: Implement** as a pure immutable record.
- [ ] **Step 5: Green. Commit** — `#266 M3: add the pure tool insertion sequence`

### Task 3.2a: remove capacity tickets from the document layer

**Files:** `lua/parley/document/state.lua:170-180,199-212,253-256`; `lua/parley/document/init.lua:312-319`
**Delete:** `tests/unit/document_capacity_spec.lua` **and** its entry at `atlas/traceability.yaml:325` — `single_source_sweeps_spec.lua:723` fails on a named path that no longer exists.

- [ ] Confirm no callers remain: `grep -rn "reserve_capacity\|release_capacity" lua/ tests/`. Record in `## Log` which invariant `document_capacity_spec.lua` was defending, so a later reader can tell deliberate removal from erosion.
- [ ] `make test` → exit 0. Commit `#266 M3: remove capacity tickets`.

### Task 3.2b: remove the round-reservation lifecycle from the machine and runner

**Files:** `lua/parley/generation.lua:131-134` (`reserve_round` emission), `:289-316` (`round_reservation_failed`/`round_reserved`), `:54-72` (`child_by_grant`/`revoke_child`), the child branch of `writable` `:32-39`, `write_result` `:234-249`; `lua/parley/generation_runner.lua:98` (**the `effect.type~='reserve_round'` liveness exemption in `mutation` — silently breaks if the effect is renamed**), `:329-354`, `:382-389`, `:404-434`; `lua/parley/response_session.lua:174`
**Test:** `tests/unit/generation_spec.lua` — the reservation tests at `:155-176`, `:292-304`, `:366-371` are removed with the contract they pin.

- [ ] Red/green per removal. `make test-spec SPEC=chat/lifecycle` between each.
- [ ] Commit `#266 M3: remove round reservation from the generation lifecycle`.

### Task 3.2c: the ordered-append pump

**Files:** `lua/parley/response_tools.lua` — rewrite `:137-182` as `begin_round`; delete `:21-26`, `:36-68`, `:154-161`, `:183-187`; rewrite `tool_outcome` `:77-102` to append
**Test:** `tests/integration/response_tools_spec.lua`

- [ ] **Step 1: Invert the pinning test** at `:141` → `'writes each call block immediately before its own result'`: assert `ca<ra and ra<cb and cb<rb`, no `(Tool result pending)` anywhere, both producers started (execution stays concurrent). Within one round insertion is monotonic at the tail, so **document order is guaranteed here** — assert it, since Task 1.9 deliberately does not claim it across generations.
- [ ] **Step 2: Add a bounded-step variant.** `f.drain()` runs to quiescence (`:37-42`) and cannot exercise "call 2's block written while result 1's multi-chunk write is mid-flight" (4096-byte slices, `generation_runner.lua:265`). Add `step(n)`.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use`
- [ ] **Step 4: Implement.** `begin_round` freezes `s.rounds[ctx.round]`, builds a `ToolSequence`, writes nothing, takes no ticket. A pump appends `Serialize.render_call` / `render_result` at the parent grant tail via `ctx.append`, one item per `adapter.step()`, driven by `Seq.next`. **Collector for the frozen round record (ARCH-FUNERAL):** `s.rounds[ctx.round]` is cleared twice over: per-round on the normal path at `response_tools.lua:237`, and wholesale by `adapter.close()` (`:241-242`, `s.rounds={}`), which production reaches via `response_session.lua:46` (`if tools then tools.close() end`) — **not** via the `terminal` hook, which is `finish(result,false)` at `:189`; only the test harness wires `terminal=adapter.close` — `retire_reservation` was only ever the collector for the *reservation*, not the round record. Assert it in Task 3.2c's test rather than assuming.
- [ ] **Step 5: Green. Commit** — `#266 M3: append tool call and result pairs in declared order`

### Task 3.3: unresolved outcomes become transcript text

**Files:** `lua/parley/tools/serialize.lua` (an unresolved rendering), `lua/parley/response_tools.lua`
**Test:** `tests/integration/response_tools_spec.lua`, `tests/unit/build_messages_spec.lua`

**The decision, re-made against the actual code.** Revision 3 chose "append a second `📎:` and make `resolve_pending` prefer the last match." That is not expressible: `pending` holds unique tool_use ids and `resolve_pending(id)` (`chat_respond.lua:636-644`) linear-scans for the one entry, so first-vs-last has no meaning there; the distinction is made by call order over `content_blocks`, and emitting the later block would detach a `tool_result` from the assistant message whose `tool_use` it answers — the Anthropic 400 that `#155`/`#156` exist to prevent (see the comment at `:680-690`).

**The marker, specified.** `⏳: <name> id=<id> (no result recorded)` — one line, no fenced body. Verified free: the answer scanner branches on `💬:`/`🤖:` (`chat_parser.lua:698,702,782`), `📝:` (`:855`), `🧠:` (`:882`), reasoning-end (`:872`), `🌿:` (`:669`) and `🔧:`/`📎:` (`:833-852`); `⏳` collides with none. It must also survive the fenced-body demotion at `:639-659`. **Assert both with a parse test** — this byte sequence lands in every user's transcript permanently, so it belongs in the plan, not in the implementer's head.

**Render the unresolved outcome as that marker, not as a `📎:` result block.** Then:

- the transcript records what happened, visibly, in the file — the target's requirement;
- the `🔧:` stays unmatched, and `chat_respond.lua:604,617-630` **already** synthesizes `"(tool call did not complete — no result recorded)"` with `is_error=true` for exactly that case;
- a later `known` outcome appends a real `📎:` carrying the id **only while that id is still pending on the wire**; it then matches and wins;
- **no change to `resolve_pending`, no duplicate block, no 400.**

**The late-arrival boundary, decided.** Once the round continues, the late result must *not* become a `📎:`. Traced: the text/tool_use branch at `chat_respond.lua:694` calls `flush_user()` → `drain_pending_into` emits a synthetic error for the unresolved id and then does `pending = {}` (`:625-630`). A `📎:` appended after that hits `resolve_pending` → `false` → the ORPHAN path (`:685-690`) and is **dropped from the wire while remaining in the file** — precisely the file-says-one-thing / wire-says-another split `transcript-is-the-whole-truth` forbids. So:

> **A tool call's outcome is final once its round continues.** Before continuation, a late `known` appends a real `📎:` and wins. After continuation, it appends a second informational `⏳:` line recording that a result arrived late, and never becomes a tool block.

Both file and wire then agree the call produced no tool result; the `⏳:` line is history, not a result. Test both sides of the boundary explicitly — the after-continuation case is the *expected* one, since Task 3.1 Step 2 makes an unresolved outcome writable evidence rather than a stall.

Constraint: the marker must not parse as a tool block. `chat_parser.lua:833-852` opens a block on `🔧:`/`📎:` at depth 0, so any other prefix is safe — verify with a parse assertion rather than by inspection.

- [ ] **Step 1:** Sweep the interleavings of `{outcome₁, outcome₂, cancel, resolve}` — **24 permutations**, not the 8 at `response_tools_spec.lua:261` (a different 4-tuple). If a subset is used, state which and why.
- [ ] **Step 2: Run, fail.** `make test-spec SPEC=providers/tool_use`
- [ ] **Step 3:** Implement the unresolved rendering.
- [ ] **Step 4: Green**, plus `make test-spec SPEC=chat/exchange_model` — assert the unresolved marker does **not** become a `tool_result` block and that the synthesized dangling text appears instead.
- [ ] **Step 5: Batch-facing check (Done-when).** `batch.lua:91-94` latches `s.unknown` and `:99` refuses resume permanently on this outcome. Assert a batch survives an unresolved tool call now that it is recorded in the transcript. Run: `make test-spec SPEC=chat/batch`.
- [ ] **Step 6: Commit** — `#266 M3: record an unresolved tool outcome in the transcript`

### Task 3.4: keep concurrency visible

**Files:** `lua/parley/response_session.lua:100-101`
**Test:** `tests/integration/chat_pending_spec.lua`

There is no tool → pending edge today. Add one so both tools read as in flight while only call 1 is written.

**Correction to draft 1:** the progress line is *not* torn down by these writes — `response_session.lua:181` calls `s.pending:written` only for `receipt.kind=='output'`, and manual appends are `'append'`/`'replace'` (`generation_runner.lua:250`). No mitigation needed.

- [ ] **Step 1:** Failing test — two tools running, one written, assert both appear in flight.
- [ ] **Step 2: Run, fail.** `make test-spec SPEC=chat/response_progress`
- [ ] **Step 3:** Add the `session:progress{tool=…}` edge (`chat_pending.lua:160-165`; `chat_presentation.lua:58` already accepts `event.tool`).
- [ ] **Step 4: Green. Step 5: Commit** — `#266 M3: show concurrent tool progress in presentation`
### Task 3.5: end-to-end and wire shape

**Precondition: a clean working tree.** `scripts/refresh_goldens.lua` and 11 golden payloads are currently modified from `f1818ee1` (#218). Resolve that before this task or a real regression will be indistinguishable from pre-existing churn.

- [ ] `chat_async_tools_spec.lua:123` and `openai_tool_loop_spec.lua:167` should pass unchanged — both already assert declaration order on real buffer text.
- [ ] Regenerate goldens. Expect **no message-shape change**: `response_tools.lua:224-234` batches the live round regardless of buffer layout, and `tests/fixtures/transcripts/two-round-tool-use.md:11-26` is already interleaved with `build_messages_spec.lua:1189-1192` pinning the four-message shape. Any diff beyond key-order churn is a red flag.
- [ ] Commit.

### Task 3.6: atlas + milestone close

- [ ] Rewrite `atlas/providers/tool_use.md` (ordered child slots and reserved result slots are gone); record the accepted four-message resubmit shape.
- [ ] `make test` → exit 0. `sdlc milestone-close --issue 266 --milestone M3`

---

## Chunk 4 — M3: the residual exclusion sweep

What remains after **M3** (Task 3.2b) removes child grants: the geometry that only existed to carve them out of a parent.

### Task 4.1: remove parent-slot exclusion

**Files:** `lua/parley/document/state.lua` — `exclude` `:147-159`, carving `:237-241,252`, `'outside parent'`/`'parent'` `:226-236`, ancestor walk + `tail_lost` `:291-311`, `'delegated parent'` `:99-101`, `'active child'` `:265-268`; `lua/parley/document/init.lua:528-529`
**Tests:** `tests/unit/document_state_spec.lua:98-133`, `tests/unit/document_write_plan_spec.lua:144-159`, `tests/unit/document_append_spec.lua:100`

- [ ] One concern per commit, `make test` between each. Each removal deletes the tests that pinned it — record in `## Log` which invariant each deleted test was defending, so a later reader can tell deliberate removal from erosion.

### Task 4.2: remove the half-open flags — LAST

**Files:** `lua/parley/document/state.lua:32-45` (`open_first`/`open_last` in `overlaps`/`contains`/`writable`)

These exist solely to disambiguate excluded seams, but they thread through the same helpers M1's turn logic uses. Remove only after **Task 4.1** is green, and run the full suite immediately.

- [ ] `make test` → exit 0. Commit `#266 M4: drop half-open seam handling with the last child grant`.

### Task 4.3: residual lifecycle cleanup

- [ ] Delete the fields with **zero readers** confirmed during the audit: `receipt.markers` (`response_tools.lua:66`), `children[i].call_block` and `children[i].result_slot` (`generation.lua:293`).
- [ ] **Add a test step** — this task had none in an earlier draft. Assert `grep -rn` finds no remaining reference to the removed symbols, and that `make test` is green.

### Task 4.4: close

- [ ] Final atlas sweep — no page may still describe reserved slots, child grants or capacity tickets.
- [ ] `make test` → exit 0, full output captured as close evidence (lint runs first; `workshop/lessons.md:792` records a close where green specs masked a red lint).
- [ ] `sdlc close --issue 266 --verified '<full make test output summary>'`

---

## Target reconciliation

`workshop/targets/transcript-is-the-whole-truth.md` says writes "land one at a time, in the order the reader sees them." Task 1.9 narrows that deliberately: **across** generations the guarantee is one-at-a-time and per-generation coherence, not document order, because generations write to different answers and admission order need not match document order. **Within** a tool round, document order does hold (Task 3.2c asserts it).

On undo granularity: holding the turn for a generation's lifetime makes its
output contiguous in write order, so `can_join_undo` (`editor.lua:192-199`)
succeeds across a run instead of being defeated per chunk. But it keys on
`(epoch, generation, **grant**)`, and one run legitimately writes through
preparation grants (`generation_runner.lua:488-492`), the main grant, and a
completion-acquired grant (`response_completion.lua:55-58`). So the guarantee is
**one undo entry per (generation, grant) run** — not per generation, as the issue
Log currently says. That is still a large improvement over today's one entry per
4096-byte chunk, and Task 1.9's invariant (no entry mixes two generations, none
is a partial chunk) holds unconditionally. Correct the Log's phrasing when M1
closes. Fold this narrowing into the target when M1 closes, so the target does not drift against the work defending it.

## Decisions taken, so they are not re-opened

- **Turn held for the generation's lifetime**, not released when idle between
  chunks (operator, 2026-09-17). A `staged(s)==0` release was proposed during
  review and rejected: it fires between essentially every SSE chunk and would
  restore per-chunk interleaving, trading the Spec's headline guarantee for a
  simpler predicate. Accepted cost: a hung provider blocks other writes until
  `:ParleyStop`, mitigated by naming the blocking exchange in presentation.
- **This also removes an edge-triggered re-request race** that only existed under
  the rejected rule: with constant release/re-request, an `output` arriving
  between a machine's `release_turn` emission and the runner executing it would
  have its `request_turn` erased by the later `retune`, stranding a generation in
  `draining` forever. Holding for the lifetime deletes the row and the race.
- **A transient grant suspension keeps the turn** (operator, 2026-09-17),
  reversing the turn-matrix `suspend` row. Suspension is routine — any edit the
  structure cannot classify at once — and with "an eligible incumbent keeps the
  turn", a holder that released for a millisecond would wait behind the next
  generation's whole lifetime, splitting its answer's history around another's.
  Holding keeps a generation's writes contiguous while it holds the turn
  uninterrupted (a pause still yields it; see Revisions, round 2). Accepted cost: a
  long suspension is a fourth visible stall shape, escaped by `:ParleyStop`.
- **Four-message resubmit wire shape** accepted (see the issue's `## Open decisions`).
- **Held-output budget stays at 1 MiB**, basis measured — largest answer block
  observed 116,703 B, so ~9× headroom.

## Verified-correct facts this plan rests on

Recorded so they are not re-derived, and so a later reader can tell which claims were checked.

- **The `M.resolve` avoidance argument holds.** Its `reject(reason)` strings are consumed as control flow at `generation_runner.lua:275-276`, `document/init.lua:535-536` and `generation.lua:227-230`; a new `'waiting'` reason there would be read as revocation and reach `stop()`. The turn is therefore enforced in the runner, not in `resolve`.
- **The no-wire-change prediction for Task 3.5 is well-founded** — `response_tools.lua:224-234` batches the live round; the fixtures are already interleaved.
- **Line references throughout this plan were spot-checked against the tree** across six review rounds; the ones that were wrong are listed in the bullet below rather than left for the implementer to trip over. Verify before editing rather than trusting any of them — the tree moves.
- **Corrected from an earlier draft:** generation ids are bare integers, not `'g'..n` (`state.lua:6-7`); `M.new` is at `:64` and `M.snapshot` at `:72`, and `D.snapshot` (`init.lua:254`) is a bare passthrough needing no change; the branch-name guard is `single_source_sweeps_spec.lua:732-743` (regex at `:737`), not `:713`.

## Revisions

### 2026-09-17 — Chunk 2 mechanism: the machine owns the deferred gap

**Reason.** Chunk 2 named the behaviour ("defer the bytes until the first output
arrives") but not who decides *when*. Tracing it showed three things the chunk
did not anticipate:

1. **"First output" is too narrow.** A generation's first write is not always
   output. A tool round with no preceding text writes call blocks first
   (`reserve_round`), and an answer that produced nothing still writes through
   `finalize`. All three must land after the gap, or a call block lands inside
   the old answer's region before the replacement that clears it.
2. **Only the machine can see all three.** Output staging, round reservation and
   finalize are all decided in `generation.lua`'s `pump`. A trigger living in
   `response_preparation` or `response_session` would have to reconstruct that
   decision from outside.
3. **`capture_topic_parent` reads the header at request time**
   (`chat_respond.lua`, via the session's `requesting` hook). With the request
   now starting before the header exists, it must move to `finalize`, where the
   gap has always landed.

**Delta.**

- `generation.lua` gains `s.gap`, enumerated rather than boolean (ARCH-ORDER):
  `'none'` → `'deferred'` (a `prepared{gap=true}` event) → `'writing'` (the
  `write_gap` effect is out) → `'none'` (`gap_result{status='applied'}`). A
  failed gap stops the generation as `prepare_failed`. A generation stopped
  while `'deferred'` never writes its gap.
- One predicate, `may_write(s)` = turn held **and** no gap outstanding, gates all
  three write-producing emissions (output `write`, `reserve_round`, `finalize`).
  `write_gap` is emitted exactly when one of them is due and the turn is held.
- `generation_runner.lua`: `cb.prepared(input, gap)` accepts an optional gap
  writer from a `prepare` operation; the runner executes `write_gap` by calling
  it and dispatching `gap_result`. The "live preparation grant" check applies
  only when no gap is deferred — with one, those grants are meant to be live.
- `response_session.lua`: `callbacks.prepared` reports the input to the runner
  immediately and passes a writer that starts `Preparation` on demand. The
  prepare operation stays unresolved until `Preparation` retires, so the
  machine's existing `outstanding(s)` accounting covers the writer's lifetime and
  `cancel_operation` reaches it with no new plumbing.
- `chat_respond.lua`: topic-parent capture moves from the `requesting` hook to
  `finalize`; the session's `requesting` hook then has no caller and is removed
  (ARCH-PURPOSE).

**Consequences worth stating.**

- Task 1.4 Step 5's anti-spin concern largely dissolves for preparation: it no
  longer starts until its generation holds the turn, so the common case — B's
  preparation waiting through A's whole stream — no longer exists. The residual
  parks (`suspended`, a pause mid-gap) are pre-existing and rare.
- Regenerating an answer no longer deletes the old one at submit. It survives
  until replacement bytes exist, so a request that fails before its first byte
  leaves the old answer in place — directly useful to parley#261.
- For a lone generation the answer header now appears with the first output
  rather than at submit. The pending spinner (extmark-only) covers the gap.
- Task 1.6 Step 4's "normal waiter" changes shape: it is no longer a generation
  parked in `preparing` with no stream, but one whose request is running and
  whose output (or declared tool round) is staged behind the holder. The
  visibility message must describe that case.

**Where the tests landed (deviation from Tasks 2.1/2.2's file list).** The
machine cases are in `tests/unit/generation_spec.lua` (request before gap; gap
immediately before the first output, round reservation and finalize; held while
turnless; never written after a pre-output cancel; failure stops). The composed
cases are in `tests/integration/response_session_spec.lua`, which already drives
the real `Preparation` — a separate `response_preparation_spec` would have needed
its own session harness to say the same thing.

**Two specs restated, not inverted-and-restored** (`chat_stop_generation_spec`
"keeps an earlier target independent…", `chat_async_tools_spec` "scopes Stop…").
Both needed a second generation to *write* a tool round's call block while the
first held the turn, which the lifetime-held turn forbids regardless of this
chunk. Each keeps the property it is named for. **M2 obligation:** once tool
execution no longer needs a reservation write, re-add a cross-generation
execution assertion (two generations' tools running concurrently while their
writes stay serialized) — the async case now proves path-scoped admission within
one round only.

**Also found while restoring the nine:** `stop()` queued `release_turn` ahead of
`revoke`, so for one runner step a `terminal` machine still held its region and
an immediate regenerate was refused `'overlap'` (`batch_lifecycle_spec`, green on
`main`). Revoke now precedes release; pinned in `generation_spec`.

### 2026-09-17 — Task 1.6: suspension holds the turn; the matrix shrinks

**Reason.** Operator decision, asked as "which gives the clearest linear
history?" — see `## Decisions taken`. The `suspend` row released on
`grant_suspended`; read against the reducer, suspension is transient and
common, and releasing would produce `A… | edit | B | …A` histories.

**Delta.**

- Turn-matrix rows removed: `suspend`, `suspend_preparation`,
  `waiting_head_of_line`. The last two were the same shape — a holder briefly
  unable to write — and hold for the same reason. What releases the turn is now:
  terminal, stop, the three pause causes, detach, reload. All were already
  implemented by Tasks 1.2–1.5; Task 1.6 adds the tests that hold them to it.
- `WriteTurn.should_release` is **not** created. With no runner-side release
  policy left, every release decision lives in `generation.lua`'s stop/pause
  paths and the reducer's terminal/detach/reload — a pure function with one
  caller would be an abstraction without a second consumer (ARCH-PURPOSE).
- Tests: `generation_spec` pins hold-through-suspension and the pause releases
  (both were already true, so they are characterization, not red-first);
  `generation_turn_spec` runs terminal / stop / detach / reload across four
  step interleavings on real runners, plus Step 3b's self-scheduled wake.
- Step 4 visibility: the runner reports `blocked = {generation, entity, phase}`
  of the holder to its `changed` adapter, recomputed on every sync (so on every
  holder write); `chat_presentation.waiting_message` owns the wording;
  `response_session` renders it on the pending extmark and restores "Working…"
  when the turn arrives. The holder's phase names why it blocks (preparing,
  streaming, running tools, finishing) — the stall shapes.

### 2026-09-17 — Task 1.7: held output was bounded by chunks, not bytes

**Reason.** Writing Step 2's test exposed a gap the budget analysis missed.
Providers call `cb.output` once per SSE delta (`dispatcher.create_output_handler`),
and each call was one machine queue item. A generation held behind the turn hit
the **256-item** cap after a few hundred deltas — a paragraph — and was stopped
as `overflow`, far below the 1 MiB byte budget. And `generation.lua`'s
transition deep-copies its whole state on every event, so a long held queue made
every event O(n).

**Delta.**

- **Coalescing.** An `output` event may carry `extend=true`: it grows the *last*
  queued item, which must be this operation's and carry this blob. An in-flight
  item is not in the queue, so it can never grow under an issued write. The
  runner tries the extension first and falls back to a new item when refused;
  appends go to a parts list joined once on read. A held answer is now one item,
  bounded by bytes (`generation_turn_spec`: 600 deltas held, one item, written
  whole).
- **Step 1, re-measured** (one-off count of the bytes from each `🤖:` line to
  the next `💬:`/`🤖:` line, over every `workshop/parley/*.md` in the sibling
  repos): **59 files, n=359 answer blocks,
  p50 573 B, p95 16,525 B, p99 36,420 B, max 116,723 B.** p99 is far under the
  ~100 KiB revisit threshold, so the budget is unchanged: 1 MiB per generation
  (~9× the largest answer), 16 MiB process-wide.
- **Step 5, the bound stated rather than tested at 16 MiB:** at most 16 runners
  (`generation_runner.lua` `active>=16`) × 1 MiB each is exactly the process
  cap, so the per-generation limit always binds first. Stated at the `stage()`
  site.
- **Steps 2–4.** Both overflow sites now end as outcome `overflow` (the runner's
  pre-admission refusal used to end as `cancelled`), via one `overflow_reason`
  that names the answer the generation was held behind. The reason reaches the
  host through the terminal snapshot's `failure`, and `chat_respond` warns
  "Response stopped: …". Found on the way: the transport's abort after a refused
  chunk re-reported `cancelled` through `cb.failed` and overwrote the cause — a
  failure reported while already stopping is now treated as an echo, not a
  reason.

### 2026-09-17 — M1 boundary review round 1 (REWORK): the response

Review sidecar: `workshop/plans/000266-…-m1-review.md`. Each finding fixed at its
class, with a test that fails without the fix unless noted.

- **C1 — a release queued behind a parked effect.** A stale-input
  `continue_round` pauses and then parks at the head of the runner's FIFO until
  resumed; the `release_turn` its pause emitted queued behind it, so a paused
  generation held the turn for good and every waiter's output piled up toward its
  budget. *Class:* control effects (`revoke`, `request_turn`, `release_turn`)
  waiting behind work. `generation_runner` `M.step` now runs any queued control
  effect ahead of a parked one, keeping control effects in FIFO order among
  themselves so `stop()`'s revoke still precedes its release. This **replaces**
  Task 1.5 Step 3's "issue release synchronously from `sync`" — dropped when the
  suspension rows went, while the pause row still parked. The resumed side is
  fixed by the same rule: `request_turn` no longer queues behind a stale release.
  Regression: `generation_turn_spec` "hands the turn on when the holder pauses on
  a stale input" (red before), plus the unknown-outcome variant (runner-level
  coverage of that row, which had none).
- **I1 — plan/code drift, recorded here.** *Fail-closed reversed to joint
  enforcement* (`99db5af2`): refusing every writer while nobody holds the turn
  broke 96 document-layer tests (96 → 9 after the change). The invariant is (a)
  every generated writer requests the turn before it writes — the machine's
  `start`/`resume_validated`, and `response_topic` around its one write — and (b)
  the coordinator refuses any owner that is not the holder. *Residual
  assumption:* a new generated writer that forgets (a) is admitted whenever
  nobody holds the turn; `State.waits_for_turn`'s comment names this.
  *`turn_status` defaults `'held'`*: harmless under (a) because the coordinator
  refuses, and `request_turn` — now a control effect — executes before any other
  effect. Tasks 1.4 Step 3 and 1.5 Step 3 describe the superseded fail-closed
  form; read them through this entry.
- **I2 — the gap writer could return without settling.** `response_session`'s
  writer now settles on every path: Preparation failing to start, failing, or
  retiring `cancelled` without reporting (`done` is idempotent). Regression:
  `response_session_spec` "settles the gap when preparation cannot start".
- **I3 — a provider failure before the first byte could emit `write_gap`.** The
  gap emission now sits after the provider-failure stop in `pump`. Regression:
  `generation_spec` "never writes the gap when the provider fails before any
  output".
- **I4 — M2 obligations promoted** to the issue's `## Plan` M2 row: re-assert
  cross-generation tool execution (restoring the two restated specs'
  cross-generation cases) and revert `atlas/providers/tool_execution.md`'s turn
  sentence.
- **I5 + the predicate family.** Three spellings of "owns the grant, turn held
  elsewhere" (one paid a full state copy per write chunk; one checked the turn
  before ownership) are now one O(1) `State.waits_for_turn(doc,generation,grant)`
  used by all five generated entry points. Unit-tested in `document_state_spec`,
  including "a non-owner is an ownership failure, not a wait".
- **Minors.** `overflow_reason` no longer re-derives the holder's line or owns
  wording: the runner records `waited_for_line` (from `blocked.line`, derived once
  in `blocker`) and `chat_presentation.overflow_message` words it. The waiting
  note no longer loses its status slot to the held answer's own provider detail
  (regression added). `tool_use.md` and README restate the serialized model. The
  obfuscated assertion in `generation_turn_spec` is plain. *Not changed:*
  `chat_presentation` has no `paused` reason — after C1 a paused generation gives
  the turn up, so it is never the holder a waiter names.

### 2026-09-17 — M1 boundary review round 2 (FIX-THEN-SHIP): the response

- **BR-2 (Important) — the contiguity claim, with its exceptions.** The atlas and
  the target said each generation's writes are one contiguous run and one undo
  step. A pause yields the turn (by design — a paused generation must not block
  every other answer), so resumed writes start a new run; and undo groups per
  (generation, grant). *Class:* an invariant stated without its exceptions. Swept
  every statement of it — `atlas/chat/ownership.md`, the target's previous
  Revision (struck, with a correcting Revision appended), and this plan's
  Decisions entry; README's "never mixes two answers" was already exact. The
  invariant is now: no undo step mixes generations (unconditional); contiguous
  while the turn is held uninterrupted; a pause starts a new run; undo per
  (generation, grant). Pinned by a pause-then-resume variant of the undo test on
  a real buffer (a's text leaves in two runs around b's, no step mixes them).
- **BR-3 (Minor) — snapshots ahead of cheap checks, again.** Round 1's I5 was
  fixed at the coordinator only; the runner's new `blocker`/`present` did the
  same on every sync, holder included. Swept the diff's per-chunk paths:
  `blocker` now checks `turn_status`/`doc.turn` first and reads phases through a
  new O(1) `G.phase`; `sync` presents only when the blocker actually changed.
  The other snapshot sites in the diff (overflow refusal, `cb.failed`, gap
  execution) run once per event, not per chunk.
- **BR-4 (Minor)** — the `response_tools` and `response_session` rows above are
  tagged *(M2)*, like `sequence`.
- **Also:** `response_topic`'s unreachable `applied.status=='waiting'` branch is
  removed — the turn was confirmed held a line earlier, and had it ever run,
  the job's own subscriber was suppressed by `s.writing` and nothing would have
  woken it. Control-effect ordering among themselves is now pinned at the runner
  (revoke one step before the turn moves), not only end to end.
- **BR-1 (round-1 plan-gate carry-over)** was withdrawn by the reviewer.

