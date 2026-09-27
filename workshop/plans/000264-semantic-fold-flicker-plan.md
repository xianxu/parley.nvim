# Semantic fold flicker (#264) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Closed semantic folds (thinking, summary, tool_use, tool_result) never visibly open during fold repair, whether it follows a local edit or a streamed append; and a local edit no longer marks the whole document as uncertain.

**Architecture:** M1 changes *how* native folds are reconciled: diff the existing native folds against the confirmed projection, leave exact matches untouched, and remove and create changed ones in the same scheduler turn. Uncertainty no longer clears native folds at all (below the 50k-row suspension threshold): Parley owns every fold, Neovim carries folds with their text, and the diff reconcile corrects the rare fold an edit distorted, one repair later. M2 changes *how far* uncertainty reaches: when the parser's local fragment transfer fails its end-state comparison, it restarts at the edit (or its answer header) instead of at row 0.

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

## Why dropping the eager clear is safe (the invariant that replaces it)

The eager clear guards against a fold displayed at a wrong position during repair (#193,
#200). Two facts make it unnecessary:
- **Parley owns every fold.** Users don't create folds (they only open and close them), so
  every native fold is one Parley made from a confirmed projection.
- **Neovim carries manual folds with their text.** Verified headless on nvim 0.11.7 in
  plan review round 2 (a brute-force sweep of every `set_lines`/`set_text` edit against a
  fold, plus native Backspace at column 0, `J`, `o` and `O`): edits that keep or lower the
  row count only shrink a fold onto its own surviving text or rewrite it in place. A fold
  absorbs rows that aren't its own **only** when an edit adds net rows inside it (or
  directly above its first row via `set_lines`).

So after any edit, a native fold is either still right, or (for that rare net insertion)
briefly covers one extra written row. Either way it stays stable in position. The diff
reconcile then makes native folds equal the confirmed projection, touching only the
differences. With folds closed, human insertions rarely land inside one: `o` and `p` on a
closed fold put text *after* it. The remaining writer-side case, streaming into a block,
goes away with #290 (one write per block, folded as it is written).

A structural edit elsewhere (a marker or fence typed above a fold) can change a fold's
*meaning* without touching its rows. The old fold then stays briefly, stale in meaning but
stable in position, until the confirmed projection removes or reshapes it.

#200's failure was *permanent* drift (a reconcile that never removed unwanted folds). The diff
reconcile keeps the settled-state guarantee: after settling, native folds equal the confirmed
projection exactly (the existing `oracle` in `tests/integration/tool_folds_spec.lua`).

**Replacement invariant:** *no native fold is removed until a confirmed projection is ready,
and a fold the projection contains with the same extent is never touched.* Its common case
is **zero-touch**: a plain streamed append or an ordinary human edit removes no native fold
at all (Task 1 asserts this with a counter).

