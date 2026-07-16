---
id: 000137
status: done
deps: []
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 4.2
started: 2026-06-25T11:18:14-07:00
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

## Spec

- Track a per-buffer pending chat lease when `chat_respond` starts a request.
  The lease records enough state to know whether callbacks may still mutate the
  transcript: target buffer, query id when known, target exchange/block role,
  and a buffer-change marker such as `changedtick`.
- The lease must distinguish out-of-band drift from Parley-owned writes. After a
  callback validates the lease and performs an expected transcript mutation, it
  commits the new `changedtick` as the next valid baseline.
- While a chat request/tool loop is pending, if the buffer's structural
  transcript changes due to undo/redo or other out-of-band edits, mark the lease
  invalid.
- Late async callbacks must check the lease before writing to the buffer. If the
  lease is invalid, they must stop/suppress further transcript mutation instead
  of streaming into stale positions.
- Guard every async transcript write owned by the request lifecycle: stream
  chunks, spinner/progress updates, progress cleanup, tool-loop block insertion,
  recursive resubmit, next-prompt insertion, topic-header updates, folds/cursor
  movement that depend on the stale model, and final callbacks that imply the
  transcript was updated.
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
- Multi-chunk normal streaming remains valid: Parley's own accepted writes update
  the lease baseline and do not self-cancel the request.
- Starting a tool-capable chat response and then undoing before tool-result
  insertion does not leave mismatched or misplaced `🔧:` / `📎:` blocks.
- Redo/undo drift during a pending request invalidates or cancels the request
  with a visible/logged message.
- Spinner/progress and topic-generation callbacks do not write stale transcript
  changes after invalidation.
- Normal streaming and recursive tool use still work when the transcript is not
  changed during the pending request.
- Tests cover at least one pending-stream invalidation path and one pending
  tool-loop invalidation path.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.8 impl=3.0
item: milestone-review design=0.0 impl=0.2
design-buffer: 0.30
total: 4.2
```

## Plan

Detailed design: [000137-undo-invalidates-pending-chat-plan.md](../plans/000137-undo-invalidates-pending-chat-plan.md).

- [x] Add a focused reproduction test for undo/drift during pending streaming.
- [x] Add a focused regression test that multi-chunk normal streaming does not
      self-invalidate.
- [x] Add a focused reproduction test for undo/drift before tool-loop result
      insertion.
- [x] Add focused coverage for spinner/progress and topic-generation callbacks
      after drift.
- [x] Introduce per-buffer chat leases and invalidation checks around async
      callbacks.
- [x] Cancel/suppress late writes when a lease is invalid.
- [x] Verify normal chat streaming and recursive tool use remain green.

## Log

### 2026-06-25
- 2026-06-25: closed — make test passed; make lint passed; focused coverage passed for stream, queued stream write, tool-loop, recursive resubmit, progress, topic spinner, and topic callback invalidation; actual is judgment-estimated because sdlc actual found no measurable activity; review verdict: FIX-THEN-SHIP
- Filed from design discussion while exploring #136. Current code has
  extmark-backed positions and a live `exchange_model`, but no undo/redo lease
  invalidation. Decision: use the safe invariant first — undo/redo or structural
  drift invalidates pending requests — and defer any attempt to reconcile leased
  cursors across undo history.
- Claimed and planned. `sdlc change-code` plan review caught two important
  design gaps: Parley-owned writes must commit their new `changedtick`, and the
  lease guard must cover spinner/progress plus topic callbacks, not just stream
  and tool-loop writes.
- Implemented `parley.chat_lease` and wired `chat_respond` to validate before
  late async transcript mutations, commit after accepted Parley-owned mutations,
  stop/suppress stale callbacks, and clear the lease on completion/abort.
- Added focused coverage for stream invalidation, multi-chunk streaming,
  tool-loop invalidation, stale progress, and stale topic callbacks.
- Side quest: normalized `rg --version` strings in grep-backed tool
  descriptions so golden payload tests do not fail on builds that include a
  ripgrep revision suffix.
- Verification:
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_lease_spec.lua"`: 5 passed.
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`: 28 passed.
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/parley_harness_golden_spec.lua"`: 7 passed.
  - `make test`: passed.
  - `make lint`: passed, 0 warnings / 0 errors in 223 files.
- Boundary review returned `REWORK`: recursive tool resubmit was validated
  before scheduling but not revalidated inside the queued recursive callback;
  atlas also needed the new lease lifecycle. Added the recursive resubmit guard,
  recursive drift/success coverage, and atlas lifecycle/tool-use traceability.
- Re-ran verification after the REWORK fix:
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`: 27 passed.
  - `make test`: passed.
  - `make lint`: passed, 0 warnings / 0 errors in 223 files.
- Boundary review returned `REWORK` again: stream validation was still one
  scheduler hop before the actual dispatcher buffer write, and `lease_commit`
  was separately scheduled. Moved lease validation/commit into dispatcher stream
  write hooks, added the queued-write drift regression, and extracted the
  duplicated grep backend version normalizer.
- Re-ran verification after the stream-write hook fix:
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`: 28 passed.
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/create_handler_spec.lua"`: 12 passed.
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/parley_harness_golden_spec.lua"`: 7 passed.
  - `make test`: passed.
  - `make lint`: passed, 0 warnings / 0 errors in 224 files.
- Boundary review returned `REWORK` a third time: topic-generation spinner
  frames were still direct async header writes outside the lease. Added
  lease-aware topic spinner write hooks and extended the stale-topic test to
  advance the spinner after undo.
- Re-ran verification after the topic-spinner hook fix:
  - `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua"`: 28 passed.
  - `make test`: passed.
  - `make lint`: passed, 0 warnings / 0 errors in 224 files.
- Boundary review returned `FIX-THEN-SHIP`: no blockers, but requested explicit
  redo coverage. Added a redo-drift late-stream regression; focused
  `chat_respond_spec.lua` now passes 29 tests.
