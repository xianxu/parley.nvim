# Serialize Transcript Mutation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exactly one generation may mutate a transcript at a time, and a tool round appends `(call, result)` pairs in call order, so the buffer's undo history is a sequence of coherent units instead of interleaved 4 KiB chunks.

**Architecture:** A **write turn** owned by the document's pure reducer (`document/state.lua`), surfaced through `D.snapshot`, and consumed by the pure generation machine as a new condition on `writable`. A generation without the turn keeps its output in the queue it already has — no new buffer. Tool rounds drop placeholder reservation, capacity tickets and child grants in favour of monotonic appends at the parent grant's tail, sequenced by a new pure `ToolSequence`. Tool and provider **execution** concurrency is untouched; only mutation serializes.

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

- **WriteTurn** — pure decision function: given the generation records and which are eligible to write, return the id that holds the turn. Eligibility order is ascending `gid`, which `state.lua:6-7 id()` already makes monotone by admission, so no separate sequence number is needed.
  - **Relationships:** 1:1 with a document (one turn per document); N:1 with generations (many generations, one holder).
  - **DRY rationale:** First occurrence of a pattern that recurs — M2's tool sequencing is the same "ordered set, one may act" shape, but over calls rather than generations. Kept separate because the eligibility predicates genuinely differ; `ToolSequence` does not reuse this.
  - **Future extensions:** Priority other than admission order (e.g. the focused exchange first) widens the eligibility predicate without changing callers.
  - **Tests:** `tests/unit/document_write_turn_spec.lua`, no IO.

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

### What is deliberately NOT changed

Execution concurrency: `generation.lua:84` fan-out cap of 4, `tools/resources.lua:82-90` admission (`running<16`, `per_document<8`, `per_generation<4`), `tasker.lua:20-21` attempt ceilings, and the path-scoped claims in `tools/async_builtin.lua:248-267`. Human edits via `apply_user` (`document/init.lua:432`) are **never** subject to the turn — the guarantee is ordering between generations, not absolute.

---

## Chunk 1 — M1: the generation write turn

### Task 1.1: `WriteTurn` pure entity

**Files:**
- Create: `lua/parley/document/write_turn.lua`
- Test: `tests/unit/document_write_turn_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
local ok,W=pcall(require,'parley.document.write_turn')
describe('write turn',function()
    it('provides the module',function()assert.is_true(ok)end)
    if not ok then return end
    it('grants the turn to the lowest eligible generation id',function()
        assert.equals('g2',W.holder({g5={eligible=true},g2={eligible=true}},nil))
    end)
    it('keeps an existing holder while it stays eligible',function()
        assert.equals('g5',W.holder({g5={eligible=true},g2={eligible=true}},'g5'))
    end)
    it('reassigns when the holder stops being eligible',function()
        assert.equals('g2',W.holder({g5={eligible=false},g2={eligible=true}},'g5'))
    end)
    it('reassigns when the holder is gone',function()
        assert.equals('g2',W.holder({g2={eligible=true}},'g5'))
    end)
    it('returns nil when nothing is eligible',function()
        assert.is_nil(W.holder({g2={eligible=false}},nil))
        assert.is_nil(W.holder({},'g5'))
    end)
end)
```

Ordering note: ids come from `state.lua:6-7 id()` as `'g'..serial`, so string compare is wrong past `g9`. `holder` must compare the numeric suffix. Add the case:

```lua
    it('orders numerically, not lexically',function()
        assert.equals('g9',W.holder({g10={eligible=true},g9={eligible=true}},nil))
    end)
```

- [ ] **Step 2: Run it and watch it fail**

`make test-spec SPEC=chat/document` → FAIL, `module 'parley.document.write_turn' not found`.

- [ ] **Step 3: Minimal implementation**

```lua
-- Pure write-turn decision. One generation may mutate a document at a time;
-- eligibility order is admission order, which state.lua's monotone id() already
-- encodes in the numeric suffix.
local M={}
local function rank(id)return tonumber(tostring(id):match('(%d+)$')) or math.huge end
--- @param generations table  map of id -> {eligible=boolean}
--- @param current string|nil currently held id
--- @return string|nil
function M.holder(generations,current)
    if current then
        local held=generations[current]
        if held and held.eligible then return current end
    end
    local best
    for id,record in pairs(generations) do
        if record.eligible and (not best or rank(id)<rank(best)) then best=id end
    end
    return best
end
return M
```

