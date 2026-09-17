# Serialize Transcript Mutation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exactly one generation may mutate a transcript at a time, and a tool round appends `(call, result)` pairs in call order, so the buffer's undo history is a sequence of coherent units instead of interleaved 4 KiB chunks.

**Architecture:** The generation machine gains a **phase** for the situation the issue names — *complete but not yet written* — rather than a boolean bolted beside the existing phases. Revisions 1–3 encoded the turn as `s.has_turn`; the Spec explicitly rejects that ("That is a new lifecycle state; enumerate it explicitly rather than encoding it as a boolean pair (ARCH-ORDER)"), and every unresolved question in those drafts — an unclosable release set, a missing re-request set, ambiguous terminal ordering — was a symptom of having no state to hang them on.

The model:

- **`document/state.lua`** owns the turn (pure `WriteTurn` decision, integer generation ids, ascending by admission).
- **`generation.lua`** gains the phase **`draining`**: the provider has completed, output is staged, and the only remaining work is to write it. It also mirrors the document's turn as **`s.turn_status`** (`'held'` | `'waiting'`) — a guard input exactly like the existing `s.grant_status`, which is mirrored the same way through `sync`. This is deliberately not a new peer of `paused`: `paused` stops work, whereas a turnless generation keeps *receiving* provider bytes (the operator chose concurrent execution with serialized writes).
- **`document/init.lua`** refuses a turnless generated write with a new `'waiting'` status at the five write entry points, plus inside `Replacement.step` — the only place a multi-chunk replacement's generation is knowable.
- **`response_tools.lua`** replaces placeholder reservation with ordered `(call, result)` appends sequenced by a pure `ToolSequence`.

**Why `'waiting'` and not `busy`.** `busy` already carries three unrelated meanings (`document/init.lua:516` append-in-flight, `document/editor.lua:203` re-entrancy, `replacement.lua:62` concurrent replacement on one grant), and it means *retry now* — `generation_runner.lua:274` returns `true`, `M.step` returns `'more'`, and `Deferred` re-arms at 1 ms, so a turn-blocked writer would hot-spin for the whole time another generation streams. `'waiting'` maps to the existing `return true,'waiting'` (`:269`), which parks the timer so the notify wakes it. ARCH-CONSTRAINTS: this is a keystroke-adjacent path; an unbounded 1 ms spin is not acceptable.

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

**The wake, as one rule.** `notify()` fires only at `document/init.lua:206,223,232,381,402`, never from `M.transition`, and `Deferred` re-arms only while `step` returns `'more'` (`deferred_work.lua:11-24`). Revision 3 scoped a new notify to `request_turn`/`release_turn`, which structurally excludes `finish_generation` — the *most common* release, since it calls `retune`. So: **`M.transition` notifies whenever the turn value differs before and after**, covering `request_turn`, `release_turn` and `finish_generation` in one place — no ordering question for an implementer to resolve. `reload`/`detach` are already covered and need nothing: they never reach `M.transition` (`observe` calls `State.transition` directly at `init.lua:219,231`) and are woken by the pre-existing `notify(s,{kind='reload'})`/`{kind='detach'}` at `:223`/`:232`.


**Issue:** parley#266 · **Target:** `workshop/targets/transcript-is-the-whole-truth.md` · **Blocks:** parley#261

**Branch:** must be `000266-serialize-transcript-mutation`. `tests/arch/single_source_sweeps_spec.lua:732-743` (regex at `:737`) only enforces "every spec this branch added is routed in `atlas/traceability.yaml`" when the branch matches `^%d%d%d%d%d%d%-`; any other name silently downgrades that guard to `pending`.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `WriteTurn` | `lua/parley/document/write_turn.lua` | new |
| `ToolSequence` | `lua/parley/tools/sequence.lua` | new |
| `DocumentState` | `lua/parley/document/state.lua` | modified |
| `GenerationMachine` | `lua/parley/generation.lua` | modified |
| `DocumentCoordinatorStatus` | `lua/parley/document/init.lua` | modified |

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
| `DocumentCoordinator` | `lua/parley/document/init.lua` | modified | reducer event whitelist + snapshot |
| `GenerationRunner` | `lua/parley/generation_runner.lua` | modified | turn polling + turn effects |
| `ToolAdapter` | `lua/parley/response_tools.lua` | modified | append-only round insertion |
| `TopicGeneration` | `lua/parley/response_topic.lua` | modified | the `D.apply` path that bypasses the runner |
| `PendingProgress` | `lua/parley/response_session.lua` | modified | tool → `chat_pending` progress edge |

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
| `start`, `resume_validated` (`:343-345`) | → `held` (requested) | — |
| `terminal` (`:98`, `:154`) | released | never (generation is gone) |
| `stop` / `phase=='stopping'` (`:40-53`) | released | never |
| pause: unknown child outcome (`:332-334`), `revoke_child` (`:60`), stale input (`:342`) | released | `resume_validated` (`:343-345`) |
| grant suspended (`sync`, `generation_runner.lua:55-61`) | released | `grant_resumed` (`:57-59`) — **exists today and must be wired; revision 3 released without re-requesting** |
| suspended *preparation* grant — `sync` dispatches `grant_suspended` for ids in `preparation_grants` (`:489-491`) but `generation.lua:254-256` rejects it (`event.grant~=s.grant`), while `response_preparation.lua:94,103` retries forever | released | needs a **new observation**; no existing event carries it |
| head-of-line `'waiting'` that is not the turn — e.g. the `reclaim_tail` `'unconfirmed identity'` retry (`generation_runner.lua:347-352`), which deliberately does not pause | released | next successful step |
| **queue empty** — `staged(s)==0` (`generation.lua:23-27`) and no pending effect: nothing to write right now | released | next `output`/`manual_*` enqueue |
| `detach` / `reload` | cleared by `state.lua:353-356` | n/a |

