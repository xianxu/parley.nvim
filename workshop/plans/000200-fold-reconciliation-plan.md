# Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make chat folding hold two invariants at all times — a user question is never folded, and every `🔧:` / `📎:` / `📝:` / `🧠:` block always is.

**Architecture:** Two independent defects produce the same class of failure. (1) `tool_folds.reconcile_exchange` does not reconcile — it only *appends* folds at model-computed rows and never removes a fold the projection does not want, so any model/buffer drift is permanent and can anchor a fold on a `💬:` line. Fix: reconcile against a *verified* desired state — check each range's anchor row actually carries its block's marker, re-derive from the buffer when it does not, then clear the exchange span before creating folds. (2) The fenced-tool-body grammar has three owners; only `tools/serialize.lua` implements it correctly (matching pair of the *same* backtick length). `answer_structure.lua` and `chat_parser.lua` each re-derive a naive version, so a nested ``` block or a `💬:` line inside a tool body breaks sectioning. Fix: extract the grammar to one pure module all three derive from (`ARCH-DRY`).

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim API (`nvim_buf_*`, `nvim_win_call`, manual folds), plenary.nvim busted tests.

**Issue:** `#200` — see its `## Log` for the audit and the reproduction.

**Non-goals** (deliberate scope boundaries, not oversights):

- **Markdown fences in ordinary answer prose stay fence-naive.** Task 9 suppresses structural markers only inside `tool_use` / `tool_result` bodies, so a `💬:` line inside a plain triple-backtick block in an answer still forks an exchange. Tool bodies are machine-generated and routinely contain transcript text, which is why they are the actual defect surface; answer prose is author-controlled and the same suppression there would need a general markdown block model, not a fence pair. Revisit only if a real transcript exhibits it.
- **Fold state is not persisted across sessions.** Reconciliation restores the invariants on hydration; it does not remember which folds the user had opened.
- **`~~~` tilde fences are not supported.** No provider emits them today; `fence.open_len` widens to return `(len, char)` if one ever does.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `fence` | `lua/parley/fence.lua` | new |
| `fold_projection` | `lua/parley/fold_projection.lua` | modified |
| `answer_structure` | `lua/parley/answer_structure.lua` | modified |
| `chat_parser` | `lua/parley/chat_parser.lua` | modified |

- **fence** — the canonical fenced-block grammar for tool bodies: `open_len(line)` → N when the line opens a fence (≥3 backticks + optional info string), `closes(line, n)` → true only for a bare run of exactly N backticks, `for_content(s)` → the shortest fence strictly longer than any run in `s`.
  - **Relationships:** 1:N — one grammar, three consumers (`serialize`, `answer_structure`, `chat_parser`). No consumer holds a reference to another.
  - **DRY rationale:** Today the rule lives in three places, each independently written. `tools/serialize.lua:84` gets it right with a `%1` backreference (and restates it again on the reader side at `:85-88` and `:135`); `answer_structure.lua:88` closes on *any* ≥3-backtick run; `chat_parser.lua:455-469` has its own correct-but-separate `tool_fence_len` tracker. This is the single source all of them derive from (`ARCH-DRY`, and `ARCH-PURPOSE`'s shadow-sweep: every consumer derives, none restates — including serialize's reader-side matchers, which are consumers too).
  - **Future extensions:** Tilde fences (`~~~`) if a provider ever emits them — `open_len` widens to return `(len, char)`.

- **fold_projection** — gains `anchor_kind` (block kind → the structural kind its first line must classify as), `verify_anchors(ranges, lines, patterns)` → `ok, failed_index` (anchor **and** interior), `verify_span(first_0, last_0, lines, patterns, anchor_required)` guarding the destructive half, and `is_foldable(kind)` as a read-only view of the policy. Stays pure and nvim-free.
  - **Relationships:** 1:1 with `exchange_model` (projects one exchange at a time); consumed only by `tool_folds`.
  - **DRY rationale:** The block-kind ↔ marker-kind mapping (`thinking`↔`reasoning`, the rest identity) exists implicitly today, split between `answer_structure`'s emitted kinds and `highlight_structure`'s classified kinds. Naming it once stops the two vocabularies drifting.
  - **Future extensions:** none outstanding — whole-range verification and span verification both shipped in M1.

- **answer_structure** — its tool-section scanner derives fence open/close from `fence` instead of "any ``` run", and stops a never-closed fence at the last line before the first following boundary rather than running to the end of the answer.

- **chat_parser** — its existing `cb_state.tool_fence_len` tracker derives its grammar from `fence` instead of restating it, and the main loop (`:549`) *consults* that tracker before classifying, so a `💬:` / `🤖:` / `📎:` / `📝:` line in tool output can no longer fork a spurious exchange. No second fence tracker is introduced (PQ-3).

**Test surface.** All four are PURE — unit tests, no IO mocks: `tests/unit/fence_spec.lua` (new), `tests/unit/fold_projection_spec.lua`, `tests/unit/answer_structure_spec.lua`, `tests/unit/chat_parser_tools_spec.lua`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `tool_folds` | `lua/parley/tool_folds.lua` | modified | Neovim window fold state |
| `exchange_anchors` | `lua/parley/exchange_anchors.lua` | new | Neovim extmark namespace |

- **exchange_anchors** — one `invalidate = true` extmark per exchange start,
  giving an exchange a durable identity that survives edits the model never saw.
  Consumed only by `tool_folds`; consumes no other module.
  - **Why it must exist:** a row-span is not an identity. Positional rules
    ("starts on a question, contains no other") are satisfied equally by a
    *different* exchange's rows, so they cannot police a destructive operation.
  - **The split it enables:** creation is *verified* (ranges checked against the
    buffer), destruction is *identified* (rows read from marks). The two halves
    fail differently and cannot share one guard — the lesson of four review
    rounds spent sharpening a single positional check.
  - `fold_projection.verify_starts` is the remaining positional check, used once
    at install time to decide whether a model is sound enough to anchor from,
    not per-clear.

- **tool_folds** — owns every fold Parley creates. `clear_folds_in_span` (new, private) replaces `delete_projected_folds`'s start-row-only `zd` loop; `reconcile_exchange` becomes verify → (re-derive on drift) → clear span → create.
  - **Injected into:** Nothing — it is the outermost shell. It *consumes* `fold_projection` (pure) and a `model_provider` seam (`M._model_provider`, already used by the existing tests to inject a fake model).
  - **Future extensions:** If reconcile ever needs to span multiple exchanges, `clear_folds_in_span` already takes an arbitrary row range.

**No external binary or service is involved**, so `ARCH-MOCK` does not apply — the existing `M._model_provider` / `M._observer` seams already let integration tests drive the module with a controlled model and observe emitted ranges without touching IO.

---

## Chunk 1: M1 — fold reconciliation

### Task 1: Anchor verification in the pure projection