- [ ] **Step 4: Run and verify green**
- [ ] **Step 5: Commit** — `#266 M1: add the pure write-turn decision`

### Task 1.2: turn state in the reducer

**Files:**
- Modify: `lua/parley/document/state.lua` (`M.new` ~`:60`, `M.transition` `:182-357`, `M.snapshot` `:68`)
- Test: `tests/unit/document_state_spec.lua`

- [ ] **Step 1: Failing test** — append to `tests/unit/document_state_spec.lua`:

```lua
    it('serializes the write turn by admission order and releases it on finish',function()
        local d=S.new()
        local a=S.transition(d,{kind='register_generation',epoch=1}).generation
        local b=S.transition(d,{kind='register_generation',epoch=1}).generation
        assert.is_nil(S.snapshot(d).turn)
        assert.is_true(S.transition(d,{kind='request_turn',epoch=1,generation=a}).ok)
        assert.equals(a,S.snapshot(d).turn)
        assert.is_true(S.transition(d,{kind='request_turn',epoch=1,generation=b}).ok)
        assert.equals(a,S.snapshot(d).turn,'a keeps the turn while eligible')
        S.transition(d,{kind='finish_generation',epoch=1,generation=a})
        assert.equals(b,S.snapshot(d).turn,'turn passes to the next admitted')
    end)
    it('releases the turn on pause so a paused holder cannot starve the queue',function()
        local d=S.new()
        local a=S.transition(d,{kind='register_generation',epoch=1}).generation
        local b=S.transition(d,{kind='register_generation',epoch=1}).generation
        S.transition(d,{kind='request_turn',epoch=1,generation=a})
        S.transition(d,{kind='request_turn',epoch=1,generation=b})
        S.transition(d,{kind='release_turn',epoch=1,generation=a})
        assert.equals(b,S.snapshot(d).turn)
    end)
    it('clears the turn on reload and detach',function()
        local d=S.new()
        local a=S.transition(d,{kind='register_generation',epoch=1}).generation
        S.transition(d,{kind='request_turn',epoch=1,generation=a})
        S.transition(d,{kind='reload',epoch=1})
        assert.is_nil(S.snapshot(d).turn)
    end)
```

- [ ] **Step 2: Run, watch it fail** — `make test-spec SPEC=chat/document`, expect `unknown event`.

- [ ] **Step 3: Implement.** In `M.new`, add `turn=nil, turn_wanted={}`. Add two branches to `M.transition` before the `else` at `:357`:

```lua
    elseif kind=='request_turn' then
        if not s.generations[event.generation] then return reject('generation') end
        s.turn_wanted[event.generation]=true
        s.turn=WriteTurn.holder(eligibility(s),s.turn)
        result.turn=s.turn
    elseif kind=='release_turn' then
        if not s.generations[event.generation] then return reject('generation') end
        s.turn_wanted[event.generation]=nil
        s.turn=WriteTurn.holder(eligibility(s),s.turn~=event.generation and s.turn or nil)
        result.turn=s.turn
```

with a local helper next to `capacity_used`:

```lua
local function eligibility(s)
    local out={}
    for id in pairs(s.generations) do out[id]={eligible=s.turn_wanted[id]==true} end
    return out
end
```

`finish_generation` (`:344-352`) additionally does `s.turn_wanted[event.generation]=nil` and recomputes; the shared `reload`/`detach` branch (`:353-356`) sets `s.turn,s.turn_wanted=nil,{}`. `M.snapshot` (`:68`) gains `turn=s.turn`.

- [ ] **Step 4: Run and verify green.**
- [ ] **Step 5: Commit** — `#266 M1: hold a write turn in the document reducer`

### Task 1.3: expose the events and snapshot field through the coordinator

**Files:**
- Modify: `lua/parley/document/init.lua:320-324` (whitelist), snapshot passthrough
- Modify: `tests/arch/document_ownership_spec.lua:76,82`

- [ ] **Step 1:** Extend the whitelist to include `request_turn` and `release_turn`.
- [ ] **Step 2:** Run `make test-spec SPEC=chat/ownership`. `tests/arch/document_ownership_spec.lua` FAILS — it enumerates the allowed coordinator events. This failure is expected and correct: the fitness function is reporting a deliberate surface change.
- [ ] **Step 3:** Update the arch spec's expected sets to include the two events, with a comment naming #266.
- [ ] **Step 4:** Green.
- [ ] **Step 5: Commit** — `#266 M1: admit turn events at the coordinator seam`

### Task 1.4: `has_turn` in the pure machine

