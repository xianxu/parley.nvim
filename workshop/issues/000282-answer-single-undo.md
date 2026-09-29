---
id: 000282
status: working
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-28
estimate_hours:
card_mirror: '1c875e5c12e01b2737c552c75ed277b1849e591e' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T21:14:10-07:00
flow: {kind: quick, provenance: inferred, spec: "1ae80399", done: "e9dd13de"}
---

# Make each answer one undo history entry

## Problem

Streaming an assistant answer currently records many incremental buffer edits.
Undo can therefore remove individual chunks instead of reverting the answer as
one user-visible action.

## Spec

Treat one submitted answer as one undo transaction from the user's perspective,
while preserving streaming, cancellation, partial-answer recovery and unrelated
edits made before or after the answer. Trace the existing response and buffer
mutation paths, then choose the smallest integration boundary that groups all
chunks belonging to one answer without merging separate answers or tool turns.
Cover answer replacement, errors, stop/cancel, reload and concurrent chats.

## Done when

- A completed streamed answer can be undone in one action.
- Separate answers and unrelated user edits retain independent undo history.
- Cancellation, errors, partial responses and reload do not corrupt undo state.
- Regression tests exercise chunked streaming and the answer lifecycle paths.

## Core concepts

| Name | Lives in | Status |
|------|----------|--------|
| `can_join_undo` (receipt kept for fully-landed plans; recorded before the post-write authority check) | `lua/parley/document/editor.lua` | modified |
| `native` (driver gains watch_write / unwatch_write: BufWritePost adopts the save's tick) | `lua/parley/document/editor.lua` | modified |
| `tool_use_sse` (shared fixture SSE builder, moved from writer_folds_spec) | `tests/helpers/respond_fixture.lua` | new |
| `seed_undo` / `adopt_undo_seed` (regeneration: the new answer's first write joins the old answer's deletion) | `lua/parley/document/editor.lua` | new |
| `set_previous_answer` (adopts the regeneration's undo seed by owner token) | `lua/parley/document/init.lua` | modified |

## Plan

Design: the editor already groups one answer's writes into one undo block — each
generated apply `undojoin`s when a private receipt (epoch, generation, grant, native
undo sequence + changedtick) still matches (`document/editor.lua` `can_join_undo`).
Two refusals that change nothing clear that receipt and split the answer:

1. Auto-save (`init.lua` prep_md, 1s after TextChanged) bumps changedtick with no text
   change and no buffer-update callback (`on_changedtick` does not fire for `:write`),
   so `can_join_undo`'s tick check refuses the next chunk. Fix: the editor watches
   `BufWritePost` and adopts the new tick while the native undo sequence is unchanged.
2. Writing a whole tool block lands the patch, then the post-write authority check
   finds the grant suspended (repair must confirm the block) and `apply` returns `stale`
   before recording the receipt. Fix: record the receipt as soon as the writer's own
   patch lands; keep it when every patch of the plan landed. A partial or refused plan
   still clears it (the existing `document_edit_spec` contract).

`can_join_undo` still requires native sequence + tick to match, and every text event
(edit, undo, redo) still clears the receipt in `observe`, so a real intervening change
still breaks the join. Operator decision (2026-09-28): one `u` undoes the whole answer,
tool rounds included.

- [x] Regression spec (red first): chunked stream with a save between chunks → 1 undo
  (was 5); two-round tool answer → 1 undo (was 5); two answers → 2 entries; user edit
  mid-stream stays its own entry; cancel mid-stream and provider error → partial answer
  is 1 entry; reload between answers → next answer 1 entry.
- [x] Editor fix (tick adoption; clear receipt only after a native edit or error), with
  unit coverage in `document_coordinator_spec`/editor fake driver if it has one.
- [x] Atlas: undo grouping contract in `atlas/chat/document.md` (write authority).

## Log

### 2026-09-26

### 2026-09-28
- Repro (scratch probe, fixture transport, disk-loaded chat): plain chunked stream = 1 undo
  (grouping works); with `:write` between chunks = 5 undos (one per chunk); two-round tool
  answer, no saves = 5 undos. Instrumented: generation/grant constant; receipt cleared by
  `apply` returning `stale` (4x, suspended grant between rounds) — nothing mutated.
- Fix landed in `document/editor.lua`. First attempt (adopt tick on the `tick` lifecycle
  event) was dead code: `on_changedtick` does not fire for `:write`; replaced by a
  `BufWritePost` watcher. Second finding: the tool-round "stale" applies had *landed*
  (receipts=1) and were revoked by the post-write authority check (grant suspended after
  a whole block), so the receipt was recorded too late. Narrowed to plans whose every
  patch landed, keeping `document_edit_spec`'s partial-operation contract.
- answer_undo_spec: 7/7, 0/15 flaky after making the mid-stream edit wait for its chunk.
  Mutation: no save watcher → 4 save cases red; no receipt when revoked → tool-round case red.
- Side fix: the sweep guard's definition matcher missed Lua methods (`function X:m`);
  pattern now includes `:`, with a matcher self-test case.
- Full suite: unit/integration green except tool_resources_spec, perf_document_spec and
  document_fold_batches_spec, which fail only under parallel load and pass alone (#294;
  tool_resources_spec is a new member of that set).
- Close review round 1 (FIX-THEN-SHIP): BR-1 regenerate / concurrent chats / mid-stream
  reload had no test; BR-2 receipt rules pinned only end-to-end. Added the three
  integration cases and direct editor cases (fully-landed-then-revoked joins, save keeps
  join, undo-then-save does not, seed joins only its adopting generation, edit drops seed).
- Regenerate was 2 undo steps: `buffer_edit.delete_answer` removes the old answer with a
  raw set_lines before the generation exists. Fix: `D.seed_undo(doc, pending_owner)` right
  after the deletion; `set_previous_answer` adopts the seed by owner token in
  `prepare_input` (before any write), so the first generated write joins the deletion.
  Mutation: no seed → regenerate case red. Mid-stream reload: the response stops ("chat was
  reloaded"), history stays undoable to the original.
- Minors: atlas sentence narrowed to the fully-landed rule; save watcher created only after
  a successful attach; two-answers case uses a two-question chat (no user edit between).
- answer_undo_spec 10/10, 0/12 flaky; document_edit_spec 23/23.