**Files:**
- Modify: `lua/parley/fold_projection.lua`
- Test: `tests/unit/fold_projection_spec.lua`

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/fold_projection_spec.lua`:

```lua
describe("anchor verification", function()
    local projection = require("parley.fold_projection")
    local patterns = require("parley.highlight_structure").patterns({})

    it("maps every foldable block kind to the marker kind it must anchor on", function()
        assert.equals("reasoning", projection.anchor_kind("thinking"))
        assert.equals("summary", projection.anchor_kind("summary"))
        assert.equals("tool_use", projection.anchor_kind("tool_use"))
        assert.equals("tool_result", projection.anchor_kind("tool_result"))
        assert.is_nil(projection.anchor_kind("text"))
        assert.is_nil(projection.anchor_kind("question"))
    end)

    it("accepts ranges whose anchor line carries the expected marker", function()
        local ranges = {
            { kind = "tool_result", start_0 = 4, end_0 = 7 },
            { kind = "summary", start_0 = 9, end_0 = 9 },
        }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [9] = "📝: did the thing",
        }, patterns)
        assert.is_true(ok)
        assert.is_nil(failed)
    end)

    it("rejects a range anchored on a user question and names the offender", function()
        local ranges = {
            { kind = "tool_result", start_0 = 4, end_0 = 7 },
            { kind = "tool_use", start_0 = 9, end_0 = 12 },
        }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [9] = "💬: second question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(2, failed)
    end)

    it("rejects a range whose anchor line is missing from the buffer", function()
        local ranges = { { kind = "tool_use", start_0 = 40, end_0 = 44 } }
        local ok, failed = projection.verify_anchors(ranges, {}, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    -- PQ-4: the Spec's invariant is "a question is never INSIDE a fold" —
    -- not merely "never a fold header". End-drift keeps the anchor correct
    -- while the range overshoots into the next exchange's question.
    it("rejects a range whose interior swallows a user question", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 8 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "```",
            [6] = "body",
            [7] = "```",
            [8] = "💬: next question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("does not mistake a question marker inside a fenced body for a turn", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 7 } }
        local ok = projection.verify_anchors(ranges, {
            [4] = "📎: grep",
            [5] = "```",
            [6] = "  💬: matched line from a transcript",
            [7] = "```",
        }, patterns)
        assert.is_true(ok)
    end)
end)
```

The last case matters: the interior scan must reject only a line that
`highlight_structure` classifies as `user` at column 0, which an indented or
fenced occurrence is not. The scan is a guard against *drift*, not a second
fence parser — M2 Task 9 owns in-body marker suppression (`ARCH-DRY`).

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fold_projection_spec.lua" -c "qa!"`
Expected: FAIL — `attempt to call field 'anchor_kind' (a nil value)`

- [ ] **Step 3: Write minimal implementation**

In `lua/parley/fold_projection.lua`, below the `FOLDABLE` table:

```lua
-- Block kinds carry answer_structure's vocabulary; the buffer line is
-- classified with highlight_structure's. They agree except for thinking,
-- whose marker classifies as "reasoning". One place, so the two vocabularies
-- cannot drift apart.
local ANCHOR_KIND = {
    thinking = "reasoning",
    summary = "summary",
    tool_use = "tool_use",
    tool_result = "tool_result",
}

--- The structural kind a foldable block's first line must classify as.
--- @return string|nil  nil when the block kind is not foldable
function M.anchor_kind(block_kind)
    return ANCHOR_KIND[block_kind]
end

--- Check that a range really describes the block it claims: its first line
--- carries the block's marker, and no interior line is a user question.
--- `lines` maps a buffer row (0-based) to its text for every row the ranges
--- cover; a missing anchor row means the range runs past end-of-buffer.
--- @return boolean ok, integer|nil failed_range_index
function M.verify_anchors(ranges, lines, patterns)
    local classify = require("parley.highlight_structure").classify
    for index, range in ipairs(ranges) do
        local anchor = lines[range.start_0]
        if anchor == nil then return false, index end
        if classify(anchor, patterns).kind ~= M.anchor_kind(range.kind) then
            return false, index
        end
        -- The invariant is "never inside a fold", so end-drift that keeps a
        -- valid anchor but overshoots the next question must fail too (PQ-4).
        for row = range.start_0 + 1, range.end_0 do
            local line = lines[row]
            if line == nil then return false, index end
            if classify(line, patterns).kind == "user" then
                return false, index
            end
        end
    end
    return true, nil
end
```

Verification is still pure and nvim-free — the caller reads the buffer once and
hands in the row→text map (`ARCH-PURE`). Passing every covered row rather than
just the anchors keeps the whole check in one pass over one input, instead of a
second `verify_spans` entry point (`ARCH-DRY`).

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fold_projection_spec.lua" -c "qa!"`
Expected: PASS — all existing cases plus the four new ones.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/fold_projection.lua tests/unit/fold_projection_spec.lua
git commit -m "folds: #200 M1: verify fold anchors in the projection"
```

---

### Task 2: Span clearing replaces start-row fold deletion

**Files:**
- Modify: `lua/parley/tool_folds.lua:26-38` (`delete_projected_folds`)
- Test: `tests/integration/tool_folds_spec.lua`

The current deleter positions the cursor at each *desired start row* and `zd`s. A fold anywhere else in the exchange is untouched — that is what lets a stale fold survive forever. Replace it with a span clear.

**This changes an ownership contract, deliberately (PQ-1).** Today the contract is *"Parley owns folds at projected start rows"*; after this task it is **"Parley owns every fold within an exchange span"** — operator decision, 2026-08-20. A manual `zf` inside an exchange is now deleted on the next reconcile. A fold outside every exchange span is still untouched.

Two pre-existing tests encode the old contract and **must both be dispositioned in this task** — do not predict their result, run them:

| Test | Fold it creates | Disposition |
|---|---|---|
| `tests/integration/tool_folds_spec.lua:39` — *"leaves a user fold outside the rewritten range untouched"* | `10,11fold`, asserted at 11–12 after the mutation shifts it | Expected to survive — the exchange holds only a `thinking` block at 7–9, so 11–12 should fall outside the span. **Verify by running; if it now fails, the fold is inside the span and this test converts like the one below.** |
| `tests/integration/tool_folds_spec.lua:57` — *"builds initial folds from semantic model blocks without clearing an unrelated fold"* | `25,26fold` over trailing prose `plain one` / `plain two`, asserted at `:76-77` | **Converts.** Lines 25–26 are the exchange's trailing text block, inside the span, so the fold is now deleted by design. |

- [ ] **Step 1: Write the failing test**

Append inside the existing `describe` in `tests/integration/tool_folds_spec.lua`:

```lua
it("clears a stale fold anywhere in the exchange, not just at a projected start", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "---", "topic: t", "file: f.md", "---", "",
        "💬: q", "", "🤖: [A]", "", "📎: read_file", "```", "b", "```",
    })
    local model = exchange_model.new(4)
    model:add_exchange(1)
    model:add_block(1, "agent_header", 1)
    model:add_block(1, "tool_result", 4)
    tool_folds.reconcile_exchange(buf, win, model, 1)

    -- A stale fold that no projected range starts on — the shape a drifted
    -- reconcile leaves behind (#200).
    vim.api.nvim_win_call(win, function() vim.cmd("6,9fold") end)

    tool_folds.reconcile_exchange(buf, win, model, 1)
    vim.cmd("normal! zM")

    assert.equals(-1, vim.fn.foldclosed(6))   -- 💬: question must not be folded
    assert.equals(10, vim.fn.foldclosed(10))  -- 📎: is folded, at its own start
    assert.equals(13, vim.fn.foldclosedend(10))
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: FAIL — `Expected -1, got 6`. The stale `6,9` fold survives and anchors on the question.

- [ ] **Step 3: Write minimal implementation**

In `lua/parley/tool_folds.lua`, replace `delete_projected_folds` with:

```lua
--- Delete every fold overlapping rows [first_0, last_0]. Manual folds are the
--- only kind Parley creates, and within an exchange span Parley owns them —
--- so the whole span is cleared before the desired set is rebuilt. Folds
--- outside the span (a user's own zf elsewhere in the buffer) are untouched.
local function clear_folds_in_span(buf, win, first_0, last_0)
    if not valid_target(buf, win) then return end
    if first_0 == nil or last_0 == nil or last_0 < first_0 then return end
    vim.api.nvim_win_call(win, function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line_count = vim.api.nvim_buf_line_count(buf)
        local last_row = math.min(last_0 + 1, line_count)
        local row = math.max(first_0 + 1, 1)
        while row <= last_row do
            -- PQ-5: probe with foldlevel (no cursor motion) and only pay for a
            -- cursor set on a row that actually carries a fold. This runs per
            -- streamed chunk via chat_respond's around_write, where the common
            -- case is "span already clean" — that case must cost one VimL call
            -- per row, not a cursor set per row.
            if vim.fn.foldlevel(row) > 0 then
                vim.api.nvim_win_set_cursor(win, { row, 0 })
                -- zD deletes nested folds at the cursor too, so one pass per row
                -- is enough; guard the loop anyway in case foldlevel does not drop.
                local guard = 0
                while vim.fn.foldlevel(row) > 0 and guard < 32 do
                    vim.cmd("normal! zD")
                    guard = guard + 1
                end
            end
            row = row + 1
        end
        vim.api.nvim_win_set_cursor(win, {
            math.min(cursor[1], vim.api.nvim_buf_line_count(buf)), cursor[2],
        })
    end)
end
```

Add a span helper next to it:

```lua
--- 0-indexed [first, last] buffer rows an exchange occupies, or nil when it
--- has no visible block.
local function exchange_span(model, exchange_index)
    if not model or not model.exchanges[exchange_index] then return nil end
    local last_0 = model:last_nonempty_block_end(exchange_index)
    if not last_0 then return nil end
    return model:exchange_start(exchange_index), last_0
end
```

Point `prepare_exchange_update` at the span instead of the projected starts:

```lua
function M.prepare_exchange_update(buf, model, exchange_index)
    if not vim.api.nvim_buf_is_valid(buf) or not model.exchanges[exchange_index] then return {} end
    local ranges = projection.desired_folds(model, exchange_index)
    local first_0, last_0 = exchange_span(model, exchange_index)
    local windows = vim.fn.win_findbuf(buf) or {}
    for _, win in ipairs(windows) do
        if valid_target(buf, win) then
            clear_folds_in_span(buf, win, first_0, last_0)
            notify({ phase = "prepare", win = win, exchange_index = exchange_index, ranges = ranges })
        end
    end
    return windows
end
```

- [ ] **Step 4: Convert the test that encodes the old contract**

In `tests/integration/tool_folds_spec.lua:57`, rename the test and invert its
last two assertions — the user fold at 25–26 is now inside the exchange span
and is cleared by design:

```lua
    it("builds initial folds from semantic model blocks and clears user folds in the span", function()
        -- ... buffer setup and `vim.cmd("25,26fold")` unchanged ...

        -- #200: Parley owns every fold within an exchange span, so a manual
        -- fold over the exchange's trailing prose does not survive a reconcile.
        assert.equals(-1, vim.fn.foldclosed(25))
    end)
```

- [ ] **Step 5: Run the whole file and disposition test `:39` empirically**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: PASS. If `leaves a user fold outside the rewritten range untouched` fails, its fold *is* inside the span — convert it the same way and record the correction in the issue `## Log`, rather than widening the span exception to keep it green.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/tool_folds.lua tests/integration/tool_folds_spec.lua
git commit -m "folds: #200 M1: clear the whole exchange span, not projected starts"
```

---

### Task 3: reconcile_exchange verifies before it folds

**Files:**
- Modify: `lua/parley/tool_folds.lua:40-51` (`reconcile_exchange`)
- Test: `tests/integration/tool_folds_spec.lua`

This is the defect that produced the reported symptom. `reconcile_exchange` must treat the projection as a *desired state to be checked*, not an append list.

- [ ] **Step 1: Write the failing test**

Append to `tests/integration/tool_folds_spec.lua`:

```lua
it("never anchors a fold on a user question when the model has drifted", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "---", "topic: t", "file: f.md", "---", "",
        "💬: first", "", "🤖: [A]", "", "📎: read_file",
        "```", "b1", "b2", "```", "", "prose", "",
        "💬: second question", "", "🤖: [A]", "",
        "📎: grep", "```", "c1", "```",
    })
    tool_folds.hydrate_window(buf, win)

    -- A model built before a mutation that bypassed with_exchange_update:
    -- the buffer has 4 more lines above exchange 2 than the model knows.
    local stale = require("parley.chat_parser")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local model = exchange_model.from_parsed_chat(
        stale.parse_chat(lines, 4, require("parley.config")))
    require("parley.buffer_edit").insert_lines_at(buf, 17, { "x1", "x2", "x3", "x4" })

    tool_folds.reconcile_exchange(buf, win, model, 2)
    vim.cmd("normal! zM")

    local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(after) do
        if line:match("^💬:") then
            assert.equals(-1, vim.fn.foldclosed(i))
        end
    end
    -- and it healed rather than merely refusing: the real 📎: is folded
    for i, line in ipairs(after) do
        if line:match("^📎: grep") then
            assert.equals(i, vim.fn.foldclosed(i))
        end
    end
