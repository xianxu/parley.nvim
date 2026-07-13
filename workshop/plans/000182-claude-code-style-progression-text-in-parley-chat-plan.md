# Playful LLM Progress Presentation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give chat-producing LLM calls delayed, minimum-visible playful progress with ordered output staging, and give inline Definition an immediate selection-anchored spinner without transient buffer edits.

**Architecture:** A pure reducer owns chat presentation states, deadlines, verb choice, and ordered staged events. Thin chat and selection adapters own Neovim timers/extmarks; `chat_respond` routes dispatcher callbacks through the chat adapter, while `skill_invoke` exposes backward-compatible terminal/progress controls for Definition. The dispatcher adds raw-SSE activity and post-start transport-failure channels without changing semantic progress callbacks.

**Tech Stack:** Lua, Neovim extmarks (`virt_lines` and inline `virt_text`), libuv timers, Plenary/Busted, curl/SSE, Python process-level test fixture.

**Spec:** `workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md`

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `chat_presentation.initial` | `lua/parley/chat_presentation.lua` | new |
| `chat_presentation.transition` | `lua/parley/chat_presentation.lua` | new |
| `chat_presentation.progress_message` | `lua/parley/chat_presentation.lua` | new |

- **`chat_presentation.initial`** — constructs one LLM leg's `waiting` state with reveal and verb-idle deadlines, an initial non-repeating verb, and no staged events.
  - **Relationships:** One state per dispatcher leg; a recursive tool loop creates a new state rather than sharing history with the prior leg.
  - **DRY rationale:** One initial-state contract prevents chat callbacks and timers from inventing different deadline defaults.
  - **Future extensions:** New cosmetic vocabularies can widen the injected verb list; timings remain fixed for #182.
- **`chat_presentation.transition`** — reduces one serialized event (`reveal_due`, `minimum_due`, `activity`, `content`, `progress`, `complete`, `failure`, or `cancel`) into a new plain-table state plus ordered actions (`show_playful`, `render_status`, `emit_content`, `hide`, `continue_completion`, `surface_failure`). It never calls Neovim, a clock, or randomness.
  - **Relationships:** N:1 events to one leg state; actions are consumed 1:1 in order by `chat_pending`.
  - **DRY rationale:** Timer, SSE, stream, completion, and cancellation races converge through one transition table instead of independently mutating flags in `chat_respond`.
  - **Future extensions:** Additional visible event kinds can join the staged-event union without changing adapter ownership.
- **`chat_presentation.progress_message`** — accumulates provider detail fragments and derives the existing meaningful reasoning/tool status text from semantic progress events.
  - **Relationships:** One progress-detail state belongs to one presentation state; each `progress` event yields at most one rendered status.
  - **DRY rationale:** Moves the current deterministic formatter out of async glue and makes both staged and released progress use the same rule.
  - **Future extensions:** New provider-normalized `kind` values widen this formatter, not `chat_respond`.

All three symbols are tested without Neovim IO or mocks in `tests/unit/chat_presentation_spec.lua` (`ARCH-PURE`).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `chat_pending.start` | `lua/parley/chat_pending.lua` | new | Neovim extmarks, libuv timers, serialized callback actions |
| `selection_spinner.start` | `lua/parley/selection_spinner.lua` | new | selection-anchored extmark and animation timer |
| `tasker.run` | `lua/parley/tasker.lua` | modified | drain-safe subprocess exit plus stdout/stderr pipe EOF |
| `dispatcher.query` | `lua/parley/dispatcher.lua` | modified | curl process, raw SSE stream, transport terminal |
| `chat_respond.respond` | `lua/parley/chat_respond.lua` | modified | exchange model, chat lease, stream/tool continuations |
| `skill_invoke.invoke` / `skill_invoke.cancel` | `lua/parley/skill_invoke.lua` | modified | headless skill process and terminal ownership |
| `define_visual` | `lua/parley/init.lua` | modified | visual selection and durable footnote rendering |
| `fake_sse_server` | `tests/fixtures/fake_sse_server` | new | real local HTTP/SSE process used by curl |

