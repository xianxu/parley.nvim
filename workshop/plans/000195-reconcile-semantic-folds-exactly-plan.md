# Localized Semantic Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each changed exchange's semantic folds converge exactly to a pure projection of its model without touching unchanged exchanges or unrelated user folds.

**Architecture:** Extract a pure fold projection from the exchange model, then render it through a buffer-owned exchange-anchor registry and per-window ownership ledger. Initial/window setup reconciles every exchange, while streaming and tool-loop paths call the same adapter for only the exchange they changed.

**Tech Stack:** Lua, Neovim extmarks/manual folds/autocmds, Plenary/Busted, `exchange_model`.

---

## Core concepts

### Pure entities

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | new |

- **`desired_folds(model, exchange_index)`** — returns ordered
  `{ block_index, kind, start_0, end_0 }` records for positive-size thinking,
  summary, tool-use, and tool-result blocks.
  - **Relationships:** One exchange projects to zero or more semantic fold
    ranges; ranges refer back to one model block.
  - **DRY rationale:** Setup, streaming, and tool-loop must not each derive fold
    coordinates or repeat the foldable-kind policy (`ARCH-DRY`).
  - **Future extensions:** New semantic kinds widen the policy in this single
    module.

### Integration points

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| `FoldOwnershipRegistry` | INTEGRATION | `lua/parley/tool_folds.lua` | new | buffer extmarks and per-window state |
| `reconcile_exchange` | INTEGRATION | `lua/parley/tool_folds.lua` | new | Neovim manual fold commands |
| `fold window lifecycle` | INTEGRATION | `lua/parley/tool_folds.lua` | modified | `BufWinEnter`/`WinEnter`/`WinClosed`/buffer teardown |

- **`FoldOwnershipRegistry`** — one buffer registry owns ranged exchange
  extmarks; each window ledger maps stable exchange extmark IDs to owned fold
  endpoint extmarks.
  - **Injected into:** The reconciliation adapter receives model/buffer/window
    inputs and delegates desired ranges to the pure projection.
  - **Future extensions:** Diagnostic inspection of owned fold identities.
- **`reconcile_exchange`** — synchronizes exchange anchors, retires only that
  exchange's owned folds in the target window, then renders its exact desired
  projection.
  - **Injected into:** Initial hydration, streaming span reconciliation, and
    tool-loop append.
  - **Future extensions:** Batched reconciliation of an explicit changed-ID
    set, without whole-document mutation.
- **`fold window lifecycle`** — hydrates missing `(window, exchange-anchor)`
  entries and retires only the state whose window/buffer ended.
  - **Injected into:** `tool_folds.setup`; no second lifecycle owner is added.
  - **Future extensions:** None planned.

## Chunk 1: Pure projection and exact ownership adapter

### Task 1: Extract the pure exchange fold projection

**Files:**
- Create: `lua/parley/fold_projection.lua`
- Create: `tests/unit/fold_projection_spec.lua`
- Modify: `tests/unit/tool_folds_spec.lua`

- [ ] **Step 1: Write RED pure projection tests**

Create model fixtures covering all four foldable kinds, non-foldable/zero-size
blocks, margins between blocks, multiple foldable blocks, and a second exchange.
Assert exact ordered inclusive zero-based records. Also assert the module source
contains no `vim`, `nvim`, filesystem, clock, or process dependency.

- [ ] **Step 2: Run the pure spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fold_projection_spec.lua" -c "qa!"`

Expected: FAIL because `parley.fold_projection` does not exist.

- [ ] **Step 3: Implement the minimal projection**

Export `desired_folds(model, exchange_index)`. Keep the foldable-kind set in
this module only. Use `model:block_start` and `model:block_end` directly; return
no editor-specific coordinates.

- [ ] **Step 4: Run projection/unit specs and verify GREEN**

Run the new spec and `tests/unit/tool_folds_spec.lua`. Expected: all pass with
the old policy test removed or redirected to the projection owner.

### Task 2: Reproduce ghost folds and ownership non-transfer

**Files:**
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED exact-reconciliation regressions**

Add real-window tests that:

1. create a fold for a streamed semantic span, mutate/reduce it into a one-line
   summary plus blank margin, reconcile that exchange, close all semantic folds,
   and enumerate every row to prove the only owned fold is the summary row;
2. create two exchanges plus an unrelated user fold, reconcile only exchange 1,
   and spy on the adapter's exchange target/ledger to prove exchange 2 receives
   no delete/create commands and both untouched folds retain range/closed state;
3. insert an exchange before an anchored exchange and prove its extmark identity
   and fold ownership move with the logical exchange;
4. replace a question line in place and reuse its valid ranged identity;
5. delete an exchange and prove invalid/orphan ownership is retired rather than
   transferred to a new exchange at that row;
6. delete/recreate a buffer number and prove no old registry state survives.

