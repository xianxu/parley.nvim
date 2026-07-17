---
id: 000193
status: working
deps: []
github_issue:
created: 2026-07-16
updated: 2026-07-16
estimate_hours: 2.2
started: 2026-07-16T22:54:13-07:00
---

# parley fold sometimes at wrong place

## Problem

Parley folds are less accurate during streaming than after finalization. The
steady-state path reconstructs exchange structure from the whole document,
while the streaming path eventually relies on that corrective reconstruction
instead of maintaining folds from the live exchange model.

The canonical exchange structure consists of `question`, `agent_header`,
ordinary answer `text`, `thinking`, `summary`, `tool_use`, and `tool_result`.
`stream_placeholder` is transient lifecycle state. Folding should hide the
auxiliary answer entities—thinking, summary, tool calls, and tool results—while
leaving the conversational spine visible.

## Spec

- Fold `thinking`, `summary`, `tool_use`, and `tool_result` blocks. Do not fold
  `question`, `agent_header`, ordinary `text`, or transient lifecycle state.
- Represent thinking and summary as first-class exchange-model blocks instead
  of absorbing them into `text`. The parser-to-model load path and the live
  streaming path must use the same block vocabulary.
- Keep the live exchange model authoritative during generation. Track the one
  insertion-point block receiving content; when a structural marker arrives,
  finalize that block and append the next semantic block. Do not reparse the
  whole document during streaming or finalization.
- Maintain folds incrementally from changed model blocks. Create or resize a
  fold only when the insertion-point block is foldable; skip fold work for
  non-foldable blocks. Completed tool blocks receive one fold when written.
  Never clear or rebuild folds outside the changed block range, including
  user-created manual folds. An update may replace only the Parley-managed fold
  for the active insertion-point block.
- On success, cancellation, or transport failure, finalize any non-empty
  emitted semantic block using its current range and remove transient
  insertion state. If the active block is empty, remove its Parley-managed fold
  rather than leaving an empty or stale fold. Preserve completed-block and
  unrelated user folds on every terminal path.
- Initial chat loading may parse the document once, construct the complete
  exchange model, and create folds for all foldable blocks.
- Keep structural classification in the canonical parser/decoration grammar;
  folding must not maintain a second raw-marker grammar (`ARCH-DRY`). Keep
  classification/model transitions pure and the Neovim manual-fold mutation a
  thin UI shell (`ARCH-PURE`). Cover both initial loading and the incremental
  streaming lifecycle so the issue is not satisfied only by a final corrective
  pass (`ARCH-PURPOSE`).

## Done when

- [ ] The exchange model exposes first-class thinking and summary blocks.
- [ ] Initial loading folds thinking, summary, tool calls, and tool results but
      not questions, agent headers, ordinary answer text, or transient state.
- [ ] Streaming updates only the current insertion-point block and never parses
      the whole chat to repair folds.
- [ ] Foldable insertion points are created/resized incrementally while
      non-foldable insertion points perform no fold creation work.
- [ ] Finalization preserves correct folds without a whole-document corrective
      pass on success, cancellation, failure, or empty output, including
      multi-round tool exchanges.
- [ ] Fold updates never clear folds outside the changed block range, including
      user-created manual folds.
- [ ] Automated tests cover parser/model structure, initial folds, partial
      streaming, structural transitions across chunk boundaries, marker-like
      ordinary content, tool blocks, terminal outcomes, and final-state parity.
- [ ] Atlas documentation lists the canonical exchange structure and folding
      lifecycle.

## Plan

- [ ] Make parser/model answer sections use the canonical semantic block kinds.
- [ ] Track streaming insertion-point structure without whole-document parsing.
- [ ] Apply initial and streaming folds from model blocks without clearing
      unrelated folds.
- [ ] Verify terminal paths, performance bounds, documentation, and regressions.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.5 impl=0.04
item: lua-neovim design=0.6 impl=0.6
item: atlas-docs design=0.05 impl=0.04
item: milestone-review design=0.0 impl=0.2
design-buffer: 0.15
total: 2.2
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The implementation estimate uses
40% of the v2 Lua/Neovim and documentation implementation ranges; the detailed
approved spec and established exchange-model architecture reduce design cost.

## Log

### 2026-07-16

### 2026-07-17

Claimed the issue and mapped the split folding lifecycle. The approved design
makes semantic exchange blocks and the live insertion point the only folding
inputs: initial load parses once, streaming mutates one block at a time, and
fold UI work is skipped for non-foldable blocks (`ARCH-DRY`, `ARCH-PURE`,
`ARCH-PURPOSE`).

## Revisions

### 2026-07-17 — crystallized the synced bug report

Moved the operator's free-form report into a concrete Problem, Spec, and Done
when contract. Added the explicit requirement that streaming consult the live
exchange structure and update only its insertion point rather than reparsing
the document.

### 2026-07-17 — closed first spec-review gaps

Defined success, cancellation, failure, and empty-output fold behavior; scoped
incremental replacement to the active Parley-managed fold while preserving
completed and user-created folds outside its range; and made chunk-boundary and
ordinary marker-like content explicit regression cases.

### 2026-07-17 — implementation plan prepared

Decomposed the work around one pure incremental segment tracker and one thin
manual-fold shell. Estimated 2.2 focused ship-hours using estimate-logic-v3.1.
