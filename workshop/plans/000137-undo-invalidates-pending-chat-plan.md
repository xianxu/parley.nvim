# Undo Invalidates Pending Chat Requests Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Prevent late async chat/tool callbacks from mutating a transcript after undo/redo or out-of-band structural drift invalidates the pending insertion point.

**Architecture:** Add a small per-buffer chat lease seam that records the `changedtick` after Parley's initial structural setup, validates that tick before later async writes, and **commits the new tick after Parley-owned writes**. This is deliberately conservative: out-of-band drift invalidates the request rather than trying to reconcile cursors across undo history (`ARCH-PURPOSE`), while normal multi-chunk streaming remains valid because accepted writes refresh the baseline. Keep the core lease state separate from `chat_respond`; `chat_respond` owns the IO shell that guards all request-lifecycle transcript writes (`ARCH-PURE`, `ARCH-DRY`).

**Tech Stack:** LuaJIT/Neovim, existing plenary test harness, existing `chat_respond` integration fake for dispatcher/query behavior.

---

## Core Concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `ChatLeaseState` | `lua/parley/chat_lease.lua` | new |

- **ChatLeaseState** — per-buffer request lease records `{ generation, baseline_changedtick, valid, reason, meta }` and exposes pure-ish table operations around begin/validate/commit/invalidate/clear. `meta` holds optional ownership details (`query_id`, target exchange/block role) for debugging and future stricter stale-callback checks; generation is the active ownership key in #137.
  - **Relationships:** 1 active lease per buffer; a query callback owns one generation and must validate it before writing.
  - **DRY rationale:** This avoids sprinkling ad hoc `changedtick` comparisons throughout `chat_respond` and gives #136 a named seam if side-chat transcripts need the same invariant later.
  - **Future extensions:** A later lease can store extmark/model anchors for reconciliation. #137 intentionally does not build that.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `chat_respond lease guard` | `lua/parley/chat_respond.lua` | modified | async stream/tool callbacks and buffer writes |

- **chat_respond lease guard** — starts a lease after Parley inserts the response placeholder, checks it before streaming chunks, spinner/progress writes, progress cleanup, tool-loop processing, recursive resubmit, topic-header update, and finalization, commits the new tick after Parley-owned writes, and invalidates/suppresses writes when the transcript changed outside that guarded path.
  - **Injected into:** `dispatcher.create_handler` via a guarded response handler; spinner/progress helpers; `on_exit` before tool-loop/finalization; topic-generation callback before `set_chat_topic_line`.
  - **Future extensions:** Autocmd-driven early invalidation on `UndoPost`/`RedoPost`; the minimal implementation can validate lazily in callbacks.

## Chunk 1: Reproduce and Fix

### Task 1: Lease core

**Files:**
- Create: `lua/parley/chat_lease.lua`
- Test: `tests/unit/chat_lease_spec.lua`

- [x] **Step 1: Write failing unit tests**
  - `begin(buf, changedtick, meta)` creates a valid generation and stores optional ownership metadata.
  - `validate(buf, generation, same_tick)` returns true.
  - `validate(buf, generation, different_tick)` invalidates and returns false with a reason.
  - `commit(buf, generation, new_tick)` updates the valid baseline.
  - `validate(buf, generation, committed_tick)` returns true after commit.
  - stale generation validates false.

- [x] **Step 2: Run test to verify it fails**

Run:
```bash
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_lease_spec.lua"
```
Expected: FAIL because `parley.chat_lease` is missing.

- [x] **Step 3: Implement minimal `chat_lease`**
  - Module-local state keyed by buffer.
  - `begin(buf, changedtick, meta?) -> generation`.
  - `validate(buf, generation, current_changedtick) -> ok, reason`.
  - `commit(buf, generation, current_changedtick)` refreshes the baseline after a guarded Parley-owned mutation.
  - `invalidate(buf, reason)` and `clear(buf, generation?)`.

- [x] **Step 4: Run unit test to verify pass**

Run the same `PlenaryBustedFile` command. Expected: PASS.

### Task 2: Pending stream invalidation