**No timer, and no threshold to derive.** Earlier revisions wanted a
"provider silent" trigger and a duration to go with it. `staged(s)==0` is the
exact, free, clockless predicate for the same situation: a generation with
nothing staged and no pending effect is not writing, whatever the reason —
silent provider, hung transport, or simply between chunks. `M.step` already
returns `'waiting'` at that point (`generation_runner.lua:452`). This deletes a
measurement task, a tunable, and a whole failure mode (*Simplicity First*).

**The cost, stated.** Releasing between chunks means another generation can
interleave mid-answer, and `can_join_undo` (`editor.lua:192-199`) clears its
receipt on any foreign write (`:67`), so A's output splits into several undo
entries. Task 1.9's invariant ("no entry mixes two generations") still holds, but
the issue Log's stronger phrasing — "one undo entry per generation run" — does
not. That is recorded in Target reconciliation rather than quietly dropped.

### ARCH-SECURE

`N/A` — touches neither untrusted input nor secrets. The turn is an in-memory ordering decision over writes the system already performs; no new parsing, no new external surface, no credential path.

### ARCH-MOCK

`N/A` — this issue adds no external binary or service dependency. All doubles already exist and are reused: `tests/helpers/fake_generation_runner.lua`, `tests/helpers/fake_document_editor.lua`, the inline `producer` table at `tests/integration/response_tools_spec.lua:12-16`, and `tests/helpers/fake_process.lua` for the end-to-end path.

### What is deliberately NOT changed

Execution concurrency: `generation.lua:84` fan-out cap of 4, `tools/resources.lua:82-90` admission (`running<16`, `per_document<8`, `per_generation<4`), `tasker.lua:20-21` attempt ceilings, and the path-scoped claims in `tools/async_builtin.lua:248-267`. Human edits via `apply_user` (`document/init.lua:432`) are **never** subject to the turn — the guarantee is ordering between generations, not absolute.

---

## Chunk 1 — M1: the write turn

**Routing rule for every task below.** `make test-spec SPEC=<key>` runs only files listed under that key in `atlas/traceability.yaml` (`Makefile.parley:113-129` → `scripts/spec_test_map.sh list-tests`). A new spec that is not routed is silently **not run**, so a "watch it fail" step would print green. Every task that creates a spec routes it in the *same* task, before the red step. Existing keys, verified: `tests/unit/generation_spec.lua` → `chat/lifecycle` (`atlas/traceability.yaml:194`); `tests/unit/document_state_spec.lua` → `chat/ownership` (`:307`, key at `:294`) **and** `chat/document` (`:391`); `tests/integration/response_tools_spec.lua` → `chat/lifecycle` (`:201`) and `providers/tool_use` (`:878`); `tests/integration/generation_sequences_spec.lua` → `chat/ownership` (`:314`); `tests/unit/document_capacity_spec.lua` → `chat/ownership` (`:325`). Also route `lua/parley/document/init.lua` and `lua/parley/document/write_turn.lua` under `chat/ownership` `code:`, since `make test-changed` keys off those lists.

### Task 1.1: `WriteTurn` pure entity

**Files:**
- Create: `lua/parley/document/write_turn.lua`
- Test: `tests/unit/document_write_turn_spec.lua`
- Modify: `atlas/traceability.yaml` — route **both** the spec (`tests:`) and `lua/parley/document/write_turn.lua` (`code:`) under `chat/ownership`, so `make test-changed` on the module runs its own spec

- [ ] **Step 1: Route the new spec** in `atlas/traceability.yaml` under `chat/document`. Two-space key, four-space `code:`/`tests:`, six-space `- path`; the awk parser is whitespace-strict.

- [ ] **Step 2: Write the failing test.** Generation ids are **bare integers** (`state.lua:6-7`), so compare with `<`.

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

- [ ] **Step 3: Run it and watch it fail.**
  Run: `make test-spec SPEC=chat/document`
  Expected: FAIL — `provides the module` asserts false (`module 'parley.document.write_turn' not found`), and the remaining `it` blocks do not run because of the `if not ok then return end` guard.

- [ ] **Step 4: Minimal implementation**

```lua
-- Pure write-turn decision. One generation may mutate a document at a time;
-- eligibility order is admission order, which state.lua's monotone integer id()
-- already encodes.
local M={}
--- @param generations table  map of integer id -> {eligible=boolean}
--- @param current integer|nil currently held id
--- @return integer|nil
function M.holder(generations,current)
    if current then
        local held=generations[current]
        if held and held.eligible then return current end
    end
    local best
    for id,record in pairs(generations) do
        if record.eligible and (not best or id<best) then best=id end
    end
    return best
end
return M
```