**Files:**
- Modify: `lua/parley/generation.lua` (`writable` `:32-39`, `M.transition` `:186-376`, `stop` `:40-53`, pause `:332-334`)
- Test: `tests/unit/generation_spec.lua`

- [ ] **Step 1: Failing test**

```lua
    it('queues output while another generation holds the write turn',function()
        local r=start()                      -- existing helper
        transition(r,{type='turn',held=false})
        transition(r,{type='output',seq=1,bytes=8,blob_ref='b1',operation=one})
        assert.is_nil(effect(r,'write'),'must not write without the turn')
        transition(r,{type='turn',held=true})
        assert.is_not_nil(effect(r,'write'),'writes as soon as the turn arrives')
    end)
    it('releases the turn when it pauses and requests it again on resume',function()
        local r=start()
        transition(r,{type='turn',held=true})
        transition(r,{type='child_outcome',outcome='unknown',...})
        assert.is_not_nil(effect(r,'release_turn'))
        transition(r,{type='resume_validated'})
        assert.is_not_nil(effect(r,'request_turn'))
    end)
```

- [ ] **Step 2: Run, watch it fail.**
- [ ] **Step 3: Implement.** Add `s.has_turn=false` to the initial state (`:167`). In `writable(s,grant)` add `if not s.has_turn then return false end` as the first condition. Add a `turn` event branch setting `s.has_turn=event.held` and calling `pump`. Emit `request_turn` from `start` and from `resume_validated`; emit `release_turn` from `stop` (`:40-53`), from the pause paths (`:60`, `:332-334`, `:342`) and alongside `terminal` (`:98`, `:154`).

**Do not change** `staged(s)` (`:23-27`) or the `bytes==0` gates at `:123`, `:129`, `:149`. A generation holding output legitimately has not finished writing and must not continue its round or finalize. The starvation risk those gates create is answered by *releasing the turn on pause*, not by weakening them. Task 1.6 tests exactly that.

- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: gate generation writes on the document turn`

### Task 1.5: wire the runner

**Files:**
- Modify: `lua/parley/generation_runner.lua` (`sync` `:47-65`, `execute` `:323-443`)
- Test: `tests/integration/generation_sequences_spec.lua`

- [ ] **Step 1: Failing test** — rewrite `:43-54` `'keeps disjoint writers independent…'` as `'serializes disjoint writers and preserves each writer's bytes'`: same two-runner setup, but assert that while `a` holds the turn `b` commits **zero** bytes, and that after `a` reaches terminal `b` drains to its full `committed_bytes`.
- [ ] **Step 2: Run, fail.**
- [ ] **Step 3: Implement.** In `sync`, read `snap.turn` and dispatch `{type='turn',held=snap.turn==s.generation}` when it changes. In `execute`, handle `request_turn`/`release_turn` by calling `D.transition(s.doc,{kind=...,generation=s.generation,epoch=s.epoch})`.
- [ ] **Step 4: Green.**
- [ ] **Step 5: Commit** — `#266 M1: poll and drive the write turn from the runner`

### Task 1.6: starvation and lifecycle invariants (ARCH-ORDER)

**Files:**
- Test: `tests/integration/generation_turn_spec.lua` (new)

- [ ] **Step 1:** Write the matrix. For each way a turn holder can stop being able to write — `terminal(success)`, `terminal(cancelled)`, `pause(unknown child outcome)`, `pause(grant revoked by human edit)`, `detach`, `reload` — assert a waiting generation acquires the turn and completes. Use the synchronous pump (`Runner.step`/`Runner.drain`, `schedule=false`); no `vim.wait`.
- [ ] **Step 2:** Run — expect failures for whichever release path is missing.
- [ ] **Step 3:** Fix the release paths found.
- [ ] **Step 4:** Green.
- [ ] **Step 5: Commit** — `#266 M1: prove no release path starves the turn queue`

### Task 1.7: held-output budget (ARCH-CONSTRAINTS)

**Files:**
- Modify: `lua/parley/generation.lua:162-164,214-215`, `lua/parley/generation_runner.lua:74-76,463-466,157-167`
- Test: `tests/integration/generation_sequences_spec.lua`

**The problem.** A generation without the turn keeps consuming provider bytes into `s.queue`. Today exceeding `staged_bytes` calls `stop(s,effects,'overflow')` and `generation_runner.lua:160` kills the provider process via `response_provider.lua:88-90`. For a *queued* writer that is wrong: it destroys work for a reason the user cannot see or act on.

