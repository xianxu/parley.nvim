# Fold-Visible Recursive Progress Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep delayed progress visible after consecutive client-side tool rounds by anchoring each recursive LLM leg outside Parley's closed tool folds.

**Architecture:** The existing `respond` IO shell already creates a canonical margin and stream placeholder for every recursive leg. Use the stable margin row as the initial presentation anchor; after content arrives, retain the existing writer-owned synchronous relocation. No reducer, fold, lease, or model contract changes are needed.

**Tech Stack:** Lua, Neovim extmarks/manual folds, Plenary/Busted integration tests.

---

## Core concepts

### Pure entities

No pure entity changes. `exchange_model` remains the single source for block
positions, and `chat_presentation` retains the complete temporal state machine.
The bug is solely in the Neovim placement shell.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.respond` recursive progress anchor | `lua/parley/chat_respond.lua` | modified | Exchange-model positions, buffer insertion, and pending extmark startup |
| Folded recursive response fixture | `tests/integration/chat_respond_spec.lua` | modified | Production chat entry, client-side tool loop, manual folds, pending scheduler, and extmarks |

- **`M.respond` recursive progress anchor** — derives the buffer-stable anchor
  from `model:block_start(target_idx, stream_block_idx) - 1`, the same row passed
  to `buffer_edit.insert_lines_at` for the canonical margin (`ARCH-DRY`). It does
  not inspect window-local fold state. The first stream write still calls
  `pending_session:tip_written(last_written_line_0)`.
  - **Injected into:** `chat_pending.start({ anchor_line = ... })`; the reducer
    remains unaware of spatial placement (`ARCH-PURE`).
  - **Future extensions:** none planned; other progress movement continues to
    use the writer-reported tip.
- **Folded recursive response fixture** — runs two tool rounds through the real
  `chat_respond → tool_loop.process_response → recursive respond` boundary, with
  only the provider transport replaced by the existing deterministic fake.
  - **Injected into:** production chat entry tests; no production test hooks.
  - **Future extensions:** additional recursive terminal cases can reuse the
    helper without duplicating tool-loop setup.

## Chunk 1: Fold-visible anchor and regression proof

### Task 1: Reproduce the hidden recursive spinner through the production path

**Files:**
- Modify: `tests/integration/chat_respond_spec.lua:1287`

- [x] **Step 1: Factor a test helper that reaches a waiting third LLM leg**

Add a local helper beside the existing recursive-tool regressions. It installs
the existing deterministic pending runtime and a fake provider transport, then
invokes the real `parley.chat_respond`, completion callback,
`tool_loop.process_response`, fold application, and recursive `M.respond` twice.
For legs one and two, set `raw_response` to
`mk_read_file_sse_response("toolu_FOLD_" .. leg, scratch_file)`; leave leg three
pending. Return the third leg's qid, content callback, completion/terminal
callbacks, plus the 1-indexed fold starts and ends returned by
`foldclosed()`/`foldclosedend()` for all four Parley-generated blocks across
the two rounds (`🔧:` tool use and `📎:` result for each round).

Do not call `tool_loop` directly or construct extmarks manually. Adapt callback
capture to the live `dispatcher.query` signature so only provider transport is
faked. Drive each fast tool-only completion through `runtime:drain()` and
`vim.wait` until the next recursive query is registered.

- [x] **Step 2: Write the failing fold-visibility and timing regression**

Using that helper, assert the third leg has no virtual text initially or at
999 ms. Advance to 1000 ms, capture the pending mark, and assert:

```lua
assert.is_not_nil(pending_virtual_text(buf))
assert.equals(-1, vim.fn.foldclosed(mark[2] + 1))
assert.equals(final_result_fold_end_1, mark[2])
assert.equals("", vim.api.nvim_buf_get_lines(buf,
    mark[2] + 1, mark[2] + 2, false)[1])
