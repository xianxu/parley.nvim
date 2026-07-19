# Localized Semantic Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make semantic folds converge to a pure projection: initial window
hydration replaces restored fold state once, while live mutations reconcile
only the changed exchange.

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
  clears restored manual-fold state before rendering every exchange once for a
  newly entered window. A `(buf,win)`
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

- [x] **Step 1: Write RED pure tests**

Build `exchange_model` fixtures for all four foldable kinds, zero-size and
ordinary blocks, margins, multiple blocks, and multiple exchanges. Assert exact
ordered inclusive zero-based records. Load the module with `_G.vim=nil` in a
plain isolated Lua package context to prove purity without brittle source grep.

- [x] **Step 2: Run RED**

Run the exact new spec with `PlenaryBustedFile`; expect module-not-found.

- [x] **Step 3: Implement `desired_folds`**

Own the foldable-kind set only in `fold_projection.lua`; use
`model:block_start/end` and return no Neovim coordinates.

- [x] **Step 4: Run GREEN**

Run the new spec and `tests/unit/tool_folds_spec.lua`; expect all pass and the
old duplicated policy owner removed.

### Task 2: Prove exact `zd` behavior and reproduce the ghost

**Files:**
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED production-shaped tests**

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

- [x] **Step 2: Run RED**

Run `tests/integration/tool_folds_spec.lua`; expect the ghost assertion to
reproduce and the prepare/reconcile APIs to be absent.

### Task 3: Implement localized prepare/reconcile

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Implement exact old-fold deletion**

`prepare_exchange_update(buf, model, exchange_index)` validates the buffer and
exchange, snapshots `win_findbuf(buf)`, projects old ranges, and in each valid
window visits starts bottom-to-top. At each start it moves the cursor
temporarily and runs `normal! zd` only when a fold level exists; it restores the
cursor. It returns the window snapshot for post-mutation reconciliation and
never runs `zE` or ranges across the exchange.

- [x] **Step 2: Implement exact new-fold rendering**

`reconcile_exchange` projects the current exchange for one window, converts
only at the Ex boundary to one-based inclusive ranges, creates each manual fold,
and closes it. A buffer-scoped finalizer runs it for each surviving snapshot
window. Invalid targets are no-ops. Add a test observer receiving
`{ phase, win, exchange_index, ranges }` for locality assertions.

- [x] **Step 3: Add failure restoration seam**

For synchronous callers, `with_exchange_update(..., mutate)` prepares all
windows, executes `mutate` under `xpcall`, and on success reconciles from the
updated live model. On error it reparses current buffer state through the shared
model provider and attempts restoration; recovery failures leave prepared folds
absent and never replace the original traceback. Add failures after buffer
mutation and after model mutation. Streaming uses the same finalization policy
through `dispatcher.create_handler`'s `around_write` seam.

- [x] **Step 4: Run GREEN**

Run fold unit/integration specs; expect exact summary-only convergence and the
documented user-fold cases.

## Chunk 2: Real consumers and window hydration

### Task 4: Bracket the actual streaming consumer

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Add RED streaming locality test**

Through `M.respond` and its real `create_handler`, stream a summary transition
in exchange 2 displayed in two windows while exchange 1 and unrelated user
folds are closed in both. Assert observer sequence prepare/reconcile for
exchange 2 in both windows, no event for exchange 1, exact absence of a
blank-line fold, and unchanged earlier/user folds. Add an empty-reduction chunk,
an injected stream-write failure, and an injected post-model-update failure;
each must run recovery/finalization and preserve the original error. Retain
bounded active-segment read assertions.

- [x] **Step 2: Wire before/after callbacks**

Add `opts.around_write(qid, chunk, write_fn)` to `dispatcher.create_handler` and
place the actual buffer write, `on_lines_changed`, and `after_write` inside
`write_fn`. Chat response supplies a wrapper that prepares exchange 2 in all
snapshot windows, invokes `write_fn`, then always finalizes from the live model
or parse-from-buffer recovery. Ensure `#replacements == 0` still reaches the
finalizer. Delete `_apply_block_fold` use.

- [x] **Step 3: Verify streaming GREEN**

Run `chat_respond_spec.lua`; expect the new sequence/range assertions and all
existing streaming tests to pass.