**Budget:** per-generation held bytes **4 MiB** (raised from 1 MiB), process-wide **16 MiB** (unchanged). *Basis:* operator choice, sized so an ordinary answer never approaches it while a long tool chain ahead of it completes; 1 MiB is the current default and answers are typically far below it, so 4× buys the wait without changing the process ceiling. **Behavior at the bound:** pause the generation with an actionable message naming the blocking exchange, retain what was written, and do **not** kill the provider. Recovery is `:ParleyStop` on the blocking generation, or waiting.

- [ ] **Step 1:** Test with `limits={staged_bytes=8,queued_items=4}` (the precedent at `generation_sequences_spec.lua:68`): hold the turn elsewhere, push past 8 bytes, assert `phase=='paused'` (not `stopping`), assert the provider was not cancelled, assert `retained_staged_bytes>0`.
- [ ] **Step 2–4:** Red → implement → green.
- [ ] **Step 5: Commit** — `#266 M1: bound held output without destroying a queued writer`

### Task 1.8: the runner-bypassing writer

**Files:**
- Modify: `lua/parley/response_topic.lua:141-147,165-166`
- Test: `tests/integration/response_topic_spec.lua`

- [ ] **Step 1:** Test that automatic topic generation does not write while another generation holds the turn.
- [ ] **Step 2–4:** Red → take the turn around the `D.apply` → green.
- [ ] **Step 5: Commit** — `#266 M1: route automatic topic writes through the turn`

### Task 1.9: undo coherence

**Files:**
- Test: `tests/integration/document_native_history_spec.lua` (add seeds), `tests/integration/chat_scoped_response_spec.lua:47` (invert)

**What to assert.** Not "undo walks backwards in document position" — generations write to different answers, so regenerating Q3 then Q1 writes Q3's region first and undo removes Q1's text first. The guarantee is that **each undo step removes exactly one coherent unit**: one generation's contiguous contribution, never a 4 KiB fragment and never a mix of two generations.

- [ ] **Step 1:** On a real buffer, run two generations to completion serialized, then loop `vim.cmd('silent undo')` capturing `vim.fn.changenr()` and the buffer text each step; assert the number of undo steps equals the number of generation runs (not the chunk count), and that each step's removed span belongs to one generation.
- [ ] **Step 2:** Run — fails today because `can_join_undo` (`document/editor.lua:194-202`) is defeated by interleaving.
- [ ] **Step 3:** No production change expected — serialization from 1.4/1.5 should already satisfy it. If not, the receipt invalidation at `editor.lua:67` is the suspect.
- [ ] **Step 4:** Green. Add a seed to `document_native_history_spec.lua`'s `{1,17,254,4099}`.
- [ ] **Step 5: Commit** — `#266 M1: assert undo coherence across serialized generations`

### Task 1.10: atlas + milestone close

- [ ] Rewrite `atlas/chat/ownership.md:8-9` — the "Disjoint generations may write separate answers" sentence is now false. Also touch `atlas/chat/lifecycle.md:266-267`, `atlas/providers/architecture.md:29`, `atlas/chat/inline_branch_links.md:76`, `atlas/chat/response_progress.md:56`.
- [ ] Route every new spec under `chat/ownership` and `chat/document` in `atlas/traceability.yaml`; add `document/write_turn.lua` to the `code:` lists.
- [ ] `make test` → exit 0.
- [ ] `sdlc milestone-close --issue 266 --milestone M1`

---

## Chunk 2 — M2: serialized `(call, result)` insertion

### Task 2.1: `ToolSequence` pure entity

**Files:**
- Create: `lua/parley/tools/sequence.lua`
- Test: `tests/unit/tools_sequence_spec.lua`

- [ ] **Step 1: Failing test**

