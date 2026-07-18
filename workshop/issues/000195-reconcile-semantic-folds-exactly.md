---
id: 000195
status: working
deps: []
github_issue:
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 2.0
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

The projection includes only foldable block kinds (`thinking`, `summary`,
`tool_use`, and `tool_result`) with positive size. It derives all positions from
`exchange_model`; it does not inspect buffer text, existing folds, or editor
state (`ARCH-PURE`, `ARCH-PURPOSE`).

The Neovim adapter owns the manual folds created from that projection. Ownership
is per window and per stable exchange anchor, not per numeric exchange index:
inserting an earlier exchange may renumber later exchanges, while an extmark at
the exchange question moves with its logical text. Each owned fold also carries
stable start/end anchors so its current editor location can be retired after
buffer edits move or shrink it.

`reconcile_exchange(buf, win, model, exchange_index)` is the only incremental
semantic-fold mutation path. It resolves or creates the exchange anchor,
removes the folds previously owned by that exchange, computes the desired pure
projection, creates exactly those folds, and replaces the ownership ledger.
Unchanged exchanges receive no fold commands. User folds outside the changed
exchange are never deleted or recreated.

Initial chat setup reconciles every exchange once. Streaming reconciliation and
tool-loop append reconcile only the exchange they already identify. A changed
exchange is reconciled when its semantic block kinds, sizes, or positions may
have changed; text-only edits that preserve those inputs do not require fold
work. All consumers use the same projection and exchange-local adapter
(`ARCH-DRY`). Buffer/window teardown discards ownership anchors and ledger state.

If a user fold overlaps a Parley-owned semantic fold in the same changed
exchange, Parley guarantees only that it does not issue a document-wide fold
clear; overlapping manual folds are subject to Neovim's native merge/nesting
behavior. The defended compatibility contract is preservation of unrelated user
folds and untouched exchanges.

## Done when

- A streamed transition to a one-line summary produces exactly one summary fold
  and no fold on the following blank line.
- Desired semantic fold ranges are computed by a pure exchange-local function.
- Streaming and tool-loop paths reconcile only their changed exchange.
- Initial setup creates the same semantic folds through the shared reconciler.
- Inserting or editing an earlier exchange does not transfer ownership of a
  later exchange's folds.
- Unchanged exchanges and unrelated user folds retain their ranges and closed
  state.
- Ownership state is retired when its buffer or window becomes invalid.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.25 impl=0.02
item: lua-neovim design=0.45 impl=0.45
item: lua-neovim design=0.25 impl=0.35
item: atlas-docs design=0.03 impl=0.02
item: milestone-review design=0.0 impl=0.15
design-buffer: 0.03
total: 2.0
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
never retires the prior Parley-owned manual fold. Neovim can migrate that prior
range onto the blank margin when streaming replaces the semantic span. The
approved design makes folds a pure per-exchange projection and reconciles only
the exchange whose structure changed, keyed by stable anchors rather than
numeric exchange indices (`ARCH-PURE`, `ARCH-DRY`, `ARCH-PURPOSE`).
