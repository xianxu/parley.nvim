---
id: '000137'
status: done
started: 2026-06-25T11:18:14-07:00
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 4.2
actual_hours: 0.8
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
