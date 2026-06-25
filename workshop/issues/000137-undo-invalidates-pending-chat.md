---
id: 000137
status: working
deps: [000136]
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours:
started: 2026-06-25T11:18:14-07:00
---

# undo invalidates pending chat requests

## Problem

Parley chat currently keeps live async state while a request is pending:
`chat_respond` parses the buffer, builds an `exchange_model`, inserts a response
placeholder, streams chunks into that slot, then may append tool-call/tool-result
blocks and recursively resubmit. Position handling is partly robust because
streaming uses extmark-backed handles and the tool loop appends through the live
model.

Undo/redo is not covered by that safety model. A user can start a request and
then press `u` / `<C-r>` while the request or a recursive tool round is still
pending. Vim may remove or restore structural transcript text underneath the
live model: answer header, stream placeholder, spinner block, tool blocks, or
the target exchange itself. The async callback can then continue writing chunks,
tool results, cleanup, topic updates, or a next prompt using stale model state.

This is the same class of problem as "leased cursor" invalidation: during a
pending async operation Parley has borrowed a structural insertion point. If the
serialized transcript changes through undo/redo, that lease may now point to
void or to a different semantic slot.

We explicitly choose the simple invariant for now: **undo/redo or structural
transcript drift invalidates pending chat requests.** Do not attempt to reconcile
leases across undo history yet. Reconciliation by reparsing plus extmarks/tool
IDs is possible, but too complex for the current need and easy to get subtly
wrong.

## Spec

- Track a per-buffer pending chat lease when `chat_respond` starts a request.
  The lease records enough state to know whether callbacks may still mutate the
  transcript: target buffer, query id when known, target exchange/block role,
  and a buffer-change marker such as `changedtick`.
- While a chat request/tool loop is pending, if the buffer's structural
  transcript changes due to undo/redo or other out-of-band edits, mark the lease
  invalid.
- Late async callbacks must check the lease before writing to the buffer. If the
  lease is invalid, they must stop/suppress further transcript mutation instead
  of streaming into stale positions.
- Invalidating a lease should cancel or stop the active task where possible and
  surface a visible/logged message such as "Parley request cancelled because the
  chat transcript changed."
- The invariant is conservative: Parley may cancel a request that could
  theoretically have been reconciled. It must not write tool results or response
  text into the wrong exchange.
- This issue is scoped to current chat/tool-loop behavior. The future artifact
  side-chat design in #136 may reuse the same lease invariant, but should not
  block this bugfix.

## Done when

- Starting a chat response and then undoing the inserted response placeholder
  before completion does not allow late stream chunks to corrupt the transcript.
- Starting a tool-capable chat response and then undoing before tool-result
  insertion does not leave mismatched or misplaced `🔧:` / `📎:` blocks.
- Redo/undo drift during a pending request invalidates or cancels the request
  with a visible/logged message.
- Normal streaming and recursive tool use still work when the transcript is not
  changed during the pending request.
- Tests cover at least one pending-stream invalidation path and one pending
  tool-loop invalidation path.

## Plan

- [ ] Add a focused reproduction test for undo/drift during pending streaming.
- [ ] Add a focused reproduction test for undo/drift before tool-loop result
      insertion.
- [ ] Introduce per-buffer chat leases and invalidation checks around async
      callbacks.
- [ ] Cancel/suppress late writes when a lease is invalid.
- [ ] Verify normal chat streaming and recursive tool use remain green.

## Log

### 2026-06-25

- Filed from design discussion while exploring #136. Current code has
  extmark-backed positions and a live `exchange_model`, but no undo/redo lease
  invalidation. Decision: use the safe invariant first — undo/redo or structural
  drift invalidates pending requests — and defer any attempt to reconcile leased
  cursors across undo history.
