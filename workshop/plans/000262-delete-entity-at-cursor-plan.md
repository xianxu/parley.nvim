# Delete Entity at Cursor — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One cursor-dispatched range — markdown section, paragraph, or chat exchange — exposed as the `ae`/`ie`/`aE` text objects plus hotkeys and `:Parley*` commands, so `dae` deletes the entity under the cursor and `daE` deletes from it to the end of the question.

**Architecture:** A pure range module (`entity_range.lua`) computes `{kind, first, last}` from an already-parsed chat plus the raw lines; it owns *all* dispatch, precedence, bounds and blank-line policy, and reuses the tested primitives (`exchange_clipboard.get_exchange_line_range`, `question_tags.semantic_start`, `lexical.is_fence_delim`, `highlight_structure.code_block_memo`) rather than re-deriving them. Two thin surfaces consume it: a text object that turns the range into a linewise visual selection (native `d` then deletes, giving every operator and dot-repeat for free), and `M.cmd` handlers that delete through `buffer_edit.replace_user_lines`. A parity test over every cursor row **in a folded buffer** pins the two surfaces to byte-identical results.

**Tech Stack:** Lua 5.1/LuaJIT, Neovim API, plenary.nvim busted specs, the `keybinding_registry` + `config.lua` single-source pair.

> **Citation policy (BR-20, 5 rounds open).** This plan cites **symbols, not
> line numbers**, for anything in `lua/`. Line numbers drift with every edit —
> that finding stayed open for five rounds because each round's "fix" updated
> the numbers and the next round's edits invalidated them again. A symbol name
> is greppable and stable, so the claim stays checkable. Line refs survive only
> for test files pinned by a specific assertion.

---

## Spec deviations — read before implementing

Four places where this plan departs from the issue as first written. **All four are now recorded in the issue's `## Revisions`** — if you change any of them, update that section in the same commit, because `sdlc close` asserts the code against `## Done when`.

1. **Precedence is a line-class rule, not containment.** The Spec says a cursor anywhere inside an answer is "inside the question". Every line of a chat buffer is inside some exchange, so read literally that makes the section and paragraph cases unreachable — and contradicts the operator's requirement that `aE` start at paragraph level inside an answer.

   | Cursor sits on | Entity |
   |---|---|
   | `💬:` question line, or its `@@tag@@` preface | whole exchange |
   | an ATX heading line | that section |
   | anything else | that paragraph |

   Containment survives as **clamping only**: a section or paragraph range never crosses its enclosing exchange's bounds.

2. **📝 preservation is an edge trim, and the non-contiguous delete is gone.** The Spec mandated a non-contiguous delete around an interior 📝 with the two surfaces documented as divergent. A stock `d` over a text object *cannot* skip an interior line, so that rule would ship two surfaces that differ on the same keystroke. Interior 📝 and whole-exchange deletes take the summary; 🧠/🔧/📎/🌿/🔒 are ordinary content.

3. **The heading dialect caps at three levels**, not six — the repo has one dialect (`document/lexical.lua`) and this feature consumes it instead of adding a fourth.

4. **`dap` equivalence holds on plain prose only.** The paragraph walk also stops at headings and structural markers with no blank line between. Strict `dap` parity would let a paragraph swallow the heading above it, or the `💬:` line itself.

---

## Core concepts

### Pure entities

| Name | Exports | Lives in | Status |
|------|---------|----------|--------|
| `markdown_heading` | `level` | `lua/parley/markdown_heading.lua` | new |
| `entity_range` | `range` | `lua/parley/entity_range.lua` | new |
| `outline` heading dialect | — | `lua/parley/outline.lua` (both heading paths) | modified |
| `chat_parser` shape test | `transcript_header_end` | `lua/parley/chat_parser.lua` | modified |

- **markdown_heading** — `level(line) -> number|nil`, the repo's one ATX dialect. Tests in `tests/unit/markdown_heading_spec.lua`, no mocks.
  - **Relationships:** 1:N — one dialect, consumed by `entity_range` and `outline`, and pinned against `document/lexical.lua` by conformance test.
  - **DRY rationale:** the dialect is already written twice — `outline.lua`'s line-based heading branch (`^### `/`^## `/`^# `) and `document/lexical.lua` (`^(#+) `, capped at 3). A third copy is exactly the drift ARCH-DRY exists to stop. `lexical.lua` keeps its inline byte-scanner (a hot incremental tokenizer; destabilizing it is not worth it) and the conformance test is what *enforces* the single source rather than documenting it (ARCH-PURPOSE).
  - **Future extensions:** levels 4-6, setext headings. Widening here widens outline and entity ranges together, which is the point.

- **entity_range** — `range(parsed, lines, row, opts) -> {kind, first, last}|nil`. The whole feature's logic. Tests in `tests/unit/entity_range_spec.lua`, no mocks: it takes a parsed chat and a line array, never a buffer.
  - **Relationships:** N:1 with a parsed chat; 1:1 with a cursor row; holds nothing between calls.
  - **DRY rationale:** first occurrence of "what structural unit is under the cursor" as a reusable value. `ChatPrune` and `ExchangeCut` each inline their own variant of the walk; collapsing them onto this is a follow-up, not this issue (YAGNI).
  - **Future extensions:** `v:count1` for `2dae` (ignored in this cut — say so in the docs); a visual scope that unions ranges across a selection.

**`entity_range.range` contract.**

```
opts.scope = "entity" (default) | "to_end"
opts.inner = false (default) | true
returns { kind = "question"|"section"|"paragraph", first = <1-based>, last = <1-based> }
         or nil   -- no entity here; every caller treats nil as "do nothing"
```

Five rules, each stated once. Where an earlier draft of this plan said the same thing three different ways, this list is authoritative.

