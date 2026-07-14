# Guarded Chat History Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ask before standard undo/redo cancels an active chat response, then cancel only that buffer and perform the counted history operation exactly once.

**Architecture:** A small pure history-policy module formats bounded prompts and translates confirmation results. Existing owners grow narrow buffer-scoped APIs: `tasker` stops transport handles for one buffer, `chat_pending` exposes identity and synchronous structural-drift retirement, and `chat_respond` orchestrates those operations around an injected native history mutation without yielding. Chat-buffer mappings are thin Neovim glue; the structural lease remains the fallback for every path that bypasses them.

**Tech Stack:** Lua, Neovim buffer-local keymaps and confirmation API, plenary/busted tests, existing Parley tasker/pending/lease lifecycle.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `HistoryGuardPolicy` | `lua/parley/chat_history.lua` | new |

- **`HistoryGuardPolicy`** — formats a single-line, UTF-8-byte-bounded confirmation prompt and maps the concrete `vim.fn.confirm` result to proceed/decline.
  - **Relationships:** N:1 from guarded `u`/`<C-r>` invocations to the policy; it consumes zero or one `PendingIdentity` per invocation.
  - **DRY rationale:** prompt normalization, byte bounds, and confirmation semantics live once instead of being repeated in two mappings (`ARCH-DRY`).
  - **Future extensions:** additional destructive history keys can call the same policy without widening pending ownership.
### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `PendingIdentity` | `lua/parley/chat_pending.lua` | new | mutable pending-session registry |
| `Tasker.stop_buf` | `lua/parley/tasker.lua` | new | libuv process handles/signals |
| `chat_pending.retire_stale_now` | `lua/parley/chat_pending.lua` | new | pending registry, timers, extmarks, discard callback |
| `chat_respond.cancel_for_history` | `lua/parley/chat_respond.lua` | new | ordered buffer cancellation transaction |
| `chat_history.guard` | `lua/parley/chat_history.lua` | new | `vim.fn.confirm` and native history callback |
| Chat history keymaps | `lua/parley/init.lua` | new | buffer-local `u` and `<C-r>` mappings |

- **`PendingIdentity`** — immutable `{ agent = string }` snapshot returned by
  the integration registry only for a fully constructed, active per-buffer
  pending session.
  - **Relationships:** 1:1 with an active pending session; the mutable registry owns the session and returns a copied identity.
  - **DRY rationale:** the pending registry remains the only source for activity and agent identity; mappings never inspect extmarks, tasker handles, or transcript text.
  - **Future extensions:** add explicitly safe display metadata only; do not expose the mutable session.
- **`Tasker.stop_buf`** — synchronously signals and removes only handles whose `buf` matches, preserving all unrelated handles.
  - **Injected into:** `chat_respond.cancel_for_history`; tests use fake handle records and an injected tasker UV seam.
  - **Future extensions:** global `stop` may later delegate to a shared filtered-stop helper, but only if that removes duplication without changing global semantics.
- **`chat_pending.retire_stale_now`** — synchronously dispatches the existing `stale` terminal for one active session, making timer/registry/UI/discard cleanup complete before it returns.
  - **Injected into:** `chat_respond.cancel_for_history`.
  - **Future extensions:** other already-mutated ownership-loss paths may opt in after proving they need synchronous convergence.
- **`chat_respond.cancel_for_history`** — executes `stop_buf(buf) → mutate_history() → retire_stale_now(buf)` in one protected, non-yielding call; every stage is attempted even if an earlier stage fails, and failures surface only one bounded generic result after retirement.
  - **Injected into:** `chat_history.guard` as the confirmed action.
  - **Future extensions:** none planned; this transaction is deliberately specific to history mutation.
- **`chat_history.guard`** — reads the pending identity, prompts only when active, and invokes either native history directly or the cancellation transaction.
  - **Injected into:** the two chat-buffer mappings with `confirm`, `pending_identity`, and `cancel_for_history` dependencies so policy tests need no UI mocks (`ARCH-PURE`).
  - **Future extensions:** expose no global mapping or command interception.
- **Chat history keymaps** — capture `vim.v.count1` and call native `normal! {count}u` / `normal! {count}<C-r>` through `chat_history.guard`.
  - **Injected into:** prepared chat buffers only.
  - **Future extensions:** command-line/custom mappings remain outside this seam and rely on the lease (`ARCH-PURPOSE`).

## Chunk 1: Buffer-scoped cancellation core

### Task 1: Stop only one buffer's transport handles

