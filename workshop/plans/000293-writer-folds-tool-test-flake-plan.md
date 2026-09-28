# Tool-round continuation latency (#293) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A large tool result (300 rows) no longer holds its round's continuation for seconds, and `writer_folds_spec` stops flaking — by cutting the work the document index and the highlighter do per repair step, not by waiting longer.

**Architecture:** The continuation is gated, by design, on document repair of the freshly written block (the write grant is suspended until repair confirms it). Repair itself is ~660 bounded steps; each step is expensive because (a) `document/sequence.lua` deep-copies summaries around every `combine` while rebuilding a 128-entry leaf, and (b) every repair step with deltas redraws, and the highlighter recomputes every row between `toprow` and `botrow` — including the 300 rows hidden inside the closed tool fold. We remove the redundant copies behind a purity contract (ARCH-PURE) and make the highlighter compute only rows a window can draw. Deterministic work counters, not wall time, guard both (ARCH-CONSTRAINTS).

**Tech Stack:** Lua (LuaJIT 2.1 in Neovim), plenary busted specs, `parley.document` work counters (`D.stats`).

---

## Evidence (from the #293 Log, captured runs)

- Result block written ~50ms after `complete`; continuation then waits on repair (`generation.lua` requires `grant_status=='valid'`; snapshot at timeout: `phase=executing_tools`, `grant_status=suspended`, `flush=pending`).
- Normal run: 658-670 productive repair steps, 1.9-5.2s (median 3.2s) vs the spec's 5s wait. Counters per run: 6-11M metadata values copied, ~2.85M summary values copied, 75-160k query results.
- `copy()` attribution: leaf rebuild `combine`/`combine_projection` (~141k top-level calls each, `sequence.lua:97/102`), branch rebuild (~70k each, `:434`), query `snapshot` (~167k, `:249<:329`, mostly the highlighter's per-redraw viewport query), `find_walk` predicates (~58k, `:699/:687`).
- Highlighter: 350 redraws x 2 passes (256 + 64 rows) per run, because `botrow` spans the closed 303-row fold. A throwaway fold-aware prototype cut query results ~3x.
- ~10% of runs are pathological on this arm64 macOS machine: LuaJIT reports `failed to allocate mcode memory` and flushes its trace cache ~1000 times; >98% of samples are in the trace compiler, per-step time ~55ms. Raising `maxmcode` did not help (4/40 still thrash) — it's the arm64 branch-range allocation under ASLR, an environmental amplifier we cannot fix. Less work per step is the only lever: it shrinks both the normal and the thrash case.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `combine` / `combine_projection` (sequence internals) | `lua/parley/document/sequence.lua` | modified |
| `visible_spans` | `lua/parley/highlighter.lua` | new |
| `until_progress` | `tests/helpers/await.lua` | new |

- **combine / combine_projection** — fold two node summaries into a parent summary. Today each call copies both operands and the result (`copy(s, s.combine(copy(a), copy(b)))`). New contract, documented on `sequence.new`: the supplied `combine`/`combine_projection` are pure — they never mutate their operands and always return a fresh table. The sequence then calls them without copies. The two shipped implementations (`grammar.merge_summary`, `projection.combine`) already satisfy this; a unit test pins it.
  - **Relationships:** 1 sequence : 1 combine pair, supplied by `structure.lua:new_sequence`.
  - **DRY rationale:** one purity contract replaces three defensive copies per call site.
  - **Future extensions:** the same contract can later cover `find_walk`'s `may_match`/`matches` predicates (Task 5 measures whether it's worth it).
- **visible_spans(first, last, fold_end_of)** — split a window's `[toprow, botrow]` into the row spans it actually draws: a closed fold contributes only its first row. `fold_end_of(row)` returns the fold's last row or nil; pure, no window access.
  - **Relationships:** called once per `on_win`; feeds `compute_window_decorations`.
  - **DRY rationale:** first occurrence; the fold walk lives in one tested place instead of inline in the decoration provider.
