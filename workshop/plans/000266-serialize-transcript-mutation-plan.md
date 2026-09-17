# Serialize Transcript Mutation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exactly one generation may mutate a transcript at a time, and a tool round appends `(call, result)` pairs in call order, so the buffer's undo history is a sequence of coherent units instead of interleaved 4 KiB chunks.

**Architecture:** A **write turn** owned by the document's pure reducer (`document/state.lua`), surfaced through `D.snapshot`, and enforced at `generation_runner.lua`'s `write()` / `replace()` — the one seam every generated mutation passes through, since `execute` routes `write`, `manual_append` and `manual_replace` to those two functions (`:357-358`). Both already return `true,'waiting'` for a suspended grant (`:269`, `:303`), so the turn reuses an existing retry protocol rather than inventing one. The pure machine additionally gates `writable` so a turnless generation stops staging early, but the runner seam is authoritative. Tool rounds drop placeholder reservation, capacity tickets and child grants in favour of monotonic appends at the parent grant's tail, sequenced by a new pure `ToolSequence`. Tool and provider **execution** concurrency is untouched; only mutation serializes.

**Why not `writable` alone:** `mutation()` (`generation_runner.lua:95-118`) — the path behind `ctx.append`/`ctx.replace`, and therefore behind *all* of M2's tool insertion plus `response_preparation.lua:90,101,108` and `response_completion.lua:63,71` — never consults the machine. Gating only `pump`'s `writable` (`generation.lua:107-116`) would leave tool rounds, preparation gaps and completion prefixes unserialized.

**Why a wake path is mandatory:** `notify()` fires only on `edit`/`reload`/`detach`/`repair` (`document/init.lua:206,223,232,381,402`), and a runner's `Deferred` re-arms only while `step` returns `'more'` (`deferred_work.lua:11-24`). A generation holding output emits no effects, so its timer stops; releasing the turn elsewhere produces no notification and it would sleep forever. Task 1.3 adds `notify(s,{kind='turn'})`.

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim 0.11 buffer API, plenary busted (`make test`).

**Issue:** parley#266 · **Target:** `workshop/targets/transcript-is-the-whole-truth.md` · **Blocks:** parley#261

**Branch:** must be `000266-serialize-transcript-mutation`. `tests/arch/single_source_sweeps_spec.lua:713` only enforces "every spec this branch added is routed in `atlas/traceability.yaml`" when the branch matches `^%d%d%d%d%d%d%-`; any other name silently downgrades that guard to `pending`.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `WriteTurn` | `lua/parley/document/write_turn.lua` | new |
| `ToolSequence` | `lua/parley/tools/sequence.lua` | new |
| `DocumentState` | `lua/parley/document/state.lua` | modified |
| `GenerationMachine` | `lua/parley/generation.lua` | modified |

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

- **DocumentState** (modified) — gains `s.turn` plus `request_turn` / `release_turn` events; `M.snapshot` exposes `turn`. `writable`/`resolve` are **not** changed, deliberately: `M.resolve`'s `reject(reason)` strings are consumed as control flow at `generation_runner.lua:275-276`, `document/init.lua:535-536` and `generation.lua:227-230`, and a new reason there would be misread as revocation.

- **GenerationMachine** (modified) — gains `s.has_turn`; `writable` (`generation.lua:32-39`) requires it; emits `request_turn` on start/resume and `release_turn` on pause, stop and terminal.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `DocumentCoordinator` | `lua/parley/document/init.lua` | modified | reducer event whitelist + snapshot |
| `GenerationRunner` | `lua/parley/generation_runner.lua` | modified | turn polling + turn effects |
| `ToolAdapter` | `lua/parley/response_tools.lua` | modified | append-only round insertion |
| `TopicGeneration` | `lua/parley/response_topic.lua` | modified | the `D.apply` path that bypasses the runner |
| `PendingProgress` | `lua/parley/response_session.lua` | modified | tool → `chat_pending` progress edge |

- **DocumentCoordinator** — adds `request_turn`/`release_turn` to the whitelist at `document/init.lua:323-324` and `turn` to the snapshot.
  - **Injected into:** nothing; it is the seam every writer already calls.
  - **Note:** `tests/arch/document_ownership_spec.lua:76,82` enumerates the allowed mutation surface and the coordinator event whitelist. It will fail; updating it is a deliberate step, not incidental.