**Files:**
- Modify: `lua/parley/tasker.lua:258`
- Test: `tests/integration/tasker_run_spec.lua`

- [x] **Step 1: Write the failing buffer-isolation tests**

Add tests that seed three fake handle records (two for buffer 11, one for buffer 22), call `tasker.stop_buf(11)`, and assert:

```lua
assert.same({ 101, 102 }, killed_pids)
assert.same({ 203 }, vim.tbl_map(function(h) return h.pid end, tasker._handles))
```

Also call `stop_buf(11)` again and assert no additional signal. Cover an already-closing matched handle: remove it without signaling, count it as a scoped stop, and emit the single scheduled `ParleyQueryFinished` event. Assert no event when no record matched.

- [x] **Step 2: Run the focused test and verify RED**

Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tasker_run_spec.lua"`

Expected: FAIL because `tasker.stop_buf` is nil.

- [x] **Step 3: Implement one filtered stop primitive**

Extract a local helper that partitions `_handles`, signals matching live handles, preserves nonmatching records in order, and schedules `ParleyQueryFinished` only when at least one record matched. Implement:

```lua
M.stop_buf = function(buf, signal)
    return stop_matching(function(handle)
        return handle.buf == buf
    end, signal)
end
```

Keep `M.stop(signal)` behavior global by delegating to the same helper with an always-true predicate. Do not alter query history or other buffers' handles.

- [x] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2.

Expected: all `tasker.run integration` tests pass.

- [x] **Step 5: Commit the transport primitive**

```bash
git add lua/parley/tasker.lua tests/integration/tasker_run_spec.lua
git commit -m "#168: stop chat transport by buffer"
```

### Task 2: Expose pending identity and synchronous stale retirement

**Files:**
- Modify: `lua/parley/chat_pending.lua:98-560`
- Test: `tests/integration/chat_pending_spec.lua`

- [x] **Step 1: Write failing registry contract tests**

Update the shared `start_fake` helper to accept/pass a stable agent first. Start two fake sessions with distinct buffers and `agent` values. Assert `identity(buf)` returns a copy only for the active session:

```lua
assert.same({ agent = "Claude" }, chat_pending.identity(first_buf))
assert.is_nil(chat_pending.identity(99999))
```

Mutate the returned table and assert the next identity remains unchanged. Then call `retire_stale_now(first_buf, "history")` and assert before return: the first session is inactive, its timers/extmark are gone, its discard callback ran once with `stale`, and the second session remains active. Repeating retirement returns false and does not call discard again. Add a throwing `on_discard` case and assert `retire_stale_now` still does not throw, the registry is clear, timers/extmark are gone, and only a bounded generic callback diagnostic is logged.

- [x] **Step 2: Run the focused test and verify RED**

Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_pending_spec.lua"`

Expected: FAIL because `identity` and `retire_stale_now` do not exist and `start` does not accept `agent`.

- [x] **Step 3: Implement immutable identity and direct stale dispatch**

Validate `opts.agent` as a non-empty string before publishing the session; store it on the private session. Add:

```lua
function M.identity(buf)
    local session = active_by_buf[buf]
    if not session or session.finished then return nil end
    return { agent = session.agent }
end

function M.retire_stale_now(buf, reason)
    local session = active_by_buf[buf]
    if not session or session.finished then return false end
    session:retire_stale_now(reason)
    return true
end
```

The session method calls the existing local `dispatch({ type = "stale", reason = reason })` directly—never `submit`/`scheduler.enqueue`—so existing `finish`, timer cancellation, hide, registry release, and protected `on_discard` invocation remain the single terminal implementation. Document it in its Lua annotation as a no-throw public contract: callback failures are already contained by `call_safely`, and the new tests pin terminal cleanup under a throwing discard callback.

- [x] **Step 4: Update every `chat_pending.start` test fixture/caller with an agent label**

Pass the real `agent_info.display_name` from `chat_respond`; use stable labels such as `"Test Agent"` in direct test construction. Grep:

Run: `rg -n 'chat_pending\.start|pending\.start' lua tests`

Expected: every constructor supplies `agent`, and there is no fallback identity inferred elsewhere.

- [x] **Step 5: Run focused pending and respond tests**

Run:

```bash
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_pending_spec.lua"
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"
```

Expected: both files pass.

- [x] **Step 6: Commit pending ownership changes**

```bash
git add lua/parley/chat_pending.lua lua/parley/chat_respond.lua tests/integration/chat_pending_spec.lua tests/integration/chat_respond_spec.lua
git commit -m "#168: expose pending chat identity and retirement"
```