- **`chat_pending.start`** — creates one registered per-buffer session, anchors a dedicated `virt_lines` extmark below the durable response header, owns reveal/minimum/animation/verb timers, feeds every callback through the pure reducer, and executes emitted actions in order.
  - **Injected into:** `chat_respond.respond` supplies `lease_valid`, the real content emitter, and the existing completion/failure continuations.
  - **Future extensions:** A different chat progress renderer can consume the same reducer actions.
- **`selection_spinner.start`** — renders `" " .. progress.frame(tick)` at the selection's exclusive end and returns an idempotent stop function.
  - **Injected into:** `define_visual`; it reuses `progress.SPINNER` but has no dependency on the detached luabar session (`ARCH-DRY`).
  - **Future extensions:** Other precisely anchored read-only skills can opt in explicitly.
- **`tasker.run`** — drains stdout and stderr to EOF before reporting the process terminal, regardless of whether pipe EOF or process exit arrives first.
  - **Injected into:** `dispatcher.query` receives a callback only after its stdout reader has consumed the final fragment; existing four-argument callbacks remain compatible.
  - **Future extensions:** The optional fifth `io_error` result can classify pipe failures for other subprocess consumers.
- **`dispatcher.query`** — invokes raw activity once per non-empty SSE line, preserves semantic `on_progress`, and chooses exactly one normal or transport-error terminal after drain-safe `tasker.run` completion.
  - **Injected into:** Chat uses the new activity/error callbacks; all existing callers omit them and retain current behavior.
  - **Future extensions:** Provider HTTP-status classification can widen the typed failure record without overloading pre-query `on_abort`.
- **`chat_respond.respond`** — removes the web-search-only buffer/model spinner, starts one presentation session for every initial/recursive leg, and defers tool-loop execution behind a visible minimum when required.
  - **Injected into:** The session receives the existing lease and `create_handler` seams; it never computes transcript positions itself.
  - **Future extensions:** None planned; background topic generation stays deliberately separate.
- **`skill_invoke.invoke` / `skill_invoke.cancel`** — centralizes one idempotent terminal path, with `opts.detached_progress` defaulting true and `opts.on_terminal` running before `opts.on_done` on every terminal path.
  - **Injected into:** Definition passes `detached_progress=false`; Review, Voice Apply, and generic callers rely on defaults.
  - **Future extensions:** Other callers can own contextual progress without changing cancellation semantics.
- **`define_visual`** — starts the inline spinner only after validating a non-empty selection, passes its stop function as terminal cleanup, and performs the existing footnote flow only after cleanup.
  - **Injected into:** `selection_spinner.start` and the generalized `skill_invoke` lifecycle.
  - **Future extensions:** None; the spinner has no one-second delay by design.
- **`fake_sse_server`** — speaks actual HTTP/SSE to curl with deterministic fast, delayed, activity-only-then-visible, partial-then-fail, and tool-use-only modes.
  - **Injected into:** A process integration spec points a test provider endpoint at the local server; callback-only tests remain for exhaustive race permutations.
  - **Future extensions:** Additional transport edge fixtures can become modes instead of new fake processes.

## Chunk 1: Presentation controller, adapters, and integrations

### Task 1: Build the pure chat presentation reducer

**Files:**
- Create: `lua/parley/chat_presentation.lua`
- Create: `tests/unit/chat_presentation_spec.lua`

- [ ] **Step 1: Write failing state-table tests for fast and delayed visible output**

Define the wished-for public API and assert actions, not internal mutation:

```lua
local presentation = require("parley.chat_presentation")

local s = presentation.initial({
    now_ms = 0,
    verbs = { "brewing", "cooking" },
    verb_index = 1,
})
local fast, actions = presentation.transition(s, {
    type = "content", now_ms = 999, qid = "q", chunk = "hello",
})
assert.are.equal("released", fast.phase)
assert.are.same({ { type = "emit_content", qid = "q", chunk = "hello" } }, actions)

local showing = select(1, presentation.transition(s, {
    type = "reveal_due", now_ms = 1000,
}))
local staged, staged_actions = presentation.transition(showing, {
    type = "content", now_ms = 1200, qid = "q", chunk = "hello",
})
assert.are.equal("showing", staged.phase)
assert.are.same({}, staged_actions)
assert.are.equal(1, #staged.staged)
```