1. **Bounds.** An exchange's span is `exchange_clipboard.get_exchange_line_range(parsed, idx, #lines)` — `semantic_start(ex)` through `semantic_start(next) - 1`, trailing blanks and branch lines included. This is the **only** span definition used. `chat_parser.find_exchange_at_line` bounds an exchange at `answer.line_end` instead, so the two disagree on the trailing gap; resolve the index with `find_exchange_at_line`, then, if it returns nil, fall back to a scan over `get_exchange_line_range` spans so a row in the gap still lands in its exchange rather than escaping into an unbounded walk.
2. **Dispatch.** Question anchor → whole exchange. Heading line → section. Otherwise → paragraph. A section or paragraph range is clamped to its exchange span.
3. **Walk stops.** A paragraph stops at a blank line, at a heading, and at a structural marker (`💬 🤖 📝 🧠 🔧 📎 🌿 🔒`) — in both directions. A section ends before the next heading whose level is `<=` its own (`#` outranks `##`), or at its clamp.
4. **Trailing blanks.** An outer range absorbs the blank run that follows it, `dap`-style, bounded by the clamp. An inner range trims trailing blanks instead. This is what makes the seam clean with no post-pass, which is what lets native `d` and the programmatic path agree byte-for-byte. `exchange_clipboard.compute_cut_cleanup` is deliberately **not** reused — it is a post-pass over already-mutated lines, which a text object has no opportunity to run.
5. **📝 edge trim.** *After* rule 4, if `kind ~= "question"` and the exchange has a summary at `sl = exchange.summary.line` where `first < sl <= last` **and every line in `(sl, last]` is blank**, set `last = sl - 1`. The `first < sl` guard is what stops the range inverting when the cursor is *on* the summary line; the all-blank tail is what makes this an edge trim rather than an interior skip. Note `chat_parser` overwrites `exchange.summary` per 📝 line, so only the last summary in an exchange is indexed — an earlier one is ordinary content.

### Integration points

| Name | Exports | Lives in | Status | Wraps |
|------|---------|----------|--------|-------|
| `entity_textobj` | `select`, `parsed_for` | `lua/parley/entity_textobj.lua` | new | Neovim visual-mode selection + fold state |
| `M.cmd.DeleteEntity` / `M.cmd.DeleteToEnd` | — | `lua/parley/init.lua` | new | `buffer_edit.replace_user_lines` |
| registry entries `entity_*` | — | `lua/parley/keybinding_registry.lua` + `lua/parley/config.lua` | modified | keymap installation |
| agreement-spec mode set | — | the `MODES` constant in `tests/integration/keybinding_agreement_spec.lua` | modified | keymap leak/ghost guards |
| traceability routing | — | `atlas/traceability.yaml` | modified | the added-spec sweep |
| app-profile carve-out | — | `lua/parley/starter_config.lua` + `tests/unit/starter_config_spec.lua` | modified | the packaged app's keymap filter |

- **entity_textobj.select(scope, inner)** — reads cursor + lines, calls `entity_range.range`, selects it linewise. Two pieces of editor state make this more than a one-liner, both verified by execution and both invisible to a naive test — see Task 10.
  - **Injected into:** nothing; it is the leaf. `entity_range` receives `lines` and `row`, so all dispatch is unit-testable without a buffer.

- **M.cmd.DeleteEntity / M.cmd.DeleteToEnd** — the discoverable twins. `ExchangeCut`'s preamble, then one `buffer_edit.replace_user_lines`.
  - **Injected into:** nothing. Both call the same `entity_range.range`, which is what the parity test pins.

**Test surface.** `markdown_heading` and `entity_range` are PURE — unit specs over literal line arrays, zero mocks. The surfaces are integration-tested against a real buffer with `D.attach(buf,{schedule=false})` (`tests/unit/user_buffer_edit_spec.lua:1-15`). ARCH-MOCK is `N/A`: no external binary or service; Neovim is exercised for real.

---

## ARCH-* review

- **ARCH-DRY** — one heading dialect, extracted and pinned; one exchange-span definition; keymaps through the registry. Note for honesty: no arch test currently rejects a hand-rolled `vim.keymap.set` (`single_source_sweeps_spec.lua` is about `native_map`/`native_overrides`), and `lua/parley/init.lua` *is* on `buffer_mutation_spec.lua`'s `nvim_buf_set_lines` allow-list (`:41`). Both choices are still right — the registry owns help/config and `buffer_edit` owns document provenance — but they rest on design intent, not on a guard that will fire.
- **ARCH-PURE** — all dispatch, bounds, blank and 📝 policy are functions over `(parsed, lines, row)`. If a range test ever needs a buffer, the boundary has leaked.
- **ARCH-PURPOSE** — the purpose is one uniform delete across three kinds and two scopes, reachable by a discoverable key. Shipping only the text object would be the easy subset; both surfaces land in M2 together. The marker policy is ruled on as a *class* (📝/🧠/🔧/📎/🌿/🔒), not one emoji.
- **ARCH-MOCK** — `N/A`, as above.
- **ARCH-CONSTRAINTS** — **keystroke/UI-response** path. Budget: one `parse_chat` per invocation, target < 16 ms on a 5 000-line transcript; basis: precedent — `ExchangeCut`/`ChatPrune` already parse the whole buffer per invocation. Exceeded → the escape hatch is `document.exchange(doc,row)` (`document.exchange`). Measured in Task 13; a miss is a finding, not a silent widening. **It missed —
see Revisions, 2026-09-16: 24.7 ms at 5 000 lines (17.0 ms on an independent
best-of-5 re-measure), accepted by the operator on the basis of real transcript
sizes rather than silently widened.** The text object gates on the cheap `M._parley_bufs[buf]` latch rather than `not_chat`.
- **ARCH-SECURE** — `N/A` for secrets. Untrusted input: the transcript is user/model-authored and may be truncated or hand-edited mid-generation. `range` must return `nil` rather than a partial range for malformed input, and never a range with `last < first` or outside `[1, #lines]` — Task 7 property-tests exactly that.
- **ARCH-ORDER** — `entity_range` holds no state between events because every call re-derives from `(parsed, lines, row)` and returns a value; there is no cache to invalidate. The one unblockable ordering is **an edit landing while a response streams into this exchange**. The programmatic path inherits `buffer_edit.replace_user_lines`' refusal (`buffer_edit.replace_user_lines` raises on a refused grant) — the same contract `ExchangeCut` relies on, so no new guard is invented. The native `d` path does **not** inherit it; it is an ordinary user edit handled by `document/user_edits.lua`. **This is the one place the two surfaces differ, it is deliberate, and the parity claim is explicitly scoped to a quiescent document.** Task 11 tests the refusal.
- **ARCH-FUNERAL** — creates no durable artifact, cache or handle. The only created things are keymaps, ended by the existing buffer-local lifecycle (`M._parley_bufs` cleared on unload, `highlighter`'s unload hook).

---

## Chunk 1: M1 — the pure range core

### Task 1: `markdown_heading.level`

**Files:**
- Create: `lua/parley/markdown_heading.lua`
- Test: `tests/unit/markdown_heading_spec.lua`

- [x] **Step 1: Write the failing test**

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
        assert.is_nil(heading.level(nil))
    end)
