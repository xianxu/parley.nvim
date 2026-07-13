---
id: 000183
issue: 000183
created: 2026-07-13
updated: 2026-07-13
---

# Keep response progress at current generation tip — implementation plan

## Goal

Move chat response progress to the stream writer's current generation tip
without changing #182's timing, staging, terminal, or lease semantics. The
writer and presentation adapter complete replacement and relocation as one
scheduled main-loop action, so a virtual line anchored on the replaceable
pending line is never observably invalid between those operations.

## Architectural shape

| Concept | Owner | Contract |
|---|---|---|
| Transcript ownership | `chat_lease` on the response header | Remains fixed and rejects stale writes; it never follows streaming content. |
| Current generation tip | `dispatcher.create_handler` | Reports its extmark-adjusted final written row after mutation and model growth. |
| Progress position | `chat_pending` session | Synchronously records or repaints the same presentation extmark at the reported tip. |
| Initial tip | `chat_respond` exchange-model integration | Fresh legs use the agent header; recursive legs snapshot the final non-empty block before adding their blank stream placeholder. |
| Temporal behavior | `chat_presentation` reducer | Unchanged and unaware of rows or extmarks. |

This preserves `ARCH-PURE` by keeping position out of the reducer, `ARCH-DRY`
by deriving the final row once in the writer that owns it, and `ARCH-PURPOSE`
by separating the durable ownership anchor from the movable cosmetic anchor.

## Task 1 — specify the synchronous tip adapter and writer seam

**Files:**

- Modify `tests/integration/chat_pending_spec.lua`
- Modify `tests/integration/create_handler_spec.lua`
- Modify `lua/parley/chat_pending.lua`
- Modify `lua/parley/dispatcher.lua`

1. Add a real-buffer adapter test that starts with hidden progress, moves the
   tip, then reveals and asserts the mark appears at the new row. Run the
   focused spec and confirm it fails because the session has no tip API.
2. Add a visible relocation test that records the extmark ID, rendered text,
   reducer state, timer identities, and minimum deadline; replace the marked
   line to invalidate it, synchronously move the tip, and assert the exact same
   ID/text/lifecycle state is restored at the new row.
3. Add adapter regressions proving a queued frame callback cannot observe the
   replacement/relocation gap, all cached fallback rows move while hidden, and
   a tip update after completion is a no-op. Include one real-buffer sequence
   that stages multiple output actions, performs invalidating replacement plus
   synchronous relocation, then terminates; assert FIFO release and exact-once
   terminal delivery together with unchanged reducer phase, timer identities,
   and minimum deadline.
4. Implement a synchronous `session:tip_written(last_written_line_0)` adapter
   operation. It must update the active anchor plus cached row/column, restore
   visible text with the existing ID when the acknowledged stream replacement
   invalidated the mark, preserve all reducer/timer/staging state, and return
   without scheduling. Leave normal render-time unexpected invalidation
   terminal behavior intact.
5. Add `create_handler` tests capturing `after_write` arguments and callback
   order. Assert the fourth argument equals the actual final pending row after
   multi-line growth and after inserting lines above the writer anchor; assert
   the callback observes the completed buffer mutation and `on_lines_changed`.
6. Extend `dispatcher.create_handler` to publish
   `after_write(qid, chunk, delta, first_line + finished_lines)` only after the
   mutation and growth callback. Keep query metadata, highlighting, cursor,
   and pending-line accumulation behavior unchanged.
7. Run both focused specs and `git diff --check`.

## Task 2 — wire fresh, recursive, and streaming tip movement

**Files:**

- Modify `tests/unit/exchange_model_spec.lua`
- Modify `tests/integration/chat_respond_spec.lua`
- Modify `lua/parley/exchange_model.lua`
- Modify `lua/parley/chat_respond.lua`

1. Add pure exchange-model tests for a semantic
   `last_nonempty_block_end(exchange_idx)` query covering mixed blocks, trailing
   empty blocks, and an exchange with no non-empty blocks. Implement the query
   beside `append_pos`, reusing one internal backward traversal so non-empty
   block selection remains single-sourced; do not infer it with margin
   arithmetic in `chat_respond` (`ARCH-DRY`, `ARCH-PURE`).
2. Add a real-entry fresh-leg test that holds a slow response before its first
   chunk and asserts delayed progress is directly below the new `🤖:` row.
3. Add a recursive-leg regression with existing answer/tool/result blocks that
   runs the canonical pending adapter under the fake clock. Advance through the
   delayed reveal and assert the real extmark/virtual line renders below the
   last non-empty block as it existed before the new `stream_placeholder` was
   inserted, and not below the agent header or blank placeholder.
4. Add a streaming regression that reveals semantic or remote-tool status,
   writes successive single- and multi-line chunks, and asserts the same
   virtual mark follows each writer-reported tip. Include an edit above the
   response so stale exchange-model coordinates would fail.
5. In `chat_respond`, compute `initial_progress_tip` before adding the recursive
   placeholder by calling the exchange model's tested
   `last_nonempty_block_end(target_idx)` query. For fresh calls, use the newly
   inserted agent-header row.
6. Pass that initial row to `chat_pending.start`. In the stream handler's
   existing `after_write` callback, synchronously call
   `pending_session:tip_written(last_written_line_0)` before lease commit and
   before the scheduled handler callback returns. Do not add `vim.schedule` or
   another queue hop.
7. Run the focused exchange-model, chat-response, pending-adapter, and handler
   specs. Re-run the existing #182 timing/terminal cases to prove the temporal
   policy did not change.

## Task 3 — document and verify the invariant

**Files:**

- Modify `atlas/chat/response_progress.md`
- Modify `atlas/chat/lifecycle.md`
- Modify `workshop/issues/000183-keep-response-progress-at-current-generation-tip.md`

1. Update the response-progress map to distinguish the fixed header lease from
   the generation-tip presentation extmark, including fresh/recursive initial
   placement and atomic synchronous relocation.
2. Update lifecycle wording that currently describes response progress as
   header-anchored; keep the lease paragraph fixed on the header.
3. Run the repository's formatter/lint command, all mapped chat tests, and the
   full suite described by `TOOLING.md`. Inspect failures and fix root causes.
4. Record exact commands and results in the issue log, check every issue-plan
   item, and inspect `git diff --check`, `git status`, and the branch diff.
5. Cross the single final boundary with `sdlc close --issue 183 --verified
   '<evidence>'`, address its mandatory fresh-context review findings, publish,
   and merge through the SDLC workflow.

## Revisions

### 2026-07-13 — initial durable plan

Promoted the fresh-review-approved issue spec into a one-boundary TDD plan. The
plan makes the writer/adapter call synchronous and tests the invalidation race
directly instead of relying only on final rendered position.

### 2026-07-13 — plan review revision

Strengthened recursive placement from an argument-capture test to a canonical
adapter/real-extmark assertion. Added an invalidating relocation sequence that
also proves staged FIFO release and exact-once terminal delivery, so unchanged
#182 lifecycle semantics are demonstrated across the new operation itself.

### 2026-07-13 — SDLC plan-quality revision

The gate identified a duplicated layout traversal in the proposed
`chat_respond` implementation. Added a pure, unit-tested exchange-model query
for the last non-empty block end and made the IO shell consume it, rather than
repeating the model's backward scan or deriving the answer from private margin
arithmetic.