- [ ] **Step 2: Run the unit spec and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/chat_presentation_spec.lua" -c "qa!"
```

Expected: FAIL because `parley.chat_presentation` does not exist.

- [ ] **Step 3: Implement `initial` and the minimal waiting/showing/released transitions**

Use immutable plain-table returns (copy only the small state), explicit millisecond deadlines (`reveal_at = start + 1000`, `minimum_at = reveal + 1000`, `verb_due_at = last_activity + 15000`), and tagged staged events. Visible `content` and `progress` share release timing but retain their distinct payloads.

- [ ] **Step 4: Run the unit spec and verify GREEN**

Expected: PASS for the fast path, reveal, staging, minimum release, and ordered flush tests.

- [ ] **Step 5: Add RED tests for the complete transition matrix**

Cover separately:

```text
activity while showing -> different verb + next 15s deadline, never visible output
verb-idle deadline -> different verb; spinner tick -> no verb change
minimum due without staged visible output -> remain showing
tool-only complete before reveal -> continue immediately, never show
tool-only complete while showing -> stage continuation until minimum, hide first
empty success while showing -> honor minimum, then hide
provider failure with ownership -> hide, ordered flush, then surface failure
cancel/stale/invalid -> hide and discard staged output
events after finished -> no actions
same-deadline permutations -> callback order decides exactly once
```

Use a deterministic requested `verb_index`; `transition` advances to the next available non-current index rather than calling `math.random`.

- [ ] **Step 6: Implement the remaining minimal transitions and `progress_message`**

Port the current reasoning/tool detail accumulation from `chat_respond.lua` into `progress_message(detail_state, event) -> new_detail_state, message`, preserving whitespace compaction and key resets.

- [ ] **Step 7: Run the unit spec, then lint the new files**

Run the unit command above, then:

```bash
luacheck lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua
```

Expected: PASS with no warnings.

- [ ] **Step 8: Commit the pure core**

```bash
git add lua/parley/chat_presentation.lua tests/unit/chat_presentation_spec.lua
git commit -m "#182: add pure chat presentation controller"
```

### Task 2: Add raw-SSE activity and a real post-start failure terminal

**Files:**
- Modify: `lua/parley/dispatcher.lua:155-415`
- Modify: `lua/parley/tasker.lua:282-355`
- Modify: `tests/unit/dispatcher_query_spec.lua:422-526`
- Modify: `tests/integration/tasker_run_spec.lua`

- [ ] **Step 1: Write RED drain-order and dispatcher callback tests**

First drive captured process-exit and pipe-reader callbacks in both permutations: stdout/stderr EOF before process exit, and process exit before stdout/stderr EOF. Assert `tasker.run` waits for all three signals, retains final fragments, invokes its public callback once, and reports read failure through an additive fifth `io_error` result.

Then retain the dispatcher-facing `tasker.run` terminal callback and stdout reader. Assert that one non-empty line calls callbacks in this order:

```lua
assert.are.same({ "activity", "progress", "content" }, observed)
```

Add cases for an SSE line with no semantic event/content (activity only), empty lines/EOF (no activity), normal exit (one `on_exit`), and curl `code ~= 0` after partial stdout (one `on_error`, no `on_exit`, partial handlers already delivered).

- [ ] **Step 2: Run tasker and dispatcher specs and verify RED**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/tasker_run_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/dispatcher_query_spec.lua" -c "qa!"
```

Expected: FAIL because `tasker.run` closes pipes at process exit instead of draining, and `query` has no activity/error callbacks or task exit status.

- [ ] **Step 3: Make `tasker.run` drain-safe**

Replace process-exit-time `read_stop`/close with a production three-signal coordinator:

```text
process exit -> record code/signal, close process handle, maybe_finish
stdout EOF/error -> close stdout, record done/error, maybe_finish
stderr EOF/error -> close stderr, record done/error, maybe_finish
maybe_finish -> after all three, invoke callback once with
                (code, signal, stdout_data, stderr_data, io_error)
```

Continue forwarding every stdout chunk and its final `nil` to `out_reader`, and likewise preserve `err_reader`. Do not add a test-only drain method.
Whichever signal makes `maybe_finish` ready must schedule the public callback
onto the Neovim main loop (retain the current `vim.schedule_wrap` behavior);
existing callers must never move into a libuv fast-event context merely because
pipe EOF happened last.