- **until_progress(predicate, progress, stall_ms, ceiling_ms)** — test wait that fails when `progress()` stops changing for `stall_ms`, or at a ceiling. Already written (uncommitted WIP) with `tests/unit/await_helper_spec.lua`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| decoration provider `on_win` | `lua/parley/highlighter.lua` | modified | Neovim redraw / fold state |
| `compute_window_decorations` | `lua/parley/highlighter.lua` | modified | `Document.query`, line reads |

- **on_win** — asks Neovim for fold ends (`foldclosedend` in the window) and passes them to `visible_spans`; computes decorations per span. Tests drive it through a real window with a real closed fold (no mocks).
- **compute_window_decorations** — gains a `margin` argument so the prefetch margin applies after the last visible span only, not after every span.

## Chunk 1: Guards first

### Task 1: Deterministic work-budget spec (red)

**Files:**
- Create: `tests/integration/repair_work_budget_spec.lua`

- [ ] **Step 1: Write the spec.** Set up a chat buffer like `writer_folds_spec` (same `parley.setup`, `F.setup`), write a 303-row `📎:` block (marker, fences, 300 body rows) with `nvim_buf_set_lines`, reset counters with `D.stats(doc, true)`, then `D.drain(doc)` synchronously (no redraw can run). Read `D.stats(doc)` and assert `summary_values_copied` and `metadata_values_copied` are below budgets.
- [ ] **Step 2: Measure baseline.** Temporarily print the two counters; record the numbers in the spec's header comment and in the issue Log. Set each budget to baseline / 5 (the combine change removes ~3 of every 3-4 copies on the rebuild path).
- [ ] **Step 3: Run; expect FAIL** on the budgets.
  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/repair_work_budget_spec.lua" -c "qa!"`
- [ ] **Step 4: Highlighter budget case.** Same buffer in a real window; close a fold over the block (`vim.cmd(first..','..last..'fold')`); spy `Document.query` to sum requested rows during one `M._compute_window_decorations`-driven redraw (`vim.api.nvim__redraw({win=w, valid=false, flush=true})`). Assert rows queried ≤ window height + `HIGHLIGHT_VIEWPORT_MARGIN` + 1. Expect FAIL (today: 320).
- [ ] **Step 5: Commit** `#293 M1: work-budget spec (red)` — on the issue branch; the spec is marked `pending` until M2/M3 land if the suite must stay green between commits.

### Task 2: Progress-aware wait in writer_folds_spec

**Files:**
- Modify: `tests/helpers/await.lua` (WIP already in tree), `tests/integration/writer_folds_spec.lua`
- Test: `tests/unit/await_helper_spec.lua` (WIP already in tree)