- **GenerationRunner** — `sync(s)` (`:47-65`) already polls `D.snapshot(s.doc).grants`; it also reads `snapshot.turn` and dispatches a `turn` event into the machine. `execute` gains handlers for the two new effects.
  - **Injected into:** `GenerationMachine`, via the existing dispatch path.

- **ToolAdapter** — `reserve_round` becomes `begin_round` (declare calls, write nothing); a pump driven by `ToolSequence` appends each block via `ctx.append`.
  - **Injected into:** the generation machine through the existing `hooks` table (`response_session.lua:174`).

- **TopicGeneration** — registers a second generation and writes via `D.apply` (`response_topic.lua:141-147,165-166`), bypassing `generation_runner` entirely. It must take the turn like any other writer.

- **PendingProgress** — there is **no tool → pending edge today** (`response_session.lua:100-101` feeds only provider stream progress). M2 adds one so concurrent tool execution stays visible once the transcript no longer lists every call upfront.

### ARCH-MOCK

`N/A` — this issue adds no external binary or service dependency. All doubles already exist and are reused: `tests/helpers/fake_generation_runner.lua`, `tests/helpers/fake_document_editor.lua`, the inline `producer` table at `tests/integration/response_tools_spec.lua:12-16`, and `tests/helpers/fake_process.lua` for the end-to-end path.

### What is deliberately NOT changed

Execution concurrency: `generation.lua:84` fan-out cap of 4, `tools/resources.lua:82-90` admission (`running<16`, `per_document<8`, `per_generation<4`), `tasker.lua:20-21` attempt ceilings, and the path-scoped claims in `tools/async_builtin.lua:248-267`. Human edits via `apply_user` (`document/init.lua:432`) are **never** subject to the turn — the guarantee is ordering between generations, not absolute.

---

## Chunk 1 — M1: the write turn

**Routing rule for every task below.** `make test-spec SPEC=<key>` runs only files listed under that key in `atlas/traceability.yaml` (`Makefile.parley:113-129` → `scripts/spec_test_map.sh list-tests`). A new spec that is not routed is silently **not run**, so a "watch it fail" step would print green. Every task that creates a spec routes it in the *same* task, before the red step. Existing keys: `tests/unit/generation_spec.lua` → `chat/lifecycle` (traceability:194); `tests/unit/document_state_spec.lua` → `chat/document` (:307); `tests/integration/response_tools_spec.lua` → `chat/exchange_model` (:201) and `providers/tool_use` (:878).

### Task 1.1: `WriteTurn` pure entity

**Files:**
- Create: `lua/parley/document/write_turn.lua`
- Test: `tests/unit/document_write_turn_spec.lua`
- Modify: `atlas/traceability.yaml` (add the spec under `chat/document` `tests:`, and `lua/parley/document/write_turn.lua` under its `code:`)

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

In `finish_generation` (`:344-352`) call `retune(s,event.generation)` after the existing cleanup. In the shared `reload`/`detach` branch (`:353-356`) add `s.turn,s.turn_wanted=nil,{}`. `M.snapshot` at `:72` is `copy(state(doc))`, so `turn` is carried automatically — no change needed there.

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
- [ ] **Step 5: Commit** — `#266 M1: notify subscribers when the write turn moves`

### Task 1.4: enforce the turn at the single write seam

**Files:**
- Modify: `lua/parley/generation_runner.lua` — `write()` `:259-290`, `replace()` `:291-322`, `sync()` `:47-65`
- Test: `tests/integration/generation_turn_spec.lua` (new), routed under `chat/ownership`

**This is the load-bearing task.** `execute` routes `write`, `manual_append` and `manual_replace` through these two functions (`:357-358`), so one check covers provider output, tool insertion, preparation gaps and completion prefixes. Both functions already have the retry precedent — `:269` `elseif grant.status=='suspended' then return true,'waiting'` and `:303` — and `M.step` already understands it (`:454-455` stores `s.pending` and reports `'waiting'`).

