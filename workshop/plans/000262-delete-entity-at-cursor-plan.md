# Delete Entity at Cursor — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One cursor-dispatched range — markdown section, paragraph, or chat exchange — exposed as the `ae`/`ie`/`aE` text objects plus hotkeys and `:Parley*` commands, so `dae` deletes the entity under the cursor and `daE` deletes from it to the end of the question.

**Architecture:** A pure range module (`entity_range.lua`) computes `{kind, first, last}` from an already-parsed chat plus the raw lines; it owns *all* dispatch, precedence and blank-line policy and reuses the existing tested primitives (`exchange_clipboard.get_exchange_line_range`, `question_tags.semantic_start`) rather than re-deriving exchange spans. Two thin surfaces consume it: a text object that turns the range into a linewise visual selection (native `d` then does the delete, giving dot-repeat and every operator for free), and `M.cmd` handlers that delete through `buffer_edit.replace_user_lines` (the arch-fenced mutation door). A parity test pins the two surfaces to byte-identical results so they cannot drift.

**Tech Stack:** Lua 5.1/LuaJIT, Neovim API, plenary.nvim busted specs, the `keybinding_registry` + `config.lua` single-source pair.

---

## Spec deviation — read before implementing

The issue's Spec says precedence is "question > section title > paragraph" and that a cursor anywhere inside an answer "should still be treated as inside the question". Taken literally that makes every line of a chat buffer a question (every line is inside some exchange), so the section and paragraph cases would be dead in chat buffers — and it contradicts the operator's later requirement that `aE` start at *paragraph* level inside an answer.

**This plan implements precedence as a line-class rule, not a containment rule:**

| Cursor sits on | Entity |
|---|---|
| `💬:` question line, or its `@@tag@@` preface | whole exchange |
| an ATX heading line | that section |
| anything else | that paragraph |

The containment reading survives only where it was actually load-bearing: a section or paragraph range never crosses its enclosing exchange's boundary. Issue #262's `## Spec` gets a `## Revisions` entry recording this before M1 lands (Task 1).

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `markdown_heading` | `lua/parley/markdown_heading.lua` | new |
| `entity_range` | `lua/parley/entity_range.lua` | new |
| `outline` heading dialect | `lua/parley/outline.lua:53-57` | modified |

- **markdown_heading** — `level(line) -> number|nil`, the repo's one ATX-heading dialect. Tests in `tests/unit/markdown_heading_spec.lua`, no mocks.
  - **Relationships:** 1:N — one dialect, consumed by `entity_range`, `outline`, and (by conformance test, not by call) `document/lexical.lua`.
  - **DRY rationale:** the dialect is currently written twice — `outline.lua:53-57` (`^### `/`^## `/`^# `) and `document/lexical.lua:352` (`^(#+) ` capped at 3). A third copy in `entity_range` is exactly the drift ARCH-DRY exists to stop. `lexical.lua` keeps its inline byte-scanner copy (it is a hot incremental tokenizer and destabilizing it is not worth it); a conformance test asserts the two agree on a shared corpus, which is how the single source is *enforced* rather than merely documented (ARCH-PURPOSE).
  - **Future extensions:** levels 4-6 (today the dialect caps at 3, so `####` is body text); setext headings. Widening here widens outline and entity ranges together, which is the point.

- **entity_range** — `range(parsed, lines, row, opts) -> {kind, first, last}|nil`. The whole feature's logic. Tests in `tests/unit/entity_range_spec.lua`, no mocks: it takes a parsed chat and a line array, never a buffer.
  - **Relationships:** N:1 with a parsed chat (many ranges per parse, no state kept between calls); 1:1 with a cursor row.
  - **DRY rationale:** first occurrence of "what structural unit is under the cursor" as a *reusable value*. Today `ChatPrune` (`init.lua:4255`) and `ExchangeCut` (`init.lua:4423`) each inline their own "find exchange at cursor, else nearest following" walk; both become candidates to collapse onto this later (not in this issue — YAGNI).
  - **Future extensions:** a `count` for `2dae`; a visual-mode scope that unions ranges across a selection (`get_exchanges_for_range` already does the exchange case).

**`entity_range.range` contract.**

```
opts.scope = "entity" (default) | "to_end"
opts.inner = false (default) | true
returns { kind = "question"|"section"|"paragraph", first = <1-based>, last = <1-based> }
```