```lua
local ok,Seq=pcall(require,'parley.tools.sequence')
describe('tool sequence',function()
    it('provides the module',function()assert.is_true(ok)end)
    if not ok then return end
    local calls={{id='a'},{id='b'}}
    it('offers the first call before anything has arrived',function()
        assert.same({kind='call',index=1},Seq.next(Seq.new(calls)))
    end)
    it('will not skip ahead when a later result arrives first',function()
        local s=Seq.new(calls)
        s=Seq.written(s,{kind='call',index=1})
        s=Seq.outcome(s,2,{content='second'})
        assert.is_nil(Seq.next(s),'call 1 result is still outstanding')
    end)
    it('drains in declared order once the earlier outcome lands',function()
        local s=Seq.new(calls)
        s=Seq.written(s,{kind='call',index=1})
        s=Seq.outcome(s,2,{content='second'})
        s=Seq.outcome(s,1,{content='first'})
        assert.same({kind='result',index=1},Seq.next(s))
        s=Seq.written(s,{kind='result',index=1})
        assert.same({kind='call',index=2},Seq.next(s))
        s=Seq.written(s,{kind='call',index=2})
        assert.same({kind='result',index=2},Seq.next(s))
        s=Seq.written(s,{kind='result',index=2})
        assert.is_nil(Seq.next(s))
        assert.is_true(Seq.complete(s))
    end)
    it('treats an unknown outcome as writable evidence, not a stall',function()
        local s=Seq.written(Seq.new(calls),{kind='call',index=1})
        s=Seq.outcome(s,1,{unresolved=true})
        assert.same({kind='result',index=1},Seq.next(s))
    end)
end)
```

- [ ] **Steps 2–5:** Red → implement a pure immutable record → green → commit `#266 M2: add the pure tool insertion sequence`.

### Task 2.2: append-only round insertion

**Files:**
- Modify: `lua/parley/response_tools.lua` — delete `:21-26` (`release_ticket`), `:36-68` (`reserve_step`), `:154-161` (placeholders), `:183-187` (`cancel_reservation`); rewrite `:137-182` as `begin_round`; rewrite `tool_outcome` `:77-102` to append rather than `ctx.replace`
- Test: `tests/integration/response_tools_spec.lua`

- [ ] **Step 1: Invert the pinning test.** Replace `:141` `'declares all call blocks and result grants before any producer starts'` with `'writes each call block immediately before its own result'`:

```lua
it('writes each call block immediately before its own result',function()
    local f=setup();f.round(calls)
    local first,second=unpack(f.producer.started)
    assert.equals(2,#f.producer.started,'both tools still execute concurrently')
    second.events.outcome('known',{content='second result'});second.events.resolved()
    f.drain()
    local text=table.concat(f.editor.lines,'\n')
    assert.is_nil(text:find('second result',1,true),'must not jump ahead of call 1')
    assert.is_nil(text:find('(Tool result pending)',1,true),'no placeholder is ever written')
    first.events.outcome('known',{content='first result'});first.events.resolved()
    f.drain()
    text=table.concat(f.editor.lines,'\n')
    local ca=text:find('🔧: read_file id=a',1,true)
    local ra=text:find('first result',1,true)
    local cb=text:find('🔧: read_file id=b',1,true)
    local rb=text:find('second result',1,true)
    assert.is_true(ca<ra and ra<cb and cb<rb,'call/result pairs in declared order')
end)
```

- [ ] **Step 2:** Run `make test-spec SPEC=providers/tool_use` → FAIL.
- [ ] **Step 3:** Implement. `begin_round` freezes `s.rounds[ctx.round]` and builds a `ToolSequence`; it writes **nothing** and takes **no capacity ticket**. A pump appends `Serialize.render_call` / `Serialize.render_result` output at the parent grant tail via `ctx.append`, one item per `adapter.step()`, driven by `Seq.next`. `ctx.replace` is no longer used by this path.
- [ ] **Step 4:** Green.
- [ ] **Step 5: Commit** — `#266 M2: append tool call and result pairs in declared order`

### Task 2.3: unresolved calls must not stall the ones behind them

**Files:**
- Modify: `lua/parley/response_tools.lua`, `lua/parley/tools/serialize.lua` (an explicit unresolved rendering)
- Test: `tests/integration/response_tools_spec.lua`

**Decision (from the target):** an unknown outcome becomes **visible text in the transcript** and the sequence continues. Today it is hidden state that blocks — `generation.lua:332-334` pauses and `batch.lua:99` refuses resume permanently. Rendering it makes the transcript the record of what happened, and stops one hung tool freezing a round.

- [ ] **Step 1:** Copy the 8-order × 2-mode cartesian sweep shape at `response_tools_spec.lua:261`. For each interleaving of `{outcome₁, outcome₂, cancel, resolve}`, assert the transcript ends in declared order and that an unresolved call₁ still lets call₂ and its result be written after an explicit unresolved marker.
- [ ] **Steps 2–4:** Red → implement → green.
- [ ] **Step 5: Commit** — `#266 M2: record an unresolved tool outcome in the transcript`

### Task 2.4: keep concurrency visible