end)
```

- [x] **Step 2: Run it and watch it fail**

```sh
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/markdown_heading_spec.lua" -c "qa!"
```
Expected: FAIL — `module 'parley.markdown_heading' not found`.

- [x] **Step 3: Write the implementation**

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

- [x] **Step 4: Run it and watch it pass** — same command, 4 successes.

- [x] **Step 5: Commit**

```bash
git add lua/parley/markdown_heading.lua tests/unit/markdown_heading_spec.lua
git commit -m "#262 M1: markdown_heading: state the ATX dialect once"
```

### Task 2: Pin `document/lexical.lua` to the shared dialect

**Files:**
- Test: `tests/unit/markdown_heading_conformance_spec.lua`

The enforcement half of ARCH-DRY. **`lexical.token(...)` does not exist** and `M.classify` does not compute `heading_level` — only the internal `finish(c)` does. The public seam is `lex_start`/`lex_step`; this exact call was run against this exact corpus and all 20 lines agree, so the test goes green as written.

- [x] **Step 1: Write the conformance test**

```lua
local heading = require("parley.markdown_heading")
local lexical = require("parley.document.lexical")
local config = require("parley.config")

-- Straddles every edge of the dialect: the cap, the required space,
-- indentation, and structural markers that must never read as headings.
local CORPUS = {
    "# One", "## Two", "### Three", "#### Four", "##### Five",
    "#NoSpace", "##", "#", "  # Indented", "\t# Tabbed",
    "", "plain", "💬: q", "🤖: a", "📝: s", "--- ", "@@tag@@",
    "#  double space", "###   spaced", "# trailing hash #",
}

describe("markdown_heading vs document.lexical", function()
    it("agrees on heading_level for every corpus line", function()
        local patterns = lexical.patterns(config.config or {})
        for _, line in ipairs(CORPUS) do
            local cursor = lexical.lex_start(patterns)
            local _, token = lexical.lex_step(cursor, line, true)
            assert.equals(heading.level(line), token.heading_level,
                ("dialect drift on %q"):format(line))
        end
    end)
end)
```

- [x] **Step 2: Run it**

```sh
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/markdown_heading_conformance_spec.lua" -c "qa!"
```
Expected: PASS. If the `lex_start`/`lex_step` arity differs from the above, read `lex_start`/`lex_step` in `lua/parley/document/lexical.lua` and adapt — but do **not** add a new public function to `lexical.lua` and do **not** copy its regex into the test. A genuine disagreement is a real finding: record it in the issue `## Log` and change `markdown_heading` to match the tokenizer, which is the incumbent.

- [x] **Step 3: Commit**

```bash
git add tests/unit/markdown_heading_conformance_spec.lua
git commit -m "#262 M1: pin the heading dialect against the document tokenizer"
```

### Task 3: `entity_range` — paragraph case with structural stops

**Files:**
- Create: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

The walk stops at blanks **and** at headings **and** at structural markers. A plain blank-only walk lets a paragraph swallow the heading directly above it — and in a transcript, the `💬:` line itself.

- [x] **Step 1: Write the failing test**

```lua
local entity_range = require("parley.entity_range")

describe("entity_range paragraph", function()
    it("takes the blank-delimited run plus its trailing blanks", function()
        local lines = { "alpha one", "alpha two", "", "beta one", "" }
        --                    1            2       3      4        5
        local r = entity_range.range(nil, lines, 1)
        assert.equals("paragraph", r.kind)
        assert.equals(1, r.first)
        assert.equals(3, r.last)
    end)

    it("stops at end of buffer without inventing a trailing blank", function()
        local r = entity_range.range(nil, { "alpha", "", "omega" }, 3)
        assert.equals(3, r.first)
        assert.equals(3, r.last)
    end)

    it("absorbs a multi-blank run", function()
        local r = entity_range.range(nil, { "alpha", "", "", "", "beta" }, 1)
        assert.equals(1, r.first)
        assert.equals(4, r.last)
    end)

    it("does not walk back over a heading with no blank between", function()
        local lines = { "## Sub", "body b", "", "next" }
        --                  1         2      3     4
        local r = entity_range.range(nil, lines, 2)
        assert.equals("paragraph", r.kind)
        assert.equals(2, r.first)   -- NOT 1
        assert.equals(3, r.last)
    end)

    it("does not walk back over a structural marker", function()
        local lines = { "💬: q", "body", "", "x" }
        local r = entity_range.range(nil, lines, 2)
        assert.equals(2, r.first)   -- NOT 1
    end)

    it("does not walk forward over a heading", function()
        local lines = { "body", "## Next", "more" }
        local r = entity_range.range(nil, lines, 1)
        assert.equals(1, r.first)
        assert.equals(1, r.last)    -- NOT 3
    end)

    it("inner drops the trailing blanks", function()
        local lines = { "alpha one", "alpha two", "", "beta" }
        local r = entity_range.range(nil, lines, 1, { inner = true })
        assert.equals(1, r.first)
        assert.equals(2, r.last)
    end)

    it("returns nil on a blank line", function()
        assert.is_nil(entity_range.range(nil, { "alpha", "", "", "beta" }, 2))
    end)
end)
```

- [x] **Step 2: Run it and watch it fail** — module not found.

- [x] **Step 3: Implement**

```lua
local heading = require("parley.markdown_heading")

local M = {}

-- The structural marker set chat_parser calls STRUCTURAL_KINDS. Read the
-- prefixes from config rather than hardcoding the emoji, so a configured
-- chat_user_prefix keeps working (document.lexical owns the vocabulary).
local function structural_prefixes(config)
    local lexical = require("parley.document.lexical")
    local p = lexical.patterns(config or {})
    return {
        p.user_prefix, p.assistant_prefix, p.summary_prefix, p.reasoning_prefix,
        p.tool_use_prefix, p.tool_result_prefix, p.branch_prefix, p.local_prefix,
    }
end

local function is_blank(line)
    return line == nil or line:match("^%s*$") ~= nil
end

--- A line the paragraph walk must not cross: blank, heading, or structural.
local function is_wall(line, prefixes)
    if is_blank(line) or heading.level(line) then
        return true
    end
    for _, prefix in ipairs(prefixes) do
        if prefix and #prefix > 0 and line:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

--- Blank/heading/marker-delimited paragraph containing `row`.
--- Pure. `bounds` clamps the walk to an enclosing exchange.
local function paragraph_range(lines, row, bounds, prefixes)
    local lo = (bounds and bounds.first) or 1
    local hi = (bounds and bounds.last) or #lines
    if row < lo or row > hi or is_wall(lines[row], prefixes) then
        return nil
    end
    local first, last = row, row
    while first > lo and not is_wall(lines[first - 1], prefixes) do first = first - 1 end
    while last < hi and not is_wall(lines[last + 1], prefixes) do last = last + 1 end
    return { kind = "paragraph", first = first, last = last }
end

--- Extend over the blank run that follows, bounded (dap semantics).
local function absorb_trailing_blanks(range, lines, bounds)
    local hi = (bounds and bounds.last) or #lines
    while range.last < hi and is_blank(lines[range.last + 1]) do
        range.last = range.last + 1
    end
    return range
end

--- Inverse of absorb: pull back off any trailing blanks (inner semantics).
local function trim_trailing_blanks(range, lines)
    while range.last > range.first and is_blank(lines[range.last]) do
        range.last = range.last - 1
    end
    return range
end
```