- `scope="entity"` — the unit under the cursor.
- `scope="to_end"` — `first` from the same unit, `last` extended to the end of the enclosing exchange (`exchange_clipboard.get_exchange_line_range`), or the enclosing section's end, or EOF outside any exchange. Never crosses the next `💬:`.
- `inner=true` — section without its heading line; question without its answer; paragraph without trailing blanks. `inner` + `to_end` is not exposed (no `iE`; see Surface below).
- **Trailing-blank policy (the load-bearing decision):** an outer (`inner=false`) range absorbs the blank run that follows it, `dap`-style. This is what makes the seam clean *without* a post-pass, which is what lets native `d` and the programmatic path agree byte-for-byte. `exchange_clipboard.compute_cut_cleanup` is deliberately **not** reused — it is a post-pass over already-mutated lines, which a text object has no opportunity to run.
- **📝 policy (operator decisions, 2026-09-16):** when `last` would land on or after a `📝:` summary line **and the question itself survives** (`kind ~= "question"`), `last` is pulled back to just before that summary. A whole-exchange range takes its summary with it. A 📝 strictly *inside* the range is deleted with everything else — preservation is an edge-trim only, which keeps the range contiguous and the two surfaces identical. 🌿 branch links and 🧠/🔧/📎 lines are ordinary content.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `entity_textobj.select` | `lua/parley/entity_textobj.lua` | new | Neovim visual-mode selection |
| `M.cmd.DeleteEntity` / `M.cmd.DeleteToEnd` | `lua/parley/init.lua` | new | `buffer_edit.replace_user_lines` |
| registry entries `entity_object_*` | `lua/parley/keybinding_registry.lua` + `lua/parley/config.lua` | modified | keymap installation |
| agreement-spec mode set | `tests/integration/keybinding_agreement_spec.lua:37` | modified | keymap leak/ghost guards |

- **entity_textobj.select(scope, inner)** — reads cursor + buffer lines, calls `entity_range.range`, issues `normal! <first>GV<last>G`. Nothing else.
  - **Injected into:** nothing; it is the leaf. `entity_range` stays pure by receiving `lines` and `row`, so the whole dispatch is unit-testable without a buffer.
  - **Future extensions:** `count` handling via `v:count1` before the range call.

- **M.cmd.DeleteEntity / M.cmd.DeleteToEnd** — the discoverable twins. Same guard/parse preamble as `ExchangeCut` (`init.lua:4423-4436`), then one `buffer_edit.replace_user_lines(buf, first-1, last, false, {})`.
  - **Injected into:** nothing; also a leaf. Both call the same `entity_range.range`, which is what the parity test pins.
  - **Future extensions:** `:ParleyYankEntity` etc. would be the same preamble with a different verb — if a third verb appears, extract the preamble (not before; YAGNI).

**Test surface.** `markdown_heading` and `entity_range` are PURE — unit specs, literal line arrays, zero mocks, matching `tests/unit/chat_parser_section_lines_spec.lua`. The command handlers are integration-tested against a real buffer with `D.attach(buf,{schedule=false})` per `tests/unit/user_buffer_edit_spec.lua:1-15`. No external binary or service is involved, so ARCH-MOCK needs no fake here (`N/A` — the only "external" surface is Neovim itself, which the harness runs for real).

---

## ARCH-* review

- **ARCH-DRY** — the heading dialect is extracted rather than written a third time; exchange spans come from `exchange_clipboard.get_exchange_line_range` + `question_tags.semantic_start` rather than from `answer.line_end` (which the issue text suggested but which omits trailing branch/blank lines the established range already handles); keymaps go through `keybinding_registry` instead of a hand-rolled `vim.keymap.set`, which `tests/arch/single_source_sweeps_spec.lua:588-647` would reject anyway.
- **ARCH-PURE** — all dispatch, precedence, blank-line and 📝 policy lives in `entity_range` as functions over `(parsed, lines, row)`. The IO shell is two files that do cursor-read → range → one mutation call. If a range test ever needs a buffer, the boundary has leaked.
- **ARCH-PURPOSE** — the issue's purpose is *one* uniform delete across three entity kinds and two scopes, reachable by a discoverable key. Shipping only the text object (leaving the hotkey "for later") would be the easy subset, because the operator's stated need is the end-user path; both surfaces land in M2 together. The 📝 rule is applied as a *class* decision over structural markers, with 🧠/🔧/📎/🌿 each ruled on, rather than a one-emoji special case.
- **ARCH-MOCK** — `N/A`. No external binary or service; Neovim is exercised for real by the harness.
- **ARCH-CONSTRAINTS** — this is a **keystroke/UI-response** path. Budget: one `parse_chat` per invocation, target < 16 ms (one frame) on a 5 000-line transcript; basis: precedent, `ExchangeCut` and `ChatPrune` already parse the whole buffer per invocation on `<C-g>X`/`<C-g>b`. Exceeded → the escape hatch is `document.exchange(doc,row)` (`document/init.lua:261`), the incremental index that already serves folds/outline. Measured in Task 12; if it misses, that is a finding, not a silent widening. `not_chat` carries an explicit "on keystroke paths" perf note (`init.lua:216`), so the text object gates on the cheap `M._parley_bufs[buf]` latch instead.
- **ARCH-SECURE** — `N/A` for secrets. Untrusted input: the transcript is user/model-authored text that may be truncated or hand-edited mid-generation. `entity_range` must return `nil` rather than a half-range for a malformed buffer (no header separator, cursor past EOF, empty buffer), and every caller treats `nil` as "do nothing, warn" — Task 6 tests exactly that.
- **ARCH-ORDER** — `entity_range` holds no state between events because every call re-derives from `(parsed, lines, row)` and returns a value; there is no cache to invalidate. The one ordering the caller cannot block is **an edit landing while a response streams into this exchange**. Policy: the programmatic path inherits `buffer_edit.replace_user_lines`' existing refusal (it captures a document provenance token and `error()`s if the document refuses) — the same contract `ExchangeCut` relies on today, so no new guard is invented here; the native `d` path is an ordinary user edit already modeled by `document/user_edits.lua`. Task 11 tests the refusal path. Nothing spawns concurrent work; extent is lexical.
- **ARCH-FUNERAL** — the feature creates no durable artifact, cache, or handle. The only created things are keymaps, whose end is the existing buffer-local lifecycle (`M._parley_bufs` cleared on unload, `highlighter.lua:1228`).