- [ ] **Step 1: Route the spec, then write the failing test.** Assert that while generation `a` holds the turn, a `ctx.append` issued by `b` commits zero bytes, and that it lands in full once `a` terminates.

- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL — `b` commits its bytes immediately; asserted `0`, got the full length.

- [ ] **Step 3: Implement.** Cache the turn on `sync` (`s.has_turn = D.snapshot(s.doc).turn == s.generation`). In both `write` and `replace`, immediately after the `grant.status=='suspended'` arm, add:

```lua
    elseif not s.has_turn then return true,'waiting'
```

Order matters: it must sit **after** the `not grant or grant.status=='revoked' or generation.phase=='stopping'` arm so a stopping generation still drains rather than parking forever.

- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: gate every generated write on the document turn`

### Task 1.5: stop staging early in the pure machine

**Files:**
- Modify: `lua/parley/generation.lua` — `writable` `:32-39`, initial state `:167`, `M.transition` `:186-376`
- Test: `tests/unit/generation_spec.lua` (routed under `chat/lifecycle`, traceability:194)

Task 1.4 makes the behavior correct; this makes it cheap, by not emitting `write` effects that will only park. It is an optimization, not the enforcement point.

- [ ] **Step 1: Failing test** — with `has_turn=false`, an `output` event must leave `effect(r,'write')` nil; after a `turn` event with `held=true`, it must appear.
- [ ] **Step 2: Run, watch it fail.**
  Run: `make test-spec SPEC=chat/lifecycle`
  Expected: FAIL — a `write` effect is emitted while turnless.
- [ ] **Step 3: Implement.** Add `s.has_turn=false` at `:167`; add `if not s.has_turn then return false end` as the first condition of `writable`; add a `turn` event branch setting `s.has_turn=event.held` then calling `pump`. Dispatch it from `sync` in the runner when the cached value changes.

  **Do not change** `staged(s)` (`:23-27`) or the `bytes==0` gates at `:123`, `:129`, `:149`. A generation whose bytes have not landed genuinely must not continue its round or finalize. Starvation is answered by Task 1.6's release rules, not by weakening these.
- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: avoid staging writes a turnless generation cannot perform`

### Task 1.6: release rules — every way a holder can stop writing

**Files:**
- Modify: `lua/parley/generation.lua` (`stop` `:40-53`, pause paths `:60`, `:332-334`, `:342`, resume `:343-345`, terminal `:98`, `:154`), `lua/parley/generation_runner.lua` (`sync` `:47-65`)
- Test: `tests/integration/generation_turn_spec.lua`

**The policy, stated once.** The turn is a **lease over a generation's run**, not a lock around each write — that is what produces one undo entry per run rather than per chunk. It is therefore held across an ordinary mid-stream wait for more provider bytes, which is bounded by the stream. It is released whenever the holder cannot write for an *unbounded* time. That set is closed and enumerable:

| Release trigger | Where |
|---|---|
| `terminal` (any outcome) | `generation.lua:98`, `:154` — already frees the slot at `generation_runner.lua:436` |
| `stop` / `phase=='stopping'` | `generation.lua:40-53` |
| pause on unknown child outcome | `generation.lua:332-334` |
| pause on `revoke_child` | `generation.lua:60` |
| pause on stale input | `generation.lua:342` |
| **grant suspended** (structural uncertainty while a human types) | observed in `sync`, `generation_runner.lua:55-61`; reachable from `write_result` `:246-248` and `round_reservation_failed` `:303` — **not a pause**, and missed by an earlier draft |
| **head-of-line `'waiting'` that is not the turn** — e.g. the `reclaim_tail` `'unconfirmed identity'` retry at `generation_runner.lua:347-352`, which deliberately does not pause | runner |
| **provider unresolved past the existing 5000 ms deadline** (`tools/operation.lua:114`) | reuse that signal; do **not** add a new clock |
| `detach` / `reload` | `state.lua:353-356` clears it unconditionally |