`M.range` for now: `paragraph_range` → absorb (outer) or trim (inner) → return.

- [x] **Step 4: Run it and watch it pass** — 8 successes.

- [x] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262 M1: entity_range: paragraph case with structural stops"
```

### Task 4: `entity_range` — section case

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

**Rank arithmetic, since it is the easiest thing here to get backwards.** "Equal or higher level" means a *smaller or equal* hash count: `#` (1) outranks `##` (2). A section ends before the next heading whose level number is `<=` its own, and swallows every deeper heading.

- [x] **Step 1: Add the failing tests**

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

    it("ends before the next same-or-higher heading", function()
        -- ## Sub is 2; next heading of level <= 2 is ## Sibling (10) => 4..9,
        -- swallowing the deeper ### Deep on the way.
        local r = entity_range.range(nil, lines, 4)
        assert.equals("section", r.kind)
        assert.equals(4, r.first)
        assert.equals(9, r.last)
    end)

    it("runs to end of buffer when nothing outranks it", function()
        -- # Top is 1 and NO later heading is level <= 1, so it carries
        -- ## Sub, ### Deep and ## Sibling with it.
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
        -- outer is 4..9; inner drops the heading (4) and the blank tail (9)
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
        assert.equals(5, r.first)
        assert.equals(6, r.last)
    end)
end)
```

- [x] **Step 2: Run and watch the new block fail**

- [x] **Step 3: Implement**

```lua
--- Section owned by the heading on `row`, through the line before the next
--- heading of equal or higher rank (level number <= this one), bounded.
local function section_range(lines, row, bounds)
    local level = heading.level(lines[row])
    if not level then
        return nil
    end
    local hi = (bounds and bounds.last) or #lines
    local last = row
    for i = row + 1, hi do
        local other = heading.level(lines[i])
        if other and other <= level then break end
        last = i
    end
    return { kind = "section", first = row, last = last }
end
```

Wire ahead of the paragraph fallback. For `inner`: `first = first + 1`, then `trim_trailing_blanks`; return `nil` if `first > last` (heading with no body).

- [x] **Step 4: Run and watch it pass** — 7 successes.

- [x] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262 M1: entity_range: section case"
```

### Task 5: `entity_range` — question case and precedence

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

Build fixtures with the real parser, as `tests/unit/chat_parser_section_lines_spec.lua` does, so the test breaks if the parser's shape moves.

- [x] **Step 1: Write the failing tests**

```lua
local chat_parser = require("parley.chat_parser")
local exchange_clipboard = require("parley.exchange_clipboard")

local function parse(lines)
    return chat_parser.parse_chat(lines, chat_parser.find_header_end(lines))
end

describe("entity_range question", function()
    local lines = {
        "# topic: t",     -- 1
        "- file: t.md",   -- 2
        "---",            -- 3
        "",               -- 4
        "@@tag@@",        -- 5
        "💬: first q",    -- 6
        "",               -- 7
        "🤖: [A]",        -- 8
        "answer para",    -- 9
        "",               -- 10
        "## In answer",   -- 11
        "under heading",  -- 12
        "",               -- 13
        "💬: second q",   -- 14
        "",               -- 15
        "🤖: [A]",        -- 16
        "second answer",  -- 17
    }
    local parsed = parse(lines)

    it("takes the whole exchange from the question line", function()
        local r = entity_range.range(parsed, lines, 6)
        local es, ee = exchange_clipboard.get_exchange_line_range(parsed, 1, #lines)
        assert.equals("question", r.kind)
        assert.equals(es, r.first)   -- 5, the @@tag@@ preface
        assert.equals(ee, r.last)    -- 13
    end)

    it("takes the whole exchange from the preface line", function()
        local r = entity_range.range(parsed, lines, 5)
        assert.equals("question", r.kind)
        assert.equals(5, r.first)
    end)

    it("takes a paragraph inside an answer, clamped to the exchange", function()
        local r = entity_range.range(parsed, lines, 9)
        assert.equals("paragraph", r.kind)
        assert.equals(9, r.first)
        assert.equals(10, r.last)    -- never reaches 14
    end)

    it("takes a section inside an answer, clamped to the exchange", function()
        local r = entity_range.range(parsed, lines, 11)
        assert.equals("section", r.kind)
        assert.equals(11, r.first)
        assert.equals(13, r.last)    -- stops at the exchange bound, not EOF
    end)

    it("inner question drops the answer", function()
        local r = entity_range.range(parsed, lines, 6, { inner = true })
        assert.equals(5, r.first)
        assert.equals(6, r.last)     -- preface + question, no answer
    end)

    it("never returns a question kind in the header", function()
        local r = entity_range.range(parsed, lines, 1)
        assert.is_true(r == nil or r.kind ~= "question")
    end)
end)
```

- [x] **Step 2: Run and watch them fail**

- [x] **Step 3: Implement the dispatch**

```lua
local exchange_clipboard = require("parley.exchange_clipboard")
local question_tags = require("parley.question_tags")

--- Exchange index + its span for `row`. ONE span definition (rule 1):
--- get_exchange_line_range. find_exchange_at_line bounds at answer.line_end,
--- so a row in the trailing gap needs the fallback scan or it escapes into an
--- unbounded walk.
local function exchange_at(parsed, lines, row)
    if not parsed or not parsed.exchanges then return nil end
    local idx = require("parley.chat_parser").find_exchange_at_line(parsed, row)
    if not idx then
        for i in ipairs(parsed.exchanges) do
            local s, e = exchange_clipboard.get_exchange_line_range(parsed, i, #lines)
            if s and row >= s and row <= e then idx = i break end
        end
    end
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

`M.range`: resolve exchange + bounds → on the question anchor, return the whole span (`inner` → through `question.line_end`) → else `section_range(lines,row,bounds)` → else `paragraph_range(lines,row,bounds,prefixes)`. Every guard returns `nil`, never a partial range.

- [x] **Step 4: Run and watch them pass** — 6 successes.

- [x] **Step 5: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262 M1: entity_range: question case and precedence"
```

