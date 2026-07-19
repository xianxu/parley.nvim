---
id: 000195
status: codecomplete
deps: []
github_issue:
created: 2026-07-17
updated: 2026-07-18
estimate_hours: 3.5
started: 2026-07-17T20:56:40-07:00
actual_hours: 6.56
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
cannot be guaranteed because Neovim exposes no fold IDs. The defended
live-update contract is explicit and testable: adjacent/partially overlapping
cases follow native `zd` behavior, while unrelated user folds and every
untouched exchange remain unchanged. Initial window hydration is the sole
exception: it issues `zE` once before rebuilding the complete semantic
projection so restored orphan folds cannot survive.

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
- [x] Add RED pure and Neovim integration regressions for exact localized reconciliation.
- [x] Implement exchange-local fold projection, mutation transaction, and reconciliation.
- [x] Route setup, streaming, and tool-loop consumers through the shared reconciler.
- [x] Update atlas and run focused, changed, and full verification.

## Log

### 2026-07-17

Root cause: `_apply_block_fold` issues `:fold` for the latest block range but
never retires the prior semantic manual fold. Neovim can migrate that prior
range onto the blank margin when streaming replaces the semantic span. The
approved design makes folds a pure per-exchange projection and brackets only
the known changed exchange's mutation (`ARCH-PURE`, `ARCH-DRY`,
`ARCH-PURPOSE`).

Implementation now projects fold ranges from `exchange_model` without Neovim,
brackets streaming writes and synchronous tool appends by their known exchange,
and reconciles that exchange across every displayed window. Regression coverage
proves the one-line summary has no following blank-line fold, unrelated folds
survive, failure recovery retains the original error, hydration is idempotent,
and the real tool-loop consumer is localized. RED evidence included the missing
projection module, missing prepare/reconcile APIs, and missing dispatcher
`around_write` seam. GREEN evidence: focused projection/fold/dispatcher/tool-loop/
chat-response specs and full `make test` (306 linted files, all tests passing).

Operator smoke testing exposed a second convergence case: a live tool-loop
transaction can finish before scheduled initial hydration, after which the
add-only hydration pass nested an identical fold around the tool block and its
trailing margin. A production-ordered RED test measured fold level 2. Hydration
and changed-exchange prepare now retire every native layer at each projected
semantic start before rendering exactly one fold; the tool-use, tool-result,
and trailing blank rows assert levels 1, 1, and 0 respectively (`ARCH-PURE`,
`ARCH-PURPOSE`).

A follow-up smoke test found an already-migrated one-line summary fold could
survive hydration because cleanup only visited desired fold starts. The pure
projection now also returns each semantic block's trailing margin row; the
adapter clears fold layers there before rendering. The production-shaped RED
case began with a fold on the blank row and now converges to summary level 1,
blank level 0 (`ARCH-PURE`, `ARCH-PURPOSE`).

Exact inspection of the reported brain chat corrected that diagnosis. The
parser records the summary at line 1466, but `from_parsed_chat` projects it at
1467 because it discards absolute spans and assumes a blank between every
exchange; the first missing historical separator is between lines 618–619 and
shifts every later exchange by one. The approved direction is therefore to
preserve gaps implied by exchange/item spans and fold only stated item bounds,
removing inferred trailing-margin cleanup (`ARCH-DRY`, `ARCH-PURE`,
`ARCH-PURPOSE`).

Implemented the absolute-span root correction. Parsed question/answer spans now
compile to explicit exchange-leading and intra-exchange gaps; zero-size blocks
contribute neither size nor gap, and streaming replacements derive gaps from
their already-bounded reducer spans. The reported file now projects summary
1466–1466 and the next question at 1468. The inferred trailing-margin cleanup
was removed; a synthetic marginless transcript and a real adjacent streamed
summary both fold only their physical marker rows.

Verification after the correction: exchange-model, projection, fold,
dispatcher, tool-loop, chat-response, mapped `chat/exchange_model`, and mapped
`chat/lifecycle` suites pass; streaming retains its bounded active-segment read.
`make lint` reports 0 warnings/errors across 306 files, `git diff --check`
passes, and `make test JOBS=1` passes every unit, architecture, and integration
spec. Awaiting the operator's exact 1466/1467 smoke test before commit/close.

The operator's 1466/1467 smoke still showed a second fold on the blank row.
The model and fresh projection were correct; a RED integration test proved the
remaining layer was restored window-local manual-fold state. Hydration had been
additive, deleting only folds at currently desired starts, so an orphan at 1467
could not be reached from the desired 1466 range. Initial window hydration now
clears restored manual folds once and rebuilds the complete projection; live
streaming remains changed-exchange-local. The regression measures summary level
1 and blank level 0 (`ARCH-PURE`, `ARCH-PURPOSE`).

Operator smoke verification after restarting Neovim confirmed the reported
folding issue is fixed. The one-line summary folds without capturing its
following blank row; #195 is ready for the close boundary.

The close review found the original normative Spec still prohibited `zE` even
though the later deterministic-hydration revision intentionally introduced it.
The Spec now names initial hydration as the sole document-wide-clear boundary;
live response/tool transactions remain exchange-local. Review-promised fault
coverage is split across the owning integration seams: dispatcher bracketing,
fold transaction recovery, multi-window convergence, and scheduled invalid
target handling (`ARCH-PURE`, `ARCH-PURPOSE`).

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

### 2026-07-18 — Hydration/live-transaction race
- 2026-07-18: closed — Full make test JOBS=1 and lint pass across 306 files; exact reported transcript hydrates with fold levels 1466=1, 1467=0, 1468=0; operator smoke confirms summaries, tool calls/results, and trailing blanks fold correctly.; review verdict: FIX-THEN-SHIP

Changed hydration from add-once to exact convergence after operator testing
showed that a live tool transaction can create folds before its scheduled
initial hydration. The adapter now removes all native fold layers at projected
semantic starts before rendering one semantic projection, allowing hydration
and later exchange transactions to repair duplicate levels while retaining the
documented overlapping-user-fold limitation.

### 2026-07-18 — Migrated trailing-margin cleanup

Extended the pure projection with model-owned trailing margin rows after smoke
testing showed that an already-migrated one-line ghost sits outside all desired
fold starts. Reconciliation clears those rows before rendering, making the
blank-line invariant self-healing during hydration and live updates.

### 2026-07-18 — Absolute-span root correction

Revised the plan after proving the remaining blank fold is a model coordinate
error, not a migrated Neovim fold. `parsed_chat` already states absolute item
bounds; the model must preserve their implied gaps instead of reconstructing a
canonical document. Fold reconciliation will target only foldable item spans
inside the selected exchange, making inter-exchange gaps irrelevant.

### 2026-07-18 — Deterministic initial hydration

Initial window hydration now replaces restored manual-fold state before
rendering the full semantic projection. This is the one lifecycle boundary
where document-wide cleanup is required to make folds a pure function of
content; subsequent response/tool mutations retain localized per-exchange
prepare/reconcile behavior.