- [ ] **Step 4: Implement the additive dispatcher contract**

Change the public signature only by appending callbacks:

```lua
D.query = function(buf, provider, payload, handler, on_exit, callback,
    on_progress, on_abort, on_activity, on_error)
```

Thread them into the private query. Call `on_activity(qid)` once before parsing each non-empty SSE line. Let stdout EOF process the final buffered line but never choose the terminal. The drain-safe `tasker.run` callback runs afterward and calls exactly one of:

```lua
on_exit(qid)                                  -- code == 0
on_error(qid, { code=code, signal=signal,
                stderr=stderr_data,
                io_error=io_error })           -- code ~= 0 / read failure
```

Keep adapter `pre_query` failures on the existing qid-free `on_abort(msg)` path. Existing callers that omit the new final args remain byte-for-byte compatible.

- [ ] **Step 5: Run dispatcher and tasker tests and verify GREEN**

Run:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/dispatcher_query_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/tasker_run_spec.lua" -c "qa!"
```

Expected: PASS; existing semantic progress expectations remain unchanged.

- [ ] **Step 6: Commit the drain and dispatcher contracts**

```bash
git add lua/parley/tasker.lua lua/parley/dispatcher.lua \
  tests/unit/dispatcher_query_spec.lua tests/integration/tasker_run_spec.lua
git commit -m "#182: expose SSE activity and transport failures"
```

### Task 3: Build the chat extmark/timer adapter

**Files:**
- Create: `lua/parley/chat_pending.lua`
- Create: `tests/integration/chat_pending_spec.lua`

- [ ] **Step 1: Write RED integration tests against a real scratch buffer**

Create a response header line and pass a fake production-shaped clock/scheduler (`now_ms`, `after`, `every`; each registration returns an idempotent cancel closure). Advance it rather than sleeping or calling private adapter methods, and inspect the dedicated namespace with `nvim_buf_get_extmarks(..., {details=true})`. Assert:

- no extmark before reveal;
- `virt_lines` contains `⠙ brewing` after reveal;
- frame ticks change only the glyph;
- activity changes the verb and resets the idle timer;
- semantic progress replaces playful text after release and may remain while content streams;
- hide removes the extmark without changing buffer lines or undo sequence;
- stop/cancel/buffer deletion are idempotent and close every timer.

- [ ] **Step 2: Run the adapter spec and verify RED**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/chat_pending_spec.lua" -c "qa!"
```

Expected: FAIL because `parley.chat_pending` does not exist.

- [ ] **Step 3: Implement `chat_pending.start` as the only chat IO owner**

The constructor accepts:

```lua
local session = chat_pending.start({
    buf = buf,
    anchor_line = header_line_0,
    lease_valid = lease_valid,
    emit_content = function(qid, chunk) base_handler(qid, chunk) end,
    choose_verb_index = function(count) return math.random(count) end,
    clock = production_monotonic_clock,       -- optional; defaults internally
    scheduler = production_timer_scheduler,  -- optional; defaults internally
})
```

Expose `activity`, `content`, `progress`, `complete`, `failure`, and `cancel` methods. Timer registrations enqueue the same reducer events through private callbacks; no public reveal/tick test methods exist. Each source enters one FIFO event pump, asks `chat_presentation.transition` for actions, and executes actions sequentially. The adapter itself handles `render_status` actions by changing the same extmark from playful copy to meaningful provider status; only real content emission is injected. Register one active session per buffer plus `cancel_all`, so user Stop cleans every session before global `tasker.stop`; starting a recursive leg replaces only an already-finished session.

Use a dedicated namespace, `invalidate=true`, `virt_lines_above=false`, and `pcall` cleanup. Every timer callback first checks `nvim_buf_is_valid(buf)` and self-cancels the whole session when false; extmark invalidation alone does not own libuv timer closure. Reuse `require("parley.progress").SPINNER`; do not add spinner frames or chat content to `exchange_model`.

- [ ] **Step 4: Run the adapter and pure specs and verify GREEN**

Run both Task 1 and Task 3 commands. Expected: PASS with no leaked timer warnings after Neovim exits.

- [ ] **Step 5: Commit the chat adapter**