end)

it("does not throw when drift runs a projected range past the end of the buffer", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "---", "topic: t", "file: f.md", "---", "",
        "💬: q", "", "🤖: [A]", "", "📎: read_file", "```", "b", "```",
    })
    local model = exchange_model.new(4)
    model:add_exchange(1)
    model:add_block(1, "agent_header", 1)
    model:add_block(1, "tool_result", 40)  -- far past EOF

    assert.has_no.errors(function()
        tool_folds.reconcile_exchange(buf, win, model, 1)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: FAIL twice — the first asserts `-1` but gets the question's own row; the second raises `Vim(fold):E16: Invalid range`.

- [ ] **Step 3: Write minimal implementation**

Replace `reconcile_exchange` in `lua/parley/tool_folds.lua`:

```lua
--- Read the buffer lines each range is anchored on, keyed by start_0.
--- Rows past the end of the buffer are simply absent (verify_anchors treats
--- a missing anchor as drift).
local function anchor_lines_for(buf, ranges)
    local out = {}
    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, range in ipairs(ranges) do
        if range.start_0 < line_count then
            out[range.start_0] = vim.api.nvim_buf_get_lines(
                buf, range.start_0, range.start_0 + 1, false)[1]
        end
    end
    return out
end

--- True when every range fits the buffer AND anchors on its own marker.
local function ranges_fit(buf, ranges, patterns)
    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, range in ipairs(ranges) do
        if range.end_0 >= line_count then return false end
    end
    return (projection.verify_anchors(ranges, anchor_lines_for(buf, ranges), patterns))
end

--- Reconcile exchange K's folds to the projection's desired state.
---
--- The projection is a desired state, not an append list: the exchange's span
--- is cleared before the desired folds are created, so a fold the projection
--- no longer wants cannot survive. Before anything is applied, every range is
--- checked against the buffer — a range must fit and must anchor on its own
--- marker line. A model that has drifted from the buffer (any mutation not
--- wrapped in with_exchange_update) would otherwise anchor a fold on a 💬:
--- question and leave it there for the rest of the session (#200). On drift
--- the model is re-derived from the buffer once; if that still does not
--- verify, no fold is created rather than a wrong one.
function M.reconcile_exchange(buf, win, model, exchange_index)
    if not valid_target(buf, win) or not model.exchanges[exchange_index] then return false end
    local patterns = require("parley.highlight_structure").patterns(require("parley.config"))
    local ranges = projection.desired_folds(model, exchange_index)
    local first_0, last_0 = exchange_span(model, exchange_index)

    if not ranges_fit(buf, ranges, patterns) then
        local provider = M._model_provider or default_model_provider
        local ok, fresh = pcall(provider, buf)
        if not (ok and fresh and fresh.exchanges[exchange_index]) then
            notify({ phase = "drift", win = win, exchange_index = exchange_index, ranges = {} })
            return false
        end
        local fresh_ranges = projection.desired_folds(fresh, exchange_index)
        if not ranges_fit(buf, fresh_ranges, patterns) then
            notify({ phase = "drift", win = win, exchange_index = exchange_index, ranges = {} })
            return false
        end
        model, ranges = fresh, fresh_ranges
        first_0, last_0 = exchange_span(fresh, exchange_index)
    end

    -- PQ-5: chat_respond.lua:1743 wraps EVERY streamed chunk in
    -- with_exchange_update, so this runs per chunk. Most chunks only grow a
    -- text block and leave the fold set identical — in that case neither the
    -- span clear nor the re-fold is needed, and skipping both keeps the hot
    -- path O(#ranges) instead of O(span). Verification above already proved
    -- the recorded set still matches the buffer, so the memo cannot go stale
    -- silently: any drift fails ranges_fit and takes the slow path.
    if applied_matches(buf, win, exchange_index, ranges) then
        notify({ phase = "unchanged", win = win, exchange_index = exchange_index, ranges = ranges })
        return true
    end

    clear_folds_in_span(buf, win, first_0, last_0)
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
        for _, range in ipairs(ranges) do
            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
        end
    end)
    record_applied(buf, win, exchange_index, ranges)
    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
    return true
end
```

With the memo alongside `initialized`, invalidated by the same `WinClosed` /
`BufUnload` / `BufDelete` autocmds so it cannot outlive the window it describes:

```lua
local applied = {}  -- [buf][win][exchange_index] = "start:end,start:end"

local function ranges_key(ranges)
    local parts = {}
    for i, r in ipairs(ranges) do parts[i] = r.start_0 .. ":" .. r.end_0 end
    return table.concat(parts, ",")
end

local function applied_matches(buf, win, exchange_index, ranges)
    local per_buf = applied[buf]
    local per_win = per_buf and per_buf[win]
    return per_win ~= nil and per_win[exchange_index] == ranges_key(ranges)
end

local function record_applied(buf, win, exchange_index, ranges)
    applied[buf] = applied[buf] or {}
    applied[buf][win] = applied[buf][win] or {}
    applied[buf][win][exchange_index] = ranges_key(ranges)
end
```

`prepare_exchange_update`'s span clear must drop the memo for that exchange
(`applied[buf][win][exchange_index] = nil`) — it removes folds reconcile would
otherwise believe are still applied.

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: PASS, all cases.

- [ ] **Step 5: Pin the streaming hot path (PQ-5)**

The memo is a performance claim, so test it as one. Append to
`tests/integration/tool_folds_spec.lua`:

```lua
it("does not re-clear or re-fold an exchange whose fold set is unchanged", function()
    -- The streaming shape: around_write calls with_exchange_update per chunk.
    -- Growing a trailing text block must not touch the fold set.
    local phases = {}
    tool_folds._observer = function(e) phases[#phases + 1] = e.phase end
    finally(function() tool_folds._observer = nil end)

    -- ... buffer with one 📎: block plus trailing prose, hydrate, then ...
    for _ = 1, 5 do
        tool_folds.reconcile_exchange(buf, win, model, 1)
    end

    local unchanged = 0
    for _, p in ipairs(phases) do if p == "unchanged" then unchanged = unchanged + 1 end end
    assert.equals(4, unchanged)  -- first applies, the rest short-circuit
end)
```

- [ ] **Step 6: Measure it against the existing perf harness**

The repo already has a streaming perf gate — `tests/perf/chat_typing.lua` driven
by `tests/integration/perf_chat_typing_spec.lua` through `tests/perf/harness.lua`.
Run it before and after Tasks 2–3:

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/perf_chat_typing_spec.lua" -c "qa!"`
Expected: within the harness's existing budget. Record both numbers in the issue
`## Log`. If the after-number regresses beyond the budget, the memo is not
short-circuiting the streaming path — fix that before proceeding to M2 rather
than raising the budget.

- [ ] **Step 7: Run the full fold + exchange-model spec set**

Run: `make test-spec SPEC=chat/exchange_model`
Expected: every mapped spec passes — in particular `keeps exactly one fold level across consecutive tool-loop appends` (the span clear is what makes that hold structurally rather than by luck) and `restores from the current buffer model without masking a mutation error`.

- [ ] **Step 8: Commit**

```bash
git add lua/parley/tool_folds.lua tests/integration/tool_folds_spec.lua
git commit -m "folds: #200 M1: reconcile to a verified desired state"
```

---

### Task 4: Corpus regression harness

The audit that found this ran as a throwaway script. Make it a durable test so the two invariants are checked against real transcripts on every run.

**Files:**
- Create: `tests/integration/fold_invariants_spec.lua`
- Reference: the in-repo corpus under `workshop/parley/` — **11 files on disk, 10 tracked** at time of writing. The *127* in the issue `## Log` is the operator's iCloud `chat_dir`, which is not available in CI; do not restate 127 as this harness's coverage. Enumerate via `git ls-files` rather than a filesystem glob, so the suite's shape does not vary with untracked or deleted working-tree files. The corpus is a *regression net over real shapes*; the adversarial fixture (Task 10) is the real coverage of the defect classes.

**The oracle must derive from the parsed model, not from raw text (PQ-2).** A regex sweep over file lines asserts `foldclosed(i) == i` for every `📎:`-looking line — but after Task 9 a `📎:` *inside* a tool body is content, correctly living inside the enclosing fold, so a raw-text oracle would demand the opposite of what Task 9 implements and Task 10's fixture could never pass. Walk the exchange model instead: only question `line_start`s and foldable block starts enter the assertions, and in-body markers are structurally invisible to them.

- [ ] **Step 1: Write the test**

```lua
local tool_folds = require("parley.tool_folds")

-- #200: the two invariants, measured on real Neovim fold state over the
-- in-repo transcript corpus. A cold parse must never fold a question and must
-- always fold a tool call / tool result / summary / thinking block.
describe("fold invariants over the repo transcript corpus", function()
    local original_buf, win

    before_each(function()
        original_buf = vim.api.nvim_get_current_buf()
        win = vim.api.nvim_get_current_win()
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(win, original_buf)
        end
    end)

    -- Tracked files only: a filesystem glob makes the suite's shape depend on
    -- the working tree (right now: 11 on disk, 10 tracked, 1 deleted-not-staged).
    local corpus = vim.fn.systemlist("git ls-files workshop/parley/*.md")

    it("finds a corpus to check", function()
        assert.is_true(#corpus > 0)
    end)

    for _, path in ipairs(corpus) do
        it("holds both invariants for " .. vim.fn.fnamemodify(path, ":t"), function()
            local lines = vim.fn.readfile(path)
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_set_option_value("foldenable", true, { win = win })
            tool_folds.hydrate_window(buf, win)
            vim.api.nvim_win_call(win, function() vim.cmd("normal! zM") end)

            -- Model-derived oracle (PQ-2): the structural positions come from
            -- the same parse the folder used, so a marker inside a tool body is
            -- not a subject of either assertion.
            local chat_parser = require("parley.chat_parser")
            local header_end = chat_parser.find_header_end(lines)
            if not header_end then return end  -- not a chat transcript
            local model = require("parley.exchange_model").from_parsed_chat(
                chat_parser.parse_chat(lines, header_end, require("parley.config")))

            for k, exchange in ipairs(model.exchanges) do
                local q_row = model:exchange_start(k) + 1
                assert.message(("question folded at %s:%d"):format(path, q_row))
                    .equals(-1, vim.fn.foldclosed(q_row))

                for b, block in ipairs(exchange.blocks) do
                    if block.size > 0 and FOLDABLE_KINDS[block.kind] then
                        local row = model:block_start(k, b) + 1
                        assert.message(("%s block not folded at its own start, %s:%d")
                            :format(block.kind, path, row))
                            .equals(row, vim.fn.foldclosed(row))
                    end
                end
            end
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end
end)
```

`FOLDABLE_KINDS` must not be a fourth restatement of the policy — export the
existing table from `fold_projection` (`M.FOLDABLE`) and read it here, so the
harness tracks the policy automatically if it ever changes (`ARCH-DRY`).

- [ ] **Step 2: Run it**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/fold_invariants_spec.lua" -c "qa!"`
Expected: PASS over the 10 tracked transcripts. The audit's equivalent sweep was clean across the operator's full 127-file `chat_dir`, so a failure here means a regression introduced by Tasks 1-3, not a pre-existing defect.

- [ ] **Step 3: Register in traceability**

In `atlas/traceability.yaml`, under `chat/exchange_model:` → `tests:`, add:

```yaml
      - tests/integration/fold_invariants_spec.lua
```

- [ ] **Step 4: Commit**

```bash
git add tests/integration/fold_invariants_spec.lua atlas/traceability.yaml
git commit -m "test: #200 M1: pin fold invariants against the transcript corpus"
```

---

### Task 5: Close M1

- [ ] **Step 1: Run the full suite**

Run: `make test`
Expected: lint clean, all unit + integration specs pass.

- [ ] **Step 2: Update the atlas**

`atlas/chat/exchange_model.md` documents the fold projection. Add a short subsection stating the reconcile contract: the projection is a desired state; the exchange span is cleared before folds are created; every range is verified against its anchor marker and the model re-derived from the buffer on drift; a question can never anchor a fold.

- [ ] **Step 3: Milestone close**

```bash
sdlc milestone-close --issue 200 --milestone M1
```

Fix Critical/Important findings before crossing, then record the `Review-Verdict:` outcome in the issue's `## Log`.

---

## Chunk 2: M2 — one fence grammar

### Task 6: Extract the fence grammar

**Files:**
- Create: `lua/parley/fence.lua`
- Test: `tests/unit/fence_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
local fence = require("parley.fence")

describe("fence grammar", function()
    it("recognises an opening fence of three or more backticks", function()
        assert.equals(3, fence.open_len("```"))
        assert.equals(4, fence.open_len("````"))
        assert.equals(3, fence.open_len("```json"))
        assert.equals(4, fence.open_len("````json"))
        assert.is_nil(fence.open_len("``"))
        assert.is_nil(fence.open_len("plain text"))
    end)

    it("closes only on a bare run of the same length", function()
        assert.is_true(fence.closes("````", 4))
        assert.is_false(fence.closes("```", 4))   -- shorter: body content
        assert.is_false(fence.closes("`````", 4)) -- longer: not this pair
        assert.is_false(fence.closes("````json", 4))
    end)

    it("picks a fence strictly longer than any run in the content", function()
        assert.equals("```", fence.for_content("no backticks here"))
        assert.equals("````", fence.for_content("a ``` block"))
        assert.equals("`````", fence.for_content("a ```` block"))
    end)

    -- The grammar is a scanner over arbitrary model output, so three literals
    -- are blind to the malformed-input class. Pin the invariant instead.
    it("always picks a fence that cannot be closed by its own content", function()
        local bodies = {
            "", "plain", "`", "``", "```", "````````",
            "``` ```` `````", "a\n```\nb\n````\nc", "`\n``\n```\n",
            "```json\n{}\n```", "text with ` inline ` ticks",
        }
        for _, body in ipairs(bodies) do
            local open = fence.for_content(body)
            local n = fence.open_len(open)
            assert.message(("for_content(%q) -> %q is not a valid opener")
                :format(body, open)).is_true(n ~= nil)
            for line in (body .. "\n"):gmatch("([^\n]*)\n") do
                assert.message(("body line %q closes its own fence %q")
                    :format(line, open)).is_false(fence.closes(line, n))
            end
        end
    end)

    it("round-trips a serialized tool result through the reader", function()
        local serialize = require("parley.tools.serialize")
        for _, body in ipairs({ "plain", "```\nnested\n```", "````\ndeep\n````" }) do
            local rendered = serialize.render_result("read_file", body)
            local parsed = serialize.parse_result(rendered)
            assert.message(("round-trip lost content for %q"):format(body))
                .equals(body, parsed.content)
        end
    end)