### Task 3: Orchestrate a non-yielding history cancellation transaction

**Files:**
- Modify: `lua/parley/chat_respond.lua:333-360`
- Test: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write failing ordering, cleanup, and isolation tests**

Inject fakes for `stop_buf`, `mutate_history`, and `retire_stale_now`, then assert the exact synchronous order:

```lua
assert.same({ "stop:11", "history", "retire:11" }, events)
```

Add failure cases where `stop_buf` throws and where history mutation throws. In both cases all later stages must still run, retirement must complete before return, `chat_pending.identity(buf)` must already be nil, and the function must return `false` after emitting one fixed generic notice of at most 160 bytes without raw exception/provider/internal data. Do not inject a throwing retirement dependency: Task 2 defines `retire_stale_now` as no-throw and proves its callback-failure cleanup directly. Add a production-shaped two-buffer case proving the first session/handles retire while the second session/handles remain active.

- [x] **Step 2: Run the focused test and verify RED**

Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`

Expected: FAIL because `cancel_for_history` does not exist.

- [x] **Step 3: Implement the protected transaction**

Add `M.cancel_for_history(buf, mutate_history, deps)` with production defaults for tasker/pending. Run each stage under its own `xpcall` handler that records only a boolean failure and discards raw exception text. Attempt `stop_buf`, history mutation, and synchronous stale retirement in that order regardless of earlier failures. Because Task 2 makes retirement no-throw and terminal, return only after the pending session is inactive. Return `true` when every stage succeeds; otherwise log/notify one fixed message of at most 160 bytes and return `false`. Never call global `tasker.stop` or `chat_pending.cancel_all`.

- [x] **Step 4: Run focused lifecycle tests and verify GREEN**

Run:

```bash
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_pending_spec.lua"
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tasker_run_spec.lua"
```

Expected: all pass; exact-once assertions remain green.

- [x] **Step 5: Commit transaction orchestration**

```bash
git add lua/parley/chat_respond.lua tests/integration/chat_respond_spec.lua
git commit -m "#168: cancel pending chat around history mutation"
```

## Chunk 2: Guarded keys, documentation, and acceptance

### Task 4: Add pure prompt policy and guarded chat-buffer mappings

**Files:**
- Create: `lua/parley/chat_history.lua`
- Modify: `lua/parley/init.lua:1950-2185`
- Test: `tests/unit/chat_history_spec.lua`
- Test: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write failing pure policy tests**

Cover one-line normalization of `\r`/`\n`, valid UTF-8 truncation, exact maximum prompt size, normal short labels, and confirmation returns `1` (Yes), `2` (default No), and `0` (dismissal). Put a unique sentinel beyond the truncation budget; assert the bounded label prefix remains, the sentinel is absent, and the prompt is no more than 160 bytes:

```lua
local prompt = history.prompt("Agent\n" .. string.rep("x", 300) .. "TAIL_SECRET")
assert.is_true(#prompt <= 160)
assert.is_truthy(prompt:find("Agent ", 1, true))
assert.is_nil(prompt:find("TAIL_SECRET", 1, true))
assert.is_true(history.should_proceed(1))
assert.is_false(history.should_proceed(2))
assert.is_false(history.should_proceed(0))
```

Test `guard` itself with injected functions: pending identity is read exactly once; inactive calls native history once without confirming; choices `2` and `0` call neither native history nor cancellation; choice `1` calls `cancel_for_history` once with the same buffer and native callback. Assert the returned result enum for every branch.

- [x] **Step 2: Run the pure test and verify RED**

Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_history_spec.lua"`

Expected: FAIL because `parley.chat_history` does not exist.

- [x] **Step 3: Implement the minimal pure policy and injected guard**

Implement `prompt(agent)`, `should_proceed(choice)`, and `guard(opts)`. `guard` calls `opts.pending_identity(buf)` once. With no identity it calls `opts.native_history()` directly. With identity it calls injected `confirm(prompt, "&Yes\n&No", 2)`; only result `1` calls `opts.cancel_for_history(buf, opts.native_history)`. It returns a small result enum (`"native"`, `"declined"`, `"cancelled"`) for deterministic tests.

- [x] **Step 4: Run the pure test and verify GREEN**

Run the command from Step 2.

Expected: all `chat_history` tests pass without creating a buffer or mocking Neovim IO.

- [x] **Step 5: Write failing production-keymap tests**

Prepare a real chat buffer through the production setup path and retrieve its normal-mode mappings with `vim.api.nvim_buf_get_keymap`. Exercise mappings with remapping-enabled, termcode-replaced input:

```lua
local keys = vim.api.nvim_replace_termcodes("3u", true, false, true)
vim.api.nvim_feedkeys(keys, "mx", false)
assert.is_true(vim.wait(100, history_reached_expected_state, 5))
```

Use the same path for counted `<C-r>` and verify `vim.v.count1` indirectly through the resulting undo sequence. Assert:

- inactive `3u` and `2<C-r>` perform native counted history with no confirmation;
- active default-No and dismissal leave `undotree().seq_cur`, transcript bytes, and pending identity unchanged;
- active Yes names the configured display agent, performs counted undo/redo exactly once, and leaves no pending identity/presentation/lease;
- a second buffer's pending identity and tasker handle remain active;
- `:undo` bypasses the mapping but the lease fallback emits exactly one notice, `#notice <= 160`, containing none of injected provider body/stderr/exception/payload markers.

- [x] **Step 6: Run the production test and verify RED**

Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`

Expected: FAIL because prepared chats do not yet map `u`/`<C-r>`.

- [x] **Step 7: Install thin buffer-local mappings**

In chat preparation, map normal-mode `u` and `<C-r>` directly (not through the configurable keybinding registry). Capture `vim.v.count1`. The native undo callback may use `normal! {count}u`; redo must replace termcodes and execute non-remapped input, for example:

```lua
local redo = vim.api.nvim_replace_termcodes(count .. "<C-r>", true, false, true)
vim.api.nvim_feedkeys(redo, "nx", false)
```

Pin the chosen mechanism with the production counted-history tests. The native callback must not merely enqueue redo and return: assert the expected undo-tree state before `cancel_for_history` advances to synchronous retirement, preserving the required mutation-before-retirement boundary. Call `chat_history.guard` with the production identity, confirm, and cancellation dependencies. Set `silent = true`, `buffer = buf`, and descriptive mapping text.

- [x] **Step 8: Run pure and production tests and verify GREEN**

Run:

```bash
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_history_spec.lua"
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"
```

Expected: both files pass, including exact history sequences and notice cardinality.

- [x] **Step 9: Commit guarded history keys**

```bash
git add lua/parley/chat_history.lua lua/parley/init.lua tests/unit/chat_history_spec.lua tests/integration/chat_respond_spec.lua
git commit -m "#168: confirm before chat undo cancels response"
```

### Task 5: Update architecture map and verify the whole issue

**Files:**
- Modify: `atlas/chat/lifecycle.md:16-20`
- Modify: `atlas/traceability.yaml:16-46`
- Modify: `README.md:120-150`
- Modify: `workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md`

- [x] **Step 1: Document the visible behavior and ownership**

Describe guarded standard keys, default-No prompt, count preservation, buffer-scoped cancellation ordering, and lease fallback for Ex/custom paths in `atlas/chat/lifecycle.md`. Add `chat_history.lua`, `chat_pending.lua`, `tasker.lua`, and their tests to the `chat/lifecycle` traceability entry. Add a concise README key note for `u`/`<C-r>` while a response is pending.

- [x] **Step 2: Run mapped lifecycle tests**

Run: `make test-spec SPEC=chat/lifecycle`

Expected: exit 0; all mapped unit, integration, and architecture specs pass.

- [x] **Step 3: Run the full repository gate**

Run: `make test`

Expected: exit 0, including lint, unit, integration, and architecture tests.

- [x] **Step 4: Run static acceptance checks**

Run:

```bash
rg -n 'tasker\.stop\(|cancel_all\(' lua/parley/chat_history.lua lua/parley/chat_respond.lua lua/parley/init.lua
git diff --check
git status --short
```

Expected: inspect every `rg` match for reachability; existing global Stop paths are legitimate, but no guarded-history callback may reach global stop/cancel. There are no whitespace errors, and only #168 files are modified.

- [x] **Step 5: Update the issue checklist and log with evidence**

Mark the issue's five existing approved plan rows complete, reconciling their wording only if implementation discoveries require a revision entry. Append a dated log entry naming focused tests, full `make test`, two-buffer isolation, counted history, and bounded-notice evidence. Do not add an `M1` tag: this issue has one atomic close boundary.

- [x] **Step 6: Commit docs and acceptance evidence**

```bash
git add README.md atlas/chat/lifecycle.md atlas/traceability.yaml workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md
git commit -m "#168: document guarded chat history"
```

- [x] **Step 7: Close through the SDLC gate**

Run `sdlc actual --issue 168`, inspect the active-time attribution, and assign its printed measured value explicitly (this is measured evidence, not a remembered estimate). Then run:

```bash
MEASURED_HOURS='<value printed by sdlc actual>'
sdlc close --issue 168 --actual "$MEASURED_HOURS" --verified '<exact focused/full test evidence; atlas updated in this change>'
```

Expected: the close gate detects the atlas change, dispatches its single mandatory fresh-context boundary review, writes the issue to `codecomplete`, and creates/updates its boundary-review evidence without committing. If it returns Critical/Important findings, fix them, add prevention rules to `workshop/lessons.md`, rerun verification, and retry close. Do not hand-type hours and do not run a separate redundant review.

- [x] **Step 8: Normalize and commit close artifacts**

Inspect `git status --short` for the exact issue and generated boundary-review paths. Normalize any generated review sidecar by removing only presentation noise (raw terminal plumbing, ANSI, duplicated prompts/diffs, trailing whitespace); preserve every substantive finding, resolution, verdict, and verification record. Run `git diff --check`, stage only those exact #168 paths, then commit:

```bash
git add workshop/issues/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message.md workshop/plans/000168-buffer-undo-operation-during-chat-generation-resulted-in-a-huge-error-message-close-review.md
git commit -m "#168: close guarded chat history"
```

Expected: the commit records `codecomplete`, measured actual hours, the close log, and the successful boundary verdict. If the binary reports a different review-sidecar path, use that exact generated path instead of inventing or blanket-staging files.

## Revisions

### 2026-07-14T11:15:00-07:00 — Chunk 1 plan review

- Reason: fresh-context review found contradictory error behavior and incomplete
  cleanup requirements around fallible cancellation stages.
- Delta: made pending retirement explicitly no-throw and terminal under callback
  failure; required every orchestration stage to be attempted; standardized all
  transaction failures on one bounded generic result; and clarified closing
  tasker-handle semantics plus shared test-fixture identity.

### 2026-07-14T11:25:00-07:00 — Chunk 2 plan review

- Reason: fresh-context review found an impossible truncation oracle, mapping
  invocation/termcode errors, missing guard-level TDD, and an invalid atlas-gate
  bypass.
- Delta: moved the sentinel beyond the truncation budget; specified remapped
  termcode input for production tests and non-remapped termcode input for redo;
  added complete injected-guard branch tests; and restored the normal atlas
  close gate.

### 2026-07-14T11:32:00-07:00 — Chunk 2 re-review

- Reason: re-review found the measured-actual handoff and post-close commit
  missing, plus ambiguity about redo completion and static-search expectations.
- Delta: passes the measured `sdlc actual` result to close, commits exact
  generated close artifacts afterward, pins mutation completion before
  retirement, and treats global-stop grep hits as reachability findings rather
  than expecting an empty search.

### 2026-07-14T11:50:00-07:00 — SDLC plan-quality estimate review

- Reason: the gate found the single Lua primitive implausibly small for three
  production ownership changes plus their integration/debugging surface.
- Delta: the issue estimate now counts tasker filtering, pending retirement,
  and guarded history as three focused `lua-neovim` primitives (4.01 hours
  total), and Task 5 now marks the existing checklist instead of replacing a
  nonexistent placeholder.

### 2026-07-14T13:10:00-07:00 — Test harness correction

- Reason: execution showed this repository's minimal Neovim test harness is
  `tests/minimal_init.vim`, not the `.lua` path written during planning.
- Delta: corrected every focused-test command without changing test scope or
  implementation intent.

### 2026-07-14T14:05:00-07:00 — Boundary review acceptance expansion

- Reason: the close review found that production coverage did not yet prove
  counted redo, counted confirmed operations, or mutation-before-retirement,
  and that transport signal failure was silently suppressed.
- Delta: expanded production mapping tests across those acceptance seams,
  propagated a sanitized scoped-stop failure after handle partitioning, and
  reconciled completed implementation-plan checkboxes.

### 2026-07-14T14:35:00-07:00 — Re-review libuv and purity correction

- Reason: re-review verified that libuv reports ordinary signal failures as a
  `nil, message, code` result rather than throwing, and found `PendingIdentity`
  incorrectly classified as pure despite its mutable-registry lookup.
- Delta: scoped stop now recognizes both thrown and return-shaped signal
  failures, a non-throwing `EPERM` regression pins the production contract, and
  `PendingIdentity` is classified as an integration snapshot/API.