### Task 6: `entity_range` — `scope = "to_end"` and the 📝 edge trim

**Files:**
- Modify: `lua/parley/entity_range.lua`
- Test: `tests/unit/entity_range_spec.lua`

- [x] **Step 1: Write the failing tests** — the arithmetic is worked out here; do not re-derive it.

```lua
describe("entity_range to_end", function()
    local lines = {
        "# topic: t",     -- 1
        "- file: t.md",   -- 2
        "---",            -- 3
        "",               -- 4
        "💬: q one",      -- 5
        "",               -- 6
        "🤖: [A]",        -- 7
        "para one",       -- 8
        "",               -- 9
        "para two",       -- 10
        "",               -- 11
        "📝: summary",    -- 12
        "",               -- 13
        "💬: q two",      -- 14
        "",               -- 15
        "🤖: [A]",        -- 16
        "tail",           -- 17
    }
    local parsed = parse(lines)
    -- exchange 1 span is 5..13; its summary is line 12.

    it("runs from the paragraph start to the summary edge", function()
        local r = entity_range.range(parsed, lines, 8, { scope = "to_end" })
        assert.equals(8, r.first)
        assert.equals(11, r.last)   -- exchange end 13, trimmed to 12-1
    end)

    it("never crosses the next question", function()
        local r = entity_range.range(parsed, lines, 10, { scope = "to_end" })
        assert.equals(10, r.first)
        assert.is_true(r.last < 14)
    end)

    it("degenerates to the whole exchange on the question line", function()
        local a = entity_range.range(parsed, lines, 5, { scope = "to_end" })
        local b = entity_range.range(parsed, lines, 5)
        assert.same(b, a)
        assert.equals(13, a.last)   -- question kind keeps its summary
    end)

    it("does not invert when the cursor is on the summary line", function()
        local r = entity_range.range(parsed, lines, 12, { scope = "to_end" })
        assert.is_true(r == nil or r.first <= r.last)
        if r then assert.is_true(r.first >= 12) end
    end)

    it("takes an interior summary with the range", function()
        local mid = {
            "# topic: t", "- file: t.md", "---", "",
            "💬: q",          -- 5
            "", "🤖: [A]",    -- 6,7
            "para A",         -- 8
            "📝: summary",    -- 9  (interior: content follows)
            "para B",         -- 10
        }
        local p2 = parse(mid)
        local r = entity_range.range(p2, mid, 8, { scope = "to_end" })
        assert.is_true(r.last >= 10)   -- summary deleted with the rest
    end)

    it("falls back to the section, then EOF, outside any exchange", function()
        local plain = { "# A", "body", "", "## B", "more" }
        local r = entity_range.range(nil, plain, 2, { scope = "to_end" })
        assert.equals(2, r.first)
        assert.equals(3, r.last)   -- clamped by ## B at 4
    end)
end)
```

- [x] **Step 2: Run and watch them fail**

- [x] **Step 3: Implement**

`scope = "to_end"`: take the entity's `first`, set `last` to the exchange bound (or enclosing section end, else `#lines`), then apply rule 5's summary trim. Order matters — **absorb first, trim second**:

```lua
local function summary_trim(range, parsed, idx, lines)
    if not idx or range.kind == "question" then return range end
    local summary = parsed.exchanges[idx].summary
    if not summary or not summary.line then return range end
    local sl = summary.line
    -- Edge trim only: the summary must be strictly inside the range (so the
    -- range cannot invert when the cursor is ON it) and everything after it
    -- in the range must be blank (so an interior summary is NOT skipped).
    if sl <= range.first or sl > range.last then return range end
    for i = sl + 1, range.last do
        if not is_blank(lines[i]) then return range end
    end
    range.last = sl - 1
    return range
end
```

- [x] **Step 4: Run and watch them pass** — 6 successes.

- [x] **Step 5: Run the whole unit suite**

```sh
make test-unit 2>&1 | tail -20
```
Expected: no new failures.

- [x] **Step 6: Commit**

```bash
git add lua/parley/entity_range.lua tests/unit/entity_range_spec.lua
git commit -m "#262 M1: entity_range: to_end scope and the summary edge trim"
```

### Task 7: Adversarial properties over arbitrary transcript text

**Files:**
- Test: `tests/unit/entity_range_spec.lua`

The input is hand-edited transcript text, so the invariants matter more than any one case (ARCH-SECURE).

- [x] **Step 1: Write the property test**

```lua
describe("entity_range invariants", function()
    local CORPUS = {
        {}, { "" }, { "   " }, { "# only" }, { "💬: q" },
        { "# topic: t", "- file: t.md", "---" },
        { "# topic: t", "- file: t.md", "---", "", "💬: q" },
        { "# topic: t", "- file: t.md", "---", "", "💬: q", "🤖: [A]", "a", "📝: s" },
        { "```", "# fenced heading", "```" },
        { "#### deep", "body" },
    }

    it("never returns an out-of-range or inverted range", function()
        for _, lines in ipairs(CORPUS) do
            local ok, parsed = pcall(parse, lines)
            if not ok then parsed = nil end
            for row = 0, #lines + 2 do
                for _, scope in ipairs({ "entity", "to_end" }) do
                    for _, inner in ipairs({ false, true }) do
                        local got = entity_range.range(parsed, lines, row,
                            { scope = scope, inner = inner })
                        if got then
                            assert.is_true(got.first >= 1, "first >= 1")
                            assert.is_true(got.last <= #lines, "last <= #lines")
                            assert.is_true(got.first <= got.last, "first <= last")
                        end
                    end
                end
            end
        end
    end)
end)
```

- [x] **Step 2: Run it.** Expected: PASS. Any failure is a real defect — fix `entity_range`, never the assertion.

- [x] **Step 3: Decide the fenced-heading case — RESOLVED by wiring the memo** (M2 review BR-21 forced it). A fence line is now a wall in `is_wall`, and `highlight_structure.code_block_memo` suppresses `section_range` inside a fenced block, matching `outline.lua`'s in-code guard's existing ruling. Without both, `dae` left an unterminated fence and every following line of the transcript rendered as code.

- [x] **Step 4: Commit**

### Task 8: Fold `outline.lua` onto the shared dialect

**Files:**
- Modify: `lua/parley/outline.lua`'s heading branch

Not a drop-in: the branch is gated on `not opts.is_chat`, and each level returns a **different indent** (`"      "`, `"    "`, `"  "` for `###`/`##`/`#`). The replacement is `heading.level(line)` plus whatever reproduces that ladder exactly — **keeping the `is_chat` gate**.