- [ ] **Step 1:** Strip all `PROBE` instrumentation from `writer_folds_spec.lua` (restore from `git diff`; keep only the `wait_for` rewrite, the repair subscription counting `event.result.status=='more'`, and `unsubscribe()` in `after_each`).
- [ ] **Step 2:** Ceiling 40000ms (below plenary's 50s file timeout, so a stuck run reports `ceiling` instead of dying silently).
- [ ] **Step 3:** Run helper spec + writer_folds_spec; expect PASS.
- [ ] **Step 4: Commit** `#293 M1: progress-aware wait for repair-gated rounds`.

- [ ] M1 — guards: budget spec (red/pending) + progress-aware wait; `sdlc milestone-close --issue 293 --milestone M1`

## Chunk 2: Cut the index copies

### Task 3: Purity contract for combine

**Files:**
- Modify: `lua/parley/document/sequence.lua:27-34` (`combine`, `combine_projection`), doc comment on `M.new`
- Test: `tests/unit/document_sequence_spec.lua`

- [ ] **Step 1: Failing test** — the shipped combines are pure: call `grammar.merge_summary(a,b)` and `projection.combine(a,b)` on deep-copied fixtures, assert operands unchanged and result `~=` either operand (fresh table). This passes already; the red test is the sequence one: build a sequence with a `combine` that records its operands' identities, update one row, and assert the operands passed are the stored summaries themselves (no copy) — fails today.
- [ ] **Step 2: Implement**
```lua
-- Supplied combine functions are pure: they never mutate operands and return
-- a fresh table (#293). Copying around them cost three deep copies per call on
-- every leaf/branch rebuild — millions per large write.
local function combine(s, a, b)
    if not s.combine then return nil end
    return s.combine(a, b)
end
local function combine_projection(s, a, b)
    if not s.combine_projection then return nil end
    return s.combine_projection(a, b)
end
```
- [ ] **Step 3:** Run `document_sequence_spec`, `document_dependencies_spec`, the seeded oracle specs (`make test-spec SPEC=chat/document`), and the budget spec's index case. Expect PASS; the index case turns green.
- [ ] **Step 4: Commit** `#293 M2: sequence combine without defensive copies`.

### Task 4: Re-measure; decide on find_walk predicates

- [ ] **Step 1:** Rerun the budget spec with counters printed. If `metadata_values_copied` from `find_walk` (`may_match`/`matches`) is still > 20% of the total, extend the purity contract to those predicates (`projection.lua:51-52`, `facts.lua:153-157` — check both only read), same test pattern as Task 3. Otherwise log the numbers and skip (YAGNI).

- [ ] M2 — index copies cut; `sdlc milestone-close --issue 293 --milestone M2`

## Chunk 3: Highlight only what a window draws

### Task 5: `visible_spans`

**Files:**
- Modify: `lua/parley/highlighter.lua` (new local + `M._visible_spans` test seam)
- Test: `tests/unit/highlighter_visible_spans_spec.lua`

- [ ] **Step 1: Failing tests** — no folds → one span `{first,last}`; a closed fold `[10,312]` inside `[0,330]` → `{0,10},{313,330}`; fold starting at `first`; fold running past `last`; adjacent folds.
- [ ] **Step 2: Implement**
```lua
-- Rows a window draws between first and last: a closed fold shows only its
-- first row (#293). fold_end_of(row) -> last row of the closed fold at row, or nil.
local function visible_spans(first, last, fold_end_of)
    local spans, row = {}, first
    while row <= last do
        local start = row
        while row <= last do
            local fold_end = fold_end_of(row)
            if fold_end then row = fold_end + 1; break end
            row = row + 1
        end
        spans[#spans + 1] = { start, math.min(row, last + 1) - 1 }
        -- a fold's first row was included above; its interior is skipped
    end
    return spans
end
```
(Adjust until the Step 1 cases pass; the fold's first row belongs to the span that reaches it.)
- [ ] **Step 3:** PASS; **commit** `#293 M3: visible_spans`.

### Task 6: `on_win` computes per visible span

**Files:**
- Modify: `lua/parley/highlighter.lua` `compute_window_decorations` (add `margin` param, default `HIGHLIGHT_VIEWPORT_MARGIN`), `on_win` (~line 1064-1100)

- [ ] **Step 1:** In `on_win`, inside `nvim_win_call`, build `fold_end_of = function(row) local e = vim.fn.foldclosedend(row + 1); return e ~= -1 and e - 1 or nil end`, take `visible_spans(cache.next_row, botrow, fold_end_of)`, and call `compute_window_decorations` per span with `margin = 0` except the last span. Keep the 256-row-per-redraw cap by summing span rows and stopping (setting `cache.next_row`) when it's reached.
- [ ] **Step 2:** Run the budget spec's highlighter case → PASS; run `tests/integration/*highlight*`, `tool_folds`, `writer_folds_spec`, `decoration` helpers' specs → PASS.
- [ ] **Step 3: Commit** `#293 M3: highlight only drawn rows`.

- [ ] M3 — highlighter bounded by drawn rows; `sdlc milestone-close --issue 293 --milestone M3`

## Verification (Done when)

- [ ] `writer_folds_spec` 50/50 consecutive runs alone (loop in the issue Log), and green inside `make test`.
- [ ] Budget spec green with the recorded baselines and new numbers in the Log.
- [ ] Settle time for the 303-row case re-measured (report median/p90 before → after).
- [ ] `atlas/chat/document.md`: the combine purity contract; `atlas/ui/` highlighter note: decorations computed for drawn rows only. `workshop/lessons.md`: "a fixed-timeout wait on repair-gated state hides a work-volume defect; measure counters" and the LuaJIT arm64 mcode thrash as an environmental amplifier.