- [ ] **Step 5: Run and verify green.** `make test-spec SPEC=chat/document` → all pass.
- [ ] **Step 6: Commit** — `#266 M1: add the pure write-turn decision`

### Task 1.2: turn state in the reducer

**Files:**
- Modify: `lua/parley/document/state.lua` (`M.new` `:64`, `M.transition` `:182-357`, `M.snapshot` `:72`)
- Test: `tests/unit/document_state_spec.lua`

**Epoch note.** `M.new` sets `epoch=opts.epoch or id()` (`:68`), and `M.transition` rejects a mismatched epoch at `:186`. Follow the file's existing convention (`document_state_spec.lua:149,189`): construct with `State.new({epoch=100})` and pass `epoch=100`, or omit `epoch` from the event entirely.

- [ ] **Step 1: Failing test** — append to `tests/unit/document_state_spec.lua`:

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

- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/document`
  Expected: FAIL — `S.transition(...).reason == 'unknown event'` (the `else` at `state.lua:357`), so `.ok` is false and `assert.is_true` fails.

- [ ] **Step 3: Implement.** Add `local WriteTurn=require('parley.document.write_turn')` at the top of `state.lua` (it currently requires nothing). In `M.new`'s doc table add `turn=nil,turn_wanted={}`. Add a helper beside `capacity_used` (`:170`):

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

Add two branches before the `else` at `:357`:

```lua
    elseif kind=='request_turn' then
        if not s.generations[event.generation] then return reject('generation') end
        s.turn_wanted[event.generation]=true
        retune(s); result.turn=s.turn
    elseif kind=='release_turn' then
        if not s.generations[event.generation] then return reject('generation') end
        retune(s,event.generation); result.turn=s.turn
```

In `finish_generation` (`:344-352`) call `retune(s,event.generation)` after the existing cleanup. In the shared `reload`/`detach` branch (`:353-356`) add `s.turn,s.turn_wanted=nil,{}`. `M.snapshot` at `:72` is `copy(state(doc))` and `copy` (`:10-26`) walks the whole table on every call — and `D.snapshot` runs per step in `sync`, `write`, `replace`, `written` and `context`. Expose `turn` but **keep `turn_wanted` out of the snapshot**, or the per-step copy grows with every admitted generation.

- [ ] **Step 4: Run and verify green.**
- [ ] **Step 5: Commit** — `#266 M1: hold a write turn in the document reducer`

### Task 1.3: coordinator passthrough and the wake path

**Files:**
- Modify: `lua/parley/document/init.lua:320-324` (whitelist), `lua/parley/document/init.lua:19-25` + the transition site (notify)
- Test: `tests/integration/document_turn_wake_spec.lua` (new)
- Modify: `atlas/traceability.yaml` (route the new spec under `chat/ownership`)

**Correction to an earlier draft of this plan:** `tests/arch/document_ownership_spec.lua:69-90` is a *forbid-list scoped to `lua/parley/chat_pending.lua` and `lua/parley/chat_presentation.lua`* — it asserts presentation cannot mint grants. It does **not** enumerate the coordinator whitelist (`grep -rn "coordinator-owned"` has exactly one hit: `document/init.lua:324` itself). Adding the two events does **not** break it. Do not expect or "fix" a failure there.

- [ ] **Step 1: Route the new spec**, then write it. The point is that a waiting runner is woken when the turn is released — the failure mode is a silent hang, so the test must use `schedule=true` (real timers) for at least one case, because `Runner.step` calls `sync` on every invocation (`:449`) and a hand-pumped harness structurally cannot observe a missing wake-up.

```lua
it('wakes a waiting generation when the holder releases the turn',function()
    -- two runners on one doc, schedule=true; a holds the turn and b is queued
    -- with output staged. Complete a. Then, WITHOUT stepping b by hand:
    assert.is_true(vim.wait(2000,function()
        return Runner.snapshot(b).committed_bytes==#expected end,10),
        'b never woke after the turn was released')
end)
```

- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL — `b never woke after the turn was released` after the 2 s wait.

- [ ] **Step 3: Implement.** Extend the whitelist at `:323-324` with `request_turn` and `release_turn`. In the coordinator's transition wrapper, after a successful `request_turn`/`release_turn`, call `notify(s,{kind='turn',turn=result.turn})`. The runner's existing subscriber (`generation_runner.lua:498-501`) already does `sync(s)` + `work:request()`, so no runner change is needed for the wake itself.
- [ ] **Step 4: Green.**
- [ ] **Step 5: Reentrancy note.** Every existing `notify` site is in `observe`/`repair_step` (`:206,223,232,381,402`); none is inside `M.transition` (`:320-341`). This adds the first, so a runner's `D.transition(release_turn)` synchronously re-enters every subscriber's `sync`. That is safe as written — subscribers only read `D.snapshot` and dispatch into their own machine, and `work:request()` defers via `vim.defer_fn` — but assert it with a test that transitions from inside a subscriber callback. Also note `M.transition:338-339` runs `Replacement.prune` plus a full `State.snapshot` on every one of these new, frequent events.
- [ ] **Step 6: Commit** — `#266 M1: notify subscribers when the write turn moves`