Worth noting while you are here: `outline` deliberately does *not* treat headings as structure in chat buffers, while `entity_range` does. That is the precedence deviation showing up a second time, and it is intended — outline is a navigation projection, the text object is an editing one.

- [x] **Step 1: Read `outline.lua`'s `is_outline_item`** and write down the current (level → indent) mapping.
- [x] **Step 2: Replace the three-branch `if`** with the shared dialect, preserving gate and indents.
- [x] **Step 3: Run the outline specs**

```sh
ls tests/unit/*outline* tests/integration/*outline* 2>/dev/null
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/outline_spec.lua" -c "qa!"
```
Expected: PASS, behavior unchanged.

- [x] **Step 4: Commit**

### Task 9: Close M1

- [x] **Step 1: Run the full suite**

```sh
make test 2>&1 | tail -30
```

- [x] **Step 2: Update `## Log`** with the range contract as built and anything the conformance test surfaced.

- [x] **Step 3: Close the milestone** — this auto-dispatches the mandatory fresh-context review (AGENTS.md §3; do **not** separately run `superpowers-requesting-code-review`).

```bash
sdlc milestone-close --issue 262 --milestone M1
```
Fix Critical/Important before crossing into M2, then log the `Review-Verdict:` outcome.

---

## Chunk 2: M2 — the surface

### Task 10: The text object

**Files:**
- Create: `lua/parley/entity_textobj.lua`
- Test: `tests/integration/entity_textobj_spec.lua`

**Two editor-state hazards, both verified by execution, both invisible to the obvious test.** Get these wrong and the feature looks fine in a spec and is broken in the editor:

1. **`x`-mode keeps the anchor.** `V` inside an existing visual selection moves only the cursor end, so `vae` with the cursor on line 1 and a range of 2–4 selects **1–4**. Stock `vip` resets both ends; `normal! 2GV4G` does not. Leave visual mode first. The repo already uses this idiom at `chat_exchange_cut`.
2. **`G` cannot enter a closed fold.** It snaps to the fold's first line, silently widening the range — verified: range 2–4 with a closed fold over 1–3 deleted **1–4**. This is not hypothetical: `prep_chat` calls `tool_folds.setup(buf)` (`prep_chat`), so 🔧/📎 blocks are closed folds in ordinary use. Clear `foldenable` for the selection and restore it.

- [x] **Step 1: Write the failing test** — real buffer, real keymaps, assert buffer contents after `normal dae` / `normal daE` / `normal die` / `normal vae` + `d`, **and the same set in a buffer with a closed fold**. Use the `prepped_chat()` idiom from `tests/integration/keybinding_agreement_spec.lua:99-126`; `D.attach(buf, {schedule=false})` before any edit.

- [x] **Step 2: Run and watch it fail**

- [x] **Step 3: Implement**

```lua
local M = {}

--- Select the entity at the cursor as a linewise visual range, so every
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
    -- x-mode: an existing visual selection keeps its anchor through V, so
    -- leave it first or the range starts wherever the user did.
    if vim.fn.mode():match("^[vV\22]") then
        vim.cmd("normal! \27")
    end
    -- G snaps out of a closed fold, silently widening the range. tool_folds
    -- closes 🔧/📎 blocks in every prepped chat buffer, so this is the
    -- ordinary case, not an edge one.
    local foldenable = vim.wo.foldenable
    vim.wo.foldenable = false
    local ok, err = pcall(vim.cmd, ("normal! %dGV%dG"):format(r.first, r.last))
    vim.wo.foldenable = foldenable
    if not ok then error(err) end
end

return M
```

`M.parsed_for(buf, lines)` gates on the cheap `_parley_bufs[buf] == "chat"` latch — not `not_chat`, which is documented as sitting on keystroke paths — then `find_header_end` + `parse_chat`, returning `nil` for markdown buffers so the same objects work there with only the section and paragraph kinds.

- [x] **Step 4: Run and watch it pass**, including the folded and `vae` cases.

- [x] **Step 5: Commit**

### Task 11: Commands, registry entries, and the mode-set widening

**Files:**
- Modify: `lua/parley/init.lua` (`M.cmd.DeleteEntity`, `M.cmd.DeleteToEnd`; callbacks in `prep_chat` ~`:2775-2820`)
- Modify: `lua/parley/keybinding_registry.lua` (`M.entries`)
- Modify: `lua/parley/config.lua`
- Modify: the `MODES` constant in `tests/integration/keybinding_agreement_spec.lua`
- Test: `tests/integration/entity_textobj_spec.lua` (the refusal + surface cases land here)

**Scope: `parley_buffer`, not `chat` + `markdown`.** The registry already has a `parley_buffer` scope (11 entries — `open_file`, `outline`, `resolve_ref_gf`, …) that installs on chat *and* markdown from **one** entry. That is five entries and five config keys, not ten. The `chat_shortcut_delete` / `chat_shortcut_delete_file` split precedent does **not** apply — that split exists because those two do genuinely different things in the two scopes.

**Chords, with the collision check actually done.** `<C-g>e` is rejected: `<C-g>em` and `<C-g>eh` are export-markdown and export-html, so `<C-g>e` is a live prefix and binding it would delay them. Use **`<C-g>k`** (delete entity, "kill") and **`<C-g>K`** (delete to end of question); neither appears in the registry or in `native_overrides`. Text objects are `ae` / `ie` / `aE`, all unclaimed in every scope.

- [x] **Step 1: Add the five registry entries** with `config.lua` twins whose `modes` match `default_modes` **exactly** (`tests/unit/keybindings_spec.lua:415-445` fails otherwise; `:447-473` requires entries sharing a `config_key` to declare identical defaults).