---

## Chunk 1: M1 — the pure range core

### Task 1: Record the Spec deviation in the issue

**Files:**
- Modify: `workshop/issues/000262-delete-entity-at-cursor.md`

- [ ] **Step 1: Append a `## Revisions` section** before `## Log`, timestamped 2026-09-16, reason = "containment precedence makes section/paragraph dead in chat buffers and contradicts the `aE` requirement", delta = the line-class table from this plan's Spec-deviation section.

- [ ] **Step 2: Commit**

```bash
git add workshop/issues/000262-delete-entity-at-cursor.md
git commit -m "#262: issue: precedence is line-class, not containment"
```

### Task 2: `markdown_heading.level`

**Files:**
- Create: `lua/parley/markdown_heading.lua`
- Test: `tests/unit/markdown_heading_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
local heading = require("parley.markdown_heading")

describe("markdown_heading.level", function()
    it("returns the level for column-zero ATX headings", function()
        assert.equals(1, heading.level("# One"))
        assert.equals(2, heading.level("## Two"))
        assert.equals(3, heading.level("### Three"))
    end)

    it("requires a space after the hashes", function()
        assert.is_nil(heading.level("#NoSpace"))
        assert.is_nil(heading.level("##"))
    end)

    it("rejects indented headings and levels past the dialect cap", function()
        assert.is_nil(heading.level("  # Indented"))
        assert.is_nil(heading.level("#### Four"))
    end)

    it("rejects non-headings", function()
        assert.is_nil(heading.level(""))
        assert.is_nil(heading.level("plain text"))
        assert.is_nil(heading.level("💬: a question"))
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

```sh
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/markdown_heading_spec.lua" -c "qa!"
```
Expected: FAIL — `module 'parley.markdown_heading' not found`.

- [ ] **Step 3: Write the minimal implementation**

```lua
-- The repo's one ATX-heading dialect: column-zero, one to three hashes,
-- followed by a literal space. Stated once so entity_range, outline and the
-- document tokenizer cannot drift apart (ARCH-DRY); document/lexical.lua keeps
-- its own inline byte-scanner for the hot incremental path and is pinned to
-- this dialect by tests/unit/markdown_heading_conformance_spec.lua.
local M = {}

M.MAX_LEVEL = 3

--- Heading level of a line, or nil when the line is not a heading.
--- Pure function.
--- @param line string|nil
--- @return number|nil
function M.level(line)
    if type(line) ~= "string" then
        return nil
    end
    local hashes = line:match("^(#+) ")
    if not hashes or #hashes > M.MAX_LEVEL then
        return nil
    end
    return #hashes
end

return M
```

- [ ] **Step 4: Run it and watch it pass**

Same command as Step 2. Expected: PASS, 4 successes.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/markdown_heading.lua tests/unit/markdown_heading_spec.lua
git commit -m "#262: markdown_heading: state the ATX dialect once"
```

### Task 3: Pin `document/lexical.lua` to the shared dialect

**Files:**
- Test: `tests/unit/markdown_heading_conformance_spec.lua`

This is the enforcement half of ARCH-DRY: `lexical.lua` keeps its inline scanner, but a test fails the moment the two disagree.

- [ ] **Step 1: Write the conformance test**