### Task 5: Bracket the actual tool-loop consumer

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Create or Modify: `tests/integration/tool_loop_spec.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED real-entry-point test**

Call `_append_section_to_answer` with a real two-window buffer/model and
observer. Assert only its supplied `exchange_idx` receives prepare/reconcile in
both windows, the appended tool block folds in both, and other exchange/user
folds are unchanged.

- [x] **Step 2: Use `with_exchange_update`**

Wrap the existing model add plus buffer insert in the shared transaction. Remove
the add-only `_apply_block_fold` call.

- [x] **Step 3: Enforce the single mutation path**

Add an architecture assertion that production code contains no
`_apply_block_fold` and no add-only semantic fold creation outside
`tool_folds.lua`; decide `apply_folds` becomes the hydration wrapper rather than
a parallel incremental API (`ARCH-DRY`, `ARCH-PURPOSE`).

- [x] **Step 4: Verify tool-loop GREEN**

Run exact tool-loop and fold specs; expect all pass.

### Task 6: Hydrate initial and late windows safely

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Add RED lifecycle tests**

Inject one `model_provider(buf)` that reparses current lines. Test initial setup,
setup called twice, a second window opened after setup and hydrated via the real
window event, independent window folds, close of window B leaving A unchanged,
and a scheduled hydration callback delivered after buffer deletion/window close
performing no mutation or error.

- [x] **Step 2: Implement idempotent hydration**

`hydrate_window(buf, win, model_provider)` checks validity and the lightweight
initialized registry, configures fold options, obtains one fresh model, and
uses the shared reconciler for every exchange before marking `(buf,win)` done.
`setup` installs one augroup owner for `BufWinEnter`/`WinEnter`, `WinClosed`,
`BufUnload`, and `BufDelete`, and schedules hydration with captured IDs. Repeat
setup/events skip initialized windows; teardown clears the corresponding keys.

- [x] **Step 3: Verify lifecycle GREEN**

Run `tool_folds_spec.lua`; expect all window/race tests pass.

### Task 7: Map, verify, and hand off

**Files:**
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

- [x] **Step 1: Update atlas and traceability**

Map pure projection, exchange-local mutation bracketing, real consumers, and
late-window hydration. Add the new pure module/spec and tool-loop integration
test mapping.

- [x] **Step 2: Run focused verification**

Run exact projection, fold, chat-respond, and tool-loop specs; mapped
`make test-spec SPEC=chat/lifecycle`; `make test-changed`; and
`git diff --check`. Expected: all zero.

- [x] **Step 3: Run full verification**

Run `make test`. If the known parallel `tools_builtin_find_spec`/`.test-tmp`
race appears, verify that exact spec and run `make test JOBS=1`; record both.

- [x] **Step 4: Update issue evidence and commit**

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

### 2026-07-18 — Exact hydration convergence

Operator smoke testing revealed that a live tool transaction can precede its
scheduled initial hydration. Revised hydration and exchange preparation to
retire every native fold layer at projected semantic starts before rendering
one fold, so lifecycle ordering cannot leave duplicate semantic nesting.

### 2026-07-18 — Trailing-margin invariant

Added pure projection of semantic trailing-margin rows and adapter cleanup at
those rows after a smoke test showed an already-migrated blank-line fold has no
desired semantic start through which hydration could otherwise retire it.

## Chunk 3: Use the exchange structure's actual layout

### Core concept correction

The earlier chunks chose the wrong coordinate basis. `parsed_chat` already
records absolute `line_start`/`line_end` for questions and answer sections, but
`exchange_model.from_parsed_chat` discarded those coordinates and rebuilt the
document with a hard-coded one-line gap between every block and exchange. One
missing historical separator therefore shifted every later fold. Clearing
inferred trailing margins treated the symptom and must be removed.

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `LayoutGap` | PURE | `lua/parley/exchange_model.lua` | modified |
| `desired_folds` | PURE | `lua/parley/fold_projection.lua` | modified |

- **`LayoutGap`** — nonnegative `gap_before` metadata on exchanges and blocks,
  derived from adjacent absolute parser spans when loading an existing chat.
  New live blocks retain the canonical one-line default, while parsed chats
  preserve zero-, one-, or multi-line historical gaps exactly.
  - **Relationships:** Each exchange exclusively owns the gap before its first
    visible block. The question/first block has `gap_before = 0` and never
    duplicates that leading gap; later blocks own only intra-exchange gaps from
    the preceding visible item. `exchange_total_size` excludes the exchange
    leading gap, while `exchange_start` adds it exactly once after the header or
    previous exchange. Position queries never invent layout.
  - **DRY rationale:** The exchange model remains the one positional source for
    folds, streaming, tool appends, and prompt insertion (`ARCH-DRY`).
  - **Future extensions:** None; gaps are the minimal missing layout fact.
- **`desired_folds`** — continues to project foldable model blocks, but asserts
  every result lies within its exchange's computed bounds. It projects no gap
  or margin rows (`ARCH-PURE`, `ARCH-PURPOSE`).

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| parsed-layout hydration | INTEGRATION | `lua/parley/exchange_model.lua` | modified | `chat_parser` absolute spans |
| streaming span replacement | INTEGRATION | `lua/parley/chat_respond.lua` | modified | reduced active-segment spans |

- **Parsed-layout hydration** derives gaps once from adjacent parser spans;
  folding does not inspect buffer text or reconstruct the whole document.
- **Streaming span replacement** supplies the reduced sections' relative gaps
  to `replace_span`; it still reads only the active segment and updates only the
  known changed exchange.

### Task 8: Preserve actual gaps in the exchange model

**Files:**
- Modify: `lua/parley/exchange_model.lua`
- Modify: `tests/unit/exchange_model_spec.lua`

- [x] **Step 1: Write the RED coordinate regression**

Build a parsed-chat fixture whose first exchange summary is immediately
followed by the next question. Assert that `from_parsed_chat` places both at
their recorded absolute rows, plus cases for canonical one-line and multi-line
gaps within/between exchanges. Expected current failure: the second question
and its summary are projected one row too low.

- [x] **Step 2: Implement explicit gap arithmetic**

Store `gap_before` on each exchange and block. `exchange_start`,
`exchange_total_size`, `block_start`, `append_pos`, and replacement math sum
stored gaps only for positive-size visible items; a zero-size block contributes
neither content nor its stored gap, preserving the existing empty-block
invisibility invariant. `new`/`add_exchange`/`add_block` preserve current canonical defaults;
`from_parsed_chat` derives gaps as `current_start - previous_end - 1` from the
recorded spans. Reject negative gaps because overlapping items violate the
exchange structure.

The ownership formula is explicit: `exchange.gap_before` alone positions block
1; block 1's gap is always zero. `exchange_total_size` sums visible block sizes
and only visible blocks 2..N's intra-exchange gaps. `exchange_start(1)` is
`header_lines + exchange[1].gap_before`; later starts are the prior start plus
prior `exchange_total_size` plus the next exchange's leading gap. Tests pin both
the first question after the header and later questions after prior exchanges.

- [x] **Step 3: Preserve gaps through mutation**

`replace_span` accepts optional per-section `gap_before`; the first replacement
inherits the replaced span's leading gap when omitted, and subsequent new live
sections default to the canonical margin. Add RED/GREEN tests for grow, append,
replace, zero-size blocks, and downstream exchanges. Pin the real empty-stream
collapse shape: setting the placeholder to size zero after deleting its content
and preceding margin leaves `append_pos` and the next exchange at their physical
rows. Every existing mutation consumer must retain exact positions.

- [x] **Step 4: Run model GREEN**

Run `tests/unit/exchange_model_spec.lua`. Expected: all coordinate and mutation
tests pass without Neovim IO.

### Task 9: Fold only the stated exchange items

**Files:**
- Modify: `lua/parley/fold_projection.lua`
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/unit/fold_projection_spec.lua`
- Modify: `tests/integration/tool_folds_spec.lua`

