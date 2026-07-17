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
  whole document during streaming or finalization. Because legacy thinking
  ends at a blank line while explicit thinking is known only when a later
  `🧠:[END]` arrives, treat a blank as a provisional legacy boundary and
  reconcile precisely the provisional span from that active response leg's
  `🧠:` opener through the later terminator. Inspect no earlier block or line.
  Ordinary writes still change only the insertion-point block; this bounded
  provisional-span replacement is the sole multi-block exception.
- Maintain folds incrementally from changed model blocks. Create or resize a
  fold only when the insertion-point block is foldable; skip fold work for
  non-foldable blocks. Completed tool blocks receive one fold when written.
  Never clear or rebuild folds outside the changed block range, including
  user-created manual folds. Since manual folds have no ownership identifier,
  maintenance must be append-only: widening may add an outer Parley fold, but
  it must never delete a fold to shrink or replace it. A contained older Parley
  fold may remain nested after widening; observable folding must match a fresh
  load at the outer semantic-block ranges, but exact nested fold sets need not.
- On success, cancellation, or transport failure, finalize any non-empty
  emitted semantic block using its current range and remove transient
  insertion state. Do not create a fold for an empty active block. Preserve
  completed-block and unrelated user folds on every terminal path.
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
- [ ] Streaming updates only the current insertion-point block, except that a
      late explicit thinking terminator may replace its bounded provisional
      opener-to-terminator span; it never parses the whole chat.
- [ ] Foldable insertion points are created/widened incrementally while
      non-foldable insertion points perform no fold creation work.
- [ ] Finalization preserves correct folds without a whole-document corrective
      pass on success, cancellation, failure, or empty output, including
      multi-round tool exchanges.
- [ ] Fold updates never clear folds outside the changed block range, including
      user-created manual folds.
- [ ] Automated tests cover parser/model structure, initial folds, partial
      streaming, structural transitions across chunk boundaries, marker-like
      ordinary content, tool blocks, terminal outcomes, and observable outer
      fold parity with a fresh load while permitting contained historical folds.
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

### 2026-07-17 — plan feasibility review

The first plan review found that future-dependent thinking grammar and unowned
Neovim manual folds made destructive resize unsafe. Revised the plan around one
shared active-response reducer, provisional legacy classification, and
append-only fold widening; added live-model cancellation repair, exact
bounded-read/terminal parity tests, performance verification, and per-chunk
commits.

### 2026-07-17 — closed second spec-review ambiguities

Removed contradictory fold-replacement permission, bounded late-terminator
reconciliation to its provisional opener-through-terminator span, and defined
final parity by observable outer semantic folds while permitting harmless
contained folds left by append-only widening.