```lua
local heading = require("parley.markdown_heading")
local lexical = require("parley.document.lexical")
local config = require("parley.config")

-- Lines chosen to straddle every edge of the dialect: the cap, the required
-- space, indentation, and structural markers that must never read as headings.
local CORPUS = {
    "# One", "## Two", "### Three", "#### Four", "##### Five",
    "#NoSpace", "##", "#", "  # Indented", "\t# Tabbed",
    "", "plain", "💬: q", "🤖: a", "📝: s", "--- ", "@@tag@@",
    "#  double space", "###   spaced", "# trailing hash #",
}

describe("markdown_heading vs document.lexical", function()
    it("agrees on heading_level for every corpus line", function()
        local patterns = require("parley.document.lexical").patterns(config.config or {})
        for _, line in ipairs(CORPUS) do
            local token = lexical.token(line, patterns)
            assert.equals(heading.level(line), token.heading_level,
                ("dialect drift on %q"):format(line))
        end
    end)
end)
```

- [ ] **Step 2: Run it**

```sh
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/markdown_heading_conformance_spec.lua" -c "qa!"
```

**If `lexical` exposes no single-line `token()` entry point**, read `lua/parley/document/lexical.lua` around the `finish(c)` function (`:343-356`) and drive whatever the module's actual public tokenizing call is; do **not** add a new public function to `lexical.lua` just for the test, and do **not** copy its regex into the test. If no public seam exists, assert against `document.query` over a one-line buffer instead and say so in a comment.

Expected: PASS. If it FAILS, the two dialects already disagree — that is a real finding; record it in the issue `## Log` and fix `markdown_heading` to match `lexical` (the tokenizer is the incumbent), not the other way round.

- [ ] **Step 3: Commit**

```bash
git add tests/unit/markdown_heading_conformance_spec.lua
git commit -m "#262: pin the heading dialect against the document tokenizer"
```

### Task 4: `entity_range` — paragraph case

**Files:**
- Create: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
local entity_range = require("parley.entity_range")

-- No parsed chat: a plain markdown buffer. Paragraph is the fallback kind.
local function lines_of(...) return { ... } end

describe("entity_range paragraph", function()
    it("takes the blank-delimited run plus its trailing blanks", function()
        local lines = lines_of(
            "alpha one",   -- 1
            "alpha two",   -- 2
            "",            -- 3
            "beta one",    -- 4
            ""             -- 5
        )
        local r = entity_range.range(nil, lines, 1)
        assert.equals("paragraph", r.kind)
        assert.equals(1, r.first)
        assert.equals(3, r.last)
    end)

    it("stops at the end of the buffer without inventing a trailing blank", function()
        local lines = lines_of("alpha", "", "omega")
        local r = entity_range.range(nil, lines, 3)
        assert.equals(3, r.first)
        assert.equals(3, r.last)
    end)

    it("collapses a multi-blank run into the range", function()
        local lines = lines_of("alpha", "", "", "", "beta")
        local r = entity_range.range(nil, lines, 1)
        assert.equals(1, r.first)
        assert.equals(4, r.last)
    end)

    it("inner drops the trailing blanks", function()
        local lines = lines_of("alpha one", "alpha two", "", "beta")
        local r = entity_range.range(nil, lines, 1, { inner = true })
        assert.equals(1, r.first)
        assert.equals(2, r.last)
    end)

    it("returns nil on a blank line with no paragraph to own it", function()
        local lines = lines_of("alpha", "", "", "beta")
        assert.is_nil(entity_range.range(nil, lines, 2))
    end)
end)
```

Note the third case: the range keeps **all** trailing blanks, leaving the blank that *preceded* the paragraph as the surviving separator. That is `dap`'s own rule and it is what produces a clean seam with no post-pass.

- [ ] **Step 2: Run it and watch it fail**

```sh
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/entity_range_spec.lua" -c "qa!"
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement just the paragraph case**

```lua
local M = {}

local function is_blank(line)
    return line == nil or line:match("^%s*$") ~= nil
end

--- Blank-delimited paragraph containing `row`, dap-style.
--- Pure. Bounds clamp the walk to an enclosing structure (an exchange, a
--- section) so a paragraph never escapes its container.
local function paragraph_range(lines, row, bounds)
    local lo = (bounds and bounds.first) or 1
    local hi = (bounds and bounds.last) or #lines
    if row < lo or row > hi or is_blank(lines[row]) then
        return nil
    end
    local first, last = row, row
    while first > lo and not is_blank(lines[first - 1]) do first = first - 1 end
    while last < hi and not is_blank(lines[last + 1]) do last = last + 1 end
    return { kind = "paragraph", first = first, last = last }
end

--- Extend a range over the blank run that follows it, bounded.
local function absorb_trailing_blanks(range, lines, bounds)
    local hi = (bounds and bounds.last) or #lines
    local last = range.last
    while last < hi and is_blank(lines[last + 1]) do last = last + 1 end
    range.last = last
    return range
end

--- The structural unit under the cursor.
--- @param parsed table|nil  parsed chat, or nil for a plain markdown buffer
--- @param lines table       1-based array of buffer lines
--- @param row number        1-based cursor row
--- @param opts table|nil    { scope = "entity"|"to_end", inner = boolean }
--- @return table|nil        { kind, first, last }
function M.range(parsed, lines, row, opts)
    opts = opts or {}
    local found = paragraph_range(lines, row, nil)
    if not found then
        return nil
    end
    if not opts.inner then
        absorb_trailing_blanks(found, lines, nil)
    end
    return found
end

return M
```