### Task 1.4: refuse a turnless generated write with `'waiting'`

**Files:**
- Modify: `lua/parley/document/init.lua` — `M.append` `:556`, `M.apply` `:491`, `M.replace_new` `:446`, `M.insert_released_new` `:459` (not `M.replace_step` `:482` — its cursor has no generation; that guard lives in `Replacement.step`, below)
- Modify: `lua/parley/document/replacement.lua` — `Replacement.step` (writes at `:180`, 4096 at a time via `:155,165`), using `c.generation` (`:60`)
- Modify, per the enumeration table in Architecture — **six caller sites**: `response_preparation.lua:94,103,113`; `response_completion.lua:66,74`; `response_topic.lua:168`
- Test: `tests/integration/generation_turn_spec.lua` (new), routed under `chat/ownership` in this task

`M.apply_user` (`:432`) is **not** changed — humans are never blocked.

- [ ] **Step 1: Route the spec**, then write the failing test — one case per row of the enumeration table (provider, tool, preparation, completion, topic, and a replacement continuation that begins while holding the turn and must stop when it moves):

```lua
for _,writer in ipairs({'provider','tool','preparation','completion','topic','replacement_continuation'}) do
  it('refuses a '..writer..' write while another generation holds the turn',function()
```

The `replacement_continuation` case is the one revisions 2 and 3 both missed: start a multi-chunk replacement while holding the turn, move the turn, then assert no further bytes land.

- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL on all six — bytes commit immediately; asserted `0`, got the full length.

- [ ] **Step 3: Implement.** Beside the existing `append_busy` check (`init.lua:516`), factored once:

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
- `response_topic` registers its own generation (`response_topic.lua:141-147`) and finishes it (`:37`); it must now `request_turn` and `release_turn` like any other writer, not rely on a permissive branch.

**Three return conventions, not one.** `M.append` and `M.apply` return a status table → `return reject('waiting','write turn held elsewhere')`. `M.replace_new` (`:446-457`) and `M.insert_released_new` (`:459-481`) return `nil,reason` → `return nil,'waiting'` (which is why `response_preparation.lua:103` and `response_completion.lua:66` are *reason* sets). `Replacement.step` must return `'waiting'` through its `result(...)` path (`replacement.lua:33-40`) **without** calling `stop(c,…)`, or the cursor is permanently dead.

Then add `'waiting'` to all six caller predicates **and** to the two runner sites above.

- [ ] **Step 4: Green.** `make test-spec SPEC=chat/ownership`
- [ ] **Step 5: Anti-spin assertion.** Add a test that a turn-blocked writer performs a bounded number of `M.step` calls over a fixed wall-clock window — the `busy`-shaped bug is invisible to a correctness assertion and only shows as CPU.
- [ ] **Step 6: Commit** — `#266 M1: refuse turnless generated writes without spinning`

### Task 1.5: the `draining` phase and `turn_status`

**Files:** `lua/parley/generation.lua` — `writable` `:32-39`, initial state `:167`, `M.transition` `:186-376`, the completion paths at `:123`, `:129`, `:149`
**Test:** `tests/unit/generation_spec.lua` (routed `chat/lifecycle`, `atlas/traceability.yaml:194`)

This is the task the Spec's ARCH-ORDER clause asks for. It is not an optimization and must not be deferred: without it, `staged(s)==0` keeps meaning both "my writes drained" and "I may proceed", and the `bytes==0` gates cannot tell a held generation from a streaming one.

- [ ] **Step 1: Failing tests.**
  - `turn_status='waiting'` + `output` → no `write` effect; after `{type='turn',status='held'}` → a `write` effect appears.
  - `provider_complete` with `staged(s)>0` → `phase=='draining'`, **not** `finalizing`.
  - from `draining`: `cancel` → `stopping`; `grant_revoked` → expressible; `input_changed` → marks stale without losing staged bytes. These three are the Spec's "cancellation, revocation and staleness must be expressible".
  - `draining` + drain to `staged(s)==0` → `finalizing`.
  - **`provider_failed`** (`generation.lua:266-271`) also does `advance(s,'finalizing')` under the comment "Drain valid writes before failure retirement" — the identical complete-but-unwritten situation. It routes through `draining` too; the phase diagram needs that failure edge.
  - **Paused overlay:** entering `draining` must go through `advance` (`:29-31`) so a paused generation records it in `s.resume_phase`, and the drain-exit must read `phase(s)`, because `pump`'s finalize gate at `:149` reads `s.phase` **directly** — a paused-draining generation would otherwise never finalize.
- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/lifecycle`
  Expected: FAIL — `phase` is `requesting`, not `draining`; a `write` effect is emitted while turnless.
- [ ] **Step 3: Implement.** Add `draining` to the phase set and `s.turn_status='waiting'` at `:167` (fail-closed, per Task 1.4). **Create the `request_turn` and `release_turn` effects here** — emitted from `start` and `resume_validated` (`:343-345`) — and their handlers in `generation_runner.lua`'s `execute`, calling `D.transition(...)`. No earlier task creates them; without this step the turn is never requested and nothing writes. `writable` gains `s.turn_status=='held'`. Add a `turn` event branch setting `s.turn_status` then calling `pump`. Route the completion transition through `draining` when `staged(s)>0`. Keep `staged(s)` (`:23-27`) as is. The `bytes==0` gate at `:149` becomes **unreachable** once completion routes through `draining`, so add the `draining → finalizing` branch rather than leaving dead code; `:123` and `:129` are unaffected.
- [ ] **Step 4: Green. Step 5: Commit** — `#266 M1: add the draining phase for complete-but-unwritten output`