```

Because `final_result_fold_end_1` is 1-indexed while `mark[2]` is 0-indexed,
their equality proves the mark is on the row immediately after the final folded
tool result. The empty next row is the recursive stream placeholder, so that
row is precisely its stable preceding separator. Deliver `"final answer"`
through the third leg's real response handler during the visible minimum and
assert the spinner keeps the same ID and separator row while the text remains
absent. Complete during that minimum, advance the remaining deadline, and prove
the spinner disappears before the answer flushes exactly once.

- [x] **Step 3: Write the released semantic-status relocation regression**

Start another two-round third leg, but deliver `"first"` before the reveal so
the waiting reducer releases directly and the real writer places it outside the
fold. Capture dispatcher argument 7 (`on_progress`), send a meaningful
`{ message = "Reasoning" }` event, and record its extmark ID at the first
written row. Deliver `" second"` through the content handler, drain both
schedulers, and assert the same status ID moves to the writer-reported row
containing `"first second"`. This retains #183's movement contract without
confusing it with the playful minimum.

- [x] **Step 4: Write folded-recursive terminal regressions**

Reuse the helper in two focused cases:

Before these cases, add `pending_runtime():open_timer_count()` using the exact
loop from `tests/integration/chat_pending_spec.lua` (count `runtime.timers`
entries whose `closed` field is false).

1. Cancellation during the waiting third leg after reveal and staged content
   calls `parley.cmd.Stop()`. Assert no pending mark, active pending
   owner, or chat lease; staged content is absent; the deterministic runtime has
   no live timers; all four tool-use/result folds retain their prior closed
   starts and ends.
2. Provider failure captures dispatcher argument 10, `on_error(qid, err)`, for
   the third leg. Advance that leg through its 1000 ms reveal, deliver
   `"partial before failure"` through its captured content handler, and drain
   the pending runtime so the content is staged but absent from the buffer.
   Temporarily wrap `vim.notify`; for each notification record whether that
   partial text is already present in the real buffer. Call
   `on_error(third_qid, { code = 22, http_status = 500, body = "broken" })`,
   drain the pending runtime and Neovim schedule, then assert the matching
   provider-failure notification observed partial text first. Finally assert no
   pending mark/owner/timers or lease remains and all four tool-use/result folds
   retain their closed starts and ends. Restore `vim.notify` even if the
   assertion fails by following the spec file's existing save/restore pattern.

- [x] **Step 5: Run the mapped regression and verify RED**

Run:

```bash
make test-spec SPEC=chat/response_progress
```

Expected: FAIL because the third-leg mark is inside the final closed tool-result
fold (`foldclosed(mark[2] + 1) ~= -1`) and is not the separator adjacent to the
stream placeholder. Semantic relocation and terminal cases may already pass;
the placement assertion must be observed failing before production code changes.

### Task 2: Anchor recursion to the stable pre-stream separator

**Files:**
- Modify: `lua/parley/chat_respond.lua:1465-1475`
- Test: `tests/integration/chat_respond_spec.lua:1287`

- [x] **Step 1: Implement the minimal spatial fix**

Change only the recursive branch:

```lua
if is_recursion then
    model:add_block(target_idx, "stream_placeholder", 1)
    stream_block_idx = #model.exchanges[target_idx].blocks
    local pos = model:block_start(target_idx, stream_block_idx)
    initial_progress_tip = pos - 1
    buffer_edit.insert_lines_at(buf, initial_progress_tip, { "", "" })
```

The anchor and insertion index intentionally share one value. Do not query
`foldclosed`, open folds, add reducer spatial state, or alter `tip_written`.

- [x] **Step 2: Run the mapped regression and verify GREEN**

Run:

```bash
make test-spec SPEC=chat/response_progress
```

Expected: PASS. The third-leg spinner is silent through 999 ms, visible at
1000 ms outside the final tool fold, stays there while minimum-visible content
is staged, semantic status later follows released streaming with the same ID,
and both folded terminal cases clean up exactly once.

- [x] **Step 3: Run the exchange-model mapping**

Run:

```bash
make test-spec SPEC=chat/exchange_model
```

Expected: PASS. `last_nonempty_block_end` remains used by `append_pos`; no pure
model contract changed.

- [x] **Step 4: Commit the TDD slice**

Stage only:

```bash
git add lua/parley/chat_respond.lua tests/integration/chat_respond_spec.lua
git commit -m "#184: keep recursive progress outside tool folds"
```

### Task 3: Align the atlas and run repository verification

**Files:**
- Modify: `atlas/chat/response_progress.md:17-20,40-45,68-70`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000184-keep-recursive-progress-visible-above-folds.md`

- [x] **Step 1: Update the response-progress map**

Replace “below the last existing answer/tool/result block” / “final visible
block” with the precise contract: a recursive leg starts at the stable
pre-stream separator outside Parley-generated tool folds, then follows the
writer-reported row after content. Add #184's folded two-round integration test
to traceability if the mapped spec entry does not already cover it.

- [x] **Step 2: Run lint and the serialized full suite**

Run:

```bash
make lint
make test JOBS=1
git diff --check
```

Expected: lint reports zero warnings/errors; all unit, architecture, and
integration specs pass; diff check emits no output.

- [x] **Step 3: Update issue evidence and commit**

Check the completed implementation/verification plan rows in #184 and append a
dated Log entry recording RED, GREEN, fold visibility, terminal proof, mapped
specs, lint, and the full suite. Preserve the final close/publish row unchecked
until its gate executes.

Stage only:

```bash
git add atlas/chat/response_progress.md atlas/traceability.yaml \
  workshop/issues/000184-keep-recursive-progress-visible-above-folds.md
git commit -m "#184: document fold-visible recursive progress"
```

## Revisions

### 2026-07-13 — fresh plan review

Strengthened the placement oracle to prove exact adjacency to the final closed
result fold, named `parley.cmd.Stop()` and dispatcher argument 10 (`on_error`)
as the terminal entry points, made `vim.notify` the partial-before-error
observation boundary, and specified the deterministic runtime's open-timer
counter by reuse of the existing pending-adapter test helper.

### 2026-07-13 — SDLC plan-quality revision

Expanded terminal fold snapshots from the two result folds to all four
tool-use/result folds across both recursive rounds, and made the provider-error
sequence explicit: reveal, deliver partial content, drain it into staging,
invoke dispatcher `on_error`, then prove the staged write precedes notification.

### 2026-07-13 — reducer-contract revision

Corrected an impossible test expectation exposed by reading the pure reducer.
Playful progress now stays at the separator while minimum-visible content is
staged and hides before flush; a separate released semantic-status case proves
same-ID writer relocation through the same folded recursive entry.