- [ ] **Step 4: Run it and watch it pass**

Same command. Expected: PASS, 5 successes.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262: entity_range: paragraph case"
```

### Task 5: `entity_range` — section case

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

- [ ] **Step 1: Add the failing tests**

```lua
describe("entity_range section", function()
    local lines = {
        "# Top",        -- 1
        "body a",       -- 2
        "",             -- 3
        "## Sub",       -- 4
        "body b",       -- 5
        "",             -- 6
        "### Deep",     -- 7
        "body c",       -- 8
        "",             -- 9
        "## Sibling",   -- 10
        "body d",       -- 11
    }

    it("takes a section through the next same-or-higher heading", function()
        -- ## Sub is rank 2; the next heading of rank <= 2 is ## Sibling (10),
        -- so the range ends at 9 and swallows the deeper ### Deep on the way.
        local r = entity_range.range(nil, lines, 4)
        assert.equals("section", r.kind)
        assert.equals(4, r.first)
        assert.equals(9, r.last)
    end)

    it("includes every nested subsection", function()
        -- # Top is rank 1 and NO later heading is rank <= 1, so the section
        -- runs to end of buffer, carrying ## Sub, ### Deep and ## Sibling.
        local r = entity_range.range(nil, lines, 1)
        assert.equals(1, r.first)
        assert.equals(11, r.last)
    end)

    it("runs to end of buffer for the last section", function()
        local r = entity_range.range(nil, lines, 10)
        assert.equals(10, r.first)
        assert.equals(11, r.last)
    end)

    it("handles a heading with no body", function()
        local r = entity_range.range(nil, { "# A", "# B" }, 1)
        assert.equals(1, r.first)
        assert.equals(1, r.last)
    end)

    it("inner drops the heading line and trailing blanks", function()
        -- outer is 4..9; inner drops the heading (4) and the trailing blank (9)
        local r = entity_range.range(nil, lines, 4, { inner = true })
        assert.equals(5, r.first)
        assert.equals(8, r.last)
    end)

    it("returns nil for inner on a heading with no body", function()
        assert.is_nil(entity_range.range(nil, { "# A", "# B" }, 1, { inner = true }))
    end)

    it("treats a non-heading line as a paragraph, not its section", function()
        local r = entity_range.range(nil, lines, 5)
        assert.equals("paragraph", r.kind)
    end)
end)
```

**Rank arithmetic, since it is the easiest thing here to get backwards.** "Equal or higher level" means a *smaller or equal* hash count: `#` (1) outranks `##` (2). A section therefore ends before the next heading whose level number is `<= its own`, and every deeper heading is swallowed. Check the fixture by hand against this before writing the implementation — the two cases above are the ones that disagree if you invert the comparison.

- [ ] **Step 2: Run and watch the new describe block fail**

- [ ] **Step 3: Implement**

```lua
local heading = require("parley.markdown_heading")

--- Section owned by the heading on `row`, through the line before the next
--- heading of equal or higher rank (lower or equal level number), bounded.
local function section_range(lines, row, bounds)
    local level = heading.level(lines[row])
    if not level then
        return nil
    end
    local hi = (bounds and bounds.last) or #lines
    local last = row
    for i = row + 1, hi do
        local other = heading.level(lines[i])
        if other and other <= level then
            break
        end
        last = i
    end
    return { kind = "section", first = row, last = last }
end
```

Wire it into `M.range` ahead of the paragraph fallback, and make `inner` drop the heading line (`first + 1`, returning `nil` when the section has no body).