### Task 1.6: the turn matrix

**Files:** `lua/parley/document/write_turn.lua` (add `should_release`), `lua/parley/generation.lua`, `lua/parley/generation_runner.lua` `sync` `:47-65`
**Test:** `tests/integration/generation_turn_spec.lua`

**ARCH-DRY:** one invariant, one implementation. Put the decision in a pure `WriteTurn.should_release(observation)` beside `WriteTurn.holder`; both the machine and the runner feed it an observation rather than each carrying half the policy.

- [ ] **Step 1: Write the matrix** — one case per row of the ARCH-ORDER table, asserting **both** that the waiting generation acquires the turn *and* that the releasing generation re-acquires it when its re-request condition fires. A release without a paired re-request is a permanent stall, which is what an earlier draft shipped. Parameterise interleavings rather than using the fixed round-robin at `generation_sequences_spec.lua:48`:

```lua
local schedules={{'a','a','b','b'},{'a','b','a','b'},{'b','a','b','a'},{'b','b','a','a'}}
for _,row in ipairs({'terminal','stop','pause_unknown','pause_revoke','pause_stale',
    'suspend','suspend_preparation','waiting_head_of_line','queue_empty','detach','reload'}) do
  for _,schedule in ipairs(schedules) do
```

- [ ] **Step 2: Run.** `make test-spec SPEC=chat/ownership`
  Expected: FAIL for `suspend` (releases but never re-requests — `grant_resumed` exists at `generation_runner.lua:57-59` and is unwired), `suspend_preparation` (no event carries it), `waiting_head_of_line`, and `queue_empty`.
- [ ] **Step 3: Implement** `WriteTurn.should_release`, wire `grant_resumed`, and add the preparation-suspension observation. **Its mechanism, named:** `sync` dispatches `grant_suspended` for every id in `s.grants`, which includes `preparation_grants` (`generation_runner.lua:55-61,489-491`), but `generation.lua:254-256` rejects it because `event.grant~=s.grant` and no child matches — so add a `preparation` branch there rather than a new event kind.
- [ ] **Step 4: Green. Step 5: Commit** — `#266 M1: make turn release and re-request symmetric`

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

- [ ] **Step 1:** Re-measure against a larger transcript corpus; record p50/p95/p99/max here. Change the number only if the data says so.
- [ ] **Step 2:** Test with `limits={staged_bytes=8,queued_items=4}` (precedent `generation_sequences_spec.lua:68`): hold the turn elsewhere, exceed it, assert the generation stops **and** that the surfaced message names the exchange holding the turn.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=chat/ownership` — the message assertion fails.
- [ ] **Step 4:** Thread the blocking exchange into both overflow messages. **Step 5:** Test the ceiling at both scopes. Four held generations on one document is 4 MiB, fine — but `generation_runner.lua:462` admits **16 runners process-wide**, and held generations are new, so the worst case is 16 × 1 MiB = *exactly* the 16 MiB cap at `:75`. Refusal there reaches `:160`/`:101-102` → `issue('staging overflow')` + `cancel`, destroying a generation. Test the multi-document case or state the bound explicitly. **Step 6: Commit** — `#266 M1: name the blocking exchange when held output overflows`

### Task 1.8: verify every writer in the enumeration

**Files:** verify only. **Test:** `tests/integration/generation_turn_spec.lua`, `tests/integration/response_topic_spec.lua`

- [ ] **Step 1: Re-run the enumeration grep from Architecture.** If it returns a writer not in the table, stop and correct the table first — that failure mode cost two review rounds in this plan's history.
- [ ] **Step 2:** One test per row. `response_completion.lua:55-58` acquires a *fresh grant* and `response_topic.lua:168` has no waiting predicate — those two are the likeliest to slip.
- [ ] **Step 3: Run.** `make test-spec SPEC=chat/ownership`
- [ ] **Step 4:** Fix what the enumeration exposes. **Step 5: Commit** — `#266 M1: verify every generated writer honours the turn`

### Task 1.9: undo coherence

**Files:**
- Test: `tests/integration/chat_scoped_response_spec.lua:47` (invert), `tests/integration/generation_turn_spec.lua`

**What to assert, and what not to.** Not "undo steps == generation runs": `can_join_undo` keys on `(epoch,generation,grant)` (`editor.lua:192-199`, identity mismatch at `:197`) and a single run legitimately writes through preparation grants (`generation_runner.lua:488-492`) *and* a completion-acquired grant (`response_completion.lua:55-58`), so a run spans several grants and therefore several undo entries. Not "backwards in document position" either — generations write to different answers, so regenerating Q3 then Q1 writes Q3's region first.

The invariant to assert is the issue's own: **no undo entry mixes two generations, and no entry is a partial chunk.** Within a single tool round, insertion is monotonic at the tail, so document order *is* additionally guaranteed there (assert that in Chunk 2).