**Files:**
- Modify: `tests/integration/chat_respond_spec.lua`
- Modify: `lua/parley/chat_respond.lua`
- Test: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write failing integration test**
  - Fake `dispatcher.query` so `chat_respond` starts and inserts the response placeholder but does not immediately stream.
  - Run actual `vim.cmd("undo")` after the placeholder is inserted to invalidate the pending request through Vim's undo stack.
  - Deliver a late stream chunk and assert it is not inserted.
  - Add a sibling regression test with no undo: deliver two stream chunks and assert both are inserted, proving Parley-owned writes commit the new `changedtick` instead of self-invalidating.

- [x] **Step 2: Run test to verify it fails**

Run:
```bash
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"
```
Expected: FAIL because late chunk still mutates the buffer.

- [x] **Step 3: Wire lease checks into streaming**
  - Start the lease after Parley performs its initial response-placeholder insertion, using the current `b:changedtick`.
  - Wrap the response handler so it validates the lease before calling the dispatcher handler.
  - After the dispatcher handler accepts a chunk, commit the current `b:changedtick` as the new baseline.
  - On invalidation, call `tasker.stop()` best-effort and log/notify once; do not write the late chunk.
  - Guard `render_spinner_line`, `set_progress_indicator_line`, and `on_progress` writes through the same validate/commit helper. If invalid, stop the spinner and suppress future progress writes.

- [x] **Step 4: Run integration test to verify pass**

Run the same integration spec. Expected: PASS.

### Task 3: Pending tool-loop/finalization invalidation

**Files:**
- Modify: `tests/integration/chat_respond_spec.lua`
- Modify: `lua/parley/chat_respond.lua`
- Test: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write failing integration test**
  - Fake a tool-capable response whose raw stream decodes to a tool call.
  - Stream the response normally, commit the stream writes, then run actual `vim.cmd("undo")` before `on_exit` processes tool calls.
  - Assert no `🔧:` / `📎:` blocks are appended after drift.
  - Add a sibling regression path without undo where the same tool response appends matching `🔧:` / `📎:` blocks, proving stream-then-tool-loop does not self-invalidate.
  - Add a spinner/progress drift test: enable spinner/progress, invalidate the lease with undo, advance a scheduled progress/spinner write, and assert no stale spinner/progress line is written.
  - Add a topic drift test when practical: topic is `?`, query completion launches topic generation, transcript drifts before the topic callback, and `topic:` is not overwritten from a stale callback. If the existing topic test harness makes this too broad, record a manual verification step and keep the callback guard in code.

- [x] **Step 2: Run test to verify it fails**

Run the chat responder integration spec. Expected: FAIL because `tool_loop.process_response` still appends tool blocks.

- [x] **Step 3: Guard `on_exit`/tool-loop/finalization**
  - Validate the lease before `request_clear_progress_indicator`, `collapse_empty_answer`, `tool_loop.process_response`, recursive resubmit, next prompt insertion, topic generation launch, cursor movement, fold application, `ParleyDone`, and final callback.
  - Validate again inside the topic-generation callback immediately before `set_chat_topic_line`; commit if the topic header write succeeds.
  - Commit the lease after each accepted Parley-owned mutation that advances `changedtick` (stream chunk, progress cleanup, tool-loop append, next prompt insertion, topic update as needed).
  - If invalid, suppress those writes and clear the lease.
  - Clear the lease on normal final completion and on abort.

- [x] **Step 4: Run integration test to verify pass**

Run the chat responder integration spec. Expected: PASS.

### Task 4: Verification and issue record

**Files:**
- Modify: `workshop/issues/000137-undo-invalidates-pending-chat.md`

- [x] **Step 1: Run focused tests**

Run:
```bash
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_lease_spec.lua"
nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"
```

- [x] **Step 2: Run broader verification**

Run:
```bash
make test
make lint
```

- [x] **Step 3: Update issue**
  - Tick plan items.
  - Add a dated log entry with test evidence and the invariant decision.

- [x] **Step 4: Commit**

Commit message:
```text
#137: invalidate pending chat writes on transcript drift
```