```bash
git add lua/parley/chat_pending.lua tests/integration/chat_pending_spec.lua
git commit -m "#182: render staged chat progress with extmarks"
```

### Task 4: Replace the buffer-backed web spinner in the real chat path

**Files:**
- Modify: `lua/parley/chat_respond.lua:333-356,1134-2108`
- Modify: `tests/integration/chat_respond_spec.lua:655-932`
- Create: `tests/fixtures/fake_sse_server`
- Create: `tests/integration/chat_progress_process_spec.lua`

- [ ] **Step 1: Rewrite the old spinner tests as RED behavioral tests**

Through `parley.chat_respond`, cover:

- answer content before 1000 ms: no playful extmark and immediate stream;
- silence through reveal: playful virtual line, no playful buffer/model block;
- content/progress during minimum: buffer, then flush once in callback order;
- remote status after release: meaningful virtual status persists through answer text and clears on completion;
- tool-use-only completion: immediate local tool before reveal, deferred local tool after reveal until hide;
- initial and recursive legs each create fresh sessions/verb histories;
- topic generation never creates a playful session;
- provider failure flushes valid partial output before warning; abort/cancel/stale lease/deleted buffer discard staged output and clean up immediately;
- exact reveal/minimum callback permutations do not double-flush or double-run completion.

Use the real `M.respond` entry and exchange model; fake only the dispatcher callback delivery for these exhaustive timing cases.

- [ ] **Step 2: Run `chat_respond_spec.lua` and verify RED**

Expected: failures show the current immediate `🔎 … Submitting...` buffer line, web-search gating, and direct stream writes.

- [ ] **Step 3: Wire one presentation session into every `M.respond` dispatcher leg**