- [ ] **Step 4: Run and watch it pass**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262: entity_range: section case"
```

### Task 6: `entity_range` — question case, precedence, and malformed input

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

Build the parsed fixture the way `tests/unit/chat_parser_section_lines_spec.lua` does — real `chat_parser.parse_chat` over literal lines, not a hand-built table, so the test breaks if the parser's shape moves.

- [ ] **Step 1: Write the failing tests**

Cover, at minimum:
1. cursor on the `💬:` line → `kind == "question"`, range equals `exchange_clipboard.get_exchange_line_range` for that exchange;
2. cursor on an `@@tag@@` preface line → same range (via `question_tags.semantic_start`);
3. cursor on a paragraph inside an answer → `kind == "paragraph"`, range does **not** cross into the next exchange;
4. cursor on a heading inside an answer → `kind == "section"`, range clamped to the exchange end;
5. cursor in the header (before any exchange) → paragraph or `nil`, never a question;
6. malformed: `row` past `#lines`, `row = 0`, empty `lines`, `parsed` with zero exchanges → `nil` every time, no error raised.

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement the dispatch**

```lua
local exchange_clipboard = require("parley.exchange_clipboard")
local question_tags = require("parley.question_tags")

--- Index of the exchange whose semantic span contains `row`, plus its bounds.
local function exchange_at(parsed, lines, row)
    if not parsed or not parsed.exchanges then return nil end
    local idx = require("parley.chat_parser").find_exchange_at_line(parsed, row)
    if not idx then return nil end
    local first, last = exchange_clipboard.get_exchange_line_range(parsed, idx, #lines)
    return idx, { first = first, last = last }
end

--- True when `row` is the question's own anchor: the 💬: line or its preface.
local function on_question_line(parsed, idx, row)
    local ex = parsed.exchanges[idx]
    if not ex or not ex.question then return false end
    return row >= question_tags.semantic_start(ex) and row <= ex.question.line_end
end
```

`M.range` then reads: resolve the exchange and its bounds → if on the question anchor, return the whole exchange range → else try `section_range(lines, row, bounds)` → else `paragraph_range(lines, row, bounds)`. Every guard returns `nil` rather than a partial range (ARCH-SECURE).

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262: entity_range: question case and precedence"
```

### Task 7: `entity_range` — `scope = "to_end"` and the 📝 edge rule

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

- [ ] **Step 1: Write the failing tests**

1. `scope="to_end"` from a paragraph mid-answer → `first` = that paragraph's start, `last` = exchange end;
2. `scope="to_end"` from a heading mid-answer → `first` = heading line;
3. `scope="to_end"` on the `💬:` line → identical range to `scope="entity"` (degenerates to the whole exchange);
4. `scope="to_end"` never crosses the next `💬:` — assert against a two-exchange fixture;
5. **📝 kept:** exchange ends `… body / blank / 📝: summary`; `to_end` from a body paragraph → `last` lands before the `📝:` line;
6. **📝 taken:** same fixture, cursor on the `💬:` line → `kind == "question"` and the range *includes* the `📝:` line;
7. **📝 interior:** `… para A / 📝: summary / para B`; `to_end` from para A → range covers all three (the summary is deleted, per the operator's decision);
8. outside any exchange → `last` is the enclosing section's end, else `#lines`.

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

Add a `summary_guard(range, parsed, idx, kind)` helper that pulls `range.last` back to `summary.line - 1` when `kind ~= "question"` and `parsed.exchanges[idx].summary` is at or after `range.last`'s trailing-blank region. Read the summary line from `exchange.summary.line` — do **not** re-scan for `📝:`, the parser already indexed it (`chat_parser.lua:799`).

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the whole unit suite** to catch collateral damage