```lua
{
    id = "entity_object_outer",
    config_key = "chat_shortcut_entity_object_outer",
    default_key = "ae",
    default_modes = { "o", "x" },
    scope = "parley_buffer",
    desc = "Parley: entity text object",
    help_desc = "Text object: entity at cursor (dae, yae, cae)",
    buffer_local = true,
},
```
…and the same shape for `entity_object_inner` (`ie`, `{o,x}`), `entity_object_to_end` (`aE`, `{o,x}`), `entity_delete` (`<C-g>k`, `{n}`), `entity_delete_to_end` (`<C-g>K`, `{n}`).

- [x] **Step 2: Widen the agreement spec's mode set** — the `MODES` constant in `tests/integration/keybinding_agreement_spec.lua`:

```lua
local MODES = { "n", "i", "v", "x", "o" }
```
Without this the new `o` maps sit outside both the leak and ghost guards. Run it: a failure means a mode leaked elsewhere, which is a real finding, not noise to suppress.

- [x] **Step 3: Add the command handlers.** `ExchangeCut`'s preamble verbatim (), then:

```lua
local r = require("parley.entity_range").range(parsed_chat, lines, cursor_line, opts)
if not r then
    M.logger.warning("DeleteEntity: no entity at cursor")
    return
end
require("parley.buffer_edit").replace_user_lines(buf, r.first - 1, r.last, false, {})
```

The index convention is confirmed against `buffer_edit.replace_user_lines`'s existing callers: `first` is 0-based, `last` is exclusive, `{}` deletes. Going through `buffer_edit` is a design choice for document provenance and the streaming-refusal contract — note that `init.lua` *is* on `buffer_mutation_spec.lua`'s allow-list's allow-list, so no test will catch a regression to raw `nvim_buf_set_lines` here.

- [x] **Step 4: Test the refusal path** — a delete attempted while the document withholds the grant must raise (`buffer_edit.replace_user_lines`) rather than silently corrupting the transcript (ARCH-ORDER).

- [x] **Step 5: Run the keybinding and arch suites**

```sh
make test-unit 2>&1 | tail -20
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/keybinding_agreement_spec.lua" -c "qa!"
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/arch/single_source_sweeps_spec.lua" -c "qa!"
```

- [x] **Step 6: Commit**

### Task 12: Route the new specs in `atlas/traceability.yaml`

**Files:**
- Modify: `atlas/traceability.yaml`

`tests/arch/single_source_sweeps_spec.lua:676` ("every spec this branch ADDED is routed somewhere") fails on an `NNNNNN-`-named branch — which `sdlc change-code` creates — when a new `*_spec.lua` is not listed. This plan adds six. Skip this and the arch suite goes red with a message that looks unrelated to your change.

- [x] **Step 1: List the added specs** — `markdown_heading_spec`, `markdown_heading_conformance_spec`, `entity_range_spec`, `entity_textobj_spec`, `entity_delete_parity_spec`. (Five, not six: the planned `entity_delete_spec` was folded into `entity_textobj_spec` rather than split.)
- [x] **Step 2: Add them under a feature key** (new: `chat/entity_delete`), following the file's existing shape.
- [x] **Step 3: Run the sweep** and confirm green.
- [x] **Step 4: Commit**

### Task 13: Parity and the performance measurement

**Files:**
- Test: `tests/integration/entity_delete_parity_spec.lua`
- ~~Create: `tests/perf/entity_range.lua`~~ — dropped, see the note in Step 3

- [x] **Step 1: Write the parity test — in a buffer with a closed fold.** This is the plan's best guard and, written naively on a flat quiescent buffer, it would have caught none of the three critical findings that review surfaced.

```lua
for row = header_end + 1, #fixture do
    local a = apply_native(fixture, row, "dae")      -- folds closed
    local b = apply_command(fixture, row, "ParleyDeleteEntity")
    assert.same(a, b, ("surfaces diverge at row %d"):format(row))
end
```
Cover `dae`/`ParleyDeleteEntity`, `daE`/`ParleyDeleteToEnd`, and the `vae`-then-`d` path. Scope the claim in a comment: parity holds on a **quiescent** document — the programmatic path inherits the streaming refusal and the native operator does not (ARCH-ORDER).

- [x] **Step 2: Run it and watch it pass.** A failure here is exactly the divergence the two-surface design exists to prevent; do not loosen the assertion.

**Perf module: dropped, measured instead (operator call, 2026-09-16).** The
question was whether a whole-buffer re-parse per invocation is affordable.
Measured rather than argued: 13.6 ms on the largest real transcript on this
machine (2 497 lines), 24.7 ms at 5 000, 97.8 ms at 20 000. Comfortable at
ordinary sizes, linear beyond them. A standing perf module and a `make perf`
target were not worth carrying for that; the numbers and the
`document.exchange(doc, row)` escape hatch are recorded in
`atlas/chat/entity_delete.md` instead.

- [x] **Step 6: Commit**

### Task 14: Documentation

**Files:**
- Create: `atlas/chat/entity_delete.md`
- Modify: `atlas/index.md`, `atlas/ui/keybindings.md`, `README.md`

`workshop/lessons.md:448-453,613` records this doc gate being violated twice — a new key absent from `atlas/ui/keybindings.md` **and** the README is a review finding.

- [x] **Step 1: Write the atlas page** — the three objects, two hotkeys, the precedence table, the 📝 edge-trim rule, the three-level heading dialect, and the markdown-vs-chat difference (no question kind outside a chat).
- [x] **Step 2: State the count behavior** — `2dae` behaves as `dae`; counts are ignored in this cut. Verified. Say it rather than letting the docs imply otherwise.
- [x] **Step 3: Grep the README** for the new keys and add them.
- [x] **Step 4: Verify `:ParleyKeyBindings` renders the new entries** — it reads the registry, so this checks `help_desc` and scope.
- [x] **Step 5: Commit**

### Task 15: Close the issue

- [x] **Step 1: Run everything**

```sh
make test 2>&1 | tail -30
```

- [x] **Step 2: Manual smoke** in a real chat transcript with tool folds present: `dae` on a 💬: line, on a heading, on a paragraph; `daE` from mid-answer; `vae` from a *different* starting line; `u` restores each in one step; `yae` then `p` round-trips.

- [x] **Step 3: Close**

```bash
sdlc milestone-close --issue 262 --milestone M2
sdlc close --issue 262 --verified '<what you ran and saw>'
```
`--actual` is measured, not typed — omit it and let the close measure and adopt the hours (AGENTS.md §5).

---

## Open items for the operator