- [x] **Step 1: Write the RED fold regression**

Use the marginless two-exchange fixture. Assert the later one-line summary fold
starts on its actual marker row, the following blank has fold level zero, and
every projected range is contained by its exchange bounds. This directly
reproduces the reported 1466/1467 failure without depending on the operator's
brain file.

- [x] **Step 2: Remove inferred-margin folding logic**

Delete `trailing_margin_rows` and all cleanup based on `end + 1`. Folds derive
only from foldable items' model spans; prepare/reconcile never targets a gap or
row outside the selected exchange. Keep the existing changed-exchange and
multi-window transaction unchanged.

- [x] **Step 3: Run fold GREEN**

Run the projection and fold specs. Expected: exact marker-row folds, zero fold
level on gaps, consecutive tool folds remain level one, and unrelated exchange
and user folds remain unchanged.

### Task 10: Feed exact relative gaps during streaming

**Files:**
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write the RED active-segment test**

Through the real dispatcher, reduce adjacent text/summary sections with no
blank between them and assert the live model matches their physical rows. Keep
the existing observer assertion that streaming reads only the active segment,
never the whole transcript.

- [x] **Step 2: Supply relative gaps to `replace_span`**

Derive each replacement section's `gap_before` from consecutive reducer
`line_start`/`line_end` values and the predecessor at the replacement boundary.
Do not parse history or adjust unchanged exchanges explicitly; model position
queries derive downstream rows from the changed sizes and gaps.