```sh
make test-unit 2>&1 | tail -20
```
Expected: no new failures.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262: entity_range: to_end scope and the summary edge rule"
```

### Task 8: Fold `outline.lua` onto the shared dialect

**Files:**
- Modify: `lua/parley/outline.lua:53-57`

- [ ] **Step 1: Read the call site** and confirm the surrounding function's contract (it maps a line to an outline item type).

- [ ] **Step 2: Replace the three-branch `if` with `markdown_heading.level(line)`**, keeping the existing behavior for every level it already handled.

- [ ] **Step 3: Run the outline specs**

```sh
make test-spec SPEC=ui/outline 2>&1 | tail -20
```
If that traceability slug does not resolve, fall back to running every spec whose name matches outline:
```sh
ls tests/unit/*outline* tests/integration/*outline* 2>/dev/null
```
Expected: PASS, unchanged behavior.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/outline.lua
git commit -m "#262: outline: consume the shared heading dialect"
```

### Task 9: Close M1

- [ ] **Step 1: Run the full suite**

```sh
make test 2>&1 | tail -30
```

- [ ] **Step 2: Update `## Log`** in the issue with what the range contract settled on and anything the conformance test surfaced.

- [ ] **Step 3: Close the milestone** — this dispatches the mandatory fresh-context review (AGENTS.md §3; do **not** separately run `superpowers-requesting-code-review`).

```bash
sdlc milestone-close --issue 262 --milestone M1
```
Fix any Critical/Important finding before crossing into M2, then log the `Review-Verdict:` outcome.

---

## Chunk 2: M2 — the surface

### Task 10: The text object

**Files:**
- Create: `lua/parley/entity_textobj.lua`
- Test: `tests/integration/entity_textobj_spec.lua`

- [ ] **Step 1: Write the failing integration test** — real buffer, real keymaps, assert on buffer contents after `normal dae` / `normal daE` / `normal die`. Use the `prepped_chat()` idiom from `tests/integration/keybinding_agreement_spec.lua:99-126`, and remember `D.attach(buf, {schedule=false})` before any edit.

- [ ] **Step 2: Run and watch it fail**

- [ ] **Step 3: Implement**

```lua
local M = {}

--- Select the entity at the cursor as a linewise visual range, so any
--- operator (d, y, c, gq) composes with it and dot-repeat comes free.
--- @param scope string   "entity" | "to_end"
--- @param inner boolean|nil
function M.select(scope, inner)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local parsed = M.parsed_for(buf, lines)   -- nil in a plain markdown buffer
    local r = require("parley.entity_range").range(parsed, lines, row,
        { scope = scope, inner = inner })
    if not r then
        return
    end
    vim.cmd(("normal! %dGV%dG"):format(r.first, r.last))
end

return M
```

`M.parsed_for(buf, lines)` gates on the cheap `_parley_bufs[buf] == "chat"` latch (never `not_chat`, which carries a keystroke-path perf warning at `init.lua:216`), then `find_header_end` + `parse_chat`; it returns `nil` for markdown buffers so the same object works there with only the section/paragraph kinds.

- [ ] **Step 4: Run and watch it pass**

- [ ] **Step 5: Commit**

### Task 11: Commands, registry entries, and the mode-set widening

**Files:**
- Modify: `lua/parley/init.lua` (add `M.cmd.DeleteEntity`, `M.cmd.DeleteToEnd`; wire callbacks in `prep_chat` ~`:2775-2820` and `setup_markdown_keymaps` ~`:3026-3044`)
- Modify: `lua/parley/keybinding_registry.lua` (`M.entries`)
- Modify: `lua/parley/config.lua` (the `chat_shortcut_*` twins)
- Modify: `tests/integration/keybinding_agreement_spec.lua:37`
- Test: `tests/integration/entity_delete_spec.lua`

- [ ] **Step 1: Add the registry entries.** Five entries — three text objects and two hotkeys — each with its `config.lua` twin whose `modes` list matches `default_modes` **exactly** (`tests/unit/keybindings_spec.lua:418-449` fails otherwise, and entries sharing a `config_key` must declare identical defaults, `:453-473`).

```lua
{
    id = "entity_object_outer",
    config_key = "chat_shortcut_entity_object_outer",
    default_key = "ae",
    default_modes = { "o", "x" },
    scope = "chat",
    desc = "Parley: entity text object",
    help_desc = "Text object: entity at cursor (dae, yae, cae)",
    buffer_local = true,
},
```
…and the same shape for `entity_object_inner` (`ie`), `entity_object_to_end` (`aE`), plus `entity_delete` and `entity_delete_to_end` hotkeys in `{ "n" }`. Register each in **both** the `chat` and `markdown` scopes (the issue's Problem names markdown notes too); follow the `chat_shortcut_delete` / `chat_shortcut_delete_file` precedent of **separate config keys per scope** — that comment at `config.lua:355-360` records exactly what goes wrong when two scopes share one knob.

- [ ] **Step 2: Extend the agreement spec's mode set**

```lua
local MODES = { "n", "i", "v", "x", "o" }
```
Without this, the new `o`-mode maps sit outside both the leak and ghost guards. Run it and confirm it still passes — a failure here means a mode leaked somewhere else and is a real finding.

- [ ] **Step 3: Add the command handlers.** Copy `ExchangeCut`'s preamble verbatim (`init.lua:4423-4436`: `not_chat` guard → `nvim_buf_get_lines` → `find_header_end` → `parse_chat`), then:

```lua
local r = require("parley.entity_range").range(parsed_chat, lines, cursor_line, opts)
if not r then
    M.logger.warning("DeleteEntity: no entity at cursor")
    return
end
require("parley.buffer_edit").replace_user_lines(buf, r.first - 1, r.last, false, {})
```

`nvim_buf_set_lines` is arch-fenced (`tests/arch/buffer_mutation_spec.lua:12-40`) — the mutation **must** go through `buffer_edit`. Note `replace_user_lines` `error()`s when the document refuses the edit (a response streaming into this exchange); let it propagate exactly as `ExchangeCut` does rather than inventing a new guard.

- [ ] **Step 4: Test the refusal path** — assert that a delete attempted while the document withholds the grant raises rather than silently corrupting the transcript (ARCH-ORDER).

- [ ] **Step 5: Run the keybinding and arch suites**

```sh
make test-unit 2>&1 | tail -20
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/arch/single_source_sweeps_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/keybinding_agreement_spec.lua" -c "qa!"
```

- [ ] **Step 6: Commit**

### Task 12: Parity and the performance budget

**Files:**
- Test: `tests/integration/entity_delete_parity_spec.lua`
- Create: `tests/perf/entity_range.lua`
- Modify: `Makefile.parley` (the `perf` target, line ~57)

- [ ] **Step 1: Write the parity test.** Over a fixture transcript, for every cursor row: apply `normal dae` to one buffer and `:ParleyDeleteEntity` to an identical buffer, assert the resulting line arrays are equal. Repeat for `daE` / `:ParleyDeleteToEnd`. This is the test that makes "two surfaces, one behavior" a checked invariant instead of a claim.

- [ ] **Step 2: Run the parity test and watch it pass.** A failure here is the divergence the whole two-surface design exists to prevent — do not paper over it by loosening the assertion.

- [ ] **Step 3: Write the perf measurement**, following the repo's convention rather than inventing one: `tests/perf/*.lua` are **reporting** modules driven by `tests/perf/harness.lua`, not busted specs — they measure and render a table, they do not assert wall-clock budgets (a timing assertion inside `make test` is flaky on a loaded machine). Reuse `tests.perf.chat_typing.build_fixture(n)`, which already builds an n-line transcript with a real header and 💬:/🤖: markers, and `harness.measure(fn, iterations)` + `harness.summarize(samples)`.

```lua
local harness = require("tests.perf.harness")
local chat_typing = require("tests.perf.chat_typing")

function M.start()
    local lines = chat_typing.build_fixture(5000)
    local parser = require("parley.chat_parser")
    local entity_range = require("parley.entity_range")
    local samples = harness.measure(function()
        local parsed = parser.parse_chat(lines, parser.find_header_end(lines))
        entity_range.range(parsed, lines, 2500)
    end, 100)
    -- render via harness.new_report / add_scenario / render_table
end
```

- [ ] **Step 4: Add it to the `perf` target** in `Makefile.parley` (~line 57), which today runs only `tests.perf.chat_typing`. Run `make perf` and read the table.

- [ ] **Step 5: Record the measured number** in the issue `## Log` against the 16 ms/frame budget from the ARCH-CONSTRAINTS section. If it misses, **stop and report** — switching to `document.exchange(doc,row)` is a design change that needs the operator, not a silent widening of the budget.

- [ ] **Step 6: Commit**

### Task 13: Documentation

**Files:**
- Modify: `atlas/ui/keybindings.md`
- Modify: `README.md`
- Modify: `atlas/index.md` (link the new page if one is added)
- Create: `atlas/chat/entity_delete.md`

`workshop/lessons.md:451,613` records the doc gate as a repeatedly-violated rule — a new key that is not named in `atlas/ui/keybindings.md` **and** the README is a review finding.

- [ ] **Step 1: Document the three objects and two hotkeys**, the precedence table, the 📝 rule, and the markdown-vs-chat difference (no question kind outside a chat).
- [ ] **Step 2: Verify `:ParleyKeyBindings` renders the new entries** — it reads the registry, so this is a check that `help_desc` and scope are right.
- [ ] **Step 3: Commit**

### Task 14: Close the issue

- [ ] **Step 1: Run everything**

```sh
make test 2>&1 | tail -30
```

- [ ] **Step 2: Manual smoke** in a real chat transcript: `dae` on a 💬: line, on a heading, on a paragraph; `daE` from mid-answer; `u` restores each in one step; `yae` then `p` round-trips.

- [ ] **Step 3: Close**

```bash
sdlc milestone-close --issue 262 --milestone M2
sdlc close --issue 262 --verified '<what you ran and saw>'
```
`--actual` is measured, not typed — omit it and let the close measure and adopt the hours (AGENTS.md §5).

---

## Open items for the operator

1. **`ie` on a question** — "inner question" is defined here as the question without its answer. If you'd rather `ie` mean "the answer without the question", say so before Task 6; it is a one-line change then and a re-test later.
2. **Markdown scope** — the plan registers the objects in markdown buffers too, since the issue's Problem names markdown notes. Say if you want chat-only for the first cut.
3. **`####` and deeper** — the repo's heading dialect caps at three levels, so `#### Four` is body text and a `dae` on it takes the paragraph. Widening the dialect is a separate change that touches outline and the document tokenizer together.