Delete the old `spinner_active`, spinner exchange block, buffer-line mutation, and timer code. Always create only `agent_header` + `stream_placeholder` real blocks. After `chat_lease.begin`, start `chat_pending` anchored directly at `model:block_start(target_idx, 2)` (already the response header's 0-based buffer row); with `virt_lines_above=false`, the virtual line renders below that durable header.

Route callbacks as follows:

```text
dispatcher handler      -> session:content(qid, chunk)
semantic on_progress    -> session:progress(qid, event)
raw on_activity         -> session:activity(qid)
normal on_exit          -> session:complete(classify qt, existing continuation)
post-start on_error     -> session:failure(qid, error, existing error surface)
pre-query on_abort      -> session:cancel(), existing empty-shell collapse + warning
lease invalidation      -> session:cancel() before tasker.stop()
user M.cmd_stop         -> chat_pending.cancel_all("user") before global tasker.stop()
```

Extract the current completion body into an idempotent continuation. Classify tool-use-only from the completed query's raw response before running `tool_loop.process_response`; pass that continuation to the controller so it cannot execute behind a minimum-visible indicator. Preserve `finalize_mutated_api_leg`, cursor placement, topic generation, raw logging, and lease clear ordering.

Modify `M.cmd_stop` explicitly to call `require("parley.chat_pending").cancel_all("user")` before `_parley.tasker.stop(signal)`. This makes user cancellation discard staged output before curl termination can be observed as a transport error.

- [ ] **Step 4: Run chat response, lease, and timer-race specs and verify GREEN**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/chat_lease_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/timer_race_spec.lua" -c "qa!"
```

Expected: PASS; playful text is absent from buffer lines and the exchange model.

- [ ] **Step 5: Add one process-level curl/SSE RED test**

Implement `fake_sse_server` as an executable local Python HTTP server whose mode is selected by an argument/environment variable. The test starts it on a free port, points an OpenAI-compatible test provider at it, and invokes the real chat entry without monkeypatching `dispatcher.query` or `tasker.run`. First prove a delayed stream shows the virtual line, buffers the first text until the minimum, then flushes and completes. Add a partial-then-broken-connection mode that makes curl exit nonzero and prove the extmark hides first, partial text appears second, and the error notification arrives last.

- [ ] **Step 6: Run the process test and verify RED, then GREEN**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/chat_progress_process_spec.lua" -c "qa!"
```

Expected RED before the fixture/wiring is complete; expected GREEN after both modes drive the real curl/SSE terminal coordinator. Ensure the server is reaped in teardown even on assertion failure.

- [ ] **Step 7: Commit the chat integration**

```bash
git add lua/parley/chat_respond.lua tests/integration/chat_respond_spec.lua \
  tests/fixtures/fake_sse_server tests/integration/chat_progress_process_spec.lua
git commit -m "#182: stage slow LLM chat output behind playful progress"
```

### Task 5: Give Definition immediate inline progress and terminal ownership

**Files:**
- Create: `lua/parley/selection_spinner.lua`
- Modify: `lua/parley/skill_invoke.lua:21-288`
- Modify: `lua/parley/init.lua:1598-1696`
- Modify: `tests/integration/skill_invoke_spec.lua`
- Modify: `tests/integration/define_spec.lua:193-412`
- Modify: `tests/integration/cliproxy_caller_teardown_spec.lua`

- [ ] **Step 1: Write RED skill lifecycle tests**

Assert `opts.detached_progress=false` never activates `progress.is_active()`, while the default still activates it for existing callers. Add one table of terminal paths: no file, already running, source failure, no agent, success, pre-query abort, explicit `skill_invoke.cancel`, buffer deletion before scheduled completion, and late callback after cancellation. For every row assert `on_terminal` runs exactly once; on normal completion/abort it runs before `on_done`; repeated finish/cancel is harmless.

- [ ] **Step 2: Run `skill_invoke_spec.lua` and verify RED**

Expected: suppression and terminal-hook assertions fail because progress is unconditional and cancellation only bumps generation.

- [ ] **Step 3: Centralize the invocation terminal path**

Document the full opts shape and implement one once-guarded `finish(result, deliver_done)` per generation. Store the active terminal closure per buffer so `M.cancel(buf)` calls it before invalidating the generation and stopping the task. Start/stop the detached luabar only when `opts.detached_progress ~= false`; defaults remain unchanged. `finish` calls `opts.on_terminal(result)` before optional `opts.on_done(result)` and clears `_in_flight`/terminal registry exactly once.

At the top of scheduled completion, before reload, `nvim_buf_get_lines`, tool rendering, or decoration work, check `nvim_buf_is_valid(buf)`. An invalid buffer immediately takes the centralized terminal path with `{ok=false, msg="buffer invalid"}` and skips `on_done`; the terminal hook still runs once. Guard every remaining completion-time buffer access that can race deletion.

- [ ] **Step 4: Run skill and cliproxy caller teardown specs and verify GREEN**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/skill_invoke_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/cliproxy_caller_teardown_spec.lua" -c "qa!"
```

Expected: PASS; existing Review/Voice/generic luabar assertions remain green.

- [ ] **Step 5: Write RED selection-spinner and real Definition entry tests**

Hold the real `define_visual` query open and assert immediately:

```text
buffer text remains "... CVR ..."
an inline virt_text extmark at row er-1, col ec renders " ⠋"
the frame advances
detached progress is inactive
```

Then cover success (spinner removed before `CVR[^cvr]` edit), no tool output, source/no-agent synchronous failure, pre-query abort, explicit cancel, stale selection, and deleted buffer. Every non-success leaves no footnote and no timer/extmark.

- [ ] **Step 6: Implement `selection_spinner.start` and Definition wiring**

Create a dedicated namespace and `virt_text_pos="inline"` mark at `{row=er-1, col=ec}` with `invalidate=true`. Return an idempotent stop closure that always stops/closes its 90 ms timer before attempting `pcall(nvim_buf_del_extmark, ...)`. Each animation callback checks buffer validity first and invokes that stop closure when invalid, so buffer deletion cannot leave the timer alive.

In `define_visual`, start it after non-empty phrase validation and call:

```lua
skill_invoke.invoke(buf, manifest, { phrase = phrase }, {
    document = context,
    no_reload = true,
    detached_progress = false,
    on_terminal = stop_selection_spinner,
    on_done = function(result) render_definition(buf, span, phrase, result) end,
})
```

Guard `render_definition` against an invalid buffer before reading lines.

- [ ] **Step 7: Run Definition tests and verify GREEN**

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/define_spec.lua" -c "qa!"
```

Expected: PASS; the durable footnote/undo/projection tests remain unchanged after the transient spinner disappears.

- [ ] **Step 8: Commit Definition progress**

```bash
git add lua/parley/selection_spinner.lua lua/parley/skill_invoke.lua lua/parley/init.lua \
  tests/integration/skill_invoke_spec.lua tests/integration/define_spec.lua \
  tests/integration/cliproxy_caller_teardown_spec.lua
git commit -m "#182: anchor definition progress to the selection"
```

### Task 6: Update the product map and run full verification

**Files:**
- Create: `atlas/chat/response_progress.md`
- Modify: `atlas/index.md`
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/context/web_search.md`
- Modify: `atlas/chat/inline_define.md`
- Modify: `atlas/traceability.yaml`
- Modify: `README.md`
- Modify: `workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md`

- [ ] **Step 1: Write the atlas page and reconcile every old behavior statement**

Map eligibility, state/event timing, extmark ownership, semantic status handoff, tool-only continuation, failure/cancellation distinction, and Definition's separate immediate renderer. Remove the old claim that web search owns a buffer-backed initial spinner. Add all new files/tests to traceability and link the new page from `atlas/index.md`; update README's chat and Definition descriptions.

- [ ] **Step 2: Run architecture shadow searches**

```bash
rg -n "Submitting|spinner_active|spinner_block_idx|🔎" lua tests atlas README.md
rg -n "progress\.start|detached_progress|on_terminal" lua/parley tests
rg -n "chat_presentation|chat_pending|selection_spinner" atlas README.md tests lua
```

Expected: no obsolete buffer-backed initial spinner implementation or stale documentation; every new consumer derives from the canonical spinner frames and lifecycle helpers (`ARCH-DRY`, `ARCH-PURPOSE`).

- [ ] **Step 3: Run mapped feature tests**

```bash
make test-spec SPEC=chat/response_progress
make test-spec SPEC=chat/lifecycle
make test-spec SPEC=chat/inline_define
make test-spec SPEC=context/web_search
```

Expected: all mapped unit, integration, architecture, and process-fake specs pass.

- [ ] **Step 4: Run lint, changed-spec checks, and the full suite**

```bash
make lint
make test-changed
make test
git diff --check origin/main...HEAD
```

Expected: every command exits 0 with no warnings or whitespace errors.

- [ ] **Step 5: Perform the manual temporal smoke test**

In Neovim, use a test provider or temporarily delayed endpoint to verify: fast answer/no spinner; slow answer/playful line after one second; staged burst after minimum; remote status handoff; tool recursion with no spinner during local execution; immediate `CVR ⠙` Definition transition to `CVR[^cvr]`; Review still uses the detached luabar. Record exact observations in the issue Log.

- [ ] **Step 6: Check off the issue plan and commit docs/evidence**

```bash
git add atlas/chat/response_progress.md atlas/index.md atlas/chat/lifecycle.md \
  atlas/context/web_search.md atlas/chat/inline_define.md atlas/traceability.yaml \
  README.md workshop/issues/000182-claude-code-style-progression-text-in-parley-chat.md
git commit -m "#182: document LLM progress presentation"
```

- [ ] **Step 7: Close and publish through the SDLC gates**

Run `sdlc actual --issue 182`, then follow `sdlc close --help`. Close with the targeted, process-fake, mapped, full-suite, diff, and manual evidence; use only the precise atlas/project bypass if the gate says it is genuinely inapplicable. Publish once with `sdlc pr` then `sdlc merge`; verify `main` contains the branch tip.

## Revisions

### 2026-07-13T00:13:49-07:00 — first plan review

Added drain-safe tasker ownership, deterministic clock/scheduler injection,
explicit global Stop cancellation, chat-adapter semantic status ownership,
invalid-buffer Definition cleanup, and the recalibrated transport primitive.

### 2026-07-13T00:16:28-07:00 — second plan review

Corrected the chat virtual-line anchor to use the exchange model's already
0-based response-header row directly. Required both extmark adapters' timer
callbacks to self-cancel when their buffer becomes invalid.

### 2026-07-13T00:17:57-07:00 — approved-plan advisory

Kept `tasker.run`'s public terminal callback scheduled on the Neovim main loop
regardless of which drain signal arrives last, preserving existing caller
context while changing pipe ownership.
