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

## Plan

Design: the editor already groups one answer's writes into one undo block — each
generated apply `undojoin`s when a private receipt (epoch, generation, grant, native
undo sequence + changedtick) still matches (`document/editor.lua` `can_join_undo`).
Two refusals that change nothing clear that receipt and split the answer:

1. Auto-save (`init.lua` prep_md, 1s after TextChanged) bumps changedtick with no text
   change → `on_changedtick` → lifecycle `tick` clears the receipt → the next chunk
   `undo_break`s. Fix: a `tick` event adopts the new tick into the receipt.
2. Between tool rounds the writer's apply is refused `stale` (grant suspended while
   repair confirms the written block) before touching the buffer, and `apply` clears
   the receipt on any non-applied status. Fix: clear only when the apply delivered a
   native edit (receipts) or errored.

`can_join_undo` still requires native sequence + tick to match, and every text event
(edit, undo, redo) still clears the receipt in `observe`, so a real intervening change
still breaks the join. Operator decision (2026-09-28): one `u` undoes the whole answer,
tool rounds included.

- [ ] Regression spec (red first): chunked stream with a save between chunks → 1 undo
  (was 5); two-round tool answer → 1 undo (was 5); two answers → 2 entries; user edit
  mid-stream stays its own entry; cancel mid-stream and provider error → partial answer
  is 1 entry; reload between answers → next answer 1 entry.
- [ ] Editor fix (tick adoption; clear receipt only after a native edit or error), with
  unit coverage in `document_coordinator_spec`/editor fake driver if it has one.
- [ ] Atlas: undo grouping contract in `atlas/chat/document.md` (write authority).

## Log

### 2026-09-26

### 2026-09-28
- Repro (scratch probe, fixture transport, disk-loaded chat): plain chunked stream = 1 undo
  (grouping works); with `:write` between chunks = 5 undos (one per chunk); two-round tool
  answer, no saves = 5 undos. Instrumented: generation/grant constant; receipt cleared by
  `apply` returning `stale` (4x, suspended grant between rounds) — nothing mutated.