end)
```

The round-trip case is the one that would have caught the `answer_structure`
defect had it existed earlier; confirm `render_result` / `parse_result` are the
actual exported names in `lua/parley/tools/serialize.lua` before writing it, and
use whatever the real pair is.

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fence_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.fence' not found`

- [ ] **Step 3: Write minimal implementation**

`lua/parley/fence.lua`:

```lua
-- The canonical fenced-block grammar for tool bodies.
--
-- A tool body opens on a run of >= 3 backticks (optionally followed by an info
-- string) and closes only on a BARE run of the SAME length. The same-length
-- rule is what lets a body contain ``` blocks of its own — the writer picks a
-- fence strictly longer than any run in the content.
--
-- Single source: tools/serialize.lua writes bodies with it, answer_structure
-- segments them with it, chat_parser suppresses structural markers inside them
-- with it. Three consumers, one grammar (ARCH-DRY).

local M = {}

M.MIN = 3

--- Length of the fence this line opens, or nil when it opens none.
function M.open_len(line)
    local run = (line or ""):match("^%s*(`+)")
    if not run or #run < M.MIN then return nil end
    return #run
end

--- True only for a bare run of exactly `len` backticks.
function M.closes(line, len)
    if not len then return false end
    local run = (line or ""):match("^%s*(`+)%s*$")
    return run ~= nil and #run == len
