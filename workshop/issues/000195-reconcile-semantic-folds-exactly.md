---
id: 000195
status: working
deps: []
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 3.0
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

Streaming brackets each write to the active exchange with prepare/reconcile.
Tool-loop append prepares its exchange before inserting and reconciles it after
the model and buffer change. Unchanged exchanges receive no fold commands. The
transaction restores the current projection even when the mutation raises,
then rethrows the original error. All consumers use the same transaction
adapter (`ARCH-DRY`, `ARCH-PURPOSE`).

Initial chat setup and a later `BufWinEnter`/`WinEnter` parse the current buffer
through one model-provider seam and create the complete projection once in that
window. Live streaming/tool-loop transactions use their already-current live
model instead of reparsing. Scheduled hydration checks buffer/window validity
at execution time and is idempotent when setup or window events repeat; no
persistent ownership ledger remains to clean up or transfer across buffer reuse.

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
- Initial setup creates the same semantic folds through the shared reconciler.
- Unchanged exchanges and unrelated user folds retain their ranges and closed
  state.
- A window opened after initial setup receives independent semantic folds;
  closing it does not disturb another window's folds.
- Repeated setup and stale scheduled hydration are idempotent and harmless after
  buffer/window teardown; buffer reuse begins with no retained fold state.
- Actual streaming and tool-loop entry points bracket mutations for only their
  known exchange, and no add-only semantic-fold consumer remains.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.25 impl=0.02
item: lua-neovim design=0.75 impl=0.75
item: lua-neovim design=0.35 impl=0.55
item: atlas-docs design=0.03 impl=0.02
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.08
total: 3.0
```

## Plan

- [ ] Write and approve the durable implementation plan.
- [ ] Add RED pure and Neovim integration regressions for exact localized reconciliation.
- [ ] Implement exchange-local fold projection, ownership, and reconciliation.
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