- [ ] **Step 1:** On a real buffer, run two generations to completion serialized, then loop `vim.cmd('silent undo')` capturing `vim.fn.changenr()` (via `nvim_buf_call`, the idiom at `document/editor.lua:13`) and the buffer text at each step. Assert every removed span lies wholly within one generation's output region, and that no step removes a 4096-byte fragment of a larger contiguous write.
- [ ] **Step 2: Run.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL today — interleaved writes defeat the receipt at `editor.lua:199` and produce per-chunk entries.
- [ ] **Step 3:** No production change expected; Tasks 1.4–1.6 should satisfy it. If not, the receipt invalidation at `editor.lua:67` is the suspect.
- [ ] **Step 4: Green.** Do **not** add a seed to `document_native_history_spec.lua` — that spec drives only human edits, undo and redo (`:51-78`) and never runs a generation, so a new seed would not exercise the writer path of `can_join_undo`.
- [ ] **Step 5:** Invert `chat_scoped_response_spec.lua:47` — rename to `'serializes two answers while the next question is edited'`, keep the reverse-order delivery, assert the second answer commits nothing until the first terminates, and keep the existing draft-preservation assertion.
- [ ] **Step 6: Commit** — `#266 M1: assert undo entries never mix generations`

### Task 1.10: atlas, routing, milestone close

- [ ] Rewrite `atlas/chat/ownership.md:8-9` — "Disjoint generations may write separate answers" is now false. Also `atlas/providers/architecture.md:29`. **Not** `atlas/chat/lifecycle.md:267` or `atlas/chat/inline_branch_links.md:76` — both describe *human* edits, which stay legal under `apply_user`; and not `atlas/chat/response_progress.md:56`, which is a test-file description. Only pages asserting concurrent *generated* writes change.
- [ ] Confirm every spec added in Chunk 1 is routed and every new `lua/` file is in the right `code:` list.
- [ ] `make test` → exit 0 (lint runs first).
- [ ] `sdlc milestone-close --issue 266 --milestone M1`

---

## Chunk 2 — M2: ordered append, and the machinery it replaces