1. **`ie` on a question** is "question without its answer" (Task 5 tests it). Say if you'd rather it mean "the answer without the question".
2. **Scope** — the objects install in markdown buffers too, via the `parley_buffer` scope, since the issue's Problem names markdown notes. Say if you want chat-only for the first cut.
3. ~~**Fenced headings**~~ — resolved during the M2 review: a fence is a wall, and a heading inside one is content, not a section.

---

## Revisions

### 2026-09-16 — M1 boundary review (REWORK → rework applied)

The plan file was written in one pass and then rewritten wholesale after the
plan-quality gate, so this is its first Revisions entry. Four deltas, all from
the M1 boundary review.

- **Header floor (Critical).** The Spec's section rule, applied literally, has
  no floor: `# topic:` is a valid level-1 heading that nothing outranks and
  there is no exchange above the first one to clamp against, so `dae` on line 1
  emptied the whole transcript, and `dae` on line 2 removed the `---` after
  which every later range silently lost its exchange clamp. Added rule 6 — the
  floor is `parsed.header_end + 1`, **derived from the parse rather than
  threaded through `opts`** (the review sketched an `opts.header_end`; deriving
  it means no caller can forget it, which is the same reason rule 1 has one
  span definition). The issue's `## Spec` and `## Done when` gained the
  corresponding sentence.
- **Unparsable-chat degradation (Important).** `parsed_for` collapsed "not a
  chat" and "a chat that will not parse" into one `nil`, so a mid-edit header
  silently switched the buffer to unclamped markdown semantics. It now returns
  a status and both surfaces refuse with a message.
- **ARCH-CONSTRAINTS budget missed and accepted.** Declared `< 16 ms @ 5 000
  lines`; measured 24.7 ms (17.0 ms best-of-5 independently). The operator's
  call was that perf is not a concern for this command, on the basis that the
  largest real transcript on this machine is 2 497 lines where the cost is
  13.6 ms / 8.5 ms — under a frame. Recorded as an accepted deviation with the
  numbers and the `document.exchange` escape hatch in
  `atlas/chat/entity_delete.md`, rather than quietly restating the budget.
- **The heading-dialect sweep left a consumer behind (ARCH-DRY).** `outline.lua`
  has two heading paths; the Core-concepts table named only the line-based one
  at `:52-60`. The token-based path at `:254` still hand-restated the cap
  (`token.heading_level <= 3`) and now reads `<= markdown_heading.MAX_LEVEL`.
  Noted for whoever widens the dialect to six levels: `exporter.lua`
  maps `^## `/`^### ` independently too, and belongs in that enumeration.

### 2026-09-16 — M1 boundary review round 2 (REWORK → reworked)

Round 1's header floor was the *site*, not the class — the same failure the
round-1 review named, repeated.

- **The floor was gated on classification (Critical).** It read
  `parsed.header_end`, and `parsed` is nil whenever `not_chat` rejects the
  buffer — which it does for five reasons unrelated to document shape (name not
  timestamped, under five lines, no `topic` header…). A transcript saved under
  a non-timestamped name is classified markdown, still gets the text object
  installed, and had no floor: `dae` on line 1 destroyed it. The floor is now
  derived from the **document's own shape** via a new pure
  `chat_parser.transcript_header_end(lines)` — a strict sibling of
  `find_header_end`, which returns the first `---` anywhere and would have
  floored a thematic break in a genuine note.
- **The refusal was half-applied (Critical).** The command's unparsable-header
  guard sat inside `if not reason then`, so it was unreachable exactly when
  needed, and the two surfaces answered "is this a chat?" differently. Both now
  go through one classifier (`entity_textobj.parsed_for`).
- **Parity varied only the cursor row (Important).** It now sweeps both
  document shapes — chat-classified and markdown-classified — which is where
  the divergence above lived.
- **The streaming refusal is tested (Important).** Scoped honestly: it asserts
  the command *propagates* a refusal and leaves the buffer intact, injected at
  the `buffer_edit` seam, because holding an overlapping user capture does not
  reproduce it (the document permits concurrent user regions) and staging a
  live generation is heavier than the claim needs. The document's own refusal
  logic stays `document_user_guards_spec`'s.

### 2026-09-16 — M2 boundary review (four rounds)

The plan body was edited repeatedly during the M2 review without recording the
deltas; this entry is that record.

- **Code fences became a first-class wall.** The paragraph walk stopped at
  blanks, headings and structural markers but not fences, so `dae` on an opener
  left a bare closer and the rest of the transcript rendered as code. Resolved
  Task 7 Step 3's open question in the process: a heading inside a fence is
  content, matching `outline.lua`'s in-code guard.
- **One fence predicate.** The first cut used `lexical.is_fence_delim` for the wall and
  `code_block_memo` for the in-block test; they recognise different fences, so
  `~~~` still broke. Both now use `lexical.is_fence_delim`.
- **`in_code` gates every heading read**, not just the dispatch — the forward
  scan in `section_range` and the `to_end` backward walk were still reading raw
  `heading.level`.
- **The parity spec was aborting**, not passing: nvim exited 1 partway through
  while printing Success lines for completed tests, and an earlier close
  recorded it as 11/11. It leaked ~500 buffers with a `parley.setup()` each.
  Setup runs once, each iteration releases its buffer, and results are read from
  the captured exit status.
- **Integration-points table** gained `starter_config.lua` + its spec, the only
  change affecting packaged-app users; stale `ExchangeCut` line refs corrected
  to `:4439`/`:4529`; the dropped `tests/perf/entity_range.lua` no longer named
  as a file to create.

### 2026-09-16 — close-gate rounds (BR-34, BR-37, partition-closed blocks)

- **The fence rule became a post-condition over the final range**, at
  `M.range`'s single exit, stating block **coverage** rather than delimiter
  parity — a range holding one block's closer and the next block's opener has
  even parity and splits both. It had also been placed after the question
  branch's early return, so whole-exchange ranges skipped it.
- **`confine_to_blocks` advanced `first` onto the closing delimiter** and
  deleted it, stranding the opener; it now advances past the closer.
- **It also over-reached**: `code_block_memo` resets at a 💬:/🤖: partition, so
  a block the next exchange closes is already whole. Pulling back there
  truncated a whole-exchange delete and stranded answer content. The pull-back
  now applies only when a fence delimiter closes the block beyond the range.
- **The fence guard gained an independent oracle.** The unit invariant computed
  its expectation from the same `code_block_memo`/`is_fence_delim` the guard
  uses, so it stayed 46/46 green with the stranded-opener bug reinstated. An
  integration oracle counting fence lines in the resulting buffer with a plain
  pattern caught it immediately.
