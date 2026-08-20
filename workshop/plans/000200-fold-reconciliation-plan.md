# Fold Reconciliation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make chat folding hold two invariants at all times — a user question is never folded, and every `🔧:` / `📎:` / `📝:` / `🧠:` block always is.

**Architecture:** Two independent defects produce the same class of failure. (1) `tool_folds.reconcile_exchange` does not reconcile — it only *appends* folds at model-computed rows and never removes a fold the projection does not want, so any model/buffer drift is permanent and can anchor a fold on a `💬:` line. Fix: reconcile against a *verified* desired state — check each range's anchor row actually carries its block's marker, re-derive from the buffer when it does not, then clear the exchange span before creating folds. (2) The fenced-tool-body grammar has three owners; only `tools/serialize.lua` implements it correctly (matching pair of the *same* backtick length). `answer_structure.lua` and `chat_parser.lua` each re-derive a naive version, so a nested ``` block or a `💬:` line inside a tool body breaks sectioning. Fix: extract the grammar to one pure module all three derive from (`ARCH-DRY`).

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim API (`nvim_buf_*`, `nvim_win_call`, manual folds), plenary.nvim busted tests.

**Issue:** `#200` — see its `## Log` for the audit and the reproduction.

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
  - **DRY rationale:** Today the rule lives in three places. `tools/serialize.lua:84` gets it right with a `%1` backreference; `answer_structure.lua:88` closes on *any* ≥3-backtick run; `chat_parser.lua:549` does not model fences at all. This is the single source those three derive from (`ARCH-DRY`, and `ARCH-PURPOSE`'s shadow-sweep: every consumer derives, none restates).
  - **Future extensions:** Tilde fences (`~~~`) if a provider ever emits them — `open_len` widens to return `(len, char)`.

- **fold_projection** — gains `anchor_kind` (block kind → the structural kind its first line must classify as) and `verify_anchors(ranges, anchor_lines, patterns)` → `ok, failed_index`. Stays pure and nvim-free.
  - **Relationships:** 1:1 with `exchange_model` (projects one exchange at a time); consumed only by `tool_folds`.
  - **DRY rationale:** The block-kind ↔ marker-kind mapping (`thinking`↔`reasoning`, the rest identity) exists implicitly today, split between `answer_structure`'s emitted kinds and `highlight_structure`'s classified kinds. Naming it once stops the two vocabularies drifting.
  - **Future extensions:** A `verify_spans` that checks the whole range, not just the anchor, if end-drift ever matters.

- **answer_structure** — its tool-section scanner derives fence open/close from `fence` instead of "any ``` run", and stops a never-closed fence at the last line before the first following boundary rather than running to the end of the answer.

- **chat_parser** — the main loop tracks tool-fence state and suppresses structural classification for lines inside a tool body, so a `💬:` / `🤖:` / `📎:` / `📝:` line in tool output can no longer fork a spurious exchange.

**Test surface.** All four are PURE — unit tests, no IO mocks: `tests/unit/fence_spec.lua` (new), `tests/unit/fold_projection_spec.lua`, `tests/unit/answer_structure_spec.lua`, `tests/unit/chat_parser_tools_spec.lua`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `tool_folds` | `lua/parley/tool_folds.lua` | modified | Neovim window fold state |

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
end)
```

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

--- Check that every range's first line really carries its block's marker.
--- `anchor_lines` maps a range's start_0 to that buffer line's text; a
--- missing entry means the row is past the end of the buffer.
--- @return boolean ok, integer|nil failed_range_index
function M.verify_anchors(ranges, anchor_lines, patterns)
    local classify = require("parley.highlight_structure").classify
    for index, range in ipairs(ranges) do
        local line = anchor_lines[range.start_0]
        if line == nil then return false, index end
        if classify(line, patterns).kind ~= M.anchor_kind(range.kind) then
            return false, index
        end
    end
    return true, nil
end
```

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
            vim.api.nvim_win_set_cursor(win, { row, 0 })
            -- zD deletes nested folds at the cursor too, so one pass per row
            -- is enough; guard the loop anyway in case foldlevel does not drop.
            local guard = 0
            while vim.fn.foldlevel(row) > 0 and guard < 32 do
                vim.cmd("normal! zD")
                guard = guard + 1
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

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: PASS — including the pre-existing `leaves a user fold outside the rewritten range untouched` (that fold sits at lines 10-11, outside the exchange span, so the span clear does not reach it).