**Files:**
- Modify: `lua/parley/response_session.lua:100-101,180-183`
- Test: `tests/integration/chat_pending_spec.lua`

- [ ] **Step 1:** Assert that with two tools running and only call 1 written, the pending extmark reports both as in flight.
- [ ] **Step 2–4:** Red → add the tool → `session:progress{tool=…}` edge (`chat_pending.lua:160-165`, `chat_presentation.lua:58` already accepts `event.tool`) → green. Watch the `session:written` teardown at `response_session.lua:180-183`: serialized insertion writes more often, so the progress line must survive a write receipt.
- [ ] **Step 5: Commit** — `#266 M2: show concurrent tool progress in presentation`

### Task 2.5: end-to-end and wire shape

**Files:**
- Modify: `tests/integration/chat_async_tools_spec.lua:123`, `tests/integration/openai_tool_loop_spec.lua:167`
- Verify: `tests/fixtures/golden_payloads/*.json` via `scripts/refresh_goldens.lua`

- [ ] **Step 1:** The two end-to-end order assertions should still pass unchanged — they already assert declaration order on real buffer text.
- [ ] **Step 2:** Regenerate goldens. Expect **no message-shape change**: the fixtures at `tests/fixtures/transcripts/*.md` are already interleaved and `build_messages_spec.lua:1189-1192` already pins the four-message shape. Any diff beyond key-order churn is a red flag — investigate, do not accept.
- [ ] **Step 3: Commit** — `#266 M2: confirm wire shape under serialized insertion`

### Task 2.6: atlas + milestone close

- [ ] Rewrite `atlas/providers/tool_use.md` (ordered child slots are gone) and the tool paragraph in `atlas/chat/ownership.md`.
- [ ] Record the accepted four-message resubmit shape in `atlas/providers/tool_use.md`.
- [ ] `make test` → exit 0. `sdlc milestone-close --issue 266 --milestone M2`

---

## Chunk 3 — M3: remove the machinery that only existed for out-of-order fills

Separate boundary so M1/M2 behavior is proven green before the scaffolding comes out. **Not** deferred work — it is in this issue, per ARCH-PURPOSE.

### Task 3.1: delete the capacity-ticket subsystem

**Files:**
- Modify: `lua/parley/document/state.lua:170-180,199-212,253-256`; `lua/parley/document/init.lua:312-319`
- Delete: `tests/unit/document_capacity_spec.lua`

- [ ] Confirm zero callers remain (`grep -rn "reserve_capacity\|release_capacity" lua/ tests/`), delete, run `make test`, commit `#266 M3: remove capacity tickets`.

### Task 3.2: delete parent/child slot exclusion

**Files:**
- Modify: `lua/parley/document/state.lua` — `exclude` `:147-159`, carving `:237-241,252`, `open_first`/`open_last` in `:32-45`, `'outside parent'`/`'parent'` `:226-236`, ancestor walk + `tail_lost` `:291-311`, `'delegated parent'` `:99-101`, `'active child'` `:265-268`; `lua/parley/document/init.lua:528-529`
- Modify: `tests/unit/document_state_spec.lua:98-133`, `tests/unit/document_write_plan_spec.lua:144-159`, `tests/unit/document_append_spec.lua:100`

**Caution:** the `open_first`/`open_last` half-open flags exist to disambiguate excluded seams. They are threaded through `overlaps`/`contains`/`writable`, which M1's turn logic also uses. Remove them **last** and run the full suite between each removal.

- [ ] Remove one concern per commit, `make test` between each.

### Task 3.3: delete the reservation lifecycle in the machine and runner

**Files:**
- Modify: `lua/parley/generation.lua:54-72,131-134,289-316`, the child branch of `writable` `:32-39`, `write_result` `:234-249`
- Modify: `lua/parley/generation_runner.lua:329-354,382-389,404-434`
- Modify: `lua/parley/response_session.lua:174`

- [ ] Also delete the fields with **zero readers** found during the audit: `receipt.markers` (`response_tools.lua:66`), `children[i].call_block` and `children[i].result_slot` (`generation.lua:293`).
- [ ] `make test`, commit `#266 M3: remove round reservation from the generation lifecycle`.

### Task 3.4: close

- [ ] Final atlas sweep — no page may still describe reserved slots, child grants or capacity tickets.
- [ ] `make test` → exit 0, full output captured as close evidence (lint runs first; `workshop/lessons.md:792` records a close where green specs masked a red lint).
- [ ] `sdlc close --issue 266 --verified '<full make test output summary>'`