Per kind (the issue's bounded-extent argument): `summary`, `tool_use` and `tool_result` are
closed from within, so an edit below them never changes their extent, and the diff reconcile
keeps them. `thinking` can legitimately grow or shrink when blanks below it change; it is
reshaped in one turn (remove plus create together), never left open between turns.

Chats over `INTERACTIVE_ROWS` (50,000 affected rows) keep today's uncertainty path exactly
(a frontier-to-EOF clear with `foldenable` suspended). Folds are disabled, so invisible, for
the whole job there, so it can't flicker. `apply` has **one** path at every size: suspended
windows run the same `inventory`→`reconcile` phases under `foldenable=false` (the old
`clear`/`create` phases are deleted). Inventory walks folds with `zj`, which needs
`foldenable` on, so `fold_native.walk` sets it inside the slice (as `clear_folds_in_span` does
today) and the slice's `restore_window` puts it back.
`document_fold_batches_spec.lua` and `document_fold_uncertainty_retirement_spec.lua` must
pass unchanged; if a work-count assertion changes, log why.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `diff` (FoldDiff) | `lua/parley/fold_diff.lua` | new |

- **FoldDiff** — given the *existing* native folds in a span
  (`{start_0,end_0,open,nested}`) and the *desired* ranges (`{start_0,end_0,identity}`),
  return an ordered list of **batches**. A batch is `{remove={...},create={...}}` covering a
  contiguous row region. Every existing fold that overlaps a desired range, or another
  changed fold, lands in the same batch as its replacement, so a region is never left
  unfolded between turns. Exact matches (same start and end, not nested) appear in no batch.
  Batches hold at most `limit` groups, and a region is never split.
  - **Relationships:** pure function; called by `tool_folds.apply`. 1 call per window per plan.
  - **DRY rationale:** replaces two separate phases (`clear` walks everything; `create`
    re-adds everything) with one decision in one place.
  - **Future extensions:** nested user folds (currently always removed with their group,
    as `zD` does today).
  - Tests: `tests/unit/fold_diff_spec.lua`, no Neovim state.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `fold_native.walk` (`walk`) | `lua/parley/fold_native.lua` | new (moved from `tool_folds.clear_folds_in_span`) | Neovim native manual folds (VimL walk) |
| `valid_target`, `restore_window` | `lua/parley/fold_native.lua` | modified (moved from `tool_folds.lua`, now exported for it) | window/buffer validity; per-slice view and `foldenable` restore |
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
- **clear_uncertainty** — for scopes ≤ `INTERACTIVE_ROWS`, does **no native work**. It only
  widens `s.first`/`s.last` to the uncertain scope so the next plan covers it (as it does
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

  Edge cases (settled state must equal the oracle; the watched fold must never open):
  - deleting a tool result's closing fence (a pure deletion of the fold's own last row);
  - a **net insertion inside** a closed tool result (`nvim_buf_set_lines(buf,r,r,false,{'x'})`
    with `r` inside the body), which grows the native fold for one repair; after settling,
    the fold equals the projection again.

  **Zero-touch cases** (the common path): extend `notify({phase='reconcile',...})` (Task 3)
  with `removed=<count>` and `created=<count>`, and capture events through `F._observer`.
  Assert `removed==0` summed over the whole repair for: a whole-block streamed tool append;
  a thinking plus summary append; each real-keystroke join; typing a character in a
  question; and Enter inside a question. Assert `created==1` for a streamed append of one
  foldable block, and `created==0` for the human edits.

- [ ] **Step 2: Run and confirm it fails.**
  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/document_fold_continuity_spec.lua" -c "qa!"`
  Expected: FAIL with `row N opened at step 3` (or similar) in the summary, thinking,
  second-exchange and streaming cases, and a nil-field error in the zero-touch cases
  (`removed` isn't reported yet). **Expected to PASS today (controls):** the blank matrix
  after a tool pair (no uncertainty, no structural apply).
  Record which cases were red in the issue Log, so Task 3/4 can show each one turning green.

- [ ] **Step 3: Commit.** `#264 M1: continuity spec for fold repair (red)`

### Task 2: `FoldDiff` (pure)

**Files:**
- Create: `lua/parley/fold_diff.lua`
- Test: `tests/unit/fold_diff_spec.lua`

- [ ] **Step 1: Failing unit tests.** Primary strategy: a **property test** over seeded
  random existing/desired interval sets (nested, overlapping, adjacent, identical;
  200 seeds, sizes 0-20), checked against an oracle. Simulate applying every batch to the
  existing set; the result must equal the desired set exactly. Exact matches must never
  appear in any batch. Each overlap-connected component of changed folds must lie in exactly
  one batch. Every batch holds ≤ `limit` groups unless it is a single component (see Step 3).
  Plus named regression cases, table-driven:
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
  excluded first); emit regions in row order and pack them into batches of ≤`limit` groups. A single
  connected region larger than `limit` becomes **its own batch** and exceeds `limit`: it
  can't be split without leaving part of a region unfolded between turns. Bound: such a
  region is at most the plan span's folds, and plan spans ≤ `INTERACTIVE_ROWS` (larger ones
  take the suspended path, where folds are invisible). Target under 80 lines.
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
  doesn't bump `changedtick`); if not, discard the plan and return `'more'` (re-plan).
  Before creating, check that each creation's rows have `foldlevel==0` after the batch's
  removals (a user `zf` inside the region between slices would otherwise nest the new
  fold); if not, discard the plan and re-plan. (ARCH-ORDER: user fold commands can
  interleave between slices; both checks are O(1) per group and put the stale-inventory
  case on the existing re-plan path instead of relying on the order of turns.) Then
  `zD` each removal (top to bottom, re-checking `current()` after each command as today),
  then `N,Mfold` each creation, then `foldopen` where `window.opened[identity]`. Keep
  `record_work` counters (`native_fold_ops`, `fold_groups_visited`), suspension and
  `restore_window` exactly as today; `notify({phase='reconcile',...})` gains
  `removed`/`created` counts (the zero-touch assertions read them).
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

