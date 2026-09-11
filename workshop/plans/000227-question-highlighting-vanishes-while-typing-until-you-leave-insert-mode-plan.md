# #227 Highlighting That Survives Typing — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A chat or markdown buffer keeps its Parley highlighting on every
redraw while the user types — Enter included — instead of dropping to plain
markdown until they leave insert mode.

**Architecture:** Every buffer edit is spliced onto the cached structure, so the
cache always lines up with the buffer row-for-row. The splice is *exact* for
ordinary typing (text, blank lines, Enter, joins) and *approximate* only when an
edit can move state the splice cannot see (a turn marker, `🧠:`, a footnote).
The decoration provider renders approximate structures instead of refusing
them, and one debounced rebuild — owned by the structure cache, not by an
unrelated event — brings an approximate structure back to exact after the burst.

**Tech Stack:** Lua (LuaJIT), Neovim 0.11 API (`nvim_buf_attach`, decoration
providers, `vim.uv` timers, `nvim__redraw`), plenary busted specs.

---

## Why the Spec's two steps are not quite enough

The issue's Spec asks for (1) render from the last good structure while dirty,
and (2) a debounced rebuild. Read literally, (1) renders a structure whose rows
no longer line up with the buffer. That matters, because three of the four
things the renderer reads from the structure are row-indexed:

- `footer_range` — `footer_start0` is a row. Press Enter in the last question of
  a chat that has definition footnotes and the stale value is now N rows too
  high, so the last N lines being typed render as **footnote** colour. That is
  precisely the "colour keeps changing while I type" report, relocated.
- `draft_blocks_in` — the draft background slides relative to the text while
  typing inside a markdown `=== draft ===` block.
- `state_before(row)` for the viewport top and for each `🧠:` lookahead.

With a debounce long enough for "one rebuild per burst", that misalignment
would last for the whole burst. So the stale structure must stay **aligned**:
each edit is spliced in (rows inserted/removed, tokens re-derived). Once it is
aligned, deciding whether the splice is also *exact* costs one state
comparison — which makes the Spec's "worth considering" fast path fall out of
the fix rather than being a separate change. The Spec gated that path on
measurement; the measurement is below and in the Log: the splice is ~250×
cheaper than a rebuild.

**This is a deliberate reversal of a #170 decision.** #170 made
`M.replace` refuse any line-count change and made a dirty cache render nothing,
to keep the per-keystroke path from ever touching the whole document. This plan
keeps #170's hard gates (zero full-buffer reads per keystroke, one structure row
per ordinary character edit, viewport-bounded redraw) and adds one bounded,
measured O(n) cost: a shallow reference copy on line-count edits.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `replace` (`highlight_structure.replace`) | `lua/parley/highlight_structure.lua` | modified |
| `build` (`highlight_structure.build`) | `lua/parley/highlight_structure.lua` | modified |
| `derive` (local) | `lua/parley/highlight_structure.lua` | new |
| `enter_row` / `leave_row` (locals) | `lua/parley/highlight_structure.lua` | new |
| `new_markers` / `add_marker` / `finish_markers` (locals) | `lua/parley/highlight_structure.lua` | new |
| `reasoning_explicit_of` (local) | `lua/parley/highlight_structure.lua` | new |
| `exit_state` (local) | `lua/parley/highlight_structure.lua` | new |
| `is_inert` / `same_state` / `initial_state` (locals) | `lua/parley/highlight_structure.lua` | new |

- **`highlight_structure.replace(structure, first0, old_last0, new_lines, patterns)`**
  — applies one edit (rows `[first0, old_last0)` replaced by `new_lines`) and
  returns `(out, rows, reason, work)`. New contract:
  - `out` is **always aligned** with the edited buffer when non-nil:
    `fingerprints`, `footer_start0`, `draft_ranges` are exact.
  - `reason == nil` → `state_before` is exact too (`out` equals
    `build(post_edit_lines)` field for field).
  - `reason == "structural"` → some `state_before` rows may carry pre-edit
    values — below the edit through the forward walk, and *above* it through
    the `🧠:` lookahead (an inserted `🧠:[END]` changes the block it closes);
    the caller owes a rebuild.
  - `out == nil, reason == "misaligned"` → the edit range does not fit this
    structure (`first0 > old_last0` or `old_last0 > #fingerprints`); rebuild.
  - Never mutates `structure`.
  - `work.rows_visited` counts rows classified plus rows walked;
    `work.entries_copied` counts array slots written by the splice.
  - **Relationships:** 1:1 with an `on_lines` event; consumed only by the
    highlighter's cache.
  - **DRY rationale:** it and `build` share `enter_row`/`leave_row`,
    `add_marker`, and `derive`, so a splice cannot interpret a token sequence
    differently from a full build.
  - **Future extensions:** exact handling of non-inert edits would widen
    `is_inert` plus a bounded lookahead rescan; not needed now.
- **Exactness rule.** A splice is exact iff (a) every removed and inserted token
  is **inert** — text `t`, blank `_`, fence `c<n>`, draft `d`/`D` — and (b) the
  first surviving row below the edit is entered in exactly the state it had
  before. Inert tokens never feed the `🧠:` lookahead or move the footer, so
  (a) protects everything above the edit and the footer relation below it;
  (b) then guarantees every later row, because the forward walk is
  deterministic from its entering state. Turn markers, `📝`/`🔧`/`📎`, `🧠:`,
  `🧠:[END]` and footnotes are non-inert.
- **`derive(fingerprints, footer_start0, draft_ranges, work)`** — everything a
  structure holds beyond its tokens. `build` = classify + `derive`; `replace`
  calls it when an edit spans the whole buffer (nothing to reuse).
- **`enter_row` / `leave_row`** — the pre-snapshot and post-snapshot halves of
  one row's forward step, lifted out of `build`'s loop (#218's phase split,
  now named). The blank-line terminator reads the `_` token instead of line
  text; `classify` assigns `_` to exactly the lines `^%s*$` matched.
- **`new_markers` / `add_marker` / `finish_markers`** — footer start and draft
  ranges accumulated token by token; `build` feeds them from classification,
  `replace` from its splice loop.
- **`reasoning_explicit_of`** — the existing backward `🧠:` lookahead pass,
  extracted; its terminator set becomes the module's existing
  `STRUCTURAL_TOKENS` (identical membership: `u a l b s U R`) instead of a
  second hand-written list.
- **`exit_state(structure, row0)`** — the state *leaving* a row, recomputed from
  `state_before[row0+1]`. A `🧠:` row's lookahead verdict is recovered from
  `state_before[row0+2].reasoning_explicit_end`, which `enter_row` never
  touches; the last row has nothing ahead, so its verdict is `false`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `rebuild_structure` | `lua/parley/highlighter.lua` | modified | `line_reader` full read, `nvim_buf_attach` |
