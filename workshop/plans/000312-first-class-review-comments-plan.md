# First-class review comments Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render `🤖` review markers compactly in every parley markdown/chat buffer (chain hidden behind `…`, anchor text highlighted) and open the chain in a focused float on `<CR>`, without changing a single byte of the file's grammar except the new single-line + `<br>` rule.

**Architecture:** One PURE layout function turns a line into marker view spans (hidden ranges with their conceal char, visible anchor range, or "broken"). The existing decoration provider (`highlighter.lua`, viewport-bounded, per-row cached) consumes it — so rendering costs nothing beyond what the per-line marker highlight already pays, and no new reparse loop exists. A small attach module sets `conceallevel`/`concealcursor`, snaps the normal-mode cursor out of hidden bytes, and dispatches `<CR>`. The float is a plain scratch buffer: PURE `thread.to_lines` / `thread.from_lines` convert marker ↔ one-turn-per-line, write-back replaces the marker span with a single re-encoded line.

**Tech Stack:** Lua, Neovim 0.11 extmarks (ephemeral `conceal`), plenary busted tests (`make test`, `make test-spec`).

---

## Decisions folded in (from the brainstorm, 2026-10-09)

- Display table (issue `## Spec`): `🤖[…]`, `🤖{…}`, `<X>` highlighted, `~D~` highlighted + strikethrough. Conceal-only — no virtual text: `🤖[H]{R}` keeps `🤖[` visible, conceals `H]{R` as `…` and the final `}` as `]`, yielding `🤖[…]`.
- **Single-line rule.** Rendered only when the marker closes on its own line. A `🤖` immediately followed by `<`/`[`/`{` that does not close on the line is painted `ParleyReviewBroken` (red undercurl) — the stateless, viewport-bounded "fail visible" signal. This covers both legacy #125 multi-line markers and a marker an edit just broke. The PARSER keeps #125's bounded multi-line tolerance (accept/reject and chat drill-in must still work on old documents); only *writers* and the *view* become single-line.
- **`<br>`** encodes a newline inside a turn. Decoded when a turn's text leaves the marker: float display, accept/reject result text, chat drill-in block formatting.
- **Edit protection** = normal-mode cursor snap + fail-visible. `concealcursor = "nc"`: normal mode keeps markers hidden even on the cursor line and the cursor can't rest inside hidden bytes, so normal-mode commands can't target them; insert/visual mode reveal the raw line (the conscious raw-edit escape hatch; also keeps `<M-q>` visual selection columns honest). A partial edit that breaks a marker shows raw + broken highlight; `u` restores. No undo-reverting guard (YAGNI; revisit if real corruption shows up).
- **Float**: plain nvim buffer, one turn per line in raw bracket form, human/robot line backgrounds, cursor in a trailing empty `[]`. No new actions; editing anything is allowed by convention. Write-back on `:w` / window close.
- **Alt+q on a multi-line visual selection** refuses with a warning (an anchor quote is prose; encoding prose newlines as `<br>` would reshape the document while it's under comment).
- Scope: every buffer `setup_markdown_keymaps` or `prep_chat` attaches (all parley markdown + chat).
- Grammar revision lands in ariadne (`construct/local/fix/review-convention.md`, the canonical source weaved into this repo) under its own ariadne issue — one issue, one repo branch.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `codec` (`encode`/`decode`) | `lua/parley/comment/codec.lua` | new |
| `view.layout` | `lua/parley/comment/view.lua` | new |
| `view.snap` | `lua/parley/comment/view.lua` | new |
| `view.marker_at` | `lua/parley/comment/view.lua` | new |
| `thread.to_lines` / `thread.from_lines` | `lua/parley/comment/thread.lua` | new |
| `drill_in.resolve` | `lua/parley/drill_in.lua` | modified (decodes `<br>`) |
| `drill_in.format_block` | `lua/parley/drill_in.lua` | modified (decodes `<br>`) |
| `compute_markdown_highlights` entries | `lua/parley/highlighter.lua` | modified (optional `conceal` field) |

- **codec** — `encode(text)`: `\r?\n` → `<br>`; `decode(text)`: `<br>` → `\n`. Tests in `tests/unit/comment_codec_spec.lua`.
  - **DRY rationale:** three consumers (float, resolve, drill-in gather) would otherwise each hand-roll the escape.
  - **Future extensions:** escaping a literal `<br>` if prose ever needs it (`<br\>`), one place.
- **view.layout(line) → markers** — for each `🤖` on the line, using `review._parse_marker_sections(line, pos, 4)` (no opts → single-text, the historical per-line behavior; a line has no `\n`, so "closes on this line" is exactly "parses"):
  `{ start, stop, kind = "bare"|"quoted"|"strike", visible = {s,e,hl}|nil, hidden = { {s,e,conceal}... } }` or `{ start, stop, broken = true }`. 0-based byte cols, `e` exclusive. Not a marker (plain `🤖`, `🤖:` chat prefix, `🤖` in inline code) → omitted. Tests in `tests/unit/comment_view_spec.lua`.
  - **Relationships:** 1 line : N markers; each marker 0–1 visible range, 1–3 hidden ranges.
  - **DRY rationale:** the single source of "what is hidden where" — consumed by the highlighter (conceal), the cursor snap, and the `<CR>` lookup. Section parsing stays in `review._parse_marker_sections` (no second parser).
  - **Future extensions:** a turn-count badge or per-kind conceal chars widen the `hidden` entries only.
- **view.snap(markers, prev_col, col) → col|nil** — if `col` lies strictly inside a hidden range (not at its first byte), return the range edge in the direction of travel (`col > prev_col` → `e`, clamped to line; else `s`); nil if no move.
- **view.marker_at(markers, col) → marker|nil** — the non-broken marker whose `[start, stop)` contains `col`.
- **thread.to_lines(marker) → lines, roles** — one entry per section: `"[" .. text .. "]"` or `"{" .. text .. "}"`, with `codec.decode` splitting multi-line turns into several float lines; appends an empty `"[]"`. `roles[i]` = `"user"|"agent"` per float line (for backgrounds). Tests in `tests/unit/comment_thread_spec.lua`.
- **thread.from_lines(prefix, lines) → raw|nil, err** — `prefix` is the marker's raw `🤖`, `🤖<X>`, or `🤖~D~`. Joins lines with `\n`, parses `"🤖" .. joined` with `_parse_marker_sections(..., { budget = #lines })`, rejects leftover non-blank text (unbalanced bracket → `err`), drops empty trailing `[]` sections, encodes each section's text, rebuilds the single line. Round-trip property: `from_lines(prefix, to_lines(m))` == original raw for any single-line marker.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| marker decoration (conceal) | `lua/parley/highlighter.lua` | modified | ephemeral extmarks in the decoration provider |
| `comment.attach` | `lua/parley/comment/init.lua` | new | window options, `CursorMoved` autocmd |
| `comment.open_thread` | `lua/parley/comment/float.lua` | new | floating window + scratch buffer, source-buffer write-back |
| `comment_open_thread` keybinding | `lua/parley/keybinding_registry.lua`, `lua/parley/init.lua` | new | buffer-local `<CR>` |
| `drill_in_visual` | `lua/parley/init.lua` | modified | refuses multi-line selection |

- **marker decoration** — `compute_markdown_highlights` replaces its inline marker loop with `view.layout`: visible range → `ParleyReviewQuoted`/`ParleyReviewStrike`, each hidden range → `{ conceal = c }` entry, broken → `ParleyReviewBroken` on `[start, stop)`. `on_line` passes `conceal` through to `nvim_buf_set_extmark(..., { ephemeral = true, conceal = c })`. Viewport-bounded and cached per (window, document) — the existing incremental machinery; nothing whole-buffer.
- **comment.attach(buf)** — called from `setup_markdown_keymaps` and `prep_chat` (replacing chat's `concealcursor = ""`). Sets `conceallevel=2`, `concealcursor="nc"` (window-local, like chat today); one buffer-local `CursorMoved` autocmd: cursor line → `view.layout` → `view.snap` with the window's previous col → `nvim_win_set_cursor`. Cost: one line parse per cursor move. Creates nothing durable (autocmd dies with the buffer; prev-col table keyed by window, cleared on `WinClosed`).
- **comment.open_thread(buf)** — `view.marker_at` on the cursor line; none → return false (caller feeds a native `<CR>`). Else: tracking extmark on the marker's start; scratch buffer (`buftype=acwrite`, `bufhidden=wipe`, `filetype=markdown`, `wrap`, `linebreak`), float sized to content (max 80% editor), title = quoted/struck anchor (truncated) or `free-standing`; `line_hl_group` extmarks `ParleyCommentUser` / `ParleyCommentAgent` per `roles`; cursor between the final `[]`. `BufWriteCmd` and `WinClosed` → write-back: re-read the source line at the extmark, require the original raw bytes still at that col (else warn "marker changed underneath — reply kept in register `\"`", yank the float text), `thread.from_lines`, on `err` warn and keep the float open, on success `buffer_edit.replace_user_lines` for that one row. Creates nothing durable: buffer wiped on close, extmark deleted in write-back.
- **keybinding** — registry entry `comment_open_thread`, `<CR>`, mode `n`, scope `parley_buffer`, `buffer_local`. Callback: `if not open_thread(buf) then feedkeys(count .. <CR>, "n") end`.

## ARCH notes

- ARCH-DRY: section parsing single-sourced in `review._parse_marker_sections`; hidden/visible geometry single-sourced in `view.layout` (highlighter, snap, `<CR>` all read it).
- ARCH-FUNERAL: no durable artifacts — float buffer wiped, tracking extmark deleted on write-back, autocmds buffer-scoped, prev-col table cleared on `WinClosed`.
- Performance: no new parse pass; the decoration provider is already viewport-bounded with a 256-row redraw budget.

---

## Chunk 1: M1 — compact rendering + cursor snap

### Task 1: codec

**Files:** Create `lua/parley/comment/codec.lua`, `tests/unit/comment_codec_spec.lua`

- [ ] **Step 1: failing test**

```lua
local codec = require("parley.comment.codec")
describe("comment.codec", function()
    it("encodes newlines as <br>", function()
        assert.equals("a<br>b<br>c", codec.encode("a\nb\r\nc"))
    end)
    it("decodes <br> to newlines", function()
        assert.equals("a\nb", codec.decode("a<br>b"))
    end)
    it("round-trips", function()
        local s = "line one\nline two\n\nend"
        assert.equals(s, codec.decode(codec.encode(s)))
    end)
    it("leaves single-line text alone", function()
        assert.equals("plain", codec.encode("plain"))
        assert.equals("plain", codec.decode("plain"))
    end)
end)
```

- [ ] **Step 2:** `make test-spec SPEC=...` is mapping-driven; run directly: `nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/comment_codec_spec.lua"` → FAIL (module not found).
- [ ] **Step 3: implement**

```lua
-- comment/codec.lua — newline escape for single-line 🤖 markers (#312).
-- A marker never spans lines in the file; a newline inside a turn is `<br>`.
local M = {}
function M.encode(text) return (text:gsub("\r?\n", "<br>")) end
function M.decode(text) return (text:gsub("<br>", "\n")) end
return M
```

- [ ] **Step 4:** re-run → PASS. **Step 5:** `git commit -m "#312 M1: comment codec for <br> newlines" -- lua/parley/comment/codec.lua tests/unit/comment_codec_spec.lua`

### Task 2: view.layout

**Files:** Create `lua/parley/comment/view.lua`, `tests/unit/comment_view_spec.lua`

- [ ] **Step 1: failing tests** — one per display-table row plus edges. Helper renders the line as the eye sees it:

```lua
local view = require("parley.comment.view")

-- Apply hidden ranges (conceal chars) to show what the user sees.
local function shown(line)
    local out, i = {}, 0
    local cuts = {}
    for _, m in ipairs(view.layout(line)) do
        for _, h in ipairs(m.hidden or {}) do cuts[#cuts + 1] = h end
    end
    table.sort(cuts, function(a, b) return a[1] < b[1] end)
    for _, h in ipairs(cuts) do
        out[#out + 1] = line:sub(i + 1, h[1]) .. h[3]
        i = h[2]
    end
    out[#out + 1] = line:sub(i + 1)
    return table.concat(out)
end

describe("comment.view.layout", function()
    it("bare human chain shows 🤖[…]", function()
        assert.equals("see 🤖[…] here", shown("see 🤖[why?]{because}[ok] here"))
    end)
    it("single human turn shows 🤖[…]", function()
        assert.equals("🤖[…]", shown("🤖[why?]"))
    end)
    it("empty 🤖[] stays as typed", function()
        assert.equals("🤖[]", shown("🤖[]"))
    end)
    it("bare robot proposal shows 🤖{…}", function()
        assert.equals("a 🤖{…} b", shown("a 🤖{insert this}[hm] b"))
    end)
    it("quoted shows only X, highlighted", function()
        local line = "the 🤖<quick fox>[too cute]{agree} jumps"
        assert.equals("the quick fox jumps", shown(line))
        local m = view.layout(line)[1]
        assert.equals("quoted", m.kind)
        assert.equals("quick fox", line:sub(m.visible[1] + 1, m.visible[2]))
        assert.equals("ParleyReviewQuoted", m.visible[3])
    end)
    it("strike shows only D with strike highlight", function()
        local line = "x 🤖~old~{new} y"
        assert.equals("x old y", shown(line))
        assert.equals("ParleyReviewStrike", view.layout(line)[1].visible[3])
    end)
    it("an unclosed opener is broken, nothing hidden", function()
        local m = view.layout("start 🤖[never closed")[1]
        assert.is_true(m.broken)
        assert.is_nil(m.hidden)
    end)
    it("ignores 🤖: chat prefix and plain 🤖", function()
        assert.same({}, view.layout("🤖: hello 🤖 there"))
    end)
    it("ignores markers in inline code", function()
        assert.same({}, view.layout("use `🤖[x]` syntax"))
    end)
    it("handles two markers on one line", function()
        assert.equals("🤖[…] and A", shown("🤖[c1] and 🤖<A>[c2]"))
    end)
end)
```

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: implement** `view.layout`. Reuse the inline-code exclusion: `review` has a local `inline_code_ranges`; expose it as `M._inline_code_ranges` in `lua/parley/skills/review/init.lua` (and pass-through in `lua/parley/review.lua` like `_parse_marker_sections`) rather than copy it (ARCH-DRY). Core:

```lua
-- comment/view.lua — PURE geometry of 🤖 markers on one line (#312).
-- What is hidden (with which conceal char) and what stays visible.
local M = {}
local MARK, MARK_LEN = "🤖", 4
local OPENERS = { ["<"] = true, ["["] = true, ["{"] = true, ["~"] = true }

local function chain_hidden(line, first, stop)
    -- `first` = byte (1-based) of the first [ / {; stop = 1-based exclusive end.
    -- Keep the opener visible, hide the middle as …, render the last byte as
    -- the opener's closer so the chain reads 🤖[…] / 🤖{…}.
    local open = line:sub(first, first)
    local close = open == "[" and "]" or "}"
    if stop - first <= 2 then return {} end -- `[]` / `{}`: nothing to hide
    return {
        { first, stop - 2, "…" },   -- 0-based [first, stop-2): bytes after opener up to last
        { stop - 2, stop - 1, close },
    }
end

function M.layout(line)
    local review = require("parley.review")
    local parse = review._parse_marker_sections
    local excluded = review._inline_code_ranges(line)
    local function in_code(i)
        for _, r in ipairs(excluded) do if i >= r[1] and i <= r[2] then return true end end
        return false
    end
    local out, from = {}, 1
    while true do
        local pos = line:find(MARK, from, true)
        if not pos then break end
        local nxt = line:sub(pos + MARK_LEN, pos + MARK_LEN)
        if in_code(pos) or not OPENERS[nxt] then
            from = pos + MARK_LEN
        else
            local sections, stop, quoted, strike = parse(line, pos, MARK_LEN)
            local start0 = pos - 1
            if #sections == 0 and not quoted and not strike then
                if nxt ~= "~" then -- unmatched ~ is ordinary prose (~/path)
                    out[#out + 1] = { start = start0, stop = #line, broken = true }
                end
                from = pos + MARK_LEN
            else
                local stop0 = stop - 1 -- 0-based exclusive
                local m = { start = start0, stop = stop0 }
                local anchor = quoted or strike
                if anchor then
                    m.kind = quoted and "quoted" or "strike"
                    m.visible = { anchor.byte_start, anchor.byte_end - 1,
                        quoted and "ParleyReviewQuoted" or "ParleyReviewStrike" }
                    m.hidden = { { start0, anchor.byte_start, "" } }        -- 🤖< / 🤖~
                    m.hidden[2] = { anchor.byte_end - 1, stop0, "" }          -- >… / ~…
                else
                    m.kind = "bare"
                    m.hidden = chain_hidden(line, sections[1].byte_start, stop)
                end
                out[#out + 1] = m
                from = stop
            end
        end
    end
    return out
end
```

(Check the exact 0/1-based arithmetic against the tests; the tests are the contract.)

- [ ] **Step 4:** run → PASS. **Step 5:** commit `#312 M1: comment view layout`.

### Task 3: view.snap + view.marker_at

**Files:** Modify `lua/parley/comment/view.lua`, `tests/unit/comment_view_spec.lua`

- [ ] **Step 1: failing tests**

```lua
describe("comment.view.snap", function()
    local line = "ab 🤖<X>[c]{d} z"
    local ms = view.layout(line)
    local h1, h2 = ms[1].hidden[1], ms[1].hidden[2]
    it("moving right out of a hidden range jumps to its end", function()
        assert.equals(h2[2], view.snap(ms, h2[1], h2[1] + 1))
    end)
    it("moving left into a hidden range jumps to its start", function()
        assert.equals(h1[1], view.snap(ms, h1[2], h1[2] - 1))
    end)
    it("the first byte of a hidden range is a legal rest", function()
        assert.is_nil(view.snap(ms, 0, h1[1]))
    end)
    it("visible text never snaps", function()
        assert.is_nil(view.snap(ms, 0, 1))
    end)
end)
describe("comment.view.marker_at", function()
    local ms = view.layout("ab 🤖[c] z 🤖[x")
    it("finds the marker under the cursor", function()
        assert.equals(ms[1], view.marker_at(ms, ms[1].start))
    end)
    it("ignores prose and broken markers", function()
        assert.is_nil(view.marker_at(ms, 0))
        assert.is_nil(view.marker_at(ms, ms[2].start))
    end)
end)
```

- [ ] **Step 2:** FAIL. **Step 3:** implement:

```lua
function M.snap(markers, prev_col, col)
    for _, m in ipairs(markers) do
        for _, h in ipairs(m.hidden or {}) do
            if col > h[1] and col < h[2] then
                if col > prev_col then return h[2] end
                return h[1]
            end
        end
    end
    return nil
end

function M.marker_at(markers, col)
    for _, m in ipairs(markers) do
        if not m.broken and col >= m.start and col < m.stop then return m end
    end
    return nil
end
```

Note `h[2]` may equal `#line` (marker at EOL); the caller clamps to `#line - 1` in normal mode.

- [ ] **Step 4:** PASS. **Step 5:** commit `#312 M1: cursor snap + marker lookup`.

### Task 4: highlighter consumes view.layout (conceal)

**Files:** Modify `lua/parley/highlighter.lua` (marker loop ~L374–L410, `on_line` ~L1176), `lua/parley/highlighter.lua` `setup_highlights` (new groups), test `tests/unit/highlighter_spec.lua` (or `tests/integration/` if `compute_markdown_highlights` isn't reachable from a unit test — expose it as `M._compute_markdown_highlights` the way `M._scan_draft_blocks` is).

- [ ] **Step 1: failing test** — entries for `"x 🤖<A>[c] y"` include `{hl_group="ParleyReviewQuoted"}` over `A`, two `{conceal=""}` entries over `🤖<` and `>[c]`, and no `ParleyReviewUser` entry; `"🤖[open"` yields one `ParleyReviewBroken` entry; a chain inside a fenced block yields nothing (existing fence handling).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: implement** — replace the `while true do ... _parse_marker_sections ...` block with:

```lua
        -- #312: 🤖 markers render compactly — view.layout owns what is hidden.
        for _, m in ipairs(require("parley.comment.view").layout(line)) do
            result[row] = result[row] or {}
            if m.broken then
                table.insert(result[row], { hl_group = "ParleyReviewBroken",
                    col_start = m.start, col_end = m.stop })
            else
                if m.visible then
                    table.insert(result[row], { hl_group = m.visible[3],
                        col_start = m.visible[1], col_end = m.visible[2] })
                end
                for _, h in ipairs(m.hidden) do
                    table.insert(result[row], { conceal = h[3],
                        col_start = h[1], col_end = h[2] })
                end
            end
        end
```

In `on_line`'s non-draft branch add `conceal = hl.conceal` and only set `hl_group` when present. Define `ParleyReviewBroken` (link `DiagnosticUnderlineError`), `ParleyCommentUser` / `ParleyCommentAgent` (backgrounds derived from the existing `ParleyReviewUser` / `ParleyReviewAgent` colors) in `setup_highlights`. Keep `ParleyReviewUser`/`ParleyReviewAgent` defined — insert/visual mode reveal the raw line and should still color its sections: add their entries too (they're harmless under conceal), i.e. also emit the per-section `ParleyReviewUser/Agent` entries as before.

- [ ] **Step 4:** PASS; `make test` green (the existing highlighter/review specs must not regress).
- [ ] **Step 5:** commit `#312 M1: render markers compactly via conceal`.

### Task 5: comment.attach — window options + cursor snap

**Files:** Create `lua/parley/comment/init.lua`; modify `lua/parley/init.lua` (`setup_markdown_keymaps` ~L3056, `prep_chat` conceal block ~L2931); test `tests/integration/comment_attach_spec.lua`.

- [ ] **Step 1: failing integration test** — open a scratch markdown buffer through the same path the plugin uses (follow an existing integration spec that calls `setup_markdown_keymaps`), set line `"ab 🤖<X>[c] z"`, assert `vim.wo.conceallevel == 2` and `vim.wo.concealcursor == "nc"`; set cursor to `(1, 3)` (the `🤖` start, a legal rest), then `nvim_win_set_cursor(0, {1, 5})` and `vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })` → cursor col is the end of hidden range 1 (start of `X`).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: implement**

```lua
-- comment/init.lua — attach compact-marker behavior to a buffer (#312).
local view = require("parley.comment.view")
local M = {}
local prev_col = {} -- [winid] = last cursor col; cleared on WinClosed

function M.attach(buf)
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
    if vim.b[buf].parley_comment_attached then return end
    vim.b[buf].parley_comment_attached = true
    local group = vim.api.nvim_create_augroup("ParleyComment" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group, buffer = buf,
        callback = function()
            local win = vim.api.nvim_get_current_win()
            local row, col = unpack(vim.api.nvim_win_get_cursor(win))
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
            local to = line:find("🤖", 1, true) and view.snap(view.layout(line), prev_col[win] or 0, col)
            if to then
                to = math.min(to, math.max(#line - 1, 0))
                vim.api.nvim_win_set_cursor(win, { row, to })
                col = to
            end
            prev_col[win] = col
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(ev) prev_col[tonumber(ev.match)] = nil end,
    })
end
return M
```

The `line:find("🤖")` short-circuit keeps the common no-marker cursor move at one plain `find`. Call `require("parley.comment").attach(buf)` at the end of `setup_markdown_keymaps`; in `prep_chat` replace the `conceallevel`/`concealcursor` pair with the same call (comment the deliberate change: branch links now stay concealed on the cursor line in normal mode too, consistent with markers).

- [ ] **Step 4:** PASS + `make test`. **Step 5:** commit `#312 M1: attach conceal options and cursor snap`.

### Task 6: M1 manual check + boundary

- [ ] Manual (record in issue `## Log`): open a markdown file with each display-table form + a 3-line #125 marker; normal mode shows the compact forms, `l`/`h` jump over hidden bytes, `i` reveals the raw line, the multi-line marker shows the broken undercurl.
- [ ] Update `atlas/modes/review.md` + `atlas/ui/highlights.md` (new groups) for the rendering surface.
- [ ] `sdlc milestone-close --issue 312 --milestone M1`

## Chunk 2: M2 — thread float, writers, grammar

### Task 7: thread.to_lines / from_lines

**Files:** Create `lua/parley/comment/thread.lua`, `tests/unit/comment_thread_spec.lua`

- [ ] **Step 1: failing tests**

```lua
local thread = require("parley.comment.thread")
local view = require("parley.comment.view")
local drill_in = require("parley.drill_in")

local function marker(raw) return drill_in.parse(raw)[1] end

describe("comment.thread", function()
    it("lays out one turn per line with a trailing empty reply", function()
        local lines, roles = thread.to_lines(marker("🤖<X>[why]{because}"))
        assert.same({ "[why]", "{because}", "[]" }, lines)
        assert.same({ "user", "agent", "user" }, roles)
    end)
    it("splits <br> turns across float lines", function()
        local lines, roles = thread.to_lines(marker("🤖[a<br>b]"))
        assert.same({ "[a", "b]", "[]" }, lines)
        assert.same({ "user", "user", "user" }, roles)
    end)
    it("round-trips any single-line marker", function()
        for _, raw in ipairs({ "🤖[q]", "🤖<X>[q]{a}[q2]", "🤖~D~{N}", "🤖{p}[h]", "🤖[a<br>b]{c}" }) do
            local m = marker(raw)
            local prefix = raw:sub(1, (m.sections[1] and m.sections[1].byte_start or #raw + 1) - 1)
            assert.equals(raw, thread.from_lines(prefix, (thread.to_lines(m))))
        end
    end)
    it("appends a multi-line reply as one <br>-encoded turn", function()
        assert.equals("🤖<X>[q]{a}[line1<br>line2]",
            thread.from_lines("🤖<X>", { "[q]", "{a}", "[line1", "line2]" }))
    end)
    it("drops an empty trailing reply", function()
        assert.equals("🤖[q]", thread.from_lines("🤖", { "[q]", "[]" }))
    end)
    it("rejects unbalanced brackets", function()
        local raw, err = thread.from_lines("🤖", { "[q]", "[oops" })
        assert.is_nil(raw)
        assert.truthy(err)
    end)
end)
```

- [ ] **Step 2:** FAIL. **Step 3: implement**

```lua
-- comment/thread.lua — PURE marker ↔ float lines (#312). One turn per line in
-- raw bracket form; a <br> inside a turn becomes a real line break in the float.
local codec = require("parley.comment.codec")
local M = {}
local OPEN = { user = "[", agent = "{" }
local CLOSE = { user = "]", agent = "}" }

function M.to_lines(marker)
    local lines, roles = {}, {}
    local function add(kind, text)
        local parts = vim.split(OPEN[kind] .. codec.decode(text) .. CLOSE[kind], "\n", { plain = true })
        for _, p in ipairs(parts) do lines[#lines + 1] = p; roles[#roles + 1] = kind end
    end
    for _, s in ipairs(marker.sections) do add(s.type, s.text) end
    add("user", "")
    return lines, roles
end

function M.from_lines(prefix, lines)
    local parse = require("parley.review")._parse_marker_sections
    local rest = table.concat(lines, "\n")
    local sections = {}
    -- The parser's chain stops at the `\n` between float lines, so parse one
    -- adjacent run at a time, skipping the whitespace between turns.
    while true do
        rest = rest:gsub("^%s+", "")
        if rest == "" then break end
        local text = "🤖" .. rest
        local run, stop = parse(text, 1, 4, { budget = #lines })
        if #run == 0 then
            return nil, "unbalanced brackets in the thread — fix them before closing"
        end
        vim.list_extend(sections, run)
        rest = text:sub(stop)
    end
    while #sections > 0 and sections[#sections].text:match("^%s*$") do
        table.remove(sections)
    end
    local out = { prefix }
    for _, s in ipairs(sections) do
        out[#out + 1] = OPEN[s.type] .. codec.encode(s.text) .. CLOSE[s.type]
    end
    return table.concat(out)
end
return M
```

- [ ] **Step 4:** PASS. **Step 5:** commit `#312 M2: thread layout round-trip`.

### Task 8: float + write-back

**Files:** Create `lua/parley/comment/float.lua`; test `tests/integration/comment_float_spec.lua`

- [ ] **Step 1: failing integration tests**
  1. Buffer line `"see 🤖<X>[q]{a} end"`, cursor on `X`; `open_thread(buf)` → returns true, a float is current, its lines are `{ "[q]", "{a}", "[]" }`, cursor on row 3 col 1.
  2. Set float line 3 to `"[r1"` and append `"r2]"`, `:w` → source line is `"see 🤖<X>[q]{a}[r1<br>r2] end"`, other lines byte-identical.
  3. Open, close without edit (`:q`) → source buffer unchanged (`changedtick` unchanged).
  4. Open, then change the source line underneath, then `:q` with a reply → source untouched, warning logged, reply text in register `"`.
  5. Unbalanced `[oops` then `:w` → error notified, float still open, source unchanged.
  6. Cursor on prose → `open_thread` returns false.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: implement** per the Integration point description. Write-back core:

```lua
local function write_back(st)
    local pos = vim.api.nvim_buf_get_extmark_by_id(st.src, NS, st.mark, {})
    local row, col = pos[1], pos[2]
    local line = row and vim.api.nvim_buf_get_lines(st.src, row, row + 1, false)[1]
    if not line or line:sub(col + 1, col + #st.raw) ~= st.raw then
        vim.fn.setreg('"', table.concat(vim.api.nvim_buf_get_lines(st.float_buf, 0, -1, false), "\n"))
        return false, "marker changed underneath — thread text kept in register \""
    end
    local raw, err = thread.from_lines(st.prefix, vim.api.nvim_buf_get_lines(st.float_buf, 0, -1, false))
    if not raw then return false, err end
    if raw ~= st.raw then
        local new = line:sub(1, col) .. raw .. line:sub(col + #st.raw + 1)
        require("parley.buffer_edit").replace_user_lines(st.src, row, row + 1, false, { new })
        st.raw = raw
    end
    return true
end
```

`st.prefix` = `st.raw:sub(1, first_section_byte_start - 1)` (the `🤖`, `🤖<X>`, or `🤖~D~`). `BufWriteCmd` → write_back, notify error or `set nomodified`; `WinClosed` → write_back (error → notify; float is gone, so on error also copy to register), then delete the extmark. The "no edit → no write" case falls out of `raw ~= st.raw`.

- [ ] **Step 4:** PASS. **Step 5:** commit `#312 M2: thread float with single-line write-back`.

### Task 9: `<CR>` binding

**Files:** Modify `lua/parley/keybinding_registry.lua` (after `chat_reject_drill_in`), `lua/parley/config.lua` (`chat_shortcut_open_thread`), `lua/parley/init.lua` (`drill_in_callbacks` + both registration tables); test: extend `tests/integration/comment_float_spec.lua`.

- [ ] **Step 1: failing test** — `feedkeys("\r", "x")` on a marker opens the float; on prose the cursor moves down one line (native `<CR>` preserved); `3<CR>` on prose moves 3 lines.
- [ ] **Step 2:** FAIL. **Step 3: implement**

```lua
	{
		id = "comment_open_thread",
		config_key = "chat_shortcut_open_thread",
		default_key = "<CR>",
		default_modes = { "n" },
		scope = "parley_buffer",
		desc = "Parley open the 🤖 comment thread at cursor (native <CR> elsewhere)",
		help_desc = "Open comment thread",
		buffer_local = true,
	},
```

Callback in `drill_in_callbacks`:

```lua
		comment_open_thread = function()
			if not require("parley.comment.float").open_thread(buf) then
				local keys = (vim.v.count > 0 and tostring(vim.v.count) or "") .. "<CR>"
				vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
			end
		end,
```

Wire `comment_open_thread = drill_in_cbs.comment_open_thread` into both `register_buffer` tables. Check `atlas/ui/keybindings.md` + any keybinding-registry spec that enumerates entries.

- [ ] **Step 4:** PASS + `make test`. **Step 5:** commit `#312 M2: <CR> opens the comment thread`.

### Task 10: single-line writers + `<br>` decode on the way out

**Files:** Modify `lua/parley/init.lua` (`drill_in_visual` ~L1891), `lua/parley/drill_in.lua` (`resolve` ~L549, `format_block` ~L651); tests `tests/unit/drill_in_spec.lua`, integration spec for `<M-q>`.

- [ ] **Step 1: failing tests**
  - `drill_in.resolve(marker("🤖{a<br>b}"), "accept")` == `"a\nb"`; `🤖~D~{x<br>y}` accept → `"x\ny"`; `🤖<X>[q]` reject still `"X"`.
  - `format_block` of a gathered `🤖<Q>[u1<br>u2]` renders `u1` and `u2` on separate lines.
  - `<M-q>` over a two-line visual selection → buffer unchanged + warning; single-line selection still wraps.
- [ ] **Step 2:** FAIL. **Step 3:** wrap section/anchor text returned by `resolve` with `codec.decode` (anchor `X`/`D` too — a legacy multi-line quote never contains `<br>`, so this is safe); decode turn texts in `format_block`; in `drill_in_visual` return early with `M.logger.warning("🤖 markers are single-line — select within one line")` when `sr ~= er`. Accept/reject producing multi-line text already flows through `narrow_replace_range`.
- [ ] **Step 4:** PASS + `make test`. **Step 5:** commit `#312 M2: single-line marker writers, decode <br> on resolve`.

### Task 11: grammar revision (ariadne) + atlas + boundary

- [ ] In `../ariadne`: `sdlc issue new "review-convention: single-line markers + <br> newline escape"`, claim, and on its branch append to `construct/local/fix/review-convention.md`: §3 note "a marker is a single line; a newline inside a block is `<br>`", §5 note "accept/reject decode `<br>`", and a `## Revisions` entry (2026-10-09, parley #312). Land through ariadne's own flow; then re-weave parley's `.agents/skills/xx-fix/review-convention.md`. Record the ariadne issue ref in this issue's `## Log`. If ariadne's issue hasn't landed by M2 close, M2 still closes — the parley behavior is self-consistent; note the pending dep.
- [ ] Atlas: `atlas/modes/review.md` (float, `<CR>`, single-line rule, `<br>`), `atlas/ui/keybindings.md` (`<CR>`), `atlas/index.md` if a new file is added.
- [ ] Manual (record in `## Log`): reply in a float across two lines, close, confirm the file line has `<br>`; `<M-a>` on a `{…<br>…}` proposal inserts two lines.
- [ ] `sdlc milestone-close --issue 312 --milestone M2`, then `sdlc close --issue 312 --verified '<evidence>'`.