- [x] **Step 3: Run consumer GREEN**

Run chat-response, dispatcher, tool-loop, projection, and fold specs. Expected:
all pass and no production consumer computes fold coordinates independently
(`ARCH-DRY`, `ARCH-PURPOSE`).

### Task 11: Verify the corrected invariant

**Files:**
- Modify: `atlas/chat/exchange_model.md`
- Modify: `atlas/chat/lifecycle.md`
- Modify: `workshop/issues/000195-reconcile-semantic-folds-exactly.md`

- [x] **Step 1: Replace the incorrect atlas explanation**

Document stored actual gaps, exchange-bounded fold projection, and localized
streaming updates. Remove the trailing-margin cleanup narrative.

- [x] **Step 2: Run verification**

Run focused specs, `make test-spec SPEC=chat/exchange_model`,
`make test-spec SPEC=chat/lifecycle`, `make test-changed`, `make lint`,
`git diff --check`, and `make test JOBS=1`. Expected: zero failures/warnings.

- [x] **Step 3: Operator smoke test**

Open the reported brain chat at lines 1466–1467 after reloading Parley. Expected:
line 1466 has the one-line summary fold; line 1467 has fold level zero. Also
exercise a fresh streaming summary plus tool-use/tool-result response before
committing or closing.

### 2026-07-18 — Coordinate-basis correction

Replaced inferred trailing-margin cleanup with the exchange structure's actual
layout math. Parser spans imply every gap already; preserving those gaps in the
size-based model makes missing historical separators irrelevant and keeps fold
projection strictly inside the selected exchange. This revision is the root
correction after repeated smoke tests exposed that globally reconstructed
one-line margins—not Neovim fold mutation—caused the remaining off-by-one.

The fresh-eyes plan review additionally pinned zero-size invisibility: stored
gaps are conditional on positive-size items, so empty-answer collapse cannot
reintroduce a one-row downstream drift.
It also single-sourced leading-gap ownership on the exchange: block 1 never owns
or contributes that gap, preventing header/question and inter-exchange gaps
from being counted twice.

### 2026-07-18 — Deterministic initial hydration

Operator smoke testing proved the corrected 1466 projection could coexist with
a persisted orphan fold at 1467 because hydration only retired folds reachable
from current semantic starts. Revised the initial-window boundary to clear all
restored manual folds before rendering the complete model projection. This is
distinct from the streaming hot path, which remains localized to the changed
exchange; the split makes initial state deterministic without reparsing or
touching unchanged exchanges during response updates (`ARCH-PURE`).

### 2026-07-18 — Close-review coverage ownership

The close review correctly found that Chunk 2 described every fault injection
as one monolithic `chat_respond` test even though the implemented architecture
places those guarantees at separate injected seams. Coverage now pins empty
chunks at dispatcher `around_write`, post-model-mutation recovery and
multi-window convergence at `tool_folds.with_exchange_update`, and stale
scheduled callbacks at hydration's validity boundary. The production
`chat_respond` tests retain the actual streaming wiring and bounded-segment
assertions; this split tests each INTEGRATION owner directly without duplicating
its behavior in a heavier harness (`ARCH-DRY`, `ARCH-PURE`).