end

--- Longest run of backticks in `s`.
local function longest_run(s)
    local longest = 0
    for run in (s or ""):gmatch("`+") do
        if #run > longest then longest = #run end
    end
    return longest
end

--- Shortest fence strictly longer than any run in `content` (floor M.MIN).
function M.for_content(content)
    local n = longest_run(content)
    if n < M.MIN then return string.rep("`", M.MIN) end
    return string.rep("`", n + 1)
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fence_spec.lua" -c "qa!"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/fence.lua tests/unit/fence_spec.lua
git commit -m "fence: #200 M2: extract the canonical fenced-body grammar"
```

---

### Task 7: serialize derives from the grammar

`tools/serialize.lua` already implements the rule correctly; the point is that it must *derive* rather than restate it, so the three consumers cannot drift (`ARCH-PURPOSE` shadow-sweep).

**Files:**
- Modify: `lua/parley/tools/serialize.lua:37-53` (`longest_backtick_run`, `fence_for`)
- Test: `tests/unit/fence_spec.lua`

- [ ] **Step 1: Write the failing parity test**

Append to `tests/unit/fence_spec.lua`:

```lua
describe("serialize parity", function()
    local fence = require("parley.fence")
    local serialize = require("parley.tools.serialize")

    -- The writer picks the fence; the reader must accept exactly that pair.
    for _, body in ipairs({
        "plain body",
        "contains ``` a nested block ```",
        "contains ```` a longer run ````",
    }) do
        it("round-trips a body whose content is " .. body:sub(1, 24), function()
            local text = serialize.render_call({
                id = "t1", name = "read_file", input = { body = body },
            })
            local lines = vim.split(text, "\n")
            local opened = fence.open_len(lines[2])
            assert.is_not_nil(opened)
            assert.equals(#fence.for_content(vim.json.encode({ body = body })), opened)

            local parsed = serialize.parse_call(text)
            assert.is_not_nil(parsed)
            assert.equals(body, parsed.input.body)
        end)
    end
end)
```

> If `render_call`'s signature differs, read `lua/parley/tools/serialize.lua` and
> adapt the call — the assertion that matters is that `fence.open_len` of the
> rendered opening fence equals `fence.for_content` of the encoded body, and
> that `parse_call` round-trips it.

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fence_spec.lua" -c "qa!"`
Expected: PASS on behavior (serialize is already correct) — this test pins parity so the next step is safe.

- [ ] **Step 3: Delete the duplicate implementation**

In `lua/parley/tools/serialize.lua`, delete `longest_backtick_run` and the body of `fence_for`, replacing with a delegation:

```lua
local fence = require("parley.fence")

-- Fence selection is the shared grammar's job (ARCH-DRY) — see parley/fence.lua.
local function fence_for(content)
    return fence.for_content(content)
end
```

Leave `FENCE_MIN` only if other code references it; otherwise delete it and use `fence.MIN`.

- [ ] **Step 3b: Convert the reader side too**

`ARCH-PURPOSE`'s shadow-sweep: the writer is not the only consumer. The reader
restates the same rule three more times as `%1` backreferences —
`lua/parley/tools/serialize.lua:88`, `:90` (the `json` info-string variant), and
`:135` in `parse_result`. A hand-maintained restatement is a deferred consumer,
not a finished one, so convert them in the same task rather than leaving the
Done-when half-met.

Replace the single-regex extraction with a line scan driven by the grammar:

```lua
-- Extract a fenced body using the shared grammar: the first line that opens a
-- fence defines the length, and only a bare run of that same length closes it.
local function extract_fenced_body(text)
    local lines = vim.split(text, "\n", { plain = true })
    local open_len, first
    for i, line in ipairs(lines) do
        if not open_len then
            open_len = fence.open_len(line)
            if open_len then first = i + 1 end
        elseif fence.closes(line, open_len) then
            return table.concat(lines, "\n", first, i - 1)
        end
    end
    return nil
end
```

Both `parse_call` and `parse_result` then call it, so writer and reader share
one definition of "the same pair". The parity test in Step 1 and
`SPEC=providers/tool_use` are the guard that behavior is unchanged; if either
regresses, the regex and the scanner disagree on an input the grammar has to
decide — fix the grammar, not the call site.

- [ ] **Step 4: Run the tool specs**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/fence_spec.lua" -c "qa!"` then `make test-spec SPEC=providers/tool_use`
Expected: PASS — serialize round-trips unchanged.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/fence.lua lua/parley/tools/serialize.lua tests/unit/fence_spec.lua
git commit -m "fence: #200 M2: serialize derives fence selection from the grammar"
```

---

### Task 8: answer_structure honours fence length

**Files:**
- Modify: `lua/parley/answer_structure.lua:80-100` (the `tool_use` / `tool_result` arm)
- Test: `tests/unit/answer_structure_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
describe("tool sections with nested fences (#200)", function()
    local answer_structure = require("parley.answer_structure")
    local patterns = require("parley.highlight_structure").patterns({})

    it("keeps a nested ``` block inside the tool section", function()
        local lines = {
            "📎: read_file",
            "````",
            "here is a markdown file:",
            "```lua",
            "print('hi')",
            "```",
            "end of file",
            "````",
            "",
            "📝: read the file",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_result", sections[1].kind)
        assert.equals(1, sections[1].line_start)
        assert.equals(8, sections[1].line_end)   -- through the matching ````
        assert.equals("summary", sections[2].kind)
        assert.equals(10, sections[2].line_start)
    end)

    it("stops an unterminated fence at the next structural boundary", function()
        local lines = {
            "📎: read_file",
            "````",
            "truncated body",
            "",
            "📝: summary survives",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_result", sections[1].kind)
        assert.equals(3, sections[1].line_end)   -- not swallowing the 📝:
        assert.equals("summary", sections[#sections].kind)
        assert.equals(5, sections[#sections].line_start)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/answer_structure_spec.lua" -c "qa!"`
Expected: FAIL — the first case ends the section at line 6 (the nested closing ```); the second swallows the `📝:`.

- [ ] **Step 3: Write minimal implementation**

Replace the `tool_use` / `tool_result` arm in `lua/parley/answer_structure.lua`:

```lua
        elseif kind == "tool_use" or kind == "tool_result" then
            local fence = require("parley.fence")
            local last = i
            -- Last row we could safely end on if the fence never closes:
            -- everything up to the first structural boundary after it opened.
            local last_safe = i
            local fence_len = nil
            local cursor = i + 1
            while cursor <= #lines do
                local next_kind = kinds[cursor]
                if fence_len then
                    last = cursor
                    if fence.closes(lines[cursor], fence_len) then
                        cursor = cursor + 1
                        last_safe = last
                        break
                    end
                    if not BOUNDARY[next_kind] then last_safe = cursor end
                else
                    local opened = fence.open_len(lines[cursor])
                    if opened then
                        fence_len = opened
                        last = cursor
                        last_safe = cursor
                    elseif BOUNDARY[next_kind] then
                        break
                    else
                        last = cursor
                        last_safe = cursor
                    end
                end
                cursor = cursor + 1
            end
            if fence_len and cursor > #lines and not fence.closes(lines[#lines] or "", fence_len) then
                -- Never closed: do not let a malformed block swallow the rest
                -- of the answer (a 📝: after it must stay foldable on its own).
                last = last_safe
                cursor = last + 1
            end
            add(kind, i, last)
            i = cursor
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/answer_structure_spec.lua" -c "qa!"`
Expected: PASS, including every pre-existing case.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/answer_structure.lua tests/unit/answer_structure_spec.lua
git commit -m "folds: #200 M2: match tool fences by length in answer_structure"
```

---

### Task 9: chat_parser suppresses markers inside tool bodies

**Files:**
- Modify: `lua/parley/chat_parser.lua:520-524` (top of the content loop) and the `tool_use` / `tool_result` arms at 661-677
- Test: `tests/unit/chat_parser_tools_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
describe("structural markers inside a tool body (#200)", function()
    local chat_parser = require("parley.chat_parser")
    local config = require("parley.config")

    it("does not fork an exchange on a 💬: line inside tool output", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: real question",
            "",
            "🤖: [A]",
            "",
            "📎: read_file",
            "````",
            "💬: this is file content, not a turn",
            "🤖: neither is this",
            "````",
            "",
            "📝: done",
        }
        local parsed = chat_parser.parse_chat(lines, 4, config)
        assert.equals(1, #parsed.exchanges)
        assert.equals(6, parsed.exchanges[1].question.line_start)
        assert.equals(6, parsed.exchanges[1].question.line_end)
    end)

    it("still ends the answer at a 💬: outside the tool body", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: first",
            "",
            "🤖: [A]",
            "",
            "📎: read_file",
            "````",
            "💬: content",
            "````",
            "",
            "💬: second",
        }
        local parsed = chat_parser.parse_chat(lines, 4, config)
        assert.equals(2, #parsed.exchanges)
        assert.equals(15, parsed.exchanges[2].question.line_start)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_parser_tools_spec.lua" -c "qa!"`
Expected: FAIL — the first case reports 3 exchanges (the two in-body markers each fork one).

- [ ] **Step 3: Write minimal implementation**

**Correction (PQ-3): `chat_parser` already models fences.** The earlier claim
that it "does not model fences at all" is false. `cb_append_line`
(`lua/parley/chat_parser.lua:455-469`) already tracks `cb_state.tool_fence_len`
with correct same-length close matching, and drives a `tool_body_complete`
auto-transition at `:428`/`:440`. Introducing `tool_fence_len` /
`tool_awaiting_fence` locals in `parse_chat` would create a **second state
machine over the same fences**, with a different open pattern and a different
close test — two trackers that can disagree (`ARCH-DRY`).

The real gap is narrower: the fence state exists in `cb_state`, but the **main
loop at `:549` never consults it** before branching on `decoration_kind`. So the
task is to read the state that is already there, and to make the one existing
tracker derive its grammar from `parley.fence`.

**Step 3a — make the existing tracker derive from the grammar.** In
`cb_append_line`, replace the two inline patterns with the module:

```lua
		if cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result" then
			if not cb_state.tool_fence_len then
				cb_state.tool_fence_len = fence.open_len(line)
			elseif fence.closes(line, cb_state.tool_fence_len) then
				cb_state.tool_body_complete = true
			end
		end
```

This is the `ARCH-PURPOSE` half of the Done-when — `chat_parser` genuinely
derives from `parley.fence` rather than restating it. Note `fence.open_len` must
accept the same info-string shape the current pattern does (`^(`+)[%w_%-]*%s*$`);
Task 6's grammar is the place to reconcile that, and a parity test there must
pin it, because this line changes how existing transcripts parse.

**Step 3b — let the main loop see the body.** In `parse_chat`, immediately after
`decoration_kind` is computed, suppress structural classification while
`cb_state` says we are inside a tool body:

```lua
		-- #200: structural markers inside a tool body are CONTENT. Tool output
		-- routinely contains 💬:/🤖:/📎: lines (reading a transcript, grepping
		-- this repo). cb_append_line already knows where the body is; the main
		-- loop just has to stop classifying against it.
		if cb_state and cb_state.tool_fence_len and not cb_state.tool_body_complete
			and (cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result")
		then
			decoration_kind = "text"
		end
```

No new state, no second grammar — the main loop reads the tracker that already
exists. Confirm by inspection that `cb_state` is in scope at `:549` and that
`cb_append_line` has already run for the *previous* line, so the flag reflects
the body the current line sits in; if the ordering is off by one, fix the
ordering rather than adding a shadow variable.

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_parser_tools_spec.lua" -c "qa!"`
Expected: PASS

- [ ] **Step 5: Run every chat_parser consumer**

Run: `make test-spec SPEC=chat/parsing` and `make test-spec SPEC=chat/exchange_model`
Expected: PASS. The parser feeds message building, folding, export and the finders — this is the widest blast radius in the plan.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/chat_parser.lua tests/unit/chat_parser_tools_spec.lua
git commit -m "parser: #200 M2: treat markers inside a tool body as content"
```

---

### Task 10: Extend the corpus harness with the adversarial fixture

The real corpus contains no in-body markers today (the audit found 0), so it cannot catch a regression here. Add a synthetic transcript that does.

**Files:**
- Create: `tests/fixtures/fold_adversarial.md`
- Modify: `tests/integration/fold_invariants_spec.lua`

- [ ] **Step 1: Write the fixture**

`tests/fixtures/fold_adversarial.md` — a transcript exercising: a tool result containing `💬:` / `🤖:` / `📎:` lines, a nested ``` block inside a ```` body, a multi-line `📝:` summary, and a question immediately following a folded tool result.

- [ ] **Step 2: Point the harness at it**

In `tests/integration/fold_invariants_spec.lua`, extend the corpus list:

Extend the `git ls-files` list Task 4 established — do not reintroduce a
filesystem glob, which is exactly what made the suite's shape depend on the
working tree:

```lua
    local corpus = vim.fn.systemlist("git ls-files workshop/parley/*.md")
    table.insert(corpus, "tests/fixtures/fold_adversarial.md")
```

The fixture is a tracked file, so it is deliberately named rather than globbed:
it is the *designed* coverage of the defect classes, and a silent disappearance
should fail the suite, not shrink it.

- [ ] **Step 3: Run it**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/fold_invariants_spec.lua" -c "qa!"`
Expected: PASS — both invariants hold on the adversarial fixture.

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/fold_adversarial.md tests/integration/fold_invariants_spec.lua
git commit -m "test: #200 M2: pin fold invariants on an adversarial transcript"
```

---

### Task 11: Close M2 and the issue

- [ ] **Step 1: Full suite**

Run: `make test`
Expected: lint clean, everything passes.

- [ ] **Step 2: Re-run the original audit scripts**

Re-run the three audit scans from the issue Log against the operator's live `chat_dir` (127 transcripts) and confirm 0 violations — the pre-fix baseline was also 0 there, so this proves no regression on real data.

- [ ] **Step 3: Atlas**

Update `atlas/chat/format.md` — the tool-body fence rule (same-length pair) is now normative and single-sourced in `lua/parley/fence.lua`; markers inside a body are content. Update `atlas/chat/exchange_model.md` if Task 5 left anything to add. Add `lua/parley/fence.lua` to `atlas/traceability.yaml` under `chat/parsing` and `providers/tool_use`.

- [ ] **Step 4: Milestone close**

```bash
sdlc milestone-close --issue 200 --milestone M2
```

- [ ] **Step 5: Lessons**

Add to `workshop/lessons.md` under a `#200` heading:

- **A function named `reconcile` that only ever adds is not a reconciler.** `reconcile_exchange` created folds from the projection and never removed one the projection no longer wanted, so drift from any unwrapped mutation was permanent and could anchor a fold on a `💬:` question for the rest of the session. Rule: when a pure projection describes a *desired state*, the applier must clear the owned span and rebuild it — never append — and must verify the projection against reality before applying, so a stale model refuses rather than corrupts (`ARCH-DRY`).
- **A display-layer fallback that renders corrupt state as ordinary output hides the bug that produced it.** `foldtext()`'s `else` branch rendered a question-anchored fold as `💬: … (N lines)`, indistinguishable from a legitimate user fold. Rule: keep the fallback only where it is genuinely reachable by design (here: the user's own `zf` folds), and enforce the invariant at *creation* time instead.
- **A grammar implemented correctly in one consumer and naively in two is still a DRY violation.** The same-length fence rule lived correctly in `tools/serialize.lua` and wrongly in `answer_structure.lua` / `chat_parser.lua`. Rule: when two consumers re-derive a format that a third already owns, extract the owner rather than fixing the copies (`ARCH-DRY`).

- [ ] **Step 6: Close**

```bash
sdlc close --issue 200 --verified '<evidence: make test output, corpus audit result, before/after repro>'
```

Let `close` measure `--actual` itself.

---

## Revisions

### 2026-08-20 — plan-quality round 1 (PQ-1 … PQ-5 + minors)

Reason: `sdlc change-code --issue 200` blocked with 1 Critical and 4 Important
findings, plus 4 Minor. Each was verified against the code before revising —
all five blocking findings were real.

Delta:

- **PQ-1 (Critical) — Task 2.** The span clear silently reversed an ownership
  contract and broke `tests/integration/tool_folds_spec.lua:57`, a test named
  *"…without clearing an unrelated fold"* whose `25,26fold` sits inside the
  exchange span. Operator decision (2026-08-20): **Parley owns every fold within
  an exchange span** — the wider contract is intended. Task 2 now states the
  contract change explicitly, tabulates *both* pre-existing tests that encode
  the old one (`:39` and `:57`), converts `:57`, and requires `:39` to be
  dispositioned by running it rather than by prediction.
- **PQ-2 (Important) — Tasks 4 & 10.** The corpus oracle regex-matched raw file
  text, so it asserted `foldclosed == i` for markers *inside* tool bodies —
  exactly what Task 9 makes untrue, meaning Task 10's fixture could never pass.
  The oracle now walks the parsed exchange model: only question `line_start`s
  and foldable block starts are subjects, so in-body markers are structurally
  invisible to it. `FOLDABLE` is exported from `fold_projection` rather than
  restated a fourth time (`ARCH-DRY`).
- **PQ-3 (Important) — Task 9.** The plan's claim that `chat_parser` "does not
  model fences at all" was **false**: `chat_parser.lua:455-469` already tracks
  `cb_state.tool_fence_len` with correct same-length matching. The planned new
  locals would have been a second state machine over the same fences. Task 9 now
  (a) converts that existing tracker to derive from `parley.fence`, and (b) has
  the main loop at `:549` consult it. Smaller change, no shadow state.
- **PQ-4 (Important) — Task 1.** `verify_anchors` checked `start_0` only, so
  end-drift that keeps a valid anchor while overshooting the next question
  passed verification — leaving the Spec's "not swallowed by an earlier fold"
  half undefended. Verification now scans each range's interior for a `user`
  classification, in the same pass over the same input.
- **PQ-5 (Important) — Tasks 2 & 3.** `chat_respond.lua:1743` wraps **every
  streamed chunk** in `with_exchange_update`, so an O(span) clear with a cursor
  set per row lands on the hot path. Two mitigations: `clear_folds_in_span`
  probes with `foldlevel` and only sets the cursor on rows that actually carry a
  fold; and `reconcile_exchange` memoizes the applied range set per
  (buf, win, exchange) and short-circuits when the desired set is unchanged —
  the common streaming case. Pinned by an observer-phase test and measured
  against the existing `tests/perf/chat_typing.lua` harness.
- **Minor — Task 6.** `fence` was tested with three hand-picked literals; added
  a property case (`for_content` output can never be closed by its own content,
  over malformed inputs) and a serialize round-trip case.
- **Minor — Task 7.** Only the writer side derived from the grammar. Added Step
  3b converting the reader-side `%1` restatements at `serialize.lua:88`, `:90`,
  `:135` — otherwise the Done-when is half-met (`ARCH-PURPOSE`).
- **Minor — Task 4.** The 127-transcript figure is the operator's iCloud
  `chat_dir`, not this harness's coverage: the in-repo corpus is 11 files, 10
  tracked. Corrected, and the corpus is now enumerated with `git ls-files` so the
  suite's shape does not vary with the working tree.
- **Minor — header.** Added an explicit **Non-goals** section: markdown fences in
  ordinary answer prose stay fence-naive (tool bodies are the actual defect
  surface), fold state is not persisted, `~~~` fences are unsupported.

### 2026-08-20 — M1 implementation deltas (boundary review REWORK → rework applied)

Reason: the M1 boundary review returned REWORK on one Critical plus five
Important findings. The plan described code that was deliberately not written,
and missed a destructive-path check.

Delta:

- **C1 — span verification added (new, not in the original plan).** Task 3's
  "verify → re-derive → clear → create" verified only the *creation* half. The
  span handed to `clear_folds_in_span` came from the same stale model and was
  never checked; with no foldable block the range list is empty and
  `verify_anchors` returns `true` vacuously, so a drifted span was cleared as-is
  and destroyed a neighbouring exchange's fold — permanently, since
  `hydrate_window` latches. Reproduced, then fixed with a pure
  `fold_projection.verify_span` applied in both `reconcile_exchange` and
  `prepare_exchange_update`. This was a regression the diff introduced: the old
  start-row-only delete could not reach a neighbour.
- **Task 3's memo is struck.** `applied_matches` / `record_applied` / the
  `"unchanged"` phase and its observer test were never written and should not
  be: verification proves the model matches the buffer, not which folds exist,
  so the short-circuit let an externally-added fold survive the span it was
  meant to own. PQ-5 is answered algorithmically instead.
- **Task 2's `clear_folds_in_span` is a fold-to-fold VimL walk**, not a per-row
  `foldlevel` probe — one `nvim_exec2` crossing using `zj`/`zD` with a
  span-bounded `s:guard`. Per-chunk on a 600-row exchange: `0.078ms` (pre-#200,
  no clearing) → `3.705ms` (row walk from Lua) → `1.198ms` (row walk in VimL) →
  `0.067ms` (fold-to-fold).
- **Task 4's harness** enumerates via an injectable corpus seam over
  `git ls-files` plus a readability filter and a `>= 8` floor, and asserts a
  per-file subject count so a parse change cannot make it green-and-empty. The
  oracle reads `projection.is_foldable()` — an accessor, not the live table.
- **A tool-bearing fixture moved earlier, into M1.** The real corpus contains
  *zero* `tool_use`/`tool_result` blocks (measured), so the harness could not
  exercise the issue's headline case at all. `tests/fixtures/fold_tool_transcript.md`
  supplies that shape now; M2 Task 10's adversarial fixture remains separate.
- **Drift is no longer silent** — the refusal carries which half failed
  (`ranges` vs `span`) and the failing range, to the observer seam and to one
  debug log line.

On I4 — my first rebuttal was wrong and is withdrawn. `Makefile.parley:28` does
set `TMPDIR="$(TEST_TMP)"`; I had grepped only `Makefile`, missing the
`include Makefile.workflow` / `-include Makefile.local` chain. The accurate
mechanism needs both halves: the harness points `TMPDIR` at `.test-tmp` inside
the repo, and the agent sandbox denies `git init` the template-hook write there.
Unsandboxed, that same `git init` succeeds and `make test` exits 0.

### 2026-08-20 — M1 boundary review round 2 (C1 over-correction)

Reason: the round-1 C1 fix over-corrected. `verify_span` required the span's
first row to be a `💬:` line, but `chat_parser.lua:623-635` fabricates a
question block for an assistant-first transcript, so `exchange_start` lands on
a blank line. Verification failed, the re-derive produced the same anchor, and
`reconcile_exchange` refused **permanently** — the same "always folded"
invariant failing with the same session-persistent signature the fix was
written to remove. Reproduced: all four markers `foldclosed=-1`, `which="span"`.

Delta:

- **`verify_span` now tests only "no question after the first row."** That is
  what the producer actually guarantees, and it still catches a span reaching a
  neighbour — reaching one means covering its question. Both C1 scenarios now
  hold at once: the assistant-first transcript folds all four markers, and the
  neighbour's `📎:` keeps `foldclosed == its own row`. Simpler than the
  reviewer's suggested "trust the re-derived model's span" and needs no
  stale-vs-fresh distinction.
- **`tests/fixtures/fold_assistant_first.md`** pins it in the corpus harness.
  Verified to have teeth: with the anchor rule restored it fails
  ("thinking block not folded at its own start").
- **The drift re-derive is memoized per `changedtick`.** It re-parsed the whole
  buffer on every refused reconcile — and reconcile runs once per exchange and
  once per streamed chunk. Measured 1356 ms per refused reconcile on a
  4805-line chat; now 1.05 ms. Keying on `changedtick` is exact rather than
  approximate: identical buffer content yields an identical parse, and any edit
  moves the tick. The drift log line is emitted once per buffer state instead of
  once per call.
- **The "injectable corpus seam" claim is withdrawn.** `corpus_provider` is a
  single point of definition, not an injection point; the comment now says so,
  and the fixtures are listed explicitly so they depend on neither git nor cwd.
- **Core concepts** now names `verify_span` and `is_foldable`, and no longer
  proposes whole-range verification as a future extension — M1 shipped it.

### 2026-08-20 — M1 boundary review round 3 (the narrowing was too loose)

Reason: round 2's interior-only span rule missed a stale span landing wholly
inside a neighbour's answer — no question in range, so nothing guarded the
clear. My stated justification ("reaching a neighbour means covering its
question") was wrong. Reproduced against HEAD.

Delta:

- **`verify_span` requires both an on-question anchor and a clean interior.**
  The anchor requirement is waived for exchange index 1 only; verified that
  `chat_parser`'s fabricated-question path can produce no other index
  (`current_exchange` is never reset to nil). Callers pass
  `exchange_index > 1`.
- **Re-derive backoff (250 ms) added.** The `changedtick` memo bounds only the
  same-tick fan-out; on the streaming path each chunk is a new tick. Measured
  refused-reconcile cost on a 4805-line chat: 1356 ms → 1.05 ms (memo) →
  0.75 ms (memo + backoff). Round 2's I1 is now actually answered, not just
  reduced.
- **The false justification is removed from the source comment** at
  `fold_projection.lua` and from `atlas/chat/exchange_model.md`, both of which
  had carried it.
- On the `git init` finding: measured rather than argued. Unsandboxed it
  succeeds under `.test-tmp`, under a repo subdirectory, and outside the repo,
  and `make test` exits 0; sandboxed it fails. The review subprocess inherits
  this session's sandbox. The half that was mine — the `Makefile.parley:28`
  `TMPDIR` redirect — stays corrected.

### 2026-08-20 — M1 round 4: extmark-anchored exchange identity (operator decision)

Reason: round 4 showed the two-part span rule still aliases. The anchor test
cannot distinguish *this* exchange's question from any other exchange's, so a
stale span aligned onto a later exchange's start passes both halves while the
range check is vacuous. Reproduced. The underlying fact is that **a row-span is
not an identity** — three rounds of sharpening a positional heuristic could not
fix that, and each round's fix introduced the next round's defect.

Operator decision (2026-08-20): fix identity properly inside M1 rather than
defer it.

**Design — `lua/parley/exchange_anchors.lua` (new, thin IO shell).**

An extmark per exchange start row, created `invalidate = true`, in a dedicated
namespace. Neovim moves marks across ordinary edits and flags one invalid only
when its own line is deleted — the same property `chat_lease` relies on (#138).

    set(buf, starts_0)   -- replace all anchors, one per exchange start
    span(buf, k, count)  -- [first_0, last_0] for exchange k, or nil
    clear(buf)

`span` derives exchange k's extent from *live* mark positions:
`[anchor_k, anchor_{k+1} - 1]`, and to the last buffer line for the final
exchange. This is what removes the aliasing: the cleared region is read from
marks that travelled with the edits, not from a model's remembered rows.

**Guards, each closing a way the anchors could themselves alias:**

- `count` must equal the model's exchange count. A structural edit that adds or
  removes an exchange makes anchor *k* refer to a different exchange than model
  index *k*; the count mismatch detects that and forces the fallback.
- Both bounding marks must be valid. If `anchor_{k+1}`'s line was deleted, the
  span would silently over-extend into the next exchange.
- No anchors, or any guard failing → fall back to the model span plus the
  existing `verify_span`. The heuristic remains as a floor, not the primary.

Anchors are refreshed only from a model that has *verified* against the buffer
(hydration, and after a successful re-derive), so a stale parse cannot install
misleading identity. Invalidated alongside `initialized` on
`WinClosed`/`BufUnload`/`BufDelete`.

**Scope note.** This does not by itself remove the per-tick re-parse for
healable drift: the *creation* half still needs verified ranges, and healing a
stale model still costs one parse per changedtick. Measured, not assumed —
see the issue Log.

### 2026-08-20 — M1 round 5: identity refresh (C1) and Core-concepts correction

Reason: the round-4 design refreshed anchors only at hydration and after a
successful re-derive. That set is insufficient. `hydrate_window` latches per
buf/win, so from the first *appended* exchange onward `#ids ~= #model.exchanges`
and identity declines for every exchange — permanently. Reproduced: after one
append, `anchors.span(buf, 1, 3)` returned nil and stayed nil across reconcile.
With identity inert, every clear fell through to the positional check the
mechanism exists to replace, and with `ranges == {}` that check is vacuous.

Delta:

- **`owned_span` reinstalls identity on decline** before giving up, so a chat
  that gains an exchange recovers on the next reconcile instead of degrading
  silently.
- **The positional fallback is removed.** A decline now returns nil and sends
  the caller to the re-derive, which installs identity from a fresh parse.
  Falling through to `verify_span` was clearing rows we could not prove we
  owned.
- **`verify_span` is replaced by `verify_starts`**, which validates a whole
  model's exchange starts (ascending, in-buffer, each on a question except
  exchange 1) at *install* time. The positional logic moves from guarding every
  clear to gating identity installation — the only place it is sound.
- **Behaviour change recorded:** the last exchange's span now runs to the end of
  the buffer rather than to `last_nonempty_block_end`, because trailing prose is
  part of that exchange's answer. A manual fold there is therefore cleared;
  `tool_folds_spec.lua:39` converts, matching `:57`.
- Dead helpers `exchange_span` and `span_lines` removed.

### 2026-08-20 — M1 round 6: identity install requires a current-buffer parse

Reason: round 5's reinstall-on-decline let a *prefix-stale* model define
identity. `verify_starts` passes such a model trivially, too few anchors get
installed, the last one owns to EOF, and its clear swallows the trailing
exchanges. Reproduced through `with_exchange_update`.

Delta:

- `owned_span(buf, model, k, patterns, verified)` — identity may be installed
  only from a model parsed from the current buffer. `reconcile_exchange` passes
  `false` for the caller's model, `true` for the re-derived one;
  `hydrate_window` passes `true`.
- `prepare_exchange_update` reports identity availability on its `prepare`
  event instead of emitting a drift event; skipping the clear is safe because
  finalize's reconcile owns the span.
- **Explicit non-fix:** do not add a buffer-wide completeness scan to
  `verify_starts`. It would be correct now and wrong at M2, where a `💬:` inside
  a fenced tool body stops starting an exchange — the scan would decline forever
  and reopen the round-2 permanent-refusal defect. Any such scan must consume
  the M2 `fence` grammar.
- Test fixtures without `---` frontmatter now declare their hand-built model as
  the buffer's truth via the existing `_model_provider` seam.
