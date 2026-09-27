# Semantic fold flicker (#264) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Closed semantic folds (thinking, summary, tool_use, tool_result) never visibly open during fold repair, whether it follows a local edit or a streamed append; and a local edit no longer marks the whole document as uncertain.

**Architecture:** M1 changes *how* native folds are reconciled: diff the existing native folds against the confirmed projection, leave exact matches untouched, and remove and create changed ones in the same scheduler turn. Uncertainty no longer clears native folds eagerly, except folds the edit itself intersects. M2 changes *how far* uncertainty reaches: when the parser's local fragment transfer fails its end-state comparison, it restarts at the edit (or its answer header) instead of at row 0.

**Tech Stack:** Lua (Neovim 0.10+), plenary busted specs, `make test-spec SPEC=chat/document`.

---

## Background (read first)

- The issue: `workshop/issues/000264-semantic-folds-flicker-open-on-a-local-blank-line-edit.md`,
  including its Log (blank-count matrix, and the per-kind bounded-extent argument) and its
  2026-09-27 Revision (the streaming append path).
- `atlas/chat/document.md` §"Fold queries…" (lines ~118-127): the current contract.
- `lua/parley/tool_folds.lua`: native fold reconciliation.
  - `clear_folds_in_span` (:35-150): VimL fold walk (`zj`/`zD`), batched.
  - `clear_uncertainty` (:257-310): **defect site 1.** It clears every native fold from the
    uncertain frontier to EOF in its own turn, before any replacement exists.
  - `apply` (:323-419): per-window phases `capture` → `clear` → `create`, each in its own
    turn. **Defect site 2:** unchanged folds are deleted in one turn and recreated in a later one.
  - `M.step` (:422-470): runs `prune_hints`, then `clear_uncertainty`, then plan/apply.