- [ ] **Step 5: Commit**

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

    clear_folds_in_span(buf, win, first_0, last_0)
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
        for _, range in ipairs(ranges) do
            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
        end
    end)
    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
    return true
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`
Expected: PASS, all cases.

- [ ] **Step 5: Run the full fold + exchange-model spec set**

Run: `make test-spec SPEC=chat/exchange_model`
Expected: every mapped spec passes — in particular `keeps exactly one fold level across consecutive tool-loop appends` (the span clear is what makes that hold structurally rather than by luck) and `restores from the current buffer model without masking a mutation error`.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/tool_folds.lua tests/integration/tool_folds_spec.lua
git commit -m "folds: #200 M1: reconcile to a verified desired state"
```

---

### Task 4: Corpus regression harness

The audit that found this ran as a throwaway script. Make it a durable test so the two invariants are checked against real transcripts on every run.

**Files:**
- Create: `tests/integration/fold_invariants_spec.lua`
- Reference: `workshop/parley/*.md` (the in-repo corpus; the operator's `chat_dir` is not available in CI)

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

    local corpus = vim.fn.glob("workshop/parley/*.md", false, true)

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

            for i, line in ipairs(lines) do
                local closed = vim.fn.foldclosed(i)
                if line:match("^💬:") then
                    assert.message(("question folded at %s:%d"):format(path, i))
                        .equals(-1, closed)
                elseif line:match("^🔧:") or line:match("^📎:")
                    or line:match("^📝:") or line:match("^🧠:") then
                    assert.message(("marker not folded at %s:%d"):format(path, i))
                        .is_true(closed ~= -1)
                    assert.message(("marker swallowed by an earlier fold at %s:%d"):format(path, i))
                        .equals(i, closed)
                end
            end
            vim.api.nvim_buf_delete(buf, { force = true })
        end)
    end
end)
```

- [ ] **Step 2: Run it**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/fold_invariants_spec.lua" -c "qa!"`
Expected: PASS. (It passed at audit time on all 127 transcripts, so a failure here means a regression introduced by Tasks 1-3, not a pre-existing defect.)

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
end)
```

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

Declare the state next to the other loop state in `parse_chat`:

```lua
	-- Tool-body fence state (#200). Structural markers inside a tool body are
	-- CONTENT — tool output routinely contains 💬:/🤖:/📎: lines (reading a
	-- transcript, grepping this repo). Without this, such a line forks a
	-- spurious exchange and drags the rest of the tool body out of its block.
	local fence = require("parley.fence")
	local tool_fence_len = nil      -- open fence length, nil when closed
	local tool_awaiting_fence = false -- saw the 🔧:/📎: header, fence not yet open
```

At the top of the content loop, immediately after `decoration_kind` is computed:

```lua
	for i = header_end + 1, #lines do
		local line = lines[i]
		local decoration_kind = highlight_structure.classify(line, decoration_patterns).kind

		if tool_fence_len then
			if fence.closes(line, tool_fence_len) then
				tool_fence_len = nil
			end
			-- Inside the body every line is content, whatever it looks like.
			decoration_kind = "text"
		elseif tool_awaiting_fence then
			local opened = fence.open_len(line)
			if opened then
				tool_fence_len = opened
				tool_awaiting_fence = false
				decoration_kind = "text"
			elseif decoration_kind ~= "text" and decoration_kind ~= "blank" then
				-- Malformed block: no body ever opened. Fall through and let
				-- the marker be structural again.
				tool_awaiting_fence = false
			end
		end
```

In the `tool_use` and `tool_result` arms, set the flag after `cb_append_line(line, i)`:

```lua
			tool_awaiting_fence = true
			tool_fence_len = nil
```

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

```lua
    local corpus = vim.fn.glob("workshop/parley/*.md", false, true)
    vim.list_extend(corpus, vim.fn.glob("tests/fixtures/fold_adversarial.md", false, true))
```

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

_(none yet — append timestamped entries here rather than overwriting above)_