**Precondition, live now:** `scripts/refresh_goldens.lua` and 11 golden payloads are modified in the working tree from `f1818ee1` (#218). Resolve before cutting the branch — Task 2.5 regenerates goldens and expects no message-shape change, which that dirt would mask.

**Boundary correction.** An earlier draft deferred child-grant removal to M3 and had M2 rewrite `response_tools.lua` alone. That is impossible: `round_reserved` requires `#event.grants==#round.children`, each identity-valid, distinct and ≠ parent (`generation.lua:306-315`). A `begin_round` that acquires no child grants yields `done(nil)` → `round_reservation_failed` → `stop(s,effects,'reservation_failed')` (`:304`). Switching to ordered append and removing the reservation lifecycle are **one change** and land together.

### Task 2.1: `ToolSequence` pure entity

**Files:**
- Create: `lua/parley/tools/sequence.lua`
- Test: `tests/unit/tools_sequence_spec.lua`
- Modify: `atlas/traceability.yaml` — route under `providers/tool_use`

- [ ] **Step 1: Route the spec.**
- [ ] **Step 2: Failing test.** Signatures: `Seq.new(calls) -> seq`, `Seq.next(seq) -> {kind='call'|'result', index=n} | nil`, `Seq.outcome(seq,index,value) -> seq`, `Seq.written(seq,item) -> seq`, `Seq.complete(seq) -> boolean`; all pure and immutable (each returns a new record). Cases: the first call is offered before anything arrives; a later outcome cannot skip ahead while an earlier result is outstanding; the round drains in declared order once the earlier outcome lands; an unresolved outcome is writable evidence, not a stall.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use` → `provides the module` false.
- [ ] **Step 4: Implement** as a pure immutable record.
- [ ] **Step 5: Green. Commit** — `#266 M2: add the pure tool insertion sequence`

### Task 2.2a: remove capacity tickets from the document layer

**Files:** `lua/parley/document/state.lua:170-180,199-212,253-256`; `lua/parley/document/init.lua:312-319`
**Delete:** `tests/unit/document_capacity_spec.lua` **and** its entry at `atlas/traceability.yaml:325` — `single_source_sweeps_spec.lua:723` fails on a named path that no longer exists.

- [ ] Confirm no callers remain: `grep -rn "reserve_capacity\|release_capacity" lua/ tests/`. Record in `## Log` which invariant `document_capacity_spec.lua` was defending, so a later reader can tell deliberate removal from erosion.
- [ ] `make test` → exit 0. Commit `#266 M2: remove capacity tickets`.

### Task 2.2b: remove the round-reservation lifecycle from the machine and runner

**Files:** `lua/parley/generation.lua:131-134` (`reserve_round` emission), `:289-316` (`round_reservation_failed`/`round_reserved`), `:54-72` (`child_by_grant`/`revoke_child`), the child branch of `writable` `:32-39`, `write_result` `:234-249`; `lua/parley/generation_runner.lua:98` (**the `effect.type~='reserve_round'` liveness exemption in `mutation` — silently breaks if the effect is renamed**), `:329-354`, `:382-389`, `:404-434`; `lua/parley/response_session.lua:174`
**Test:** `tests/unit/generation_spec.lua` — the reservation tests at `:155-176`, `:292-304`, `:366-371` are removed with the contract they pin.

- [ ] Red/green per removal. `make test-spec SPEC=chat/lifecycle` between each.
- [ ] Commit `#266 M2: remove round reservation from the generation lifecycle`.

### Task 2.2c: the ordered-append pump

**Files:** `lua/parley/response_tools.lua` — rewrite `:137-182` as `begin_round`; delete `:21-26`, `:36-68`, `:154-161`, `:183-187`; rewrite `tool_outcome` `:77-102` to append
**Test:** `tests/integration/response_tools_spec.lua`

- [ ] **Step 1: Invert the pinning test** at `:141` → `'writes each call block immediately before its own result'`: assert `ca<ra and ra<cb and cb<rb`, no `(Tool result pending)` anywhere, both producers started (execution stays concurrent). Within one round insertion is monotonic at the tail, so **document order is guaranteed here** — assert it, since Task 1.9 deliberately does not claim it across generations.
- [ ] **Step 2: Add a bounded-step variant.** `f.drain()` runs to quiescence (`:37-42`) and cannot exercise "call 2's block written while result 1's multi-chunk write is mid-flight" (4096-byte slices, `generation_runner.lua:265`). Add `step(n)`.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use`
- [ ] **Step 4: Implement.** `begin_round` freezes `s.rounds[ctx.round]`, builds a `ToolSequence`, writes nothing, takes no ticket. A pump appends `Serialize.render_call` / `render_result` at the parent grant tail via `ctx.append`, one item per `adapter.step()`, driven by `Seq.next`. **Collector for the frozen round record (ARCH-FUNERAL):** `s.rounds[ctx.round]` is cleared twice over: per-round on the normal path at `response_tools.lua:237`, and wholesale by `adapter.close()` (`:241-242`, `s.rounds={}`), which production reaches via `response_session.lua:46` (`if tools then tools.close() end`) — **not** via the `terminal` hook, which is `finish(result,false)` at `:189`; only the test harness wires `terminal=adapter.close` — `retire_reservation` was only ever the collector for the *reservation*, not the round record. Assert it in Task 2.2c's test rather than assuming.
- [ ] **Step 5: Green. Commit** — `#266 M2: append tool call and result pairs in declared order`

### Task 2.3: unresolved outcomes become transcript text

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

Both file and wire then agree the call produced no tool result; the `⏳:` line is history, not a result. Test both sides of the boundary explicitly — the after-continuation case is the *expected* one, since Task 2.1 Step 2 makes an unresolved outcome writable evidence rather than a stall.

Constraint: the marker must not parse as a tool block. `chat_parser.lua:833-852` opens a block on `🔧:`/`📎:` at depth 0, so any other prefix is safe — verify with a parse assertion rather than by inspection.

- [ ] **Step 1:** Sweep the interleavings of `{outcome₁, outcome₂, cancel, resolve}` — **24 permutations**, not the 8 at `response_tools_spec.lua:261` (a different 4-tuple). If a subset is used, state which and why.
- [ ] **Step 2: Run, fail.** `make test-spec SPEC=providers/tool_use`
- [ ] **Step 3:** Implement the unresolved rendering.
- [ ] **Step 4: Green**, plus `make test-spec SPEC=chat/exchange_model` — assert the unresolved marker does **not** become a `tool_result` block and that the synthesized dangling text appears instead.
- [ ] **Step 5: Batch-facing check (Done-when).** `batch.lua:91-94` latches `s.unknown` and `:99` refuses resume permanently on this outcome. Assert a batch survives an unresolved tool call now that it is recorded in the transcript. Run: `make test-spec SPEC=chat/batch`.
- [ ] **Step 6: Commit** — `#266 M2: record an unresolved tool outcome in the transcript`

### Task 2.4: keep concurrency visible

**Files:** `lua/parley/response_session.lua:100-101`
**Test:** `tests/integration/chat_pending_spec.lua`

There is no tool → pending edge today. Add one so both tools read as in flight while only call 1 is written.

**Correction to draft 1:** the progress line is *not* torn down by these writes — `response_session.lua:181` calls `s.pending:written` only for `receipt.kind=='output'`, and manual appends are `'append'`/`'replace'` (`generation_runner.lua:250`). No mitigation needed.

- [ ] **Step 1:** Failing test — two tools running, one written, assert both appear in flight.
- [ ] **Step 2: Run, fail.** `make test-spec SPEC=chat/response_progress`
- [ ] **Step 3:** Add the `session:progress{tool=…}` edge (`chat_pending.lua:160-165`; `chat_presentation.lua:58` already accepts `event.tool`).
- [ ] **Step 4: Green. Step 5: Commit** — `#266 M2: show concurrent tool progress in presentation`
### Task 2.5: end-to-end and wire shape

**Precondition: a clean working tree.** `scripts/refresh_goldens.lua` and 11 golden payloads are currently modified from `f1818ee1` (#218). Resolve that before this task or a real regression will be indistinguishable from pre-existing churn.

- [ ] `chat_async_tools_spec.lua:123` and `openai_tool_loop_spec.lua:167` should pass unchanged — both already assert declaration order on real buffer text.
- [ ] Regenerate goldens. Expect **no message-shape change**: `response_tools.lua:224-234` batches the live round regardless of buffer layout, and `tests/fixtures/transcripts/two-round-tool-use.md:11-26` is already interleaved with `build_messages_spec.lua:1189-1192` pinning the four-message shape. Any diff beyond key-order churn is a red flag.
- [ ] Commit.

### Task 2.6: atlas + milestone close

- [ ] Rewrite `atlas/providers/tool_use.md` (ordered child slots and reserved result slots are gone); record the accepted four-message resubmit shape.
- [ ] `make test` → exit 0. `sdlc milestone-close --issue 266 --milestone M2`

---

## Chunk 3 — M3: the residual exclusion sweep

What remains after M2 removes child grants: the geometry that only existed to carve them out of a parent.

### Task 3.1: remove parent-slot exclusion

**Files:** `lua/parley/document/state.lua` — `exclude` `:147-159`, carving `:237-241,252`, `'outside parent'`/`'parent'` `:226-236`, ancestor walk + `tail_lost` `:291-311`, `'delegated parent'` `:99-101`, `'active child'` `:265-268`; `lua/parley/document/init.lua:528-529`
**Tests:** `tests/unit/document_state_spec.lua:98-133`, `tests/unit/document_write_plan_spec.lua:144-159`, `tests/unit/document_append_spec.lua:100`

- [ ] One concern per commit, `make test` between each. Each removal deletes the tests that pinned it — record in `## Log` which invariant each deleted test was defending, so a later reader can tell deliberate removal from erosion.

### Task 3.2: remove the half-open flags — LAST

**Files:** `lua/parley/document/state.lua:32-45` (`open_first`/`open_last` in `overlaps`/`contains`/`writable`)

These exist solely to disambiguate excluded seams, but they thread through the same helpers M1's turn logic uses. Remove only after 3.1 is green, and run the full suite immediately.

- [ ] `make test` → exit 0. Commit `#266 M3: drop half-open seam handling with the last child grant`.

### Task 3.3: residual lifecycle cleanup

- [ ] Delete the fields with **zero readers** confirmed during the audit: `receipt.markers` (`response_tools.lua:66`), `children[i].call_block` and `children[i].result_slot` (`generation.lua:293`).
- [ ] **Add a test step** — this task had none in an earlier draft. Assert `grep -rn` finds no remaining reference to the removed symbols, and that `make test` is green.

### Task 3.4: close

- [ ] Final atlas sweep — no page may still describe reserved slots, child grants or capacity tickets.
- [ ] `make test` → exit 0, full output captured as close evidence (lint runs first; `workshop/lessons.md:792` records a close where green specs masked a red lint).
- [ ] `sdlc close --issue 266 --verified '<full make test output summary>'`

---

## Target reconciliation

`workshop/targets/transcript-is-the-whole-truth.md` says writes "land one at a time, in the order the reader sees them." Task 1.9 narrows that deliberately: **across** generations the guarantee is one-at-a-time and per-generation coherence, not document order, because generations write to different answers and admission order need not match document order. **Within** a tool round, document order does hold (Task 2.2c asserts it).

Second narrowing, from the `queue_empty` release rule: because the turn is released whenever a generation has nothing staged, another generation may interleave *between* chunks of an answer, and `Editor:observe` clears the undo receipt on any foreign write (`editor.lua:67`). So the issue Log's phrasing — "one undo entry per generation run" — is **not** guaranteed; what is guaranteed is Task 1.9's invariant, that no entry mixes two generations and none is a partial chunk. Correct the Log when M1 closes rather than leaving the stronger claim standing. Fold this narrowing into the target when M1 closes, so the target does not drift against the work defending it.

## Verified-correct facts this plan rests on

Recorded so they are not re-derived, and so a later reader can tell which claims were checked.

- **The `M.resolve` avoidance argument holds.** Its `reject(reason)` strings are consumed as control flow at `generation_runner.lua:275-276`, `document/init.lua:535-536` and `generation.lua:227-230`; a new `'waiting'` reason there would be read as revocation and reach `stop()`. The turn is therefore enforced in the runner, not in `resolve`.
- **The no-wire-change prediction for Task 2.5 is well-founded** — `response_tools.lua:224-234` batches the live round; the fixtures are already interleaved.
- **`generation.lua` line ranges** `32-39, 40-53, 84, 123/129/149, 162-164, 214-215, 186-376`; **`state.lua`** `182-357` and every M3 range; **`document/init.lua`** `312-319, 323-324, 432, 528-529, 535-536`; **`editor.lua`** `67, 194-202`; **`response_tools.lua`** `21-26, 36-68, 66, 137-182, 154-161, 183-187`; **`generation_runner.lua`** `47-65, 74-76, 157-167, 259, 323-443, 463-466`; all five atlas references; `response_provider.lua:88-90`; `lessons.md:792, 1280`.
- **Corrected from an earlier draft:** generation ids are bare integers, not `'g'..n` (`state.lua:6-7`); `M.new` is at `:64` and `M.snapshot` at `:72`, and `D.snapshot` (`init.lua:254`) is a bare passthrough needing no change; the branch-name guard is `single_source_sweeps_spec.lua:732-743` (regex at `:737`), not `:713`.
