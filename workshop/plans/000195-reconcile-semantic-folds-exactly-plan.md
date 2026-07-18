# Localized Semantic Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make semantic folds converge to a pure projection of only the exchange being mutated, without ghost folds or document-wide fold clearing.

**Architecture:** A pure module projects one exchange's model blocks into exact fold ranges. Because Neovim manual folds have no stable IDs after mutation, consumers bracket a known exchange mutation across every window displaying the buffer: delete its old projected folds while intact, perform the buffer/model change, then render its new projection; initial and late-window hydration parse once and render all exchanges with lightweight per-window initialization state.

**Tech Stack:** Lua, Neovim manual folds/window events, Plenary/Busted, `exchange_model`.

---

## Core concepts

### Pure entities

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | new |

- **`desired_folds(model, exchange_index)`** — ordered
  `{ block_index, kind, start_0, end_0 }` records for positive-size thinking,
  summary, tool-use, and tool-result blocks.
  - **Relationships:** One exchange projects to zero or more inclusive
    zero-based ranges; each range refers to one model block.
  - **DRY rationale:** Setup, streaming, and tool-loop share policy and
    coordinates (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** New foldable semantic kinds widen here only.

### Integration points

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| `prepare_exchange_update` | INTEGRATION | `lua/parley/tool_folds.lua` | new | buffer-window snapshot + window-local `normal! zd` |
| `reconcile_exchange` | INTEGRATION | `lua/parley/tool_folds.lua` | new | window-local `:fold` creation |
| `hydrate_window` | INTEGRATION | `lua/parley/tool_folds.lua` | modified | parser/model provider + initialized registry + window events |
| `around_write` | INTEGRATION | `lua/parley/dispatcher.lua` | new | guaranteed streaming mutation finalization |

- **`prepare_exchange_update`** — snapshots all windows showing the buffer and
  deletes the old projection in each before mutation can shrink or migrate it.
  It visits projected starts in reverse order and runs one `normal! zd` only
  when `foldclosed(start_1)` or `foldlevel(start_1)` proves a fold exists there.
  - **Injected into:** Streaming `before_write` and tool-loop append.
  - **Future extensions:** A synchronous `with_exchange_update` wrapper for
    callers whose mutation is not split across callbacks.
- **`reconcile_exchange`** — renders exactly the current pure projection after
  mutation, in one specified window. It does not inspect other exchanges.
  - **Injected into:** Streaming `after_write`, tool-loop append, and hydration.
  - **Future extensions:** Explicit list of changed exchange indexes.
- **`hydrate_window`** — obtains a fresh model through one provider seam and
  renders every exchange once for a newly entered window. A `(buf,win)`
  initialized registry prevents duplicate identical folds and is cleared on
  window/buffer teardown. Live consumers use their current model and never
  reparse on success.
  - **Injected into:** `setup`, `BufWinEnter`, and `WinEnter`.
  - **Future extensions:** None planned.
- **`around_write`** — wraps dispatcher buffer write, line/model callbacks, and
  `after_write` so fold finalization runs on success, empty reductions, and
  thrown callbacks.
  - **Injected into:** `dispatcher.create_handler` options.
  - **Future extensions:** Other buffer-state transactions needing finally.

## Chunk 1: Pure projection and mutation transaction

### Task 1: Extract the pure exchange projection

**Files:**
- Create: `lua/parley/fold_projection.lua`
- Create: `tests/unit/fold_projection_spec.lua`
- Modify: `tests/unit/tool_folds_spec.lua`

- [ ] **Step 1: Write RED pure tests**

Build `exchange_model` fixtures for all four foldable kinds, zero-size and
ordinary blocks, margins, multiple blocks, and multiple exchanges. Assert exact
ordered inclusive zero-based records. Load the module with `_G.vim=nil` in a
plain isolated Lua package context to prove purity without brittle source grep.

- [ ] **Step 2: Run RED**

Run the exact new spec with `PlenaryBustedFile`; expect module-not-found.

- [ ] **Step 3: Implement `desired_folds`**

Own the foldable-kind set only in `fold_projection.lua`; use
`model:block_start/end` and return no Neovim coordinates.

- [ ] **Step 4: Run GREEN**

Run the new spec and `tests/unit/tool_folds_spec.lua`; expect all pass and the
old duplicated policy owner removed.

### Task 2: Prove exact `zd` behavior and reproduce the ghost

**Files:**
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED production-shaped tests**

With a real window/manual folds:

1. create the pre-summary streamed semantic fold, perform the actual
   `stream_replace_at_line`/model-span transition, then use the current add-only
   path and enumerate fold starts to prove the blank-line ghost exists;
2. in two real windows, delete the projected fold before that same mutation,
   render the new summary in both, and assert exactly one summary fold per
   window and none on either following blank line;
3. pin `normal! zd` behavior for open and closed semantic folds;
4. assert adjacent and disjoint user folds survive prepare/reconcile unchanged;
5. document native behavior for nested and partially overlapping user folds
   without promising identity Neovim does not expose.

- [ ] **Step 2: Run RED**

Run `tests/integration/tool_folds_spec.lua`; expect the ghost assertion to
reproduce and the prepare/reconcile APIs to be absent.

### Task 3: Implement localized prepare/reconcile

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Implement exact old-fold deletion**

`prepare_exchange_update(buf, model, exchange_index)` validates the buffer and
exchange, snapshots `win_findbuf(buf)`, projects old ranges, and in each valid
window visits starts bottom-to-top. At each start it moves the cursor
temporarily and runs `normal! zd` only when a fold level exists; it restores the
cursor. It returns the window snapshot for post-mutation reconciliation and
never runs `zE` or ranges across the exchange.

- [ ] **Step 2: Implement exact new-fold rendering**

`reconcile_exchange` projects the current exchange for one window, converts
only at the Ex boundary to one-based inclusive ranges, creates each manual fold,
and closes it. A buffer-scoped finalizer runs it for each surviving snapshot
window. Invalid targets are no-ops. Add a test observer receiving
`{ phase, win, exchange_index, ranges }` for locality assertions.

- [ ] **Step 3: Add failure restoration seam**

For synchronous callers, `with_exchange_update(..., mutate)` prepares all
windows, executes `mutate` under `xpcall`, and on success reconciles from the
updated live model. On error it reparses current buffer state through the shared
model provider and attempts restoration; recovery failures leave prepared folds
absent and never replace the original traceback. Add failures after buffer
mutation and after model mutation. Streaming uses the same finalization policy
through `dispatcher.create_handler`'s `around_write` seam.

- [ ] **Step 4: Run GREEN**

Run fold unit/integration specs; expect exact summary-only convergence and the
documented user-fold cases.

## Chunk 2: Real consumers and window hydration

### Task 4: Bracket the actual streaming consumer

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [ ] **Step 1: Add RED streaming locality test**

Through `M.respond` and its real `create_handler`, stream a summary transition
in exchange 2 displayed in two windows while exchange 1 and unrelated user
folds are closed in both. Assert observer sequence prepare/reconcile for
exchange 2 in both windows, no event for exchange 1, exact absence of a
blank-line fold, and unchanged earlier/user folds. Add an empty-reduction chunk,
an injected stream-write failure, and an injected post-model-update failure;
each must run recovery/finalization and preserve the original error. Retain
bounded active-segment read assertions.

- [ ] **Step 2: Wire before/after callbacks**

Add `opts.around_write(qid, chunk, write_fn)` to `dispatcher.create_handler` and
place the actual buffer write, `on_lines_changed`, and `after_write` inside
`write_fn`. Chat response supplies a wrapper that prepares exchange 2 in all
snapshot windows, invokes `write_fn`, then always finalizes from the live model
or parse-from-buffer recovery. Ensure `#replacements == 0` still reaches the
finalizer. Delete `_apply_block_fold` use.

- [ ] **Step 3: Verify streaming GREEN**

Run `chat_respond_spec.lua`; expect the new sequence/range assertions and all
existing streaming tests to pass.

### Task 5: Bracket the actual tool-loop consumer

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Create or Modify: `tests/integration/tool_loop_spec.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED real-entry-point test**

Call `_append_section_to_answer` with a real two-window buffer/model and
observer. Assert only its supplied `exchange_idx` receives prepare/reconcile in
both windows, the appended tool block folds in both, and other exchange/user
folds are unchanged.

- [ ] **Step 2: Use `with_exchange_update`**

Wrap the existing model add plus buffer insert in the shared transaction. Remove
the add-only `_apply_block_fold` call.

- [ ] **Step 3: Enforce the single mutation path**

Add an architecture assertion that production code contains no
`_apply_block_fold` and no add-only semantic fold creation outside
`tool_folds.lua`; decide `apply_folds` becomes the hydration wrapper rather than
a parallel incremental API (`ARCH-DRY`, `ARCH-PURPOSE`).

- [ ] **Step 4: Verify tool-loop GREEN**

Run exact tool-loop and fold specs; expect all pass.

### Task 6: Hydrate initial and late windows safely

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [ ] **Step 1: Add RED lifecycle tests**

Inject one `model_provider(buf)` that reparses current lines. Test initial setup,
setup called twice, a second window opened after setup and hydrated via the real
window event, independent window folds, close of window B leaving A unchanged,
and a scheduled hydration callback delivered after buffer deletion/window close
performing no mutation or error.

- [ ] **Step 2: Implement idempotent hydration**

`hydrate_window(buf, win, model_provider)` checks validity and the lightweight
initialized registry, configures fold options, obtains one fresh model, and
uses the shared reconciler for every exchange before marking `(buf,win)` done.
`setup` installs one augroup owner for `BufWinEnter`/`WinEnter`, `WinClosed`,
`BufUnload`, and `BufDelete`, and schedules hydration with captured IDs. Repeat
setup/events skip initialized windows; teardown clears the corresponding keys.

- [ ] **Step 3: Verify lifecycle GREEN**

Run `tool_folds_spec.lua`; expect all window/race tests pass.

### Task 7: Map, verify, and hand off

**Files:**
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

- [ ] **Step 1: Update atlas and traceability**

Map pure projection, exchange-local mutation bracketing, real consumers, and
late-window hydration. Add the new pure module/spec and tool-loop integration
test mapping.

- [ ] **Step 2: Run focused verification**

Run exact projection, fold, chat-respond, and tool-loop specs; mapped
`make test-spec SPEC=chat/lifecycle`; `make test-changed`; and
`git diff --check`. Expected: all zero.

- [ ] **Step 3: Run full verification**

Run `make test`. If the known parallel `tools_builtin_find_spec`/`.test-tmp`
race appears, verify that exact spec and run `make test JOBS=1`; record both.

- [ ] **Step 4: Update issue evidence and commit**

Tick plan/issue steps and append RED/GREEN/final evidence. Commit with #195 and
the required co-author trailer. Do not close or land before operator smoke test.

## Revisions

### 2026-07-17 — Plan-review Neovim semantics spike

Removed the infeasible extmark ownership ledger after direct tests showed no
gravity configuration preserves a question-start identity across insertion and
full-line replacement, and endpoint marks cannot identify a migrated manual
fold. Replaced it with prepare-before-mutation/reconcile-after-mutation, named
the exact `normal! zd` selection behavior and overlap boundary, added real
streaming/tool-loop/lifecycle tests plus a model-provider seam, enforced removal
of add-only consumers, and raised the estimate to 3.0h.

### 2026-07-17 — Multi-window and failure-finally correction

Expanded each mutation transaction to snapshot and converge every window
displaying the changed buffer; added dispatcher `around_write` so streaming
finalization covers empty reductions and failures; defined parse-from-buffer
recovery without masking the original error; and added a lightweight
initialized `(buf,win)` registry plus teardown to make hydration idempotent.