`resume_validated` (`generation.lua:343-345`) re-requests the turn and re-queues **behind** the current holder (Task 1.2's third test pins that).

**Release must not strand an in-flight write.** `pump` emits the `write` effect and sets `s.inflight` (`:111-113`); the effect then sits in the runner queue until `M.step`. `write()` re-checks grant status and `phase=='stopping'` but not pause, so a paused generation's already-queued write would still execute *after* its successor had written. Release is therefore conditional on `s.inflight==nil`; when a write is in flight, mark the intent and release on the next `write_result`.

- [ ] **Step 1: Write the matrix** — one case per row above, each asserting a waiting generation acquires the turn and completes. Parameterise the interleaving rather than using the fixed round-robin at `generation_sequences_spec.lua:48`; follow the cartesian-sweep idiom at `response_tools_spec.lua:261`:

```lua
local schedules={{'a','a','b','b'},{'a','b','a','b'},{'b','a','b','a'},{'b','b','a','a'}}
for _,trigger in ipairs({'terminal','stop','pause_unknown','pause_revoke','pause_stale',
                         'suspend','waiting_head_of_line','provider_unresolved','detach','reload'}) do
  for _,schedule in ipairs(schedules) do
    it('releases the turn on '..trigger..' under '..table.concat(schedule,','),function()
```

- [ ] **Step 2: Run.**
  Run: `make test-spec SPEC=chat/ownership`
  Expected: FAIL for `suspend`, `waiting_head_of_line` and `provider_unresolved` at minimum — those three have no release path before this task.
- [ ] **Step 3: Implement** the missing releases plus the `s.inflight` guard.
- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: release the turn on every unbounded block`

### Task 1.7: bound held output honestly (ARCH-CONSTRAINTS)

**Files:**
- Modify: `lua/parley/generation_runner.lua:157-167` (the `cb.output` refusal message)
- Test: `tests/integration/generation_sequences_spec.lua`

**What is actually bounded.** A held generation cannot continue its round or finalize (`generation.lua:123`, `:129`, `:149` all gate on `bytes==0`), so it can accumulate **at most one provider response** no matter how long the chain ahead of it runs. Held bytes are therefore bounded by maximum response size, not by wait duration.

**Budget: unchanged — 1 MiB per generation (`generation_runner.lua:463-464`), 16 MiB process-wide (`:75`).** *Basis:* derived from the paragraph above, not chosen. An earlier draft of this plan proposed raising it to 4 MiB on "operator choice"; that was the plan inventing a number and attributing it. It is also arithmetically bad — `state.lua:190` admits 4 generations per document, so 4 × 4 MiB is the entire process ceiling.

**Behavior at the bound: unchanged — the generation is cancelled.** `cb.output` returning anything but `true` reaches `response_provider.lua:88-90` and stops the transport; there is no backpressure on an SSE stream, so the only alternative would be to return `true` and silently discard provider bytes, which violates the target this issue serves. What changes is the *message*: `issue(s,...)` must name the exchange holding the turn, so the user knows what to stop.

- [ ] **Step 1: Test** with `limits={staged_bytes=8,queued_items=4}` (precedent at `generation_sequences_spec.lua:68`): hold the turn elsewhere, push past 8 bytes, assert the generation stops **and** that the surfaced message names the blocking exchange.
- [ ] **Step 2: Run, fail** (message assertion).
- [ ] **Step 3:** Thread the blocking exchange into the message.
- [ ] **Step 4: Green.**
- [ ] **Step 5:** Add a test proving the derivation: a held generation that has received one complete provider response stages no further bytes.
- [ ] **Step 6: Commit** — `#266 M1: name the blocking exchange when held output overflows`

### Task 1.8: the writers that bypass the runner

**Files:**
- Modify: `lua/parley/response_topic.lua:141-147,165-166`
- Verify only: `lua/parley/response_preparation.lua:90,101,108`, `lua/parley/response_completion.lua:55-58,63,71`
- Test: `tests/integration/response_topic_spec.lua`

`response_preparation` and `response_completion` reach the document through `ctx.append`/`ctx.replace`, so Task 1.4 already covers them — **confirm this with a test rather than assuming it**; `response_completion.lua:55-58` acquires a *fresh grant*, which is the case most likely to slip through. `response_topic` is different: it registers a second generation and calls `D.apply` directly, bypassing the runner entirely.

- [ ] **Step 1:** Test that automatic topic generation does not write while another generation holds the turn, and a second test that a completion prefix does not either.
- [ ] **Step 2: Run, fail** (topic case at minimum).
- [ ] **Step 3:** Take the turn around `response_topic`'s `D.apply`.
- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: route topic and completion writes through the turn`

### Task 1.9: undo coherence

**Files:**
- Test: `tests/integration/chat_scoped_response_spec.lua:47` (invert), `tests/integration/generation_turn_spec.lua`

**What to assert, and what not to.** Not "undo steps == generation runs": `can_join_undo` keys on `(epoch,generation,grant)` (`editor.lua:196-200`) and a single run legitimately writes through preparation grants (`generation_runner.lua:488-492`) *and* a completion-acquired grant (`response_completion.lua:55-58`), so a run spans several grants and therefore several undo entries. Not "backwards in document position" either — generations write to different answers, so regenerating Q3 then Q1 writes Q3's region first.

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

- [ ] Rewrite `atlas/chat/ownership.md:8-9` — "Disjoint generations may write separate answers" is now false. Also `atlas/chat/lifecycle.md:266-267`, `atlas/providers/architecture.md:29`, `atlas/chat/inline_branch_links.md:76`, `atlas/chat/response_progress.md:56`.
- [ ] Confirm every spec added in Chunk 1 is routed and every new `lua/` file is in the right `code:` list.
- [ ] `make test` → exit 0 (lint runs first).
- [ ] `sdlc milestone-close --issue 266 --milestone M1`

---

## Chunk 2 — M2: ordered append, and the machinery it replaces

**Boundary correction.** An earlier draft deferred child-grant removal to M3 and had M2 rewrite `response_tools.lua` alone. That is impossible: `round_reserved` requires `#event.grants==#round.children`, each identity-valid, distinct and ≠ parent (`generation.lua:306-315`). A `begin_round` that acquires no child grants yields `done(nil)` → `round_reservation_failed` → `stop(s,effects,'reservation_failed')` (`:304`). Switching to ordered append and removing the reservation lifecycle are **one change** and land together.

### Task 2.1: `ToolSequence` pure entity

**Files:**
- Create: `lua/parley/tools/sequence.lua`
- Test: `tests/unit/tools_sequence_spec.lua`
- Modify: `atlas/traceability.yaml` — route under `providers/tool_use`

- [ ] **Step 1: Route the spec.**
- [ ] **Step 2: Failing test** (as drafted previously — `Seq.new/next/outcome/written/complete`, covering: first call offered; a later outcome cannot skip ahead; declared-order drain once the earlier outcome lands; an unresolved outcome is writable evidence, not a stall).
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use` → `provides the module` false.
- [ ] **Step 4: Implement** as a pure immutable record.
- [ ] **Step 5: Green. Commit** — `#266 M2: add the pure tool insertion sequence`

### Task 2.2: replace the reservation lifecycle with ordered append

**Files:**
- Modify: `lua/parley/response_tools.lua` — rewrite `:137-182` as `begin_round`; delete `:21-26`, `:36-68`, `:154-161`, `:183-187`; rewrite `tool_outcome` `:77-102` to append
- Modify: `lua/parley/generation.lua:131-134` (`reserve_round` emission), `:289-316` (`round_reservation_failed` / `round_reserved`), `:54-72` (`child_by_grant`/`revoke_child`), the child branch of `writable` `:32-39`, `write_result` `:234-249`
- Modify: `lua/parley/generation_runner.lua:98` (**the `effect.type~='reserve_round'` liveness exemption in `mutation` — silently breaks if the effect is renamed**), `:329-354`, `:382-389`, `:404-434`
- Modify: `lua/parley/response_session.lua:174` (hook table)
- Modify: `lua/parley/document/state.lua:170-180,199-212,253-256` + `lua/parley/document/init.lua:312-319` — remove capacity tickets
- Delete: `tests/unit/document_capacity_spec.lua`, and its entry in `atlas/traceability.yaml:325` (`single_source_sweeps_spec.lua:723` fails on a named path that no longer exists)

- [ ] **Step 1: Invert the pinning test** at `tests/integration/response_tools_spec.lua:141` → `'writes each call block immediately before its own result'`, asserting `ca<ra and ra<cb and cb<rb`, no `(Tool result pending)` anywhere, and both producers still started (execution stays concurrent).
- [ ] **Step 2:** Add a **bounded-step** variant. `f.drain()` runs to quiescence (`:37-42`) and cannot exercise "call 2's block written while result 1's multi-chunk write is mid-flight" (4096-byte slices, `generation_runner.lua:265`). Add a `step(n)` helper that pumps a fixed number of times.
- [ ] **Step 3: Run, fail.** `make test-spec SPEC=providers/tool_use`.
- [ ] **Step 4: Implement.** `begin_round` freezes `s.rounds[ctx.round]`, builds a `ToolSequence`, writes nothing, takes no ticket. A pump appends `Serialize.render_call` / `render_result` output at the parent grant tail via `ctx.append`, one item per `adapter.step()`, driven by `Seq.next`. Remove the now-unsatisfiable `round_reserved` contract rather than trying to satisfy it.
- [ ] **Step 5: Green. Commit** — `#266 M2: append tool call and result pairs in declared order`

### Task 2.3: unresolved outcomes become transcript text

**Files:** `lua/parley/response_tools.lua`, `lua/parley/tools/serialize.lua`; test `tests/integration/response_tools_spec.lua`

**Decision (from the target):** an unknown outcome is rendered into the transcript and the sequence continues, instead of being hidden state that blocks (`generation.lua:332-334` pauses; `batch.lua:99` refuses resume permanently).

- [ ] **Step 1:** Sweep the interleavings of the four events `{outcome₁, outcome₂, cancel, resolve}`. That is **24 permutations**, not the 8 used at `response_tools_spec.lua:261` — that sweep covers a different 4-tuple. Either enumerate all 24 or state which subset and why.
- [ ] **Steps 2–5:** Red → implement → green → commit `#266 M2: record an unresolved tool outcome in the transcript`

### Task 2.4: keep concurrency visible

**Files:** `lua/parley/response_session.lua:100-101`; test `tests/integration/chat_pending_spec.lua`

There is no tool → pending edge today. Add one so both tools read as in flight while only call 1 is written.

**Correction:** an earlier draft warned the progress line would be torn down by write receipts. It would not — `response_session.lua:181` calls `s.pending:written` only for `receipt.kind=='output'`, and manual appends are `'append'`/`'replace'` (`generation_runner.lua:250`). No mitigation needed.

- [ ] Red → add the `session:progress{tool=…}` edge (`chat_pending.lua:160-165`; `chat_presentation.lua:58` already accepts `event.tool`) → green → commit.

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

## Verified-correct facts this plan rests on

Recorded so they are not re-derived, and so a later reader can tell which claims were checked.

- **The `M.resolve` avoidance argument holds.** Its `reject(reason)` strings are consumed as control flow at `generation_runner.lua:275-276`, `document/init.lua:535-536` and `generation.lua:227-230`; a new `'waiting'` reason there would be read as revocation and reach `stop()`. The turn is therefore enforced in the runner, not in `resolve`.
- **The no-wire-change prediction for Task 2.5 is well-founded** — `response_tools.lua:224-234` batches the live round; the fixtures are already interleaved.
- **`generation.lua` line ranges** `32-39, 40-53, 84, 123/129/149, 162-164, 214-215, 186-376`; **`state.lua`** `182-357` and every M3 range; **`document/init.lua`** `312-319, 323-324, 432, 528-529, 535-536`; **`editor.lua`** `67, 194-202`; **`response_tools.lua`** `21-26, 36-68, 66, 137-182, 154-161, 183-187`; **`generation_runner.lua`** `47-65, 74-76, 157-167, 259, 323-443, 463-466`; all five atlas references; `response_provider.lua:88-90`; `lessons.md:792, 1280`.
- **Corrected from an earlier draft:** generation ids are bare integers, not `'g'..n` (`state.lua:6-7`); `M.new` is at `:64` and `M.snapshot` at `:72`, and `D.snapshot` (`init.lua:254`) is a bare passthrough needing no change; the branch-name guard is `single_source_sweeps_spec.lua:732-743` (regex at `:737`), not `:713`.