### Task 4: Uncertainty does no native work

**Files:**
- Modify: `lua/parley/tool_folds.lua` (`clear_uncertainty` :257-310)

- [ ] **Step 1:** In `clear_uncertainty`, for scopes ≤ `INTERACTIVE_ROWS`, remove the
  frontier-to-EOF delete walk: keep only the widening of `s.first`/`s.last` to the scope and
  mark it handled (`s.uncertainty_cleared=true`). Above `INTERACTIVE_ROWS`, keep the
  existing delete walk and suspension unchanged.
- [ ] **Step 2:** Continuity spec: all cases PASS, including the edge and zero-touch cases.
- [ ] **Step 3:** Full fold and document suites green (the Task 3 Step 5 list), plus
  `tests/integration/chat_stop_generation_spec.lua` and
  `tests/integration/response_tools_spec.lua` (streaming writes). The #193/#194/#195/#200
  behaviours are defended by `tool_folds_spec.lua` (oracle, question never folded),
  `fold_invariants_spec.lua` and `document_folds_spec.lua` in that list. If any spec
  asserted that folds are cleared *before* repair (the old eager behaviour), change it to
  assert the settled oracle plus continuity, and note it in the issue Log with the reason.
- [ ] **Step 4: Commit.** `#264 M1: uncertainty no longer clears native folds`

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
  compute a local restart with a helper **extracted** from `before_splice` (:255-264, ARCH-DRY):
  `local function restart_point(w,row)` returns `restart,checkpoint` by pulling `row` back to
  the preceding row's `metadata.answer_header` row (a question-role edit has no header, so
  the restart stays `row`) and reading the preceding row's `metadata.after`, or `0` and
  `G.initial()` when that's missing. `before_splice` calls it with its
  `min(first, dependency origin, global)` row, with identical behaviour (its existing tests
  pin that); `before_fragment` calls it with `first`, reusing the `header` it already
  captured (:388) instead of re-reading it. If the helper returns restart 0 for a `first>0`
  (no preceding `metadata.after`), **don't** prepare a local restart. Then
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
  header to convergence). There's no new durable state (ARCH-FUNERAL: the plan and its
  inventory are in-memory and die with the plan).

## Deliberate narrowing (recorded in the issue's Revisions)

The issue Log (2026-09-19) proposed a per-kind negative: an edit below a `summary` or fenced
tool block should leave its confirmation intact. M2's restart at the answer header does
un-confirm a summary in the *same* answer, so the tests assert only that the restart is
bounded below by the header. Reason: M1 removes the visible symptom regardless of how far
confirmation reaches, and restarting inside an answer would need section-level restart
evidence the parser doesn't have yet. It's worth a follow-up only if settle time on long
answers shows up in measurements.

## Out of scope

- Folding a block as the writer writes it (so new blocks never appear unfolded): #290.

- Writing tool blocks in one piece (#290) and marker escaping (#291).
- Changing `INTERACTIVE_ROWS`/`BATCH_GROUPS` or the >50k-row suspension behaviour.