| `on_lines` (structure cache) | `lua/parley/highlighter.lua` | modified | `nvim_buf_attach` on_lines |
| `on_reload` (structure cache) | `lua/parley/highlighter.lua` | new | `nvim_buf_attach` on_reload |
| `arm_repair` + `new_uv_deferral` | `lua/parley/highlighter.lua` | new | `vim.uv` timer, `vim.schedule_wrap`, `nvim__redraw` |
| `_set_repair_deferral` (`highlighter._set_repair_deferral`) | `lua/parley/highlighter.lua` | new | test seam over the deferral factory + delay |
| `setup_buf_handler` (its decoration provider's on_win) | `lua/parley/highlighter.lua` | modified | decoration provider |
| `forget_structure` (local) | `lua/parley/highlighter.lua` | new | cache entry + deferral teardown |
| `capture_provider` / `frame` / `has` / `manual_deferrals` | `tests/helpers/decoration.lua` | new | provider capture, frame capture, hand-fired repair deferral for specs |

- **`on_lines`** — splices every edit. A throwing splice, a `"misaligned"`
  result, or a spliced row count that differs from `nvim_buf_line_count`
  resyncs with a synchronous rebuild; if that fails too, the entry is dropped
  (drawing nothing beats drawing a misaligned structure). The row-count check
  exists because Nvim reports emptying a buffer as `new_lastline == 0` while
  keeping one empty line (probed this session: `on_lines 0 2 0`, then
  `line_count == 1`).
  - **Injected into:** nothing; it is the glue around `replace`.
- **`on_reload`** — `:checktime`/autoread replaces the text without `on_lines`.
  With no `on_reload` handler Nvim **detaches** the attachment instead (probed:
  only `on_detach` fires), clearing the cache so every window on the buffer but
  the current one renders plain until an unrelated event. The handler resyncs.
  Probed: `on_reload` already sees the new text.
- **`arm_repair` / deferral** — one restartable one-shot per cache. Every edit
  that leaves the cache dirty restarts it; a successful rebuild (from any
  source) stops it; teardown closes it. When it fires it checks the cache is
  still the same object, still dirty, and the buffer valid, rebuilds, then
  requests `nvim__redraw({ buf = buf, valid = false })`. `valid = false`
  because `valid = true` re-ran `on_win` but redrew **zero** lines of an
  unchanged buffer (probed).
  - **Injected into:** `on_lines` via the module-local factory; tests replace it
    with a hand-fired fake through `_set_repair_deferral`.
- **`on_win`** — renders whenever a cache entry exists; returns `false` only
  when there is no entry.

### Cache state × event (ARCH-ORDER)

| State ↓ / Event → | edit, exact splice | edit, approximate | splice throws / misaligned | repair fires | convergence event¹ | reload | teardown² |
|---|---|---|---|---|---|---|---|
| **ABSENT** (no entry) | — (not attached) | — | — | no-op (identity check) | build+attach → EXACT; fail → ABSENT | — | no-op |
| **EXACT** | EXACT | APPROXIMATE, arm | resync → EXACT, else ABSENT | no-op (not dirty) | no-op | resync → EXACT, else ABSENT | ABSENT, deferral closed |
| **APPROXIMATE** | APPROXIMATE, re-arm | APPROXIMATE, re-arm | resync → EXACT, else ABSENT | rebuild → EXACT, repaint; fail → APPROXIMATE, not re-armed | rebuild → EXACT, disarm; fail → APPROXIMATE, lifecycle notifies | resync | ABSENT, deferral closed |

¹ `InsertLeave`, `TextChanged`, `BufWritePost`, `BufEnter`, `WinEnter`, stream-leg
finalization — unchanged `buffer_lifecycle`. ² `BufUnload`/`BufDelete`
(`clear_structure`) and `on_detach`.

- Cache fields become `structure` (aligned), `dirty` (= APPROXIMATE), `repair`
  (the deferral), plus the unchanged attachment bookkeeping. `renderable` is
  **deleted**: it only ever equalled `not dirty`, and under fail-open a dirty
  cache renders.
- **Event most likely to be mishandled:** a repair callback that outlives its
  cache — teardown, or Nvim reusing the numeric handle for a new buffer. It is
  ignored by the identity check `structure_caches[buf] == cache`, and teardown
  closes the timer synchronously (lesson #189: never relinquish a resource
  because its cleanup was queued).
- **Extent:** at most one pending repair per cache; stopped by any successful
  rebuild; closed on teardown. A failed repair does not re-arm — the next edit
  or convergence event retries — so a deterministic build bug cannot loop.
- **Nondeterminism** enters only through the timer. Tests drive it through the
  injected deferral, so arm / restart / cancel / late-fire orderings are
  constructed, not sampled; one real-timer test proves the production wiring.

### Operating envelope (ARCH-CONSTRAINTS)

Workload: keystroke path in insert mode; chat/markdown buffers of 100–5,000
lines typical (the #170 perf fixture sizes), 20,000 as a stress bound.
Timings: pure LuaJIT, measured this session with `tests.perf.chat_typing`'s
fixture (scratch bench, 20–200 iterations).

| Path | Budget / cost | Basis | When exceeded |
|---|---|---|---|
| Keystroke, fingerprint-identical edit | classify changed rows, share arrays, 0 copies | #170 gate, unchanged | — |
| Keystroke, splice (Enter, join, blank↔text) | classify+walk the changed rows + one shallow copy of two n-slot arrays: **0.005 ms @1k, 0.019 ms @5k, 0.09 ms @20k** | measured | linear in n; still far under one redraw at 100k |
| Redraw | viewport + 20 rows, zero full-buffer reads | #170 hard gates, unchanged | — |
| Repair rebuild | full build **1.1 ms @1k, 5.5 ms @5k, 21.8 ms @20k** + one full read | measured | once per burst, only after an approximate edit, `STRUCTURE_REPAIR_MS` (250 ms) after the last edit — off the keystroke path |
| Memory | two n-slot arrays per splice (~80 KB @5k), garbage | estimate | — |
| Concurrency | ≤ 1 pending repair per buffer | design | restart, never queue |

`STRUCTURE_REPAIR_MS = 250` is an **operator choice** to confirm at approval:
longer than the gap between keystrokes of steady typing, short enough that a
pause converges almost at once. It only governs how long an approximate
structure waits; exact splices never schedule anything.

### Not applicable

- **ARCH-MOCK** — N/A: no external binary or service. Every seam here is the
  Neovim runtime the specs already run inside.
- **ARCH-SECURE** — N/A: the only input is buffer text in the same process,
  typed into tokens by `classify` at the boundary. Nothing persisted, no
  credentials. The one untrusted *shape* — Nvim's `on_lines` ranges — is
  validated (`"misaligned"` + the row-count check) before use.

### The class this fix belongs to (ARCH-PURPOSE)

The issue names one path — `on_lines` marking the cache dirty with nothing to
repair it. The class is **every way the structure stops matching its buffer
without a scheduled repair**. Enumerated:

| Path | Today | This plan |
|---|---|---|
| `on_lines`, edit `replace` cannot absorb (Enter, marker, blank↔text…) | dirty, renders nothing until an unrelated event | aligned splice; exact or approximate + scheduled repair |
| `on_lines`, splice throws | unprotected; error per keystroke | contained; synchronous resync |
| `on_lines`, Nvim's empty-buffer `new_lastline == 0` | n/a (bailed anyway) | row-count check → resync |
| `:checktime` / autoread reload | detach → cache cleared → non-current windows plain until BufEnter/WinEnter | `on_reload` resync |
| failed rebuild | `renderable = false` → renders nothing | keeps the aligned structure rendering |
| `:e!` | detach → `BufEnter` fires during the command and rebuilds (probed) | unchanged — already repaired synchronously |
| whole-buffer `set_lines` | bail → dirty | splice with no prefix/suffix → `derive` → exact |

## Non-goals

- Exact incremental handling of non-inert edits. They are rare in insert mode;
  approximate + one repair is enough.
- Changing #170's "diagnostics stay stale during `TextChangedI`" policy. The
  repair rebuilds only the structure; `buffer_lifecycle` is untouched.
- A user-facing option for the repair delay.

## Chunk 1: Pure splice

### Task 1: Split `build` into shared per-row steps

Behavior-preserving refactor so `replace` can reuse the exact steps `build`
uses. The existing `highlight_structure_spec.lua` build tests are the parity
oracle.

**Files:**
- Modify: `lua/parley/highlight_structure.lua:115-349` (`copy_state` … `M.build`)
- Test: `tests/unit/highlight_structure_spec.lua`

- [x] **Step 1: Write the guard for the one semantic substitution**

The refactor swaps the blank-line test `lines[row + 1]:match("^%s*$")` for
`token == "_"`. Pin whitespace-only lines, which are the only place the two
could disagree. Append inside the top `describe("highlight_structure", …)`:

```lua
    it("terminates legacy reasoning on whitespace-only lines, not just empty ones", function()
        for _, blank in ipairs({ "", "   ", "\t" }) do
            local built = structure.build({ "🧠: thought", "more", blank, "after" }, patterns)
            assert.is_true(structure.state_before(built, 2).in_reasoning, vim.inspect(blank))
            assert.is_false(structure.state_before(built, 3).in_reasoning, vim.inspect(blank))
        end
    end)
```

- [x] **Step 2: Run it — expect PASS on the current code** (it guards a refactor, so it must be green before and after)

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'`
Expected: all green.

- [x] **Step 3: Refactor**

Replace `M.build` (and add helpers above it, after `M.reset_partition`) with:

```lua
local function initial_state()
    return copy_state({
        in_question = false, in_code = false, in_reasoning = false,
        reasoning_explicit_end = false, in_tool = false,
    })
end

--- Footer start and draft ranges, accumulated one token at a time so `build`
--- (from classified lines) and `replace` (from a spliced token array) derive
--- them with the same code.
local function new_markers()
    return { footer_start0 = nil, draft_ranges = {}, draft_start = nil }
end

local function add_marker(markers, row0, token)
    if markers.footer_start0 == nil and token == TOKENS.footnote then
        markers.footer_start0 = row0
    end
    if token == TOKENS.draft_open and markers.draft_start == nil then
        markers.draft_start = row0
    elseif token == TOKENS.draft_end and markers.draft_start ~= nil then
        markers.draft_ranges[#markers.draft_ranges + 1] = {
            start_row = markers.draft_start, end_row_exclusive = row0 + 1,
        }
        markers.draft_start = nil
    end
end

local function finish_markers(markers, row_count)
    if markers.draft_start ~= nil then
        markers.draft_ranges[#markers.draft_ranges + 1] = {
            start_row = markers.draft_start, end_row_exclusive = row_count,
        }
    end
    return markers.footer_start0, markers.draft_ranges
end

--- PRE-snapshot half of a row's forward step: what the row resets on entry.
--- The footer ends exchange colouring; a partition clears code state (#218).
local function enter_row(state, row0, token, footer_start0)
    if footer_start0 and row0 >= footer_start0 then
        state.in_question = false
        state.in_reasoning = false
    end
    M.reset_partition(state, token)
end

--- POST-snapshot half: the row's own transition. `explicit` is the lookahead
--- verdict for a 🧠: row — does its 🧠:[END] arrive before the next marker.
--- Blank rows are the `_` token: `classify` gives it to exactly the lines the
--- old `^%s*$` test matched, so the walk needs no line text.
local function leave_row(state, token, explicit)
    M.advance(state, token)
    if token == TOKENS.reasoning_end then
        state.in_reasoning = false
        state.reasoning_explicit_end = false
    elseif token == TOKENS.reasoning then
        state.in_reasoning = true
        state.reasoning_explicit_end = explicit or false
    elseif state.in_reasoning and token == TOKENS.blank and not state.reasoning_explicit_end then
        state.in_reasoning = false
    end
end

--- Backward 🧠: lookahead. The markers that end it are STRUCTURAL_TOKENS —
--- the same set chat_parser terminates reasoning on — not a second list.
local function reasoning_explicit_of(fingerprints, work)
    local explicit, end_ahead = {}, false
    for index = #fingerprints, 1, -1 do
        work.rows_visited = work.rows_visited + 1
        local token = fingerprints[index]
        if token == TOKENS.reasoning then
            explicit[index] = end_ahead
        elseif token == TOKENS.reasoning_end then
            end_ahead = true
        elseif STRUCTURAL_TOKENS[token] then
            end_ahead = false
        end
    end
    return explicit
end

--- Everything a structure holds beyond its tokens, derived from them alone.
--- `build` is classify + derive; `replace` derives when an edit leaves no row
--- to reuse, so the two cannot disagree about what a token sequence means.
local function derive(fingerprints, footer_start0, draft_ranges, work)
    local explicit = reasoning_explicit_of(fingerprints, work)
    local state_before = {}
    local state = initial_state()
    for row0 = 0, #fingerprints - 1 do
        work.rows_visited = work.rows_visited + 1
        local token = fingerprints[row0 + 1]
        enter_row(state, row0, token, footer_start0)
        state_before[row0 + 1] = copy_state(state)
        leave_row(state, token, explicit[row0 + 1])
    end
    return {
        fingerprints = fingerprints,
        state_before = state_before,
        footer_start0 = footer_start0,
        draft_ranges = draft_ranges,
    }
end

function M.build(lines, patterns)
    lines = lines or {}
    patterns = patterns or M.patterns()
    local work = { rows_visited = 0, entries_copied = 0 }
    local fingerprints, markers = {}, new_markers()
    for row0 = 0, #lines - 1 do
        work.rows_visited = work.rows_visited + 1
        local token = M.classify(lines[row0 + 1], patterns).token
        fingerprints[row0 + 1] = token
        add_marker(markers, row0, token)
    end
    local footer_start0, draft_ranges = finish_markers(markers, #lines)
    return derive(fingerprints, footer_start0, draft_ranges, work), #lines, work
end
```

`build` still visits each row three times (classify, lookahead, walk), so the
existing `rows_visited = #lines * 3` assertion must stay green unchanged.

- [x] **Step 4: Run the unit spec plus every highlighting integration spec**

Run each (all must pass):
```
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/fence_containment_spec.lua' -c 'qa!'
```

- [x] **Step 5: Commit**

```bash
git add lua/parley/highlight_structure.lua tests/unit/highlight_structure_spec.lua
git commit -m "#227: split structure build into shared per-row steps"
```

### Task 2: `replace` returns an aligned splice and knows when it is exact

**Files:**
- Modify: `lua/parley/highlight_structure.lua` (`M.replace`, new locals `is_inert`, `same_state`, `exit_state`)
- Test: `tests/unit/highlight_structure_spec.lua` — rewrite the three tests that pin the old refusal (lines 123-151 and 251-259), add the shape table and the property test

- [x] **Step 1: Rewrite the tests that pinned refusal, and add the shape table**

Replace the test `"separates cardinality rejection's contract count from actual visits"` with:

```lua
    it("splices a pure insertion exactly and accounts its copy", function()
        local original = structure.build({ "💬: q", "body" }, patterns)
        local replaced, rows, reason, work = structure.replace(original, 1, 1, { "inserted" }, patterns)
        assert.is_nil(reason)
        assert.equals(1, rows)
        assert.are.same(structure.build({ "💬: q", "inserted", "body" }, patterns), replaced)
        -- 1 classified + 1 walked; 3 token slots + 3 state slots written.
        assert.are.same({ rows_visited = 2, entries_copied = 6 }, work)
    end)
```

Replace `"rejects structural replacements without suffix work or mutation"` with
the shape table below (it covers that test's six edits and more). Add the
fixture and helper at the top of the file, after `state(...)`:

```lua
-- One document exercising every structural feature a splice must keep right:
-- a question block, a legacy 🧠: block (blank-terminated), a fence, an
-- explicit 🧠: block (🧠:[END]), a draft, a second question, and a footer.
-- The turn markers at 11-12 matter: a 🧠: row does not end the lookahead, so
-- without a marker between them the [END] at 15 would make row 4 explicit too.
local DOC = {
    "💬: q",            -- 0
    "question body",    -- 1
    "",                 -- 2
    "🤖: a",            -- 3
    "🧠: legacy",       -- 4
    "legacy more",      -- 5
    "",                 -- 6  ends the legacy block
    "answer prose",     -- 7
    "```lua",           -- 8
    "code",             -- 9
    "```",              -- 10
    "💬: middle",       -- 11
    "🤖: a2",           -- 12
    "🧠: explicit",     -- 13
    "",                 -- 14 inside the explicit block
    "🧠:[END]",         -- 15
    "=== draft ===",    -- 16
    "draft body",       -- 17
    "=== end ===",      -- 18
    "💬: q2",           -- 19
    "typing here",      -- 20
    "",                 -- 21
    "[^x]: footnote",   -- 22
    "[^y]: second",     -- 23
}

local function splice_lines(lines, first0, old_last0, new_lines)
    local out = {}
    for i = 1, first0 do out[#out + 1] = lines[i] end
    for _, line in ipairs(new_lines) do out[#out + 1] = line end
    for i = old_last0 + 1, #lines do out[#out + 1] = lines[i] end
    return out
end
```

Then, inside `describe("highlight_structure", …)`:

```lua
    it("returns an aligned structure for every edit shape, exact exactly when promised", function()
        local cases = {
            -- name, first0, old_last0, new_lines, expected reason
            { "Enter mid-line in a question", 1, 2, { "question", " body" }, nil },
            { "Enter at the end of the typing line", 20, 21, { "typing here", "" }, nil },
            { "join a line with the blank below it", 20, 22, { "typing here" }, nil },
            { "first character on a blank line", 21, 22, { "x" }, nil },
            { "pure insertion of prose", 2, 2, { "new" }, nil },
            { "pure deletion of prose", 7, 8, {}, nil },
            { "insertion at row 0", 0, 0, { "preamble" }, nil },
            { "append at EOF", 24, 24, { "tail" }, nil },
            { "blank inside explicit reasoning", 14, 14, { "" }, nil },
            { "Enter inside a draft", 17, 18, { "draft", " body" }, nil },
            { "delete the draft closer", 18, 19, {}, nil },
            { "body line becomes a draft opener", 1, 2, { "=== draft ===" }, nil },
            { "body line becomes blank", 1, 2, { "" }, nil },
            { "whole buffer replaced", 0, 24, { "💬: fresh", "🧠: t", "", "x" }, nil },
            { "delete the blank that ends legacy reasoning", 6, 7, {}, "structural" },
            { "open a fence in prose", 7, 8, { "```" }, "structural" },
            { "widen a fence", 8, 9, { "````lua" }, "structural" },
            { "insert a turn marker", 7, 8, { "💬: new" }, "structural" },
            { "delete a turn marker", 1, 4, {}, "structural" },
            { "insert a 🧠: line", 7, 7, { "🧠: new" }, "structural" },
            { "delete 🧠:[END]", 15, 16, {}, "structural" },
            { "insert a footnote above the footer", 20, 20, { "[^z]: early" }, "structural" },
            { "delete the first footnote", 22, 23, {}, "structural" },
            { "body line becomes a footnote", 1, 2, { "[^x]: footer" }, "structural" },
        }
        local original = structure.build(DOC, patterns)
        for _, case in ipairs(cases) do
            local name, first0, old_last0, new_lines, want_reason = unpack(case, 1, 5)
            local snapshot = vim.deepcopy(original)
            local out, rows, reason = structure.replace(original, first0, old_last0, new_lines, patterns)
            local want = structure.build(splice_lines(DOC, first0, old_last0, new_lines), patterns)
            assert.are.same(snapshot, original, name .. ": mutated its input")
            assert.equals(#new_lines, rows, name)
            assert.equals(want_reason, reason, name)
            assert.are.same(want.fingerprints, out.fingerprints, name)
            assert.equals(want.footer_start0, out.footer_start0, name)
            assert.are.same(want.draft_ranges, out.draft_ranges, name)
            if want_reason == nil then
                assert.are.same(want.state_before, out.state_before, name)
            end
        end
    end)

    it("never claims exact when an edit changes the lookahead of a 🧠: row above it", function()
        -- Inserting 🧠:[END] turns the legacy block at row 0 explicit, so the
        -- blank at row 1 stops terminating it: rows 1-2 change state ABOVE the
        -- edit, where the convergence check (which looks below) cannot see.
        -- Only the inertness rule rejects this.
        local lines = { "🧠: a", "", "x", "[^f]: n" }
        local original = structure.build(lines, patterns)
        local out, _, reason = structure.replace(original, 3, 3, { "🧠:[END]" }, patterns)
        assert.equals("structural", reason)
        local want = structure.build({ "🧠: a", "", "x", "🧠:[END]", "[^f]: n" }, patterns)
        assert.are_not.same(want.state_before, out.state_before, "fixture must exercise stale rows above")
    end)

    it("refuses an edit range that does not fit the structure", function()
        local original = structure.build({ "a" }, patterns)
        for _, edit in ipairs({ { 0, 2 }, { 1, 0 }, { 2, 2 } }) do
            local out, _, reason = structure.replace(original, edit[1], edit[2], { "x" }, patterns)
            assert.is_nil(out)
            assert.equals("misaligned", reason)
        end
    end)
```

In the `#218` describe, change `"replace: editing a fence's WIDTH invalidates the fast path"` to:

```lua
    it("replace: editing a fence's WIDTH is never claimed exact", function()
        -- PQ-2. TOKENS.fence used to be one token for every width, so this edit
        -- kept an identical fingerprint and M.replace served stale state for the
        -- rest of the buffer. Now it splices, and must say the state is stale.
        local lines = { "🤖: a", "```", "body", "```", "after" }
        local built = structure.build(lines, P)
        local out, _, reason = structure.replace(built, 1, 2, { "````" }, P)
        assert.equals("structural", reason, "a width edit must force a rebuild")
        assert.are.same(structure.build({ "🤖: a", "````", "body", "```", "after" }, P).fingerprints,
            out.fingerprints)
    end)
```

- [x] **Step 2: Add the property test**

Append at the end of the file:

```lua
-- #227: the splice's whole contract, over random documents and edit
-- sequences. Tokens, footer and drafts must ALWAYS match a fresh build; state
-- must match whenever replace claims exactness. The vocabulary is weighted to
-- inert rows so both outcomes are exercised heavily.
describe("replace splices stay aligned and honest about exactness (#227)", function()
    local VOCAB = {
        "prose", "prose", "prose", "prose", "more prose", "", "", "   ",
        "```", "````", "=== d ===", "=== end ===",
        "💬: q", "🤖: a", "🧠: r", "🧠:[END]", "[^n]: f", "📝: s", "🔧: t", "📎: r",
        "🌿: b", "🔒: l",
    }
    local function random_lines(count)
        local out = {}
        for i = 1, count do out[i] = VOCAB[math.random(#VOCAB)] end
        return out
    end

    it("matches build() on tokens/footer/drafts always, and on state whenever exact", function()
        math.randomseed(227)
        local exact, approximate = 0, 0
        for _ = 1, 300 do
            local lines = random_lines(math.random(0, 24))
            local current = structure.build(lines, patterns)
            for _ = 1, 12 do
                local first0 = math.random(0, #lines)
                local old_last0 = math.random(first0, math.min(#lines, first0 + 3))
                local inserted = random_lines(math.random(0, 3))
                local post = splice_lines(lines, first0, old_last0, inserted)
                local context = string.format("\nedit [%d,%d) <- %s\nlines:\n%s", first0, old_last0,
                    vim.inspect(inserted), table.concat(lines, "\n"))
                local snapshot = vim.deepcopy(current)
                local out, _, reason = structure.replace(current, first0, old_last0, inserted, patterns)
                local want = structure.build(post, patterns)
                assert.are.same(snapshot, current, "replace mutated its input" .. context)
                assert.are.same(want.fingerprints, out.fingerprints, context)
                assert.equals(want.footer_start0, out.footer_start0, context)
                assert.are.same(want.draft_ranges, out.draft_ranges, context)
                if reason == nil then
                    exact = exact + 1
                    assert.are.same(want.state_before, out.state_before, context)
                    current = out
                else
                    approximate = approximate + 1
                    assert.equals("structural", reason, context)
                    current = want -- what the caller's repair does
                end
                lines = post
            end
        end
        -- Non-vacuity: a property test that never reaches a branch proves nothing.
        assert.is_true(exact >= 150, "exact splices exercised: " .. exact)
        assert.is_true(approximate >= 150, "approximate splices exercised: " .. approximate)
    end)
end)
```

- [x] **Step 3: Run — expect RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'`
Expected: the new tests fail (current `replace` returns `nil` for every line-count change).

- [x] **Step 4: Implement**

Replace `M.replace` with:

```lua
--- Inert tokens never feed the 🧠: lookahead or move the footer, so an edit
--- made only of them can change later rows solely through the forward walk —
--- which `replace` checks directly. Every other token can move state a splice
--- cannot see.
local function is_inert(token)
    return token == TOKENS.text or token == TOKENS.blank
        or token == TOKENS.draft_open or token == TOKENS.draft_end
        or token:sub(1, 1) == TOKENS.fence
end

local function same_state(a, b)
    return a.in_question == b.in_question and a.in_code == b.in_code
        and a.code_fence_len == b.code_fence_len and a.in_reasoning == b.in_reasoning
        and a.reasoning_explicit_end == b.reasoning_explicit_end and a.in_tool == b.in_tool
end

--- The state LEAVING `row0`. `state_before` holds the state entering each row
--- (after that row's own resets), so a row's exit is recomputed from its entry.
--- A 🧠: row's lookahead verdict rides in the next row's entering state, which
--- `enter_row` never touches; the last row has nothing ahead of it.
local function exit_state(structure, row0)
    local state = copy_state(structure.state_before[row0 + 1])
    local after = structure.state_before[row0 + 2]
    leave_row(state, structure.fingerprints[row0 + 1], after and after.reasoning_explicit_end or false)
    return state
end

--- Apply one buffer edit — rows [first0, old_last0) replaced by `new_lines` —
--- and return a structure ALIGNED with the edited buffer (#227).
---
--- Tokens, footer and draft ranges are always exact. `reason` says whether
--- `state_before` is:
---   nil           exact — identical to build() of the edited buffer
---   "structural"  some rows may keep pre-edit state: below the edit via the
---                 forward walk, above it via the 🧠: lookahead; rebuild
---   "misaligned"  (no structure) the range does not fit; rebuild
--- Never writes `structure`.
function M.replace(structure, first0, old_last0, new_lines, patterns)
    new_lines = new_lines or {}
    patterns = patterns or M.patterns()
    local old_n = #structure.fingerprints
    local m = #new_lines
    local work = { rows_visited = 0, entries_copied = 0 }
    if first0 < 0 or first0 > old_last0 or old_last0 > old_n then
        return nil, m, "misaligned", work
    end
    local inserted = {}
    for i, line in ipairs(new_lines) do
        work.rows_visited = work.rows_visited + 1
        inserted[i] = M.fingerprint(line, patterns)
    end

    -- Same span, same tokens: every derived value is unchanged, so share it.
    if old_last0 - first0 == m then
        local identical = true
        for i = 1, m do
            if inserted[i] ~= structure.fingerprints[first0 + i] then
                identical = false
                break
            end
        end
        if identical then
            return {
                fingerprints = structure.fingerprints,
                state_before = structure.state_before,
                footer_start0 = structure.footer_start0,
                draft_ranges = structure.draft_ranges,
            }, m, nil, work
        end
    end

    -- Splice the tokens; footer and drafts are re-derived in the same pass.
    local delta = m - (old_last0 - first0)
    local new_n = old_n + delta
    local fingerprints, markers = {}, new_markers()
    for row0 = 0, new_n - 1 do
        local token
        if row0 < first0 then
            token = structure.fingerprints[row0 + 1]
        elseif row0 < first0 + m then
            token = inserted[row0 - first0 + 1]
        else
            token = structure.fingerprints[row0 - delta + 1]
        end
        fingerprints[row0 + 1] = token
        add_marker(markers, row0, token)
    end
    work.entries_copied = work.entries_copied + new_n
    local footer_start0, draft_ranges = finish_markers(markers, new_n)

    -- Nothing above or below survives: derive the whole thing.
    if first0 == 0 and old_last0 == old_n then
        return derive(fingerprints, footer_start0, draft_ranges, work), m, nil, work
    end

    -- Walk the inserted rows forward from the state leaving the row above.
    local state = first0 == 0 and initial_state() or exit_state(structure, first0 - 1)
    local walked = {}
    for i = 1, m do
        work.rows_visited = work.rows_visited + 1
        enter_row(state, first0 + i - 1, inserted[i], footer_start0)
        walked[i] = copy_state(state)
        -- An inserted 🧠: row's verdict is unknown here. It is not inert, so
        -- the result is already approximate and the caller's rebuild settles it.
        leave_row(state, inserted[i], false)
    end

    -- Converged when the first surviving row below is entered exactly as before.
    local converged = true
    if old_last0 < old_n then
        enter_row(state, first0 + m, structure.fingerprints[old_last0 + 1], footer_start0)
        converged = same_state(state, structure.state_before[old_last0 + 1])
    end

    local state_before = {}
    for row0 = 0, new_n - 1 do
        if row0 < first0 then
            state_before[row0 + 1] = structure.state_before[row0 + 1]
        elseif row0 < first0 + m then
            state_before[row0 + 1] = walked[row0 - first0 + 1]
        else
            state_before[row0 + 1] = structure.state_before[row0 - delta + 1]
        end
    end
    work.entries_copied = work.entries_copied + new_n

    local exact = converged
    for i = 1, m do
        if not is_inert(inserted[i]) then exact = false end
    end
    for row = first0 + 1, old_last0 do
        if not is_inert(structure.fingerprints[row]) then exact = false end
    end
    return {
        fingerprints = fingerprints,
        state_before = state_before,
        footer_start0 = footer_start0,
        draft_ranges = draft_ranges,
    }, m, (not exact) and "structural" or nil, work
end
```

- [x] **Step 5: Run — expect GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/unit/highlight_structure_spec.lua' -c 'qa!'`
Expected: all pass. If a shape-table row's expected reason disagrees, do not
edit the expectation to match — derive by hand whether the edit can change
later state, and fix whichever side is wrong.

- [x] **Step 6: Break the invariant and watch it fail** (lessons 2026-08-22: a guard is finished when you have seen it red)

One at a time, re-run the spec after each temporary change, confirm RED, revert:
1. `local converged = true` with the `if old_last0 < old_n` block deleted → property test and "delete the blank that ends legacy reasoning" go red.
2. `is_inert` returning `true` always → the property test and `"never claims
   exact when an edit changes the lookahead of a 🧠: row above it"` go red.
   (Shape rows like "insert a 🧠: line" stay green: convergence already fails
   below them. Only an edit whose effect lands *above* it isolates inertness.)
3. `add_marker(markers, row0, token)` removed from the splice loop → footer/draft assertions go red.

Record the three observed failures in the issue `## Log`.

- [x] **Step 7: Lint and commit**

```bash
make lint
git add lua/parley/highlight_structure.lua tests/unit/highlight_structure_spec.lua
git commit -m "#227: splice every edit into an aligned structure, exact when inert"
```

## Chunk 2: The cache renders while typing and repairs itself

### Task 3: Shared decoration test helpers

**Files:**
- Create: `tests/helpers/decoration.lua`
- Modify: `tests/integration/highlighting_spec.lua:71-83` (its local `capture_decoration_provider` delegates to the helper)

- [x] **Step 1: Create the helper**

```lua
-- Decoration-provider fixtures shared by the highlighting specs.
local M = {}

--- The provider `setup_buf_handler` registers, captured without installing it.
function M.capture_provider(parley)
    local original = vim.api.nvim_set_decoration_provider
    local captured
    vim.api.nvim_set_decoration_provider = function(_, provider) captured = provider end
    local ok, err = pcall(parley.setup_buf_handler)
    vim.api.nvim_set_decoration_provider = original
    assert(ok, err)
    return captured
end

--- One redraw frame over rows [top, bot]: `false` when on_win declined to draw,
--- else every extmark on_line placed, as { row, col, end_col, hl_group }.
function M.frame(provider, win, buf, top, bot)
    if provider.on_win(nil, win, buf, top, bot) == false then
        return false
    end
    local drawn = {}
    local original = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(_, _, row, col, opts)
        drawn[#drawn + 1] = { row = row, col = col, end_col = opts.end_col, hl_group = opts.hl_group }
        return 1
    end
    local ok, err = pcall(function()
        for row = top, bot do provider.on_line(nil, win, buf, row) end
    end)
    vim.api.nvim_buf_set_extmark = original
    assert(ok, err)
    return drawn
end

function M.has(drawn, row, hl_group)
    for _, mark in ipairs(drawn or {}) do
        if mark.row == row and mark.hl_group == hl_group then return true end
    end
    return false
end

return M
```

- [x] **Step 2: Point `highlighting_spec.lua` at it**

Replace lines 71-83 of `tests/integration/highlighting_spec.lua` with:

```lua
local decoration = require("tests.helpers.decoration")

local function capture_decoration_provider()
    return decoration.capture_provider(parley)
end
```

- [x] **Step 3: Run `highlighting_spec.lua`** — expect unchanged pass/fail (green).

- [x] **Step 4: Commit**

```bash
git add tests/helpers/decoration.lua tests/integration/highlighting_spec.lua
git commit -m "#227: share decoration-provider test fixtures"
```

### Task 4: Fail open, splice in `on_lines`, repair on a timer, resync on reload

**Files:**
- Modify: `lua/parley/highlighter.lua:62-63` (constants), `:908-973` (`rebuild_structure`, `clear_structure`), `:992-999` (`on_win`)
- Modify: `tests/integration/highlighting_spec.lua` — the four tests that pin fail-closed (lines ~545, 572-590, 626-647, 852-876)
- Create: `tests/integration/highlight_typing_spec.lua`
- Modify: `tests/perf/chat_typing.lua:300` (`cache.renderable` → `cache.structure`)

- [x] **Step 1: Write `tests/integration/highlight_typing_spec.lua` (RED)**

```lua
-- #227: highlighting must not blank or shimmer while typing. Every edit splices
-- the buffer's structure so it stays aligned; an edit it cannot apply exactly
-- leaves it approximate — still rendering — until one scheduled rebuild.
local tmp_dir = vim.fn.tempname() .. "-parley-typing"
vim.fn.mkdir(tmp_dir, "p")
local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })

local decoration = require("tests.helpers.decoration")
local highlighter = require("parley.highlighter")
local model = require("parley.highlight_structure")

-- The operator's shape: a chat whose last question is being typed, above a
-- managed footnote footer (the row-indexed value a stale structure gets wrong).
local CHAT = {
    "---", "topic: t", "file: f.md", "---", "",
    "💬: Astrophotography.",           -- 5
    "what should I buy first?",       -- 6
    "",                               -- 7
    "🤖: [Claude]",                    -- 8
    "🧠: legacy thought",              -- 9
    "",                               -- 10
    "Start with a tracking mount.",   -- 11
    "",                               -- 12
    "💬: follow up",                   -- 13
    "",                               -- 14  <- typing happens here
    "",                               -- 15
    "[^mount]: a motorized base",     -- 16
}

local DRAFT = { "# notes", "", "=== draft ===", "first", "", "=== end ===", "after" }

-- Deferrals the test fires by hand (highlighter._set_repair_deferral), so the
-- arm / restart / cancel ordering is asserted rather than sampled from a clock.
local function manual_deferrals()
    local log = { starts = 0, all = {} }
    local function factory()
        local d = { pending = nil, closed = false }
        function d:start(_, fn) log.starts = log.starts + 1; self.pending = fn end
        function d:stop() self.pending = nil end
        function d:close() self.closed = true; self.pending = nil end
        log.all[#log.all + 1] = d
        return d
    end
    function log.pending()
        local n = 0
        for _, d in ipairs(log.all) do if d.pending then n = n + 1 end end
        return n
    end
    function log.fire()
        local fired = 0
        for _, d in ipairs(log.all) do
            local fn = d.pending
            d.pending = nil
            if fn then fired = fired + 1; fn() end
        end
        return fired
    end
    return log, factory
end

local function open(lines, kind)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    parley._parley_bufs[buf] = kind or "chat"
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    assert.is_truthy(highlighter.rebuild_structure(buf))
    return buf, win
end

local function oracle(buf)
    return model.build(vim.api.nvim_buf_get_lines(buf, 0, -1, false), model.patterns(parley.config))
end

-- The whole-buffer row map a structure produces; comparing live against
-- oracle(buf) compares exactly what differs between an incremental and a
-- clean render.
local function decorations(buf, win, structure)
    local last = vim.api.nvim_buf_line_count(buf) - 1
    return highlighter._compute_window_decorations(win, buf, 0, last, nil, structure)
end

local function count_builds(buf)
    local n = 0
    require("parley.line_reader").set_observer(buf, function(event)
        if event.operation == "structure_build" then n = n + 1 end
    end)
    return function() return n end
end

-- One real buffer edit per keystroke, so Neovim's on_lines reports each exactly
-- as it would an insert-mode key. ASCII only; "\n" is Enter.
local function type_text(buf, row, col, text, each)
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == "\n" then
            vim.api.nvim_buf_set_text(buf, row, col, row, col, { "", "" })
            row, col = row + 1, 0
        else
            vim.api.nvim_buf_set_text(buf, row, col, row, col, { ch })
            col = col + 1
        end
        if each then each() end
    end
    return row, col
end

local restore_deferral
local deferrals

describe("highlighting while typing (#227)", function()
    before_each(function()
        local factory
        deferrals, factory = manual_deferrals()
        restore_deferral = highlighter._set_repair_deferral(factory)
    end)
    after_each(function()
        restore_deferral()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == "" then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end)

    it("renders every frame exactly like a clean rebuild while typing a list with Enter", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local text = "1. a mount\n2. a camera\n3. patience"
        local frames = 0
        type_text(buf, 14, 0, text, function()
            frames = frames + 1
            local cache = highlighter._structure_cache(buf)
            assert.is_false(cache.dirty, "ordinary typing must splice exactly")
            -- The whole structure, not just what row 0's viewport consumes:
            -- a scrolled window reads state_before at its own top row.
            assert.are.same(oracle(buf), cache.structure)
            local drawn = decoration.frame(provider, win, buf, 0, vim.api.nvim_buf_line_count(buf) - 1)
            assert.is_truthy(drawn, "a frame drew nothing")
            assert.is_true(decoration.has(drawn, 13, "ParleyQuestion"))
            assert.are.same(decorations(buf, win, oracle(buf)), decorations(buf, win, cache.structure))
        end)
        assert.equals(#text, frames)
        assert.equals(0, deferrals.starts)
    end)

    it("keeps a markdown draft background on every draft row while typing inside it", function()
        local buf, win = open(DRAFT, "markdown")
        type_text(buf, 3, 5, " line\nsecond\n", function()
            local cache = highlighter._structure_cache(buf)
            assert.is_false(cache.dirty)
            assert.are.same(decorations(buf, win, oracle(buf)), decorations(buf, win, cache.structure))
        end)
    end)

    it("still draws rows outside a line-count edit", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        vim.api.nvim_buf_set_lines(buf, 14, 14, false, { "", "" })
        local drawn = decoration.frame(provider, win, buf, 0, vim.api.nvim_buf_line_count(buf) - 1)
        assert.is_truthy(drawn)
        assert.is_true(decoration.has(drawn, 5, "ParleyQuestion"), "question above the edit")
        assert.is_true(decoration.has(drawn, 18, "ParleyFootnote"), "footer below it, shifted")
        assert.is_false(decoration.has(drawn, 16, "ParleyFootnote"), "old footer row is typing now")
    end)

    it("renders an approximate structure and repairs it without any convergence event", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local builds = count_builds(buf)
        local calls = { hqb = 0, redraw = {} }
        local original_hqb = highlighter.highlight_question_block
        highlighter.highlight_question_block = function(...) calls.hqb = calls.hqb + 1; return original_hqb(...) end
        local original_redraw = vim.api.nvim__redraw
        vim.api.nvim__redraw = function(opts) calls.redraw[#calls.redraw + 1] = opts end

        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        local cache = highlighter._structure_cache(buf)
        assert.is_true(cache.dirty)
        assert.is_truthy(decoration.frame(provider, win, buf, 0, 16), "fail open while dirty")
        assert.equals(1, deferrals.pending())
        assert.equals(0, builds())

        assert.equals(1, deferrals.fire())
        highlighter.highlight_question_block = original_hqb
        vim.api.nvim__redraw = original_redraw

        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
        assert.equals(1, builds())
        assert.equals(0, calls.hqb)
        assert.are.same({ { buf = buf, valid = false } }, calls.redraw)
    end)

    it("costs one rebuild per burst on a long chat: each dirtying edit restarts the one pending repair", function()
        local lines, target = require("tests.perf.chat_typing").build_fixture(5000)
        local buf = open(lines)
        local builds = count_builds(buf)
        vim.api.nvim_buf_set_lines(buf, target, target, false, { "```" })
        local text = "local x = 1\nprint(x)\n"
        type_text(buf, target + 1, 0, text)
        assert.equals(1 + #text, deferrals.starts, "every edit on a dirty cache restarts the repair")
        assert.equals(1, deferrals.pending(), "restart, never queue")
        assert.equals(0, builds(), "nothing rebuilt mid-burst")
        deferrals.fire()
        assert.equals(1, builds())
        assert.is_false(highlighter._structure_cache(buf).dirty)
    end)

    it("never schedules a rebuild for a plain-text burst with Enter on a long chat", function()
        local lines, target = require("tests.perf.chat_typing").build_fixture(5000)
        local buf = open(lines)
        local builds = count_builds(buf)
        type_text(buf, target - 1, #lines[target], "\nhello\nworld")
        assert.equals(0, deferrals.starts)
        assert.equals(0, builds())
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("closes a pending repair on teardown so a late fire touches nothing", function()
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "💬: new" })
        local deferral = deferrals.all[1]
        local late = deferral.pending
        highlighter.clear_structure(buf)
        assert.is_true(deferral.closed)
        local builds = count_builds(buf)
        late()
        assert.equals(0, builds())
        assert.is_nil(highlighter._structure_cache(buf))
    end)

    it("closes a pending repair when Nvim detaches the buffer", function()
        -- Called directly: deleting the buffer would also run the BufUnload
        -- autocmd's clear_structure, hiding whether on_detach tears down alone.
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "💬: new" })
        local deferral = deferrals.all[1]
        highlighter._structure_cache(buf).on_detach(nil, buf)
        assert.is_true(deferral.closed)
        assert.is_nil(highlighter._structure_cache(buf))
    end)

    it("resyncs when a splice throws instead of erroring on every keystroke", function()
        local buf = open(CHAT)
        local original = model.replace
        model.replace = function() error("forced splice failure") end
        local ok = pcall(vim.api.nvim_buf_set_lines, buf, 14, 14, false, { "x" })
        model.replace = original
        assert.is_true(ok)
        local cache = highlighter._structure_cache(buf)
        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
    end)

    it("drops a cache it cannot realign, then recovers on the next rebuild", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local replace, build = model.replace, model.build
        model.replace = function() error("splice") end
        model.build = function() error("build") end
        pcall(vim.api.nvim_buf_set_lines, buf, 14, 14, false, { "x" })
        model.replace, model.build = replace, build
        assert.is_nil(highlighter._structure_cache(buf))
        assert.is_false(provider.on_win(nil, win, buf, 0, 5))
        assert.is_truthy(highlighter.rebuild_structure(buf))
        vim.api.nvim_buf_set_lines(buf, 14, 14, false, { "y" })
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("stays aligned through Nvim's empty-buffer line", function()
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
        assert.equals(1, #highlighter._structure_cache(buf).structure.fingerprints)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: a", "b", "c" })
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("keeps the structure aligned with the buffer across random real edits", function()
        -- The unit property test models on_lines ranges; this one takes them
        -- from Neovim itself, including multi-line set_text joins and splits.
        local VOCAB = { "prose", "", "```", "💬: q", "🤖: a", "🧠: r", "🧠:[END]", "[^n]: f", "=== d ===" }
        math.randomseed(2270)
        local buf = open(CHAT)
        for step = 1, 400 do
            local n = vim.api.nvim_buf_line_count(buf)
            local pick = math.random(4)
            local repl = {}
            for i = 1, math.random(1, 3) do repl[i] = VOCAB[math.random(#VOCAB)] end
            if pick == 1 then
                local sr = math.random(0, n - 1)
                local er = math.random(sr, math.min(n - 1, sr + 2))
                local sl = vim.api.nvim_buf_get_lines(buf, sr, sr + 1, false)[1]
                local el = vim.api.nvim_buf_get_lines(buf, er, er + 1, false)[1]
                local sc = math.random(0, 1) == 0 and 0 or #sl
                local ec = (er == sr) and #sl or (math.random(0, 1) == 0 and 0 or #el)
                vim.api.nvim_buf_set_text(buf, sr, sc, er, ec, repl)
            elseif pick == 2 then
                local at = math.random(0, n)
                vim.api.nvim_buf_set_lines(buf, at, at, false, repl)
            elseif pick == 3 then
                local s = math.random(0, n - 1)
                vim.api.nvim_buf_set_lines(buf, s, math.min(n, s + math.random(1, 2)), false, {})
            else
                local s = math.random(0, n - 1)
                vim.api.nvim_buf_set_lines(buf, s, s + 1, false, repl)
            end
            local cache = highlighter._structure_cache(buf)
            local want = oracle(buf)
            local context = "step " .. step
            assert.equals(vim.api.nvim_buf_line_count(buf), #cache.structure.fingerprints, context)
            assert.are.same(want.fingerprints, cache.structure.fingerprints, context)
            assert.equals(want.footer_start0, cache.structure.footer_start0, context)
            assert.are.same(want.draft_ranges, cache.structure.draft_ranges, context)
            if cache.dirty then
                deferrals.fire() -- the repair; exact state is then required below
                assert.is_false(cache.dirty, context)
            end
            assert.are.same(want.state_before, cache.structure.state_before, context)
        end
    end)

    it("resyncs on a :checktime reload instead of detaching", function()
        local path = tmp_dir .. "/reload.md"
        vim.fn.writefile(CHAT, path)
        -- noautocmd: no BufEnter, so buffer_lifecycle never adopts this buffer
        -- and nothing but the structure cache's own on_reload can repair it.
        vim.cmd("noautocmd edit " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        parley._parley_bufs[buf] = "chat"
        assert.is_truthy(highlighter.rebuild_structure(buf))
        local autoread = vim.o.autoread
        vim.o.autoread = true
        vim.fn.writefile({ "💬: replaced", "body", "[^a]: note" }, path)
        local now = os.time() + 5
        vim.uv.fs_utime(path, now, now)
        vim.cmd("checktime " .. buf)
        vim.o.autoread = autoread
        local cache = highlighter._structure_cache(buf)
        assert.is_truthy(cache, "reload detached the structure cache")
        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
        vim.api.nvim_buf_delete(buf, { force = true })
        vim.fn.delete(path)
    end)
end)

describe("highlighting repair on the real clock (#227)", function()
    it("fires the production timer, rebuilds, and invalidates the window for repaint", function()
        local restore = highlighter._set_repair_deferral(nil, 20)
        local buf = open(CHAT)
        local builds = count_builds(buf)
        -- A second provider counts lines actually redrawn in this window.
        local counted = 0
        local ns = vim.api.nvim_create_namespace("parley-227-redraw-probe")
        vim.api.nvim_set_decoration_provider(ns, {
            on_win = function(_, _, wbuf) return wbuf == buf end,
            on_line = function() counted = counted + 1 end,
        })
        vim.cmd("redraw")
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        vim.cmd("redraw")
        assert.is_true(highlighter._structure_cache(buf).dirty)
        -- Reset BEFORE waiting: whether the main loop flushes the invalidation
        -- inside vim.wait or only at the explicit redraw below, it is counted.
        -- Without the repair's invalidation nothing redraws at all — the text
        -- has not changed since the last redraw.
        counted = 0
        assert.is_true(vim.wait(2000, function() return not highlighter._structure_cache(buf).dirty end, 5),
            "repair never fired")
        vim.cmd("redraw")
        vim.api.nvim_set_decoration_provider(ns, {})
        restore()
        assert.equals(1, builds())
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
        assert.is_true(counted >= 10, "repair did not invalidate the window: " .. counted .. " lines redrawn")
        vim.api.nvim_buf_delete(buf, { force = true })
    end)
end)
```

Note for the real-clock test: `open` and `oracle` are file-level locals, so the
second `describe` can use them.

- [x] **Step 2: Run it — expect RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlight_typing_spec.lua' -c 'qa!'`
Expected: fails — `_set_repair_deferral` does not exist; after stubbing that
mentally, the first test fails on `cache.dirty` after the first Enter.

- [x] **Step 3: Implement in `lua/parley/highlighter.lua`**

Constants, next to `HIGHLIGHT_VIEWPORT_MARGIN`:

```lua
-- Quiet time after the last edit before an approximate structure is rebuilt
-- (#227). Longer than the gap between keystrokes, so a burst costs one
-- rebuild; short enough that a pause converges almost at once.
local STRUCTURE_REPAIR_MS = 250
```

Deferral + seam + cache helpers, after `local structure_caches = {}`:

```lua
-- A restartable one-shot run-later (#227): each `start` replaces the pending
-- run. Production rides a libuv timer and hops to the main loop before calling
-- Neovim; tests swap the factory for one they fire by hand.
local function new_uv_deferral()
    local timer = vim.uv.new_timer()
    if not timer then return nil end
    return {
        start = function(_, delay_ms, fn)
            timer:stop()
            timer:start(delay_ms, 0, vim.schedule_wrap(fn))
        end,
        stop = function() timer:stop() end,
        close = function() stop_and_close_timer(timer) end,
    }
end
local new_deferral = new_uv_deferral

--- Test seam: swap the repair deferral factory and/or its delay. `nil`
--- keeps the production factory. Returns a function restoring both.
function M._set_repair_deferral(factory, delay_ms)
    local prev_factory, prev_delay = new_deferral, STRUCTURE_REPAIR_MS
    new_deferral = factory or new_uv_deferral
    STRUCTURE_REPAIR_MS = delay_ms or STRUCTURE_REPAIR_MS
    return function()
        new_deferral, STRUCTURE_REPAIR_MS = prev_factory, prev_delay
    end
end

-- Drop a cache whose structure may no longer line up with its buffer. Its
-- attachment sees the missing entry on its next event and detaches.
local function forget_structure(buf)
    local cache = structure_caches[buf]
    if cache and cache.repair then
        cache.repair:close()
        cache.repair = nil
    end
    structure_caches[buf] = nil
end
```

`arm_repair` — placed immediately **above** `function M.rebuild_structure`
(it calls `M.rebuild_structure`, resolved at call time):

```lua
-- (Re)start the one scheduled rebuild that brings an approximate structure
-- back to exact. Restarting on every edit that leaves the cache dirty is what
-- makes a burst of keystrokes cost one rebuild, after the burst.
local function arm_repair(buf, cache)
    cache.repair = cache.repair or new_deferral()
    if not cache.repair then return end
    cache.repair:start(STRUCTURE_REPAIR_MS, function()
        if structure_caches[buf] ~= cache or not cache.dirty or not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        local rebuilt, err = M.rebuild_structure(buf)
        if not rebuilt then
            _parley.logger.debug("structure repair failed: " .. tostring(err):sub(1, 200))
            return
        end
        -- Decorations are ephemeral and an unedited buffer is not redrawn on
        -- its own. `valid = true` would re-run on_win yet redraw no lines.
        vim.api.nvim__redraw({ buf = buf, valid = false })
    end)
end
```

Replace `M.rebuild_structure` and `M.clear_structure` with:

```lua
function M.rebuild_structure(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return nil, "invalid buffer" end
    local existing = structure_caches[buf]
    if existing and not existing.dirty then
        return existing.structure
    end
    local ok, candidate = pcall(build_structure, buf)
    if not ok then
        -- An existing cache keeps its structure: every edit spliced it, so it
        -- still lines up with the buffer and keeps rendering while dirty (#227).
        return nil, candidate
    end
    local cache = existing or {}
    cache.structure = candidate
    cache.dirty = false
    if cache.repair then cache.repair:stop() end
    structure_caches[buf] = cache
    if not cache.attached then
        local generation = {}
        cache.generation = generation
        local function owned(changed_buf)
            local current = structure_caches[changed_buf]
            if current and current.generation == generation and vim.api.nvim_buf_is_valid(changed_buf) then
                return current
            end
        end
        -- A structure that cannot be spliced onto an edit is rebuilt now, and
        -- dropped if even that fails: a misaligned structure is worse than none.
        local function resync(changed_buf, current)
            current.dirty = true
            if not M.rebuild_structure(changed_buf) then forget_structure(changed_buf) end
        end
        cache.on_lines = function(_, changed_buf, _, firstline, lastline, new_lastline)
            local current = owned(changed_buf)
            if not current then return true end
            local model = require("parley.highlight_structure")
            local line_reader = require("parley.line_reader")
            local ok_splice, replaced, rows, reason = pcall(function()
                local new_lines = line_reader.for_buffer(changed_buf):lines(firstline, new_lastline, false)
                return model.replace(current.structure, firstline, lastline, new_lines,
                    model.patterns(_parley.config))
            end)
            -- Nvim reports emptying a buffer as zero lines though it keeps one,
            -- so a self-consistent splice can still miss the buffer: check the
            -- one fact rendering depends on.
            if not ok_splice or not replaced
                or #replaced.fingerprints ~= vim.api.nvim_buf_line_count(changed_buf) then
                resync(changed_buf, current)
                return
            end
            line_reader.record_work(changed_buf, {
                operation = "structure_replace", structure_rows_processed = rows,
            })
            current.structure = replaced
            current.dirty = current.dirty or reason ~= nil
            if current.dirty then arm_repair(changed_buf, current) end
        end
        -- :checktime/autoread replaces the text without on_lines. Without this
        -- handler Nvim detaches instead, leaving every window on the buffer but
        -- the current one plain until an unrelated event rebuilt it.
        cache.on_reload = function(_, reloaded_buf)
            local current = owned(reloaded_buf)
            if current then resync(reloaded_buf, current) end
        end
        cache.on_detach = function(_, detached_buf)
            local current = structure_caches[detached_buf]
            if current and current.generation == generation then
                forget_structure(detached_buf)
            end
        end
        local attached = vim.api.nvim_buf_attach(buf, false, {
            on_lines = cache.on_lines,
            on_reload = function(_, reloaded_buf) cache.on_reload(nil, reloaded_buf) end,
            on_detach = function(_, detached_buf) cache.on_detach(nil, detached_buf) end,
        })
        if not attached then
            forget_structure(buf)
            return nil, "failed to attach structure cache"
        end
        cache.attached = true
    end
    return candidate
end

function M.clear_structure(buf)
    forget_structure(buf)
    require("parley.line_reader").clear_buffer(buf)
end
```

In `on_win`, replace the dirty/renderable refusal with:

```lua
            -- A dirty cache still renders (#227): every edit splices it, so it
            -- lines up with the buffer and only its state below the edit can
            -- lag, until the scheduled repair.
            local structure_cache = structure_caches[bufnr]
            if not structure_cache then
                return false
            end
```

`tests/perf/chat_typing.lua:300`:

```lua
            assert(cache and cache.structure, "decoration structure cache has no structure")
```

- [x] **Step 4: Update the `highlighting_spec.lua` tests that pinned fail-closed**

Every site, by current line number (verified with
`grep -n "renderable\|local prior" tests/integration/highlighting_spec.lua`):

1. `:545` (`"does identical bounded work for matched 1000 and 5000 line viewports"`) —
   replace `assert.is_true(require("parley.highlighter")._structure_cache(buf).renderable)`
   with `assert.is_false(require("parley.highlighter")._structure_cache(buf).dirty)`.
2. `:572-590` — rename `"marks structural edits dirty until lifecycle convergence rebuilds"` to
   `"renders while a structural edit is pending and converges on InsertLeave"`;
   replace `assert.is_false(provider.on_win(nil, win, buf, 0, 2))` with
   `assert.is_nil(provider.on_win(nil, win, buf, 0, 2))`, and delete the
   `assert.is_true(cache.renderable)` line (`:588`).
3. `:626-647` — rename `"keeps failed rebuilds unrenderable and retries transactionally"` to
   `"keeps rendering the aligned structure when a rebuild fails, and retries"`.
   **Move `local prior = highlighter._structure_cache(buf).structure` (`:633`) to
   just after the `nvim_buf_set_lines` edit (`:634`)**: a structural edit now
   installs a spliced table, so what a failed rebuild must preserve is that
   aligned splice, not the pre-edit object. Replace `:644`
   (`assert.is_false(…renderable)`) with
   `assert.is_nil(capture_decoration_provider().on_win(nil, vim.api.nvim_get_current_win(), buf, 0, 1))`,
   and `:646` (`assert.is_true(…renderable)`) with
   `assert.is_false(highlighter._structure_cache(buf).dirty)`.
4. `:852-876` (`"retains the prior real cache across lifecycle rebuild failure and swaps on retry"`) —
   **move `local prior = …structure` (`:861`) to just after the edit (`:862`)**
   for the same reason, and delete `:872` (`assert.is_false(…renderable)`).
   `:874`'s `assert.is_not.equals(prior, …)` stays valid: the retry installs a
   fresh build.
5. `:1282` and `:1306` (production first-entry convergence, the first inside a
   chat/markdown loop) — replace each `assert.is_true(cache.renderable)` with
   `assert.is_false(cache.dirty)`.

Then confirm no reference to the deleted field survives:

Run: `grep -rn "renderable" lua tests`
Expected: no output.

- [x] **Step 5: Run — expect GREEN**

```
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlight_typing_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/highlighting_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua' -c 'qa!'
nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/arch/performance_line_reader_spec.lua' -c 'qa!'
```

`perf_chat_typing_spec` must stay green unchanged: its probe types one
character into prose, which is the shared fast path (one structure row, zero
full reads).

- [x] **Step 6: Break each new guard and watch it fail**

One at a time, confirm RED, revert:
1. Delete the `on_reload` key from the `nvim_buf_attach` opts → the checktime test fails ("reload detached").
2. Delete the `nvim__redraw` call → the real-clock test fails on `counted`.
3. Make `arm_repair` a no-op → the repair tests fail.
4. Drop the `#replaced.fingerprints ~= nvim_buf_line_count` check → the empty-buffer test fails.
5. Restore `if not structure_cache or structure_cache.dirty then return false end` →
   `"renders an approximate structure and repairs it…"` and the real-clock test
   fail. (The list-typing test does not: it only ever sees exact splices, which
   is its point.)

Record the observed failures in the issue `## Log`.

- [x] **Step 7: Lint and commit**

```bash
make lint
git add lua/parley/highlighter.lua tests/integration/highlight_typing_spec.lua \
  tests/integration/highlighting_spec.lua tests/perf/chat_typing.lua
git commit -m "#227: render while typing, repair structure on a timer, resync on reload"
```

## Chunk 3: Measurement and documentation

### Task 5: Report splice and rebuild cost in `make perf`, record it

**Files:**
- Modify: `tests/perf/chat_typing.lua` (`isolated_phases`)
- Modify: `workshop/issues/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode.md` (`## Log`)

- [x] **Step 1: Add two isolated phases** to the table `isolated_phases(scenario)` returns:

```lua
        -- #227: an Enter at the end of the target row, spliced onto the cached
        -- structure — the per-keystroke cost of a line-count edit.
        structure_splice = function()
            local model = require("parley.highlight_structure")
            local cache = require("parley.highlighter")._structure_cache(buf)
            local row0 = scenario.target_line - 1
            model.replace(cache.structure, row0, row0 + 1, { scenario.original_line, "" },
                model.patterns(require("parley").config))
        end,
        -- #227: the one rebuild a burst of approximate edits costs.
        structure_rebuild = function()
            local highlighter = require("parley.highlighter")
            highlighter._structure_cache(buf).dirty = true
            assert(highlighter.rebuild_structure(buf))
        end,
```

- [x] **Step 2: Run the report**

Run: `make perf PERF_OUTPUT="$TMPDIR/parley-227-perf.json"`
Expected: exit 0 (hard gates unchanged: `edit_total` zero full reads and one
structure row; `decoration_redraw` zero full reads); the table lists
`structure_splice` and `structure_rebuild` at 100/1,000/5,000 lines.

- [x] **Step 3: Record** median/p95 of `edit_total`, `decoration_redraw`,
`structure_splice`, and `structure_rebuild` at 1,000 and 5,000 lines in the
issue `## Log`, alongside the one-rebuild-per-burst result from Task 4's
5,000-line test.

- [x] **Step 4: Commit**

```bash
git add tests/perf/chat_typing.lua workshop/issues/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode.md
git commit -m "#227: report splice and rebuild cost in make perf"
```

### Task 6: Atlas, tooling docs, traceability, full suite

**Files:**
- Modify: `atlas/ui/highlights.md` (new section)
- Modify: `atlas/chat/lifecycle.md:145-147`
- Modify: `TOOLING.md:72-82` (perf section) and the phase list at `:46-49`
- Modify: `atlas/traceability.yaml` (add `tests/integration/highlight_typing_spec.lua` beside `tests/integration/highlighting_spec.lua`)

- [x] **Step 1: `atlas/ui/highlights.md`** — add after the #218 section:

```markdown
## The structure cache while typing (#227)

Decorations are computed on redraw from a buffer-owned structure
(`highlight_structure`), and that structure must line up with the buffer
row-for-row: the footer start, draft ranges and `state_before` are all
row-indexed.

- **Every edit is spliced.** `highlight_structure.replace` splices the edit's
  rows in and re-derives tokens, footer and drafts, so the cache never renders a
  misaligned structure. Fingerprint-identical edits share the old arrays;
  anything else costs one shallow O(n) copy (0.02 ms at 5,000 lines).
- **Exact vs approximate.** A splice is exact when every touched row is inert —
  text, blank, fence, draft delimiter — and the first row below the edit is
  entered in the same state as before. That covers ordinary typing, Enter and
  joins. Turn markers, `📝`/`🔧`/`📎`, `🧠:`, `🧠:[END]` and footnotes can move
  state a splice cannot see; those leave the cache *approximate*.
- **Fail open.** The provider renders approximate structures. Its visible rows
  are walked from the actual lines, so what can lag is limited to `🧠:`
  lookahead (which can reach rows above the edit) and windows whose top is
  below the edit.
- **One repair per burst.** An approximate cache arms a 250 ms deferral; every
  further edit restarts it, and any successful rebuild (including the
  `buffer_lifecycle` convergence events) cancels it. It repaints with
  `nvim__redraw({ buf, valid = false })`.
- **Resync.** A splice that throws or no longer matches the buffer's line count
  (Nvim's empty buffer), and a `:checktime` reload (`on_reload`), rebuild
  synchronously; a cache that cannot be realigned is dropped rather than drawn.
```

- [x] **Step 2: `atlas/chat/lifecycle.md`** — replace the sentence
"Structural-marker edits mark decorations dirty in bounded changed-row work and
may suppress them until convergence; ordinary prose edits keep the current
structure valid." with:

```markdown
Every edit splices the decoration structure in bounded work, so decorations
never drop out while typing. Ordinary typing, Enter included, keeps it exact;
a structural-marker edit leaves it approximate but still rendering, and one
rebuild follows 250 ms after the burst — or at the next convergence event,
whichever comes first (see [ui/highlights](../ui/highlights.md)).
```

- [x] **Step 3: `TOOLING.md`** — in the perf section, replace "Structural
marker edits may suppress decorations during insertion; the same convergence
events rebuild structure before returning." with:

```markdown
Structural marker edits never suppress decorations: they leave the structure
approximate and still rendering, and it is rebuilt 250 ms after the burst or at
the next convergence event.
```

and extend the phase sentence at `:46-49` to name the new isolated phases:
"…reports the real insert-event/redraw interval plus isolated timezone,
footnote, decoration, spell, structure-splice, and structure-rebuild phases."

- [x] **Step 4: README discoverability check** (lessons #176/#187)

Run: `grep -n -i -e "insert mode" -e "highlight" README.md`
Expected: no sentence describing highlighting disappearing in insert mode. If
one exists, update it in this commit.

- [x] **Step 5: Stale-wording sweep** (lesson 2026-06-17)

Run: `grep -rn -i -e "suppress them" -e "suppress decorations" -e "renderable" atlas TOOLING.md README.md lua tests`
Expected: no output.

- [x] **Step 6: Full suite**

Run: `make test`
Expected: exit 0 (lint + unit + integration). Paste the summary into the issue
`## Log`.

- [x] **Step 7: Commit**

```bash
git add atlas/ui/highlights.md atlas/chat/lifecycle.md TOOLING.md atlas/traceability.yaml \
  workshop/issues/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode.md
git commit -m "#227: atlas and tooling for highlighting that survives typing"
```

### Task 7: Manual check with the operator, then close

- [ ] **Step 1: Hand the operator the e2e steps** (ask; do not claim done before they confirm):
  1. Open a chat with a managed footnote footer. In the last question, type a
     numbered list, pressing Enter between items, without leaving insert mode.
     Expect: the `💬:` line, the list, and its `1.` `2.` `3.` markers keep the
     question colour on every keystroke; the footnote lines keep theirs.
  2. Type a line starting with three backticks, keep typing, then pause ~½ s.
     Expect: no blank frame at any point; after the pause, everything below
     matches what `<Esc>` would show.
  3. In a markdown file, type inside a `=== draft ===` block with Enter.
     Expect: the draft background stays on every draft line.

  Step 1 also settles the issue's open hypothesis (whether the list-marker
  colour flicker was markdown showing through): with the overlay present on
  every frame, the markers must hold one colour.

- [ ] **Step 2: Close** via `sdlc close --issue 227 --verified '<make test summary + operator confirmation>'`
  (the binary runs the mandatory boundary review; fix Critical/Important before
  crossing).

## Revisions

### 2026-09-10 — during implementation

Reason: the plan-quality gate's three Minor findings (disposed in code, not by
editing the gated plan), plus one defect the Task 4 mutation step exposed.
Delta:
- `manual_deferrals` lives in `tests/helpers/decoration.lua` (not inline in the
  typing spec) and `highlighting_spec.lua` installs it file-wide, so its
  structural-edit tests never arm a real 250 ms timer while later tests pump
  the loop with `vim.wait` (gate finding: injected clock).
- The new spec is listed under **both** traceability entries that own
  `highlighting_spec.lua` — `chat/lifecycle` and `ui/highlights` (gate finding).
- The issue's two drifted `init.lua` pointers were corrected (gate finding).
- Every stub in `highlight_typing_spec.lua` is registered on a cleanup stack
  that `after_each` unwinds. The fail-closed mutation showed why: the failing
  test died before its inline restore of `vim.api.nvim__redraw`, and the
  leaked stub made the real-clock test fail too. With the stack, that mutation
  reddens only the intended test.
- `on_detach` teardown is tested by calling the attachment's callback directly
  (plan review recommendation), not through buffer deletion.
- Core-concepts Name cells now lead with each symbol's bare grep-able name
  (`build`, `replace`, `_set_repair_deferral`, …): the
  `single_source_sweeps_spec` table-vs-diff guard looks for the backticked
  bare name, and `highlight_structure.build` did not match it (lesson #186).