- `lua/parley/document/semantic.lua`:
  - `before_fragment` (:318-420): prepares a local transfer. It proves, via
    `w.deps:restart_origin`, that no earlier row depends on the edited rows. But its
    prepared fallback evidence is hard-coded to `restart=0` with `fallback=true`
    (:406-407).
  - `after_fragment` (:448-...): **defect site 3.** When the re-derived end checkpoint differs
    from the captured one (:494-495; true for any blank-count change), it falls back to that
    restart-0 evidence, rebuilding the dependency index and re-parsing from the top.
  - `before_splice` (:230-270): the general path's local restart computation
    (min of edit row, dependency origin and global position; pulled back to the answer header;
    checkpoint from the preceding row's `metadata.after`).
- Evidence gathered in design (2026-09-27, scratch instrumentation, not committed):
  - Blank deletion after a summary, after thinking, and in a *second* exchange all report
    `uncertain={0,N}`, all via `after_fragment` :495. The same deletion after a fenced tool
    block reports no uncertainty.
  - Streaming append of a tool block with a closed earlier fold in the same exchange: the
    earlier fold reads `foldclosed==-1` for one `F.step` (two if the result arrives in two
    writes).

## Why deferring the clear is safe (the invariant that replaces eager clearing)

The eager clear guards against a fold displayed at a wrong position during repair (#193,
#200). Neovim keeps manual folds attached to their text across edits; a fold's extent goes
wrong in only two ways:
1. **The edit writes rows inside the fold.** Neovim grows, or shrinks to its first line, a
   manual fold whose rows were replaced or inserted into (#193 Spec). → Such folds are still
   cleared eagerly (M1 Task 4).

   **Intersection rule (precise).** An edit event carries post-edit `first_row`/`last_row`
   and pre-edit `old_last_row`. A manual fold can absorb rows that aren't its own **only
   when the edit adds net rows**: `last_row-first_row > old_last_row-first_row`. (Verified
   headless on nvim 0.11.7 in plan review round 2: a brute-force sweep of every
   `set_lines`/`set_text` edit against a fold, plus native Backspace-at-column-0, `J`, `o` and
   `O`. Edits that keep or lower the row count only shrink a fold onto its own surviving
   text or rewrite it in place.) So only a net-growing edit is recorded, as its written rows
   post-edit `[first_row, last_row)`, and intersection is measured against **post-edit**
   fold extents. (A line inserted directly above a fold's first row with `set_lines` is
   absorbed into the fold, so post-edit extents are what show that.)
   Consequences: pure deletions **and joins** (Backspace at column 0 or `J` on the blank
   under a `📝:`/`🧠:`, and Delete at end of line) never clear eagerly. That's the issue's
   main case. Deleting a fold's own last rows (e.g. a tool result's closing fence) doesn't
   either; the diff reconcile fixes the extent. Only `semantic_changed` edits are recorded:
   non-semantic edits schedule no repair today.
2. **The structure changed without touching the fold's rows** (for example, a marker typed
   above it changes how its rows parse). → The old fold stays briefly: stale in meaning,
   but stable in position, over exactly the rows it covered. The diff reconcile removes or
   reshapes it as soon as the confirmed projection is ready.

#200's failure was *permanent* drift (a reconcile that never removed unwanted folds). The diff
reconcile keeps the settled-state guarantee: after settling, native folds equal the confirmed
projection exactly (the existing `oracle` in `tests/integration/tool_folds_spec.lua`).

**Replacement invariant:** *a fold not intersected by an edit is never removed until a
confirmed projection is ready, and is left untouched if that projection contains it with the
same extent.*

Per kind (the issue's bounded-extent argument): `summary`, `tool_use` and `tool_result` are
closed from within, so an edit below them never changes their extent, and the diff reconcile
keeps them. `thinking` can legitimately grow or shrink when blanks below it change; it is
reshaped in one turn (remove plus create together), never left open between turns.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `FoldDiff` | `lua/parley/fold_diff.lua` | new |

- **FoldDiff** — given the *existing* native folds in a span
  (`{start_0,end_0,open,nested}`) and the *desired* ranges (`{start_0,end_0,identity}`),
  return an ordered list of **batches**. A batch is `{remove={...},create={...}}` covering a
  contiguous row region. Every existing fold that overlaps a desired range, or another
  changed fold, lands in the same batch as its replacement, so a region is never left
  unfolded between turns. Exact matches (same start and end, not nested) appear in no batch.
  Batches hold at most `limit` groups, and a region is never split.
  - **Relationships:** pure function; called by `tool_folds.apply`. 1 call per window per plan.
  - **DRY rationale:** replaces two separate phases (`clear` walks everything; `create`
    re-adds everything) with one decision in one place. It is also reused by M1 Task 4's
    edit-intersection clear (a batch with only `remove`).
  - **Future extensions:** nested user folds (currently always removed with their group,
    as `zD` does today).
  - Tests: `tests/unit/fold_diff_spec.lua`, no Neovim state.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `fold_native.walk` | `lua/parley/fold_native.lua` | new (moved from `tool_folds.clear_folds_in_span`) | Neovim native manual folds (VimL walk) |
| `apply` (phases) | `lua/parley/tool_folds.lua` | modified | native fold commands |
| `clear_uncertainty` | `lua/parley/tool_folds.lua` | modified | native fold commands |
| `Deps:prune_from` / `Deps:install` | `lua/parley/document/dependencies.lua` | new | dependency index (persistent trees) |
| `after_fragment` fallback | `lua/parley/document/semantic.lua` | modified | dependency index |

- **fold_native.walk** — the existing guarded VimL fold walk (`clear_folds_in_span`,
  :35-150), moved out of `tool_folds.lua` (already ~595 lines) and given a `mode`:
  `'delete'` (today's behaviour, `zD`) or `'inventory'` (no mutation). Inventory records each
  top-level group's exact extent: `zC` (close the whole group, not the innermost fold), read
  `foldclosed`/`foldclosedend`, then `zO` if it was open, all in one turn so nothing is
  visible. It also records `nested` (any row in the group with `foldlevel>1`). The same
  ownership guard, `live()` checks and command bound (`BATCH_GROUPS*2`) apply to both modes,
  so large spans are inventoried across turns *without mutating anything*, which is safe to
  split. `tool_folds` keeps a thin `clear_folds_in_span` wrapper (mode `'delete'`) for the
  >50k-row path, so there's one walk and no copy (ARCH-DRY).
  - **Injected into:** `FoldDiff` receives the inventory as plain data.
- **Deps:prune_from / Deps:install** — the dependency trees are persistent (`prefix`/`join`
  build new nodes; `self.roots` is swapped whole). `prune_from(handle, opts)` computes the
  roots `remove_from` would install and returns them without committing; `install(roots)`
  commits them. This lets M2 do the pruning **before** the splice, when every handle still
  ranks, and commit it only if the local transfer fails.
- **apply** — phases become `capture` (unchanged: open state per identity) → `inventory` →
  `reconcile` (for each batch from `FoldDiff`, in one slice: `zD` each removal, then
  `N,Mfold` each creation, then restore open state). The `clear` and `create` phases are
  deleted. Large-scope suspension (>`INTERACTIVE_ROWS`) keeps its current behaviour.
- **clear_uncertainty** — for scopes ≤ `INTERACTIVE_ROWS`, no longer clears the
  frontier-to-EOF span. It clears only folds that intersect a written row (the rule above),
  and widens `s.first`/`s.last` to the uncertain scope so the next plan covers it (as it does
  today). **Above `INTERACTIVE_ROWS` it keeps today's behaviour exactly** (frontier-to-EOF
  delete walk with `foldenable` suspended). Folds are disabled, and so invisible, for the
  whole job there, so it can't flicker, and
  `document_fold_uncertainty_retirement_spec.lua` keeps its contract.
- **after_fragment fallback** — see M2.

---

## Chunk 1: M1 — reconcile in place

### Task 1: Continuity regression spec (fails today)

**Files:**
- Create: `tests/integration/document_fold_continuity_spec.lua`
- Modify: `atlas/traceability.yaml` (map it under the `chat/document` spec key, next to
  `document_fold_uncertainty_retirement_spec.lua`)

- [ ] **Step 1: Write the harness and cases.** One helper drives repair one step at a time
  and asserts continuity after *every* step, not only when settled:

```lua
local D=require('parley.document')
local F=require('parley.tool_folds')
-- Opens `lines` settled, closes every fold, applies `mutate`, then steps repair to
-- idle, asserting after every step that each row in `watch` stays inside a closed fold.
local function continuity(lines,watch,mutate)
    local buf=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_set_current_buf(buf)
    vim.wo.foldmethod='manual';vim.wo.foldenable=true
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    local doc=D.attach(buf,{schedule=false})
    assert.equals('idle',D.drain(doc,100000).status)
    F.setup(buf);assert.equals('idle',F.flush(buf))
    for _,row in ipairs(watch) do assert.equals(row,vim.fn.foldclosed(row),'precondition row '..row) end
    mutate(buf)
    D.drain(doc,100000)
    for step=1,500 do
        local status=F.step(buf)
        for _,row in ipairs(watch) do
            assert.are_not.equals(-1,vim.fn.foldclosed(row),('row %d opened at step %d'):format(row,step))
        end
        if status=='idle' then break end
        if status=='pending' then D.drain(doc,100000) end
    end
    vim.api.nvim_buf_delete(buf,{force=true})
end
```

  Cases (each `it`):
  - Blank-count matrix after a summary: blanks n∈{1,2,4}, deleting m∈{1,n-1,n} (m≤n), `💬:`
    after; watch the summary row. (Reproduces the issue Log's matrix.)
  - The same matrix after a thinking block (`🧠: thought` / `body`); watch its first row.
  - The same after a closed tool pair (`🔧`/`📎`); watch both.
  - Edit in a *second* exchange; watch folds in the first **and** second exchanges.
  - Streaming append (the #281 repro): a closed tool pair, then append a second tool
    block (a) in one write, (b) split with the closing fence in a second write (drain and
    step between writes, asserting continuity throughout), (c) a one-line result; watch
    the first pair.
  - Append a `🧠:` block, then a summary, below a closed summary; watch the earlier summary.
  - Negative: after settling, the existing settled oracle still holds (copy `oracle()` from
    `tests/integration/tool_folds_spec.lua:33-45` into this file's helpers).

  Real keystrokes (not only `set_lines`), because joins take a different edit shape. Drive
  them with `vim.api.nvim_feedkeys(keys,'xt',false)` on a window showing the buffer, cursor
  placed first:
  - Backspace at column 0 of the blank under a summary, and under a thinking block (insert
    mode: `i<BS><Esc>`);
  - `J` on the summary row with a blank below;
  - Delete at end of line (`A<Del><Esc>`) on the summary row.
  Watch the summary/thinking row: it must never open.

  Boundary cases for the intersection rule (Task 4):
  - deleting a tool result's closing fence (a pure deletion of the fold's own last row): the
    fold is never eagerly cleared, and the settled state equals the oracle;
  - a **net insertion inside** a closed tool result (`nvim_buf_set_lines(buf,r,r,false,{'x'})`
    with `r` inside the body), which really does grow the fold: the fold *is* cleared
    before repair and the settled state equals the oracle. This case is excluded from the
    continuity watch.

- [ ] **Step 2: Run and confirm it fails.**
  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/document_fold_continuity_spec.lua" -c "qa!"`
  Expected: FAIL with `row N opened at step 3` (or similar) in the summary, thinking,
  second-exchange and streaming cases. **Expected to PASS today (controls):** the blank
  matrix after a tool pair (no uncertainty, no structural apply) and both boundary cases.
  Record which cases were red in the issue Log, so Task 3/4 can show each one turning green.

- [ ] **Step 3: Commit.** `#264 M1: continuity spec for fold repair (red)`

### Task 2: `FoldDiff` (pure)

**Files:**
- Create: `lua/parley/fold_diff.lua`
- Test: `tests/unit/fold_diff_spec.lua`

- [ ] **Step 1: Failing unit tests**, table-driven:
  - identical existing/desired → no batches;
  - one desired fold grows (`{5,9}` → `{5,12}`) → one batch `{remove={5..9},create={5..12}}`;
  - removal only (existing with no desired overlap) → remove-only batch;
  - creation only → create-only batch;
  - a changed fold overlapping two desired folds → all three in one batch;
  - a nested existing group → removed and recreated even when its outer extent matches;
  - `limit=2` with five independent changes → three batches in row order, none splitting
    an overlap region;
  - an unchanged fold between two changes is never listed in any batch.
- [ ] **Step 2: Run, confirm FAIL** (module missing).
  `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fold_diff_spec.lua" -c "qa!"`
- [ ] **Step 3: Implement.** Sweep both lists sorted by `start_0`; build regions as
  connected components of the overlap graph restricted to non-matching folds (exact matches
  excluded first); emit regions in row order and pack them into batches of ≤`limit` groups.
  Target under 80 lines.
- [ ] **Step 4: Run, confirm PASS.**
- [ ] **Step 5: Commit.** `#264 M1: fold_diff: pure diff of native vs desired folds`

### Task 3: Inventory and a single reconcile phase in `apply`

**Files:**
- Create: `lua/parley/fold_native.lua` (the walk moved out of `tool_folds.lua` :35-150)
- Modify: `lua/parley/tool_folds.lua` (`apply` :323-419; `clear_folds_in_span` becomes a
  wrapper around `fold_native.walk(...,'delete',...)`)
- Test: `tests/unit/fold_native_spec.lua`,
  `tests/integration/document_fold_continuity_spec.lua` (streaming cases)

- [ ] **Step 1: Move, don't copy.** Move `clear_folds_in_span`'s body to
  `fold_native.walk(buf,win,first_0,last_0,mode,command_limit,remember,current,owner)`;
  `mode=='delete'` is byte-for-byte today's VimL, and `tool_folds.clear_folds_in_span` calls
  it. Keep `M._last_clear_iters` on `tool_folds` (tests read it). Run the fold suites
  (Task 3 Step 4 list) and confirm no behaviour change. Commit:
  `#264 M1: move the native fold walk to fold_native (no behaviour change)`.
- [ ] **Step 2: Inventory mode.** In the same VimL loop, `mode=='inventory'` replaces
  `zc`+`zD` with: `zC`, record `[foldclosed('.')-1, foldclosedend('.')-1, was_open,
  nested]` (nested: any row in the group with `foldlevel>1`), `zO` if `was_open`, then move
  past the group (`foldclosedend+1`). It returns `folds,next_row,done`. Unit test
  `tests/unit/fold_native_spec.lua`: three groups (open, closed, and nested with the inner
  fold on the outer's first row) → exact outer extents and `nested` flags; the *outer*
  open/closed state is unchanged afterwards for every group. The inner state of a nested
  group isn't preserved (`zC`/`zO` reopens inner folds). That's acceptable because a nested
  group is never an exact match: `FoldDiff` always removes and recreates it, restoring the
  open state from the `capture` phase, which runs first.
- [ ] **Step 3: Single reconcile phase.** In `apply`, replace phases `clear`/`create` with
  `inventory` (accumulate over slices) → `reconcile`: compute
  `require('parley.fold_diff').diff(existing,plan.ranges,BATCH_GROUPS)` once, then per
  slice apply one batch: for each removal, **re-check** that `foldlevel(start)>0` and
  `foldclosed`-start still equals the inventoried start (user `zf`/`zd`/`zE` between slices
  doesn't bump `changedtick`); if not, discard the plan and return `'more'` (re-plan). Then
  `zD` each removal (top to bottom, re-checking `current()` after each command as today),
  then `N,Mfold` each creation, then `foldopen` where `window.opened[identity]`. Keep
  `record_work` counters (`native_fold_ops`, `fold_groups_visited`),
  `notify({phase='reconcile',...})`, suspension and `restore_window` exactly as today.
- [ ] **Step 4:** Run the continuity spec. Expected: the streaming cases now PASS;
  blank-line cases may still fail at `clear_uncertainty` (Task 4).
- [ ] **Step 5:** Run `make test-spec SPEC=chat/document` and each of:
  `tests/integration/tool_folds_spec.lua`, `tests/integration/fold_invariants_spec.lua`,
  `tests/integration/document_folds_spec.lua`,
  `tests/integration/document_fold_batches_spec.lua`,
  `tests/integration/document_fold_join_spec.lua`,
  `tests/integration/document_fold_retirement_spec.lua`,
  `tests/integration/document_fold_uncertainty_retirement_spec.lua`,
  `tests/integration/document_fold_native_spec.lua`,
  `tests/unit/tool_folds_spec.lua`, `tests/unit/fold_projection_spec.lua`. All green. Fix any
  assertion that pinned the *old* phase names or work counts only if it measured
  implementation detail; note each such change in the issue Log with the reason.
- [ ] **Step 6: Commit.** `#264 M1: reconcile native folds by diff in one phase`

### Task 4: Uncertainty clears only edit-intersected folds

**Files:**
- Modify: `lua/parley/tool_folds.lua` (`clear_uncertainty` :257-310; the `edit` branch of the
  document subscriber in `ensure`, :480-505)

- [ ] **Step 1:** Track written rows: in the `edit` branch, **only when
  `event.semantic_changed` and the edit adds net rows**
  (`event.last_row-event.first_row > event.old_last_row-event.first_row`; the intersection
  rule), record `{first=event.first_row,last=event.last_row}` in `s.edited`. Shift entries by the row
  delta exactly as `s.first`/`s.last` are shifted. Bound it: keep at most 8 ranges, merging
  the two nearest when a ninth arrives (the union can only widen the eager clear, which is
  the conservative direction; count merges with `line_reader.record_work(buf,{fold_edit_merges=1})`
  so an unexpected rise is visible, since with the net-growth filter merging should be rare). Clear `s.edited` whenever `M.step` returns `'idle'` (settled
  or nothing to do), on `reload`, and on `detach`. Unit test: 1000 semantic single-row
  inserts leave `#s.edited<=8`; a settle empties it.
- [ ] **Step 2:** In `clear_uncertainty`, for scopes ≤ `INTERACTIVE_ROWS`, replace the
  frontier-to-EOF delete walk with: widen `s.first`/`s.last` to the scope (as now); inventory
  (`fold_native.walk` mode `'inventory'`) only over the `s.edited` ranges; remove the groups
  intersecting them (remove-only `FoldDiff` batches). Above `INTERACTIVE_ROWS`, keep the
  existing delete walk and suspension unchanged.
- [ ] **Step 3:** Continuity spec: all cases PASS, including both intersection-rule boundary
  cases from Task 1.
- [ ] **Step 4:** Full fold and document suites green (the Task 3 Step 5 list), plus
  `tests/integration/chat_stop_generation_spec.lua` and
  `tests/integration/response_tools_spec.lua` (streaming writes). The #193/#194/#195/#200
  behaviours are defended by `tool_folds_spec.lua` (oracle, question never folded),
  `fold_invariants_spec.lua` and `document_folds_spec.lua` in that list.
- [ ] **Step 5: Commit.** `#264 M1: uncertainty clears only folds the edit touched`

### Task 5: M1 atlas and close

- [ ] Update `atlas/chat/document.md` §Fold queries: replace "Uncertainty invalidation clears
  semantic folds in the unconfirmed suffix independently of recreation" with the replacement
  invariant above plus the diff reconcile (one sentence each).
- [ ] Add the lesson to `workshop/lessons.md` if the milestone review surfaces one.
- [ ] `sdlc milestone-close --issue 264 --milestone M1`

## Chunk 2: M2 — local restart after a failed fragment transfer

### Task 6: Uncertainty-extent spec (fails today)

**Files:**
- Create: `tests/integration/document_uncertainty_extent_spec.lua`
- Modify: `atlas/traceability.yaml` (map under `chat/document`)

- [ ] **Step 1:** For each case: open settled, delete one blank with `nvim_buf_set_lines`,
  then read `D.uncertain_range(doc)` *before* draining. Assert
  `range==nil or range.first>=expected_first`. (The range stays `{restart, EOF}`: bounded
  below, not local to the block. That meets the Done-when bullet "not whole-document".)
  Then drain and assert the settled document equals a **cold parse** of the same lines: a
  fresh `D.attach` on a copy buffer, compared row by row on **handle-free fields only**:
  `metadata.semantic.role`, `.section_kind`, `.section_start`, `metadata.confirmed`, and
  `D.folds` row ranges. (Other `metadata.semantic` fields, e.g. `preface_origin`, hold handles
  that differ between buffers.)
  Cases and `expected_first`:
  - blank after a summary, first exchange → the `🤖:` header row;
  - blank after thinking → the `🤖:` header row;
  - blank in a *second* exchange's answer → the second `🤖:` header row;
  - blank in a *question* (question-role edit, no answer header) → the edit row itself;
  - blank after a tool block → `nil` (already local today; guard against regression).
- [ ] **Step 2:** Run and confirm FAIL: `first=0` for the summary, thinking, second-exchange
  and question cases; the tool case passes (control).
- [ ] **Step 3: Commit.** `#264 M2: uncertainty extent spec (red)`

### Task 7: Local fallback evidence

**Files:**
- Modify: `lua/parley/document/dependencies.lua` (`Index:remove_from` :172-182 → split into
  `prune_from` + `install`; `remove_from` becomes `install(prune_from(...))`)
- Modify: `lua/parley/document/semantic.lua` (`before_fragment` :400-420, `after_fragment`
  :492-495)
- Test: `tests/unit/document_dependencies_spec.lua` (existing)

- [ ] **Step 1: `prune_from`/`install`.** `Index:prune_from(origin,opts)` runs the same
  `operation(self,opts,…)` body as `remove_from` but returns
  `{status='ok',roots=roots,removed=n}` without assigning `self.roots`; `Index:install(roots)`
  assigns them. `remove_from` = prune then install (no behaviour change). Unit test: pruning
  leaves the index unchanged until `install`; install equals `remove_from`'s result; a
  budget-exhausted prune reports a non-`ok` status and installs nothing.
- [ ] **Step 2: Prepare the local restart before the splice.** In `before_fragment`, after
  the transfer is admitted (it has proved `affected.origin==nil` over `changed` channels),
  compute a local restart exactly as `before_splice` does (:255-263) from pre-splice rows:
  `restart=first`; if the row before `restart` has `metadata.answer_header`, pull back to
  that header's row (a question-role edit has no header, so the restart stays `first`);
  `checkpoint` = that preceding row's `metadata.after`; if `restart>0` and there is no
  preceding `metadata.after`, **don't** prepare a local restart (keep restart 0). Then
  `pruned=w.deps:prune_from(<handle at restart>,{budget=dep_budget,before_rank=...})`, while
  every handle still ranks. If it's not `ok` (budget), don't prepare a local restart. Store
  `captured.local_restart={restart=restart,checkpoint=checkpoint,roots=pruned.roots,
  deps=w.deps,base_roots=w.deps.roots}`. This now runs on every admitted local fragment (the
  per-keystroke path): record `prune_from`'s node visits in the fragment's `work`, and compare
  the per-keystroke work counts before and after in `tests/unit/document_splice_admission_spec.lua`
  (log the numbers in the issue).
- [ ] **Step 3: Use it only on an end-state mismatch.** In `after_fragment`, **only** at the
  end-checkpoint comparison (:492-495) and only if `captured.local_restart` exists:
  first guard in O(1) that the index is the one pruned (with `r=captured.local_restart`):
  `w.deps==r.deps and w.deps.roots==r.base_roots` (the `serial` check doesn't prove this,
  because `deps:add` doesn't bump `serial`); if it fails, take the restart-0 path. Otherwise
  `w.deps:install(r.roots)`, then build evidence with **every** field
  `after_splice` reads: `{worker=worker, restart=r.restart, checkpoint=r.checkpoint,
  serial=w.serial, fallback=false, active_scope=captured.active}` (`captured.active` is
  re-certified by `after_splice`'s existing `validate_certificate` check), register it in
  `evidence_store`, and return `M.after_splice(worker,token,first,newlast)` with
  `result.work` as the current fallback sets it. Every other fallback (row count, token
  mismatch, `global.need`, projected dependencies, `token.status=='fallback'`) keeps the
  restart-0 path: those mean the fragment's own assumptions broke.
- [ ] **Step 4:** Extent spec PASS; `make test-spec SPEC=chat/document` green, including the
  seeded flat-model comparisons and golden fixtures (they defend the settled parse against
  the conservative path).
- [ ] **Step 5:** Scale check, logged in the issue Log: the issue's 242-row / 40-summary
  case. Record `uncertain_range` and steps to settle, before and after.
- [ ] **Step 6: Commit.** `#264 M2: local restart when a fragment's end state changes`

### Task 8: M2 atlas and close

- [ ] `atlas/chat/document.md` §repair (lines ~55-57): one sentence stating that a failed
  local transfer restarts at the edit's answer header, not at row 0, and why that's sound
  (the dependency proof in `before_fragment`).
- [ ] `sdlc milestone-close --issue 264 --milestone M2`, then `sdlc close --issue 264`.

## Operating envelope (ARCH-CONSTRAINTS)

- Inventory cost is O(folds in scope), like today's clear walk, and batched at the same
  command bound. Reconcile cost is O(changed folds): an append to an exchange with k
  unchanged folds does 0 native operations on them (today: 2k).
- M2 turns an O(document) re-parse after a blank-line edit into O(rows from the answer
  header to convergence). There's no new durable state; `s.edited` dies with the plan
  (ARCH-FUNERAL: in-memory, cleared on settle and on detach).

## Deliberate narrowing (recorded in the issue's Revisions)

The issue Log (2026-09-19) proposed a per-kind negative: an edit below a `summary` or fenced
tool block should leave its confirmation intact. M2's restart at the answer header does
un-confirm a summary in the *same* answer, so the tests assert only that the restart is
bounded below by the header. Reason: M1 removes the visible symptom regardless of how far
confirmation reaches, and restarting inside an answer would need section-level restart
evidence the parser doesn't have yet. It's worth a follow-up only if settle time on long
answers shows up in measurements.

## Out of scope

- Writing tool blocks in one piece (#290) and marker escaping (#291).
- Changing `INTERACTIVE_ROWS`/`BATCH_GROUPS` or the >50k-row suspension behaviour.
