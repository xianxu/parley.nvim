---
id: 000195
status: working
deps: []
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 3.5
started: 2026-07-17T20:56:40-07:00
---

# Reconcile semantic folds exactly

## Problem

Semantic folds are calculated from `exchange_model`, but the Neovim adapter
only adds manual folds. When streaming changes a block from one semantic shape
to another, Neovim can shrink the old manual fold onto an adjacent blank line;
Parley then adds the new fold without retiring the old one. The result is a
ghost empty-line fold below a valid summary fold.

Clearing every manual fold is not acceptable because operators may create
their own folds. Recomputing every exchange after each streamed chunk is also
unnecessary: the response and tool-loop paths already know which exchange
changed.

## Spec

Semantic folds are an exchange-local pure projection:

`desired_semantic_folds(exchange_model, exchange_index) -> ordered ranges`

Each returned record is `{ block_index, kind, start_0, end_0 }`, where endpoints
are inclusive, zero-based buffer rows and records remain in block order. Only
the thin Neovim adapter converts them to one-based inclusive `:fold` ranges.
Pure unit coverage includes all four foldable kinds, zero-size exclusion,
margins, multiple blocks, and multiple exchanges.

The projection includes only foldable block kinds (`thinking`, `summary`,
`tool_use`, and `tool_result`) with positive size. It derives all positions from
`exchange_model`; it does not inspect buffer text, existing folds, or editor
state (`ARCH-PURE`, `ARCH-PURPOSE`).

Manual folds have no stable identity after their covered text changes. The
adapter therefore uses a mutation transaction rather than a persistent fold
ledger. `prepare_exchange_update(buf, win, model, exchange_index)` computes the
old pure projection while its manual folds are still intact and deletes one
fold at each projected start with window-local `normal! zd`, in reverse block
order. `reconcile_exchange(buf, win, model, exchange_index)` runs after the
buffer/model mutation and creates exactly the new pure projection. The caller's
current model plus exchange index identifies the changed exchange; no extmark or
historical numeric index is used as durable identity.

The mutation transaction is buffer-scoped. It snapshots every valid window
displaying the buffer, prepares the changed exchange in each before mutation,
then reconciles that exchange in every surviving snapshot window afterward. A
window appearing later hydrates normally. Streaming brackets each write to the
active exchange through a dispatcher `around_write` seam whose scope includes
the buffer write, live-model growth/reduction, and after-write callbacks;
reconciliation therefore runs as a `finally` action even for an empty reduction
or thrown write/callback. Tool-loop append uses the synchronous form around its
model and buffer mutation. Unchanged exchanges receive no fold commands.

On successful mutation, reconciliation uses the caller's updated live model. On
failure, the transaction attempts to rebuild a model from the current buffer
through the shared model-provider seam and reconciles the changed exchange in
each surviving window. If reparsing/reconciliation also fails, it leaves the
prepared semantic folds absent, preserves unrelated folds, and rethrows the
original error/traceback; recovery failure must never obscure the cause. Tests
inject failure after buffer mutation and after model mutation. All consumers use
the same transaction adapter (`ARCH-DRY`, `ARCH-PURPOSE`).

Initial chat setup and a later `BufWinEnter`/`WinEnter` parse the current buffer
through one model-provider seam and create the complete projection once in that
window. A lightweight initialized registry keyed only by `(buf, win)` prevents
repeated setup/window events from duplicating identical manual folds; it stores
no fold ranges or exchange ownership. Live transactions use their current model
and update no hydration identity. External structural edits do not trigger
automatic full rehydration; their native manual-fold movement remains outside
this regression's changed-exchange contract. `WinClosed`, `BufUnload`, and
`BufDelete` clear initialized entries, so window/buffer reuse starts cleanly.
Scheduled hydration checks validity and initialization again at execution time.

If a user fold overlaps a semantic fold in the changed exchange, `zd` may select
the innermost native manual fold; exact preservation of overlapping/nested folds
cannot be guaranteed because Neovim exposes no fold IDs. The defended contract
is explicit and testable: adjacent/partially overlapping cases follow native
`zd` behavior, while unrelated user folds and every untouched exchange remain
unchanged. Parley never issues `zE` or a document-wide fold clear.

## Done when

- A streamed transition to a one-line summary produces exactly one summary fold
  and no fold on the following blank line.
- Desired semantic fold ranges are computed by a pure exchange-local function.
- Streaming and tool-loop paths reconcile only their changed exchange.
- Every window showing the changed buffer converges for that exchange.
- Initial setup creates the same semantic folds through the shared reconciler.
- Unchanged exchanges and unrelated user folds retain their ranges and closed
  state.
- A window opened after initial setup receives independent semantic folds;
  closing it does not disturb another window's folds.
- Repeated setup and stale scheduled hydration are idempotent and harmless after
  buffer/window teardown; buffer reuse begins with no retained fold state.
- Actual streaming and tool-loop entry points bracket mutations for only their
  known exchange, including empty reductions and failures, and no add-only
  semantic-fold consumer remains.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.25 impl=0.02
item: lua-neovim design=0.75 impl=0.75
item: lua-neovim design=0.35 impl=0.55
item: lua-neovim design=0.15 impl=0.35
item: atlas-docs design=0.03 impl=0.02
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.10
total: 3.5
```

## Plan

- [x] Write and approve the durable implementation plan.
- [ ] Add RED pure and Neovim integration regressions for exact localized reconciliation.
- [ ] Implement exchange-local fold projection, mutation transaction, and reconciliation.
- [ ] Route setup, streaming, and tool-loop consumers through the shared reconciler.
- [ ] Update atlas and run focused, changed, and full verification.

## Log

### 2026-07-17

Root cause: `_apply_block_fold` issues `:fold` for the latest block range but
never retires the prior semantic manual fold. Neovim can migrate that prior
range onto the blank margin when streaming replaces the semantic span. The
approved design makes folds a pure per-exchange projection and brackets only
the known changed exchange's mutation (`ARCH-PURE`, `ARCH-DRY`,
`ARCH-PURPOSE`).

## Revisions

### 2026-07-17 — Fresh-eyes spec review

Defined inclusive zero-based projection records and adapter-only Ex conversion;
specified ranged extmark gravity/invalidation plus registry synchronization and
orphan retirement; widened setup/cleanup to the per-window lifecycle; and added
acceptance coverage for late splits, question replacement, exchange deletion,
insertion before an exchange, and buffer-number reuse.

### 2026-07-17 — Plan review identity spike

Direct Neovim experiments disproved the extmark-ledger design: insertion at an
anchor and full-line replacement do not preserve a question-start identity
under one gravity configuration, and a migrated manual fold exposes no fold ID
that endpoint anchors can delete reliably. Replaced persistent ownership with a
localized prepare-before-mutation/reconcile-after-mutation transaction, defined
the exact window-local `zd` behavior and overlap limitation, made late-window
hydration explicitly reparse through one provider, added real consumer/race
tests, and raised the estimate from 2.0h to 3.0h.

### 2026-07-17 — Transaction scope and failure review

Expanded prepare/reconcile across every window displaying the changed buffer;
placed streaming writes and model callbacks inside a dispatcher `around_write`
finally boundary; defined parse-from-buffer recovery without masking the
original error; and added a lightweight per-window initialization registry so
repeat setup/events cannot create duplicate identical folds. Explicitly scoped
external structural-edit rehydration out of this regression.