- [ ] **Step 2: Run the integration spec and verify RED**

Run the exact `tool_folds_spec.lua` command. Expected: the ghost-fold assertion
finds the extra blank-line fold and the new reconciliation/registry APIs are
missing.

### Task 3: Implement buffer identities and localized reconciliation

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add one module namespace and ownership state**

Store state by buffer, then window, then exchange extmark ID. Exchange marks are
ranged across the question with `right_gravity=false`,
`end_right_gravity=true`, and `invalidate=true`. Owned fold range marks use the
same invalidating behavior. Expose test-only state inspection/reset seams rather
than duplicating registry logic in tests.

- [ ] **Step 2: Implement registry synchronization**

For the current model, query existing exchange anchors with details. Retire
invalid anchors and anchors whose start row no longer matches any current
question start from every window ledger. Reuse a valid identity only at the
same current question start; create identities for missing starts. Never key
ownership by exchange index.

- [ ] **Step 3: Implement `reconcile_exchange`**

Resolve the stable exchange identity, delete only the target window's prior
owned manual folds using their current anchored positions, compute
`desired_folds`, convert each range to one-based inclusive Ex coordinates,
create the folds, and replace only that ledger entry. Invalid buffer/window or
missing exchange returns without mutation. Preserve fold closed state by
closing newly rendered semantic folds; do not issue `zE`/document-wide clears.

- [ ] **Step 4: Verify GREEN and exact locality**

Run unit and integration fold specs. Expected: one summary fold, no blank-line
ghost, stable ownership through insertion/replacement, orphan cleanup after
deletion/reuse, and unchanged user/other-exchange folds.

## Chunk 2: Consumer and window lifecycle convergence

### Task 4: Route every semantic-fold consumer through exchange reconciliation

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `lua/parley/tool_loop.lua`
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/chat_respond_spec.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED consumer-locality tests**

In streaming, instrument the reconciliation observer and assert a semantic span
change calls it once for `target_idx` and never for another exchange. In
tool-loop append, assert only `exchange_idx` is reconciled. Keep the existing
bounded streaming-read assertions unchanged.

- [ ] **Step 2: Replace `_apply_block_fold` consumers**

After `answer_structure.reduce` updates the current model, call
`reconcile_exchange(buf, win, model, target_idx)` once, outside the changed-block
loop. After tool-loop appends a block, call the same adapter once for
`exchange_idx`. Delete `_apply_block_fold` and its parallel add-only behavior
(`ARCH-DRY`, `ARCH-PURPOSE`).

- [ ] **Step 3: Run consumer specs and verify GREEN**

Run `chat_respond_spec.lua` and `tool_folds_spec.lua`. Expected: locality probes
see only the changed exchange and all prior streaming/tool folds remain correct.

### Task 5: Hydrate and retire per-window ownership

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED late-window and cleanup tests**

Set up a buffer in window A, open window B afterward, trigger the production
window event, and prove B receives independent semantic folds without commands
against A. Close B and prove A's ledger/folds survive. Trigger `BufUnload` and
`BufDelete` and prove all buffer registry state/anchors are retired.

- [ ] **Step 2: Implement idempotent lifecycle wiring**

`setup(buf)` configures the current window and installs one augroup-backed
lifecycle owner. `BufWinEnter`/`WinEnter` configures the entered window and
reconciles only missing exchange identities for that window. `WinClosed`
retires only that window ledger. `BufUnload`/`BufDelete` clears all buffer state
and namespace marks. Repeated events are idempotent.

- [ ] **Step 3: Run lifecycle integration specs and verify GREEN**

Run `tool_folds_spec.lua`; expected: late windows hydrate independently and all
teardown assertions pass.

### Task 6: Map and verify the finalized architecture

**Files:**
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

- [ ] **Step 1: Update atlas**

Map the pure per-exchange projection, stable exchange anchors, per-window owned
fold ledgers, localized consumer calls, and lifecycle cleanup. Add the new pure
module/spec to traceability.

- [ ] **Step 2: Run focused verification**

Run:

- exact pure projection spec;
- exact `tool_folds_spec.lua`;
- exact `chat_respond_spec.lua`;
- `make test-spec SPEC=chat/lifecycle`;
- `make test-changed`;
- `git diff --check`.

Expected: all exit zero with no failures.

- [ ] **Step 3: Run full verification**

Run `make test`. If the known parallel `tools_builtin_find_spec`/`.test-tmp`
race appears, verify its exact spec independently and run `make test JOBS=1`;
record both outcomes without weakening the #195 regression gate.

- [ ] **Step 4: Update issue evidence and commit**

Tick completed issue/plan checkboxes and append RED/GREEN/final verification to
the issue log. Commit implementation and docs with #195 and the required
co-author trailer; do not close or land until the operator smoke-tests the
folding behavior.
