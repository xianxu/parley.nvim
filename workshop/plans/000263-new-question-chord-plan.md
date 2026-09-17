# New-Question Chord Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One keystroke (`<C-g>n` / `<M-n>`) opens a new, empty `💬:` question immediately after the exchange the cursor is in, leaving the cursor in insert mode ready to type — with no clipboard, no emoji picker, and no duplicate when an empty question is already there.

**Architecture:** A pure planner (`lua/parley/new_question.lua`) turns `(parsed_chat, lines, cursor_line, header_end, user_prefix)` into a *plan value* — either an insertion (where, what lines, where the cursor lands) or a focus (just where the cursor lands). It computes the insertion point and the blank-line seam by calling `exchange_clipboard.get_paste_line` / `build_paste_lines`, which already own that arithmetic for `<C-g>V` (ARCH-DRY), so a pasted exchange and a new question land with byte-identical spacing. A thin IO shell (`M.cmd.NewQuestion` in `init.lua`) reads the buffer, applies the plan through `buffer_edit.replace_user_lines` — the same provenance-guarded write `<C-g>V` and `<C-g>k` use, which is what makes the action *refuse* rather than corrupt a transcript mid-stream (ARCH-ORDER) — then places the cursor and enters insert mode.

The chord is freed by retiring `chat_search`, a one-line `/^💬:\|^🌿:` wrapper the operator chose to drop (see the issue's `## Revisions`). Because the issue's Done-when requires the chord to "shadow no existing Parley chord (verified against the keybinding registry)", the existing collision guard — which inspects only `<M-…>` keys and so could not have caught this very collision — is generalized to the whole chord space including prefix shadowing (ARCH-PURPOSE: the class, not the instance).

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim API, plenary.nvim busted specs (`make test-spec SPEC=…`), luacheck.

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `plan` | `lua/parley/new_question.lua` | new |
| `is_empty_question` | `lua/parley/new_question.lua` | new |
| `exchange_index_at` | `lua/parley/exchange_clipboard.lua` | new |
| `get_paste_line` | `lua/parley/exchange_clipboard.lua` | modified |
| `build_paste_lines` | `lua/parley/exchange_clipboard.lua` | unchanged (reused) |
| `chat_search` registry entry | `lua/parley/keybinding_registry.lua` | deleted |
| `chat_shortcut_search` option | `lua/parley/config.lua` | deleted |
| `new_question` registry entry | `lua/parley/keybinding_registry.lua` | new |
| `chat_shortcut_new_question` option | `lua/parley/config.lua` | new |

**Test surface implied by the table.** `lua/parley/new_question.lua` is pure — it takes a parsed chat and a line array, never a buffer, exactly like `entity_range.lua` (#262). Its unit spec (`tests/unit/new_question_spec.lua`) runs with no buffer, no mocks and no IO. The deleted `chat_search` entry has no test of its own to remove; the registry specs that enumerate entries are generic and stay.

- **`plan(parsed_chat, lines, cursor_line, header_end, user_prefix)`** (`new_question.plan`) — decides what the keystroke does, as a value.
  - Returns `{ kind = "insert", after = N, lines = {…}, row = R }` or `{ kind = "focus", after = nil, lines = {…} | nil, row = R }`. In both cases `row` is the 1-based line that will hold the question, and the **post-condition is the same**: after the shell applies the plan, `lines[row]` equals `user_prefix .. " "` — or the prefix followed by at least one space, if the line already had trailing whitespace.
  - **Relationships:** 1:1 with a keystroke; N:1 with `parsed_chat`. Holds no state (ARCH-ORDER: it is a pure function of its arguments, so there is no state to carry between events).
  - **DRY rationale:** It does not re-derive the exchange span or the blank-line seam — both come from `exchange_clipboard`, the module whose header already declares itself the owner of "an exchange includes its preface, question, and answer … including trailing blank lines". Without this, `<C-g>n` and `<C-g>V` would drift into two different ideas of where an exchange ends.
  - **Future extensions:** the natural axis is *what* gets opened — a `🔒:` local note or a `@@tag@@`-prefaced question. That widens as a `kind` argument feeding the `lines` it builds, not as a second function.

- **`is_empty_question(lines, exchange, user_prefix)`** (`new_question.is_empty_question`) — is this exchange an unanswered question with no body?
  - **DRY rationale:** first occurrence of the predicate as a *shared* helper. `outline.lua:259` has the same idea inline for display purposes; that one classifies an outline item, this one classifies a parsed exchange, and merging them would couple the outline's item shape to the parser's. Named and exported so the next caller reuses it rather than re-inlining a third copy.
  - **ARCH-SECURE:** `user_prefix` is operator configuration and is compared with `string.sub`, never interpolated into a Lua pattern. A prefix containing a magic character (`>`, `%`, `.`, `-`) must behave like any other string; `init.lua:3940` records what happened the last time runtime text reached a pattern position (#214 BR-34).

- **`exchange_index_at(parsed_chat, cursor_line, total_lines)`** — the single owner of "which exchange is the cursor in". Added in close round 2, after the boundary gate reported a **second** finding in the `duplicated-command-preamble` family: `new_question` had shipped its own copy of the scan that already lived inside `get_paste_line`. `get_paste_line` now calls it, and so does `new_question.exchange_at`.
  - **DRY rationale:** the rule the repeat finding produced — *when a block is extracted into a shared helper, every caller consumes every field the helper now owns, and a new derivation of a concept the owning module already computes calls that module instead.*
  - **Future extensions:** a `{ nearest = true }` option would let `get_paste_line`'s second loop (nearest-exchange-before-cursor) move here too; it is the only remaining scan of the same shape.

- **`chat_buffer` / `parse` / `resolve`** (`lua/parley/chat_context.lua`) — **integration points, not pure entities.** They read the current buffer and window and call `not_chat`; an earlier draft of this table listed the helper under Pure entities, which was wrong (#263 close round 3, BR-10). They own the `not_chat` → `find_header_end` → `parse_chat` → cursor sequence for the whole codebase.
  - **Injected into:** nothing — they are the boundary. Each caller supplies its own wording, because the messages genuinely differ: `NewQuestion` names the command, `chat_respond.respond` names the file, and `chat_respond.respond_all` returns `nil, reason` to its caller for the header case.
  - **Why two phases:** `respond_all` interleaves its own precondition (is a batch already running?) between the chat check and the parse. A single monolithic `resolve` would reorder its messages — a chat with no `---` *and* an active batch would start reporting the header instead of the batch.
  - **DRY rationale:** the preamble was on its fourth verbatim copy; extracting it *file-locally into `init.lua`* fixed four sites and left two in `chat_respond.lua` unreachable, so the family came back a third time. The rule this settled: **the sequence has one owner reachable from any module**, and `not_chat → find_header_end → parse_chat` is written out nowhere else. Enumerated: 4 in `init.lua`, 2 in `chat_respond.lua`, 1 partial in `exporter.lua:965`, and 1 deliberate exclusion — `delete_entity_range`, which classifies through `entity_textobj.parsed_for` so the text objects and the `:ParleyDelete*` commands cannot disagree.

- **`chat_context(what)`** (`lua/parley/init.lua`) — now only the command-entry *wording* over that owner: a warning naming the command, or the header error. `ChatPrune`, `ExchangeCut`, `ExchangePaste` and `NewQuestion` consume it, including its `cursor_line`.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.cmd.NewQuestion` | `lua/parley/init.lua` | new | buffer read/write, cursor, mode |
| `new_question` keymap callback | `lua/parley/init.lua` (chat `register_buffer` table) | new | Neovim keymap dispatch |
| `chat_buffer` | `lua/parley/chat_context.lua` | new | current buffer/window, `not_chat` |
| `parse` | `lua/parley/chat_context.lua` | new | buffer read, cursor read |
| `resolve` | `lua/parley/chat_context.lua` | new | both phases |
| `chat_context` | `lua/parley/init.lua` | new | logger (wording only) |

- **`M.cmd.NewQuestion`** — the IO shell. Guards with `M.not_chat`, reads lines, finds the header, parses, reads the cursor, calls `new_question.plan`, applies through `buffer_edit.replace_user_lines`, sets the cursor and calls `startinsert!`. Auto-registers as `:ParleyNewQuestion` via the `for cmd, _ in pairs(M.cmd)` loop at `init.lua:1317`.
  - **Injected into:** nothing — it is the outermost layer. It injects `M.config.chat_user_prefix` *into* the pure planner, which is what keeps an operator override honored without the planner knowing what config is.
  - **ARCH-MOCK:** N/A. This touches no external binary or service — only the current Neovim buffer. The integration spec drives the real editor, not a double.
  - **Future extensions:** a `{ before = true }` option if "new question *before* this exchange" is ever wanted; the planner already returns an `after` index, so only the index changes.

- **`new_question` keymap callback** — normal- and insert-mode entry points.
  - Normal mode calls the command directly. Insert mode leaves insert first (`stopinsert`) so the buffer write is not folded into the surrounding insert session's undo block, then the command's own `startinsert!` puts the cursor back in insert at the new line. This is the one behavior the plan cannot settle by reading code — Task 4 tests it (single-undo, correct mode) before it is called done.

### Residue (ARCH-FUNERAL)

Creates nothing durable that accumulates. The only bytes this feature writes are question lines **inside a transcript the user already owns and edits by hand** — they live and die with that chat file, and the existing chat-delete path already removes them. It opens no file, spawns no process, writes no cache, log, temp file or request body, and adds no field to any persisted state. The new module and registry entry are code, not a growing artifact family. The one thing it *could* have leaked — the transcript text — never leaves the buffer, because the action neither sends nor serializes anything.

### Operating envelope (ARCH-CONSTRAINTS)

- **Interaction path:** keystroke / UI response.
- **Work per press:** one full-buffer read + one `parse_chat` + one line-range write. **Basis: measured fact** — this is byte-for-byte the same shape as `M.cmd.ExchangePaste` (`init.lua:4580-4592`) and `delete_entity_range` (`init.lua:4529-4553`), both already on chord paths today. No new budget is introduced and none of the existing chat-typing budget is consumed, because the parse happens on the chord, not on every keystroke.
- **Scale:** bounded by transcript length, identical to `<C-g>V`. Growth: `N/A` — a transcript that is too large for this is already too large for outline, paste and delete.
- **Overload behavior:** none needed; the write is synchronous and single-shot.
- **Concurrency / interrupting events (ARCH-ORDER):** the planner holds no state between events. The shell carries state for the duration of one call only, and two events can interleave with it:
  1. **A response is streaming into the buffer.** `buffer_edit.capture_user` refuses a write whose region is not user-owned; `replace_user_lines` raises on refusal. Governed by **ignore-with-a-visible-error** — the action must report, not silently no-op. This is the event most likely to be mishandled, so Task 4 tests it against a real pending generation.
  2. **A second press before the user types anything.** After the first press the cursor sits on the new empty question, so the second press takes the *focus* branch and creates nothing. This is not an accident of ordering — it is the non-duplication rule from the issue, and Task 2 pins it.
  - Process death mid-transition, connection loss and out-of-order completions do not apply: the write is one synchronous buffer edit with no external effect and nothing to reconcile.

---

## Chunk 1: The action

### Task 1: Free the chord — retire `chat_search`

`<C-g>n` is currently `chat_search` (`keybinding_registry.lua:658`), whose entire body is `vim.cmd("/^" .. pesc(user_prefix) .. "\\|^" .. pesc(branch_prefix))`. Operator decision: retire it; plain `/` covers it.

**Files:**
- Modify: `lua/parley/config.lua:372` (delete `chat_shortcut_search`)
- Modify: `lua/parley/keybinding_registry.lua:657-666` (delete the `chat_search` entry)
- Modify: `lua/parley/init.lua:2803-2808` (delete the `chat_search` callback)

- [x] **Step 1: Confirm the blast radius is exactly those three sites**

Run:
```bash
grep -rn "chat_search\|chat_shortcut_search" --include="*.lua" --include="*.md" --include="*.txt" . | grep -v workshop/
```
Expected: **exactly four lines**, covering the three sites — `init.lua:2803`, `config.lua:372`, and `keybinding_registry.lua:658` **and** `:659` (the registry entry matches twice, on its `id` and its `config_key`). Nothing under `tests/`, `README.md` or `atlas/`, and this repo has no `doc/` directory. If a fifth line appears, it is a consumer this plan did not account for — stop and add it.

- [x] **Step 2: Delete the config option**

Remove `lua/parley/config.lua:372`:
```lua
	chat_shortcut_search = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },
```

- [x] **Step 3: Delete the registry entry**

Remove the whole entry at `lua/parley/keybinding_registry.lua:657-666`:
```lua
	{
		id = "chat_search",
		config_key = "chat_shortcut_search",
		default_key = "<C-g>n",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Search Chat Sections",
		help_desc = "Search chat sections",
		buffer_local = true,
	},
```

- [x] **Step 4: Delete the callback**

Remove `lua/parley/init.lua:2803-2808`:
```lua
			chat_search = function()
				local user_prefix = M.config.chat_user_prefix
				local branch_prefix = M.config.chat_branch_prefix
				vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(branch_prefix))
			end,
```

- [x] **Step 5: Run the keybinding specs — they must still pass**

Run: `make test-spec SPEC=ui/keybindings`
Expected: PASS. Several specs assert "every registry entry can be disabled / rebound" and "help shows no key that is not bound"; removing an entry cleanly must not disturb them. A failure here means something outside the three sites referenced `chat_search`.

- [x] **Step 6: Commit**

```bash
git add lua/parley/config.lua lua/parley/keybinding_registry.lua lua/parley/init.lua
git commit -m "#263: retire chat_search, freeing <C-g>n"
```

---

### Task 2: The pure planner

**Files:**
- Create: `lua/parley/new_question.lua`
- Test: `tests/unit/new_question_spec.lua`

**Test strategy for `plan`.** The adversarial axis is *where the cursor is*, because every branch of the function is chosen by it: inside an exchange, inside the header before any exchange, below the last exchange, and inside an exchange that is already an empty question. The second axis is *what the prefix is* — a non-default `chat_user_prefix` containing a Lua-pattern magic character, which is the input that would expose a pattern-interpolation bug. The oracle is the returned plan value compared against a hand-written expectation; the spec builds `parsed_chat` by calling the real `chat_parser.parse_chat` on fixture lines rather than hand-rolling exchange tables, so a parser change cannot leave this spec green against a shape the parser no longer produces.

**Test strategy for `is_empty_question`.** Its whole job is a boundary: "blank body" must accept `💬:`, `💬: `, `💬:` followed by blank lines, and must reject a question with one word of text and any question that has an answer. Drive it directly with the parsed exchanges from the same fixtures.

- [x] **Step 1: Write the failing unit spec**

Create `tests/unit/new_question_spec.lua`:

```lua
local nq = require("parley.new_question")
local chat_parser = require("parley.chat_parser")

local PREFIX = "💬:"

-- The same minimal stub `tests/unit/parse_chat_spec.lua` uses: it covers every
-- field parse_chat reads from config. A two-key table is NOT enough -- the
-- parser reaches chat_local_prefix, chat_branch_prefix and chat_memory too.
local function config_for(prefix)
    return {
        chat_user_prefix      = prefix or PREFIX,
        chat_local_prefix     = "🔒:",
        chat_branch_prefix    = "🌿:",
        chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
        chat_memory = {
            enable           = true,
            summary_prefix   = "📝:",
            reasoning_prefix = "🧠:",
        },
    }
end

--- Build (lines, parsed_chat, header_end) from a transcript body.
local function transcript(body, prefix)
    local lines = vim.split("---\ntopic: t\nfile: t.md\n---\n" .. body, "\n", { plain = true })
    local header_end = chat_parser.find_header_end(lines)
    local parsed = chat_parser.parse_chat(lines, header_end, config_for(prefix))
    return lines, parsed, header_end
end

describe("new_question.is_empty_question", function()
    it("accepts a bare prefix line with no answer", function()
        local lines, parsed = transcript("\n💬:\n")
        assert.is_true(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("accepts a prefix line that is only trailing whitespace", function()
        local lines, parsed = transcript("\n💬:   \n")
        assert.is_true(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("rejects a question that has text", function()
        local lines, parsed = transcript("\n💬: hello\n")
        assert.is_false(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("rejects an empty question that already has an answer", function()
        local lines, parsed = transcript("\n💬:\n\n🤖: [x]\n\nanswered\n")
        assert.is_false(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)
end)

describe("new_question.plan", function()
    -- One answered exchange, then a second answered exchange.
    local BODY = "\n💬: first\n\n🤖: [x]\n\nA1\n\n💬: second\n\n🤖: [x]\n\nA2\n"

    it("opens a question after the exchange the cursor is in, not at the end", function()
        local lines, parsed, header_end = transcript(BODY)
        local first_q = parsed.exchanges[1].question.line_start
        local p = nq.plan(parsed, lines, first_q, header_end, PREFIX)
        assert.equals("insert", p.kind)
        -- It lands inside the transcript, not appended at EOF.
        --
        -- `<=`, NOT `<`. Measured: for BODY, p.after = 11, p.row = 12 and
        -- exchange 2's PRE-insertion line_start is also 12. That is structural,
        -- not fixture luck -- get_paste_line returns the end of exchange 1,
        -- which includes its trailing blank, so the new question takes exactly
        -- the row exchange 2 used to occupy and pushes it down. `<` here fails
        -- against CORRECT code, and the tempting fix (shrink row by one)
        -- destroys the blank-line seam this module exists to preserve.
        assert.is_true(p.row <= parsed.exchanges[2].question.line_start)
        assert.is_true(p.row > parsed.exchanges[1].question.line_start)
        assert.is_true(vim.tbl_contains(p.lines, PREFIX .. " "))
    end)

    it("the planned row is the prefix line, with a trailing space", function()
        local lines, parsed, header_end = transcript(BODY)
        local p = nq.plan(parsed, lines, parsed.exchanges[2].question.line_start, header_end, PREFIX)
        -- Apply the plan to a copy and read row back: the post-condition, checked
        -- against the resulting text rather than against the planner's own math.
        local after = {}
        for i = 1, p.after do after[#after + 1] = lines[i] end
        for _, l in ipairs(p.lines) do after[#after + 1] = l end
        for i = p.after + 1, #lines do after[#after + 1] = lines[i] end
        assert.equals(PREFIX .. " ", after[p.row])
    end)

    it("focuses an existing empty question instead of creating a second one", function()
        local lines, parsed, header_end = transcript("\n💬: first\n\n🤖: [x]\n\nA1\n\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[2].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.equals(parsed.exchanges[2].question.line_start, p.row)
    end)

    it("gives a bare focused prefix its trailing space", function()
        local lines, parsed, header_end = transcript("\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.same({ PREFIX .. " " }, p.lines)
    end)

    it("leaves an already-spaced focused prefix untouched", function()
        local lines, parsed, header_end = transcript("\n💬:   \n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.is_nil(p.lines)
    end)

    -- A tab is whitespace, so is_empty_question accepts the line -- but it is
    -- not the separator the post-condition names, and leaving it would make
    -- startinsert! produce `💬:\thello`.
    it("normalizes a tab-separated focused prefix to a space", function()
        local lines, parsed, header_end = transcript("\n💬:\t\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.same({ PREFIX .. " " }, p.lines)
    end)

    -- The one path that can legitimately produce two consecutive `💬:` lines.
    -- Recorded as a DECISION, not an oversight: the rule is about the exchange
    -- the cursor is IN (the revision's wording), so pressing the chord from an
    -- answered exchange opens a question after it even when the next exchange
    -- is already empty. Reaching past the cursor's exchange to adopt a
    -- neighbour's empty question would make the chord's landing spot depend on
    -- content the user is not looking at.
    it("does not adopt the NEXT exchange's empty question", function()
        local lines, parsed, header_end = transcript(
            "\n💬: first\n\n🤖: [x]\n\nA1\n\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start,
            header_end, PREFIX)
        assert.equals("insert", p.kind)
    end)

    it("opens the first question when the chat has none", function()
        local lines, parsed, header_end = transcript("\n")
        local p = nq.plan(parsed, lines, 1, header_end, PREFIX)
        assert.equals("insert", p.kind)
        assert.is_true(p.after >= header_end)
        assert.is_true(p.row > header_end)
    end)

    it("honors a configured prefix that is full of Lua-pattern magic", function()
        local magic = "%-Q.:"
        local lines, parsed, header_end = transcript("\n" .. magic .. " first\n", magic)
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start,
            header_end, magic)
        assert.equals("insert", p.kind)
        local found = false
        for _, l in ipairs(p.lines) do
            if l == magic .. " " then found = true end
        end
        assert.is_true(found)
    end)

    it("is a plan only -- it mutates nothing it was handed", function()
        local lines, parsed, header_end = transcript(BODY)
        local before = vim.deepcopy(lines)
        nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.same(before, lines)
    end)
end)
```

- [x] **Step 2: Run it to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/new_question_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.new_question' not found`.

- [x] **Step 3: Write the minimal implementation**

Create `lua/parley/new_question.lua`:

```lua
-- Where a new, empty question goes -- as a value.
--
-- Pure: takes a parsed chat and a line array, never a buffer, so every rule
-- below is unit-testable without nvim state (ARCH-PURE). The insertion point
-- and the blank-line seam are NOT decided here: they come from
-- exchange_clipboard, which already owns "where does this exchange end" for
-- <C-g>V (ARCH-DRY). One definition means a pasted exchange and a new
-- question land with identical spacing.
--
-- Post-condition, in both branches: after the shell applies the returned plan,
-- the line at `row` is the user prefix followed by at least one space. That is
-- what makes `startinsert!` at end-of-line produce `💬: text` rather than
-- `💬:text`.
local clipboard = require("parley.exchange_clipboard")

local M = {}

--- An unanswered question whose body is blank.
--- `user_prefix` is OPERATOR CONFIG: compared with sub(), never interpolated
--- into a pattern, so a prefix containing `%`, `.` or `-` behaves like any
--- other string (ARCH-SECURE; cf. init.lua:3940, #214 BR-34).
function M.is_empty_question(lines, exchange, user_prefix)
	if not exchange or not exchange.question or exchange.answer then
		return false
	end
	local first = exchange.question.line_start
	local last = exchange.question.line_end or first
	local head = lines[first]
	if not head or head:sub(1, #user_prefix) ~= user_prefix then
		return false
	end
	if head:sub(#user_prefix + 1):match("^%s*$") == nil then
		return false
	end
	for i = first + 1, last do
		if lines[i] and lines[i]:match("^%s*$") == nil then
			return false
		end
	end
	return true
end

--- The exchange containing `cursor_line`, or nil when the cursor is outside
--- every exchange (in the header, or in trailing space below the last one).
local function exchange_at(parsed_chat, cursor_line, total_lines)
	for i in ipairs(parsed_chat.exchanges) do
		local first, last = clipboard.get_exchange_line_range(parsed_chat, i, total_lines)
		if first and cursor_line >= first and cursor_line <= last then
			return parsed_chat.exchanges[i]
		end
	end
	return nil
end

--- @return table plan
---   { kind = "insert", after = N, lines = {…}, row = R } -- insert after line N
---   { kind = "focus",  lines = {…}|nil,        row = R } -- replace row, or nothing
function M.plan(parsed_chat, lines, cursor_line, header_end, user_prefix)
	local total = #lines
	local question = user_prefix .. " "

	local current = exchange_at(parsed_chat, cursor_line, total)
	if M.is_empty_question(lines, current, user_prefix) then
		local row = current.question.line_start
		-- Already `💬: ` or `💬:   ` -- nothing to write, just go there.
		-- The test is "prefix then a SPACE", not "prefix then anything": a
		-- `💬:\t` line is whitespace-only to is_empty_question but would leave
		-- startinsert! producing `💬:\thello`. A tab is not the separator the
		-- post-condition promises.
		if lines[row]:sub(#user_prefix + 1, #user_prefix + 1) == " " then
			return { kind = "focus", row = row }
		end
		-- Bare `💬:`, or `💬:` followed by some other whitespace -- normalize to
		-- the one shape the post-condition names.
		return { kind = "focus", row = row, lines = { question } }
	end

	local after = clipboard.get_paste_line(parsed_chat, cursor_line, header_end, total)
	local insert = clipboard.build_paste_lines(lines, after, { question }, total)
	local row
	for i, l in ipairs(insert) do
		if l == question then
			row = after + i
			break
		end
	end
	return { kind = "insert", after = after, lines = insert, row = row }
end

return M
```

- [x] **Step 4: Run the spec to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/new_question_spec.lua" -c "qa!"`
Expected: PASS, all twelve cases. This was verified empirically during plan review — the literal spec above was run against the literal implementation below in a real headless nvim.

Do **not** "fix" a failure by shrinking `p.row`. The seam (`build_paste_lines` deciding whether a blank line precedes the new question) is the whole reason this module delegates to `exchange_clipboard`; moving `row` to satisfy an assertion re-encodes that rule in the wrong place. If `row` looks off by one, re-read the `<=` comment in the first test.

The parser side is settled, so it is not a suspect: for a trailing bare `💬:` with no answer, `chat_parser` yields `line_start = line_end` and `answer = nil`, and `line_end` is **never** nil — `finalize_component(#lines)` at `chat_parser.lua:998` always sets it.

- [x] **Step 5: Lint**

Run: `make lint`
Expected: clean.

- [x] **Step 6: Route the new spec in `atlas/traceability.yaml` — in this commit, not later**

`tests/arch/single_source_sweeps_spec.lua`'s `every spec this branch ADDED is routed somewhere` guard fails on any `NNNNNN-…` branch for an added-or-untracked `*_spec.lua` that no traceability entry names — and it reads the **working tree**, so an unstaged new spec trips it too. Route it in the same commit that creates it, or every later `make test-spec` run in this plan goes red for a reason that has nothing to do with the code under test.

Under `chat/lifecycle`, add to `code:` → `lua/parley/new_question.lua`, and to `tests:` → `tests/unit/new_question_spec.lua`.
Under `ui/keybindings`, add the same two.

Verify:
```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/arch/single_source_sweeps_spec.lua" -c "qa!"
```
Expected: PASS (`every path it names exists` also checks the new paths are real).

- [x] **Step 7: Commit**

```bash
git add lua/parley/new_question.lua tests/unit/new_question_spec.lua atlas/traceability.yaml
git commit -m "#263: where a new question goes, as a value"
```

---

### Task 3: Wire the command and the chord

**Files:**
- Modify: `lua/parley/init.lua` (add `M.cmd.NewQuestion` near `M.cmd.ExchangePaste`, ~line 4595; add `new_question` to the chat callback table at ~line 2800)
- Modify: `lua/parley/keybinding_registry.lua` (add the `new_question` entry where `chat_search` was)
- Modify: `lua/parley/config.lua` (add `chat_shortcut_new_question` where `chat_shortcut_search` was)

- [x] **Step 1: Add the config option**

At `lua/parley/config.lua`, where `chat_shortcut_search` was deleted in Task 1:

```lua
	-- #263: open a new, empty question after the exchange at the cursor. `n` for
	-- new, in both families. It took <C-g>n from chat_search, a `/^💬:\|^🌿:`
	-- wrapper plain `/` already covers.
	--
	-- <C-g>n LEADS, which is deliberate and is the one place this entry departs
	-- from #214's "the portable alt key leads" rule (branch_ref, prune,
	-- open_file). The operator asked for <C-g>n by name and chose to retire
	-- chat_search for it, so <C-g>n is the gesture being taught and help must
	-- advertise it first; <M-n> rides along as the alt-family twin. `outline`
	-- ships { "<C-g>t", "<M-t>" } in the same order, so this is not a novel shape.
	--
	-- Overriding `shortcut` REPLACES the list -- name both if you want both.
	chat_shortcut_new_question = { modes = { "n", "i" }, shortcut = { "<C-g>n", "<M-n>" } },
```

- [x] **Step 2: Add the registry entry**

At `lua/parley/keybinding_registry.lua`, where the `chat_search` entry was:

```lua
	{
		id = "new_question",
		config_key = "chat_shortcut_new_question",
		default_key = { "<C-g>n", "<M-n>" },
		default_modes = { "n", "i" },
		scope = "chat",
		desc = "Parley new question",
		help_desc = "New question after this exchange",
		buffer_local = true,
	},
```

- [x] **Step 3: Add the command**

At `lua/parley/init.lua`, immediately after `M.cmd.ExchangePaste` (~line 4593):

```lua
--- #263 Open a new, empty question after the exchange at the cursor. The
--- end-user path to a `💬:` line: no clipboard, no emoji picker.
---
--- The structure decision is a pure plan (parley.new_question); this is the IO
--- shell. Writing through buffer_edit rather than nvim_buf_set_lines is what
--- gives the edit its provenance token -- and what makes this REFUSE, loudly,
--- rather than corrupt a transcript a response is streaming into (ARCH-ORDER).
M.cmd.NewQuestion = function()
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("NewQuestion is only available in chat files: " .. reason)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then
		M.logger.error("NewQuestion: could not find header separator ---")
		return
	end

	local parsed_chat = M.parse_chat(lines, header_end)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local plan = require("parley.new_question").plan(
		parsed_chat, lines, cursor_line, header_end, M.config.chat_user_prefix)

	local edits = require("parley.buffer_edit")
	local ok, err
	if plan.kind == "insert" then
		ok, err = pcall(edits.replace_user_lines, buf, plan.after, plan.after, false, plan.lines)
	elseif plan.lines then
		ok, err = pcall(edits.replace_user_lines, buf, plan.row - 1, plan.row, false, plan.lines)
	else
		ok = true
	end
	if not ok then
		M.logger.warning("NewQuestion stopped: " .. tostring(err))
		return
	end

	-- The planner always names a row; a nil here means the clipboard arg was
	-- empty, which cannot happen, and nvim_win_set_cursor's error would not say
	-- so. State the invariant where it is cheap to read.
	assert(plan.row, "new_question.plan returned no row")
	local row = math.min(plan.row, vim.api.nvim_buf_line_count(buf))
	-- Column 0 is deliberate: `startinsert!` IS `A`, so it lands at end-of-line
	-- whatever column we set. Only the ROW matters here.
	vim.api.nvim_win_set_cursor(0, { row, 0 })
	vim.cmd("startinsert!")
end
```

- [x] **Step 4: Wire the keymap callback**

At `lua/parley/init.lua`, in the chat `register_buffer` callback table where `chat_search` was (~line 2803):

```lua
			new_question = {
				n = M.cmd.NewQuestion,
				-- Leave insert BEFORE writing, so the buffer edit is its own undo
				-- step rather than being folded into the surrounding insert
				-- session; NewQuestion's own startinsert! puts us back.
				i = function()
					vim.cmd("stopinsert")
					M.cmd.NewQuestion()
				end,
			},
```

- [x] **Step 5: Verify the command and chord exist**

Run:
```bash
make test-spec SPEC=ui/keybindings
```
Expected: PASS. Four existing guards bear on this entry specifically (names are the real `it(…)` strings — `<C-g>? can show every bound key` is the enclosing `describe`, not a test):
- `every key of every displayed entry appears in its context's help` (line 708) — both chords must show in the chat help.
- `and the reverse — help shows no key that is not bound` (line 735).
- `no alt key is live twice in the same buffer` (line 935) — `<M-n>` must be unowned elsewhere. Verified during plan review: `<M-n>` appears nowhere in `lua/` or `tests/`.
- `each shipped default preserves the entry's registry keys AND modes` (line 415) — `config.lua`'s `shortcut` list must be a superset of the registry's `default_key` list, and its `modes` a subset of `default_modes`. The plan ships both as `{ "<C-g>n", "<M-n>" }` / `{ "n", "i" }` precisely so this passes; if you change one, change both.

**Do not run `make test-spec SPEC=ui/keybindings` yet** — see Task 2 Step 6 and Task 4 Step 5. That spec key fans out to `tests/arch/single_source_sweeps_spec.lua`, whose `every spec this branch ADDED is routed somewhere` guard fails on an issue branch until each new spec is listed in `atlas/traceability.yaml`. Run the keybindings spec file directly here:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/keybindings_spec.lua" -c "qa!"
```

- [x] **Step 6: Commit**

```bash
git add lua/parley/init.lua lua/parley/keybinding_registry.lua lua/parley/config.lua
git commit -m "#263: <C-g>n / <M-n> opens a new question"
```

---

### Task 4: Prove it in a real editor

**Files:**
- Create: `tests/integration/new_question_spec.lua`

**Test strategy.** The unit spec proves the planner's arithmetic; this spec exists to test what the planner cannot see — the real keymap, the real modes, undo, and the streaming refusal. Its assertions are deliberately **not** derived from the code under test: question lines are counted with a plain `vim.startswith` scan of the buffer, not by re-parsing (the #262 lesson — a guard whose expectation is computed with its own predicates agrees with itself). The riskiest function here is the insert-mode callback, because the undo grouping is the one thing this plan asserts without having been able to read it off existing code.

- [x] **Step 1: Write the failing integration spec**

Create `tests/integration/new_question_spec.lua`. Three different files supply the three techniques this spec needs — verified during plan review, because the first draft of this step attributed all three to one file that uses none of them:

1. **Fixture** — `tests/integration/entity_textobj_spec.lua`'s `prepped()`. It writes the transcript to disk and `:edit`s it, which is what gives the buffer real undo history; case 4 below depends on that (a buffer built with `nvim_buf_set_lines` reverts to empty on `u`).
2. **Invoking the chord** — `tests/integration/user_edit_callers_spec.lua:22-26`, the repo's idiom for firing a registry keymap:

```lua
local Registry = require("parley.keybinding_registry")
local function press(id, mode)
    local key = Registry.key_for(id, parley.config)
    local mapping = vim.fn.maparg(key, mode or "n", false, true)
    assert.equals("function", type(mapping.callback))
    mapping.callback()
end
```

   `nvim_feedkeys` is **not** the idiom here and `entity_textobj_spec` does not use it — it drives `vim.cmd("normal dae")` and asserts mapping existence via `nvim_buf_get_keymap`.
3. **Asserting insert mode** — `vim.fn.mode()` is used by **no test in this repo**, and it will not work: `startinsert!` issued inside a mapping callback does not take effect until control returns to the main loop, so a synchronous `mode()` read in headless plenary sees normal. The precedent is spying on `vim.cmd`, from `tests/integration/open_reference_spec.lua:521-561` — including its hard-won detail:

```lua
local cmds = {}
local real_cmd = vim.cmd
vim.cmd = function(c) table.insert(cmds, tostring(c)) end
press("new_question")
-- `startinsert` is scheduled, so the spy has to outlive the callback.
-- Restoring first is why the first version of that test saw nothing.
vim.wait(50, function() return false end)
vim.cmd = real_cmd
assert.is_truthy(table.concat(cmds, "\n"):match("startinsert"))
```

Cases:

1. **Normal mode, mid-transcript** — cursor on exchange 1 of a two-exchange chat, press `<C-g>n`. Independent oracle: the count of lines starting with `💬:` goes from 2 to 3, **and** the new one sits between the old first and second (compare line indices, not parser output).
2. **The line is `💬: ` and insert was requested** — after the press, the spy from (3) above saw `startinsert`, the cursor's **row** is the planned row, and that line is exactly `💬: `. Do not assert the cursor column: `startinsert!` sets it, and it has not run yet when the callback returns.
3. **Typing into it produces `💬: hello`** — the real proof the trailing space is there. Because the mode change is scheduled, drive this the way the repo drives post-`startinsert` behavior: after the press, `vim.wait(50, function() return false end)`, then `nvim_buf_set_text` at end-of-line and assert the resulting line. (If you prefer a genuine keystroke, `nvim_feedkeys(..., "x", false)` forces the pending mode change to be processed first — but the buffer-text assertion is the load-bearing one either way.)
4. **Insert mode entry** — start insert on an answer line, press the insert-mode mapping (`press("new_question", "i")`), assert the same post-condition as (2).
5. **Single undo** — from case (1), press `u` once and assert the buffer is byte-identical to the pre-press snapshot. This is the assertion that judges the `stopinsert`-first decision in Task 3 Step 4; if it fails, the callback is wrong, not the test. Requires the on-disk fixture from (1) above — a synthesized buffer has no undo history to return to.
6. **No duplicate on a second press** — press twice with no typing in between; the `💬:` count goes 2 → 3, not 2 → 4.
7. **Empty chat** — a transcript with a header and nothing else; one press produces exactly one `💬: ` line below the `---`.
8. **Non-default prefix** — `parley.setup{ chat_user_prefix = ">>" }`, and the inserted line is `>> `.
9. **Refusal while streaming** — a press must leave the buffer unchanged **and** log a warning; assert both, so a silent no-op cannot pass. Build the guard state directly through `document.capture_user`, following `tests/integration/document_user_guards_spec.lua`. Do **not** plan to "reuse the pending helper" from `tests/integration/chat_pending_spec.lua` — `fake_runtime` (line 2), `fixture` (91) and `start` (96) are file-local `local function`s with no exports, so that would be a copy, not a reuse.
10. **The next exchange's empty question is not adopted** — cursor in an answered exchange whose *successor* is already an empty question; the press inserts rather than jumping forward. Pins the decision recorded in the unit spec, at the surface the user actually touches.

- [x] **Step 2: Run it to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/new_question_spec.lua" -c "qa!"`
Expected: the cases that exercise behavior not yet correct fail. Cases 1, 6, 7, 8 and 10 should already pass from Task 3. **Cases 2, 3, 4, 5 and 9 are the open set** — every one of them turns on scheduled-`startinsert` timing, undo grouping, or the refusal path, none of which this plan could settle by reading existing code.

- [x] **Step 3: Fix whatever the open set exposes**

- **Cases 2-4 (mode/timing):** if the spy sees no `startinsert`, it was restored before the scheduled command ran — the `vim.wait` above is not optional. If it sees `startinsert` but the text lands wrong, the row is wrong, not the mode.
- **Case 5 (undo):** a failure means the insert-mode callback folded the edit into the surrounding undo block. Adjust the `i` handler; the likely fix is `vim.cmd("stopinsert")` followed by running the command from `vim.schedule`, at the cost of making this spec schedule-aware.
- **Case 9 (refusal):** if nothing is raised, `replace_user_lines` is not refusing where expected — read `buffer_edit.capture_user`'s refusal path rather than adding a guard of your own.

- [x] **Step 4: Run the full spec to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/new_question_spec.lua" -c "qa!"`
Expected: PASS, all ten cases.

- [x] **Step 5: Route the new spec in `atlas/traceability.yaml`**

Same reason as Task 2 Step 6 — in the commit that creates it, not in Task 6. Add `tests/integration/new_question_spec.lua` to the `tests:` lists under both `chat/lifecycle` and `ui/keybindings`.

Verify:
```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/arch/single_source_sweeps_spec.lua" -c "qa!"
```
Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add tests/integration/new_question_spec.lua lua/parley/init.lua atlas/traceability.yaml
git commit -m "#263: drive the chord through a real editor"
```

---

## Chunk 2: The guard and the docs

### Task 5: Generalize the shadowing guard (ARCH-PURPOSE)

The issue's Done-when says the chord must shadow no existing Parley chord, "verified against the keybinding registry". Today's guard (`tests/unit/keybindings_spec.lua:935`, `"no alt key is live twice in the same buffer"`) filters to `k:match("^<[Mm]%-")` — it inspects only alt keys and therefore **could not have caught this `<C-g>n` collision**, which is the exact class the issue names. Fixing only the one chord is the instance; the class is "no chord is live twice in the same buffer, and no chord delays another".

Measured before planning: under the wider rule the registry has **0** collisions today, so this generalization lands green rather than opening a cleanup.

**Files:**
- Modify: `tests/unit/keybindings_spec.lua:878-968` (the `describe("open_file joins the alt family (#214)")` block, which holds `scopes_overlap` at line 922 and the guard at 935)

The three loops below share one `owners_by_key` / `collisions` pair. Writing the detection out once per `it` is how a plant ends up proving a *different* guard than the one that ships — which is the same defect the plan flags in Task 4 (an expectation computed with the code under test agrees with itself), and ARCH-DRY.

- [x] **Step 1: Add the shared helpers, widen the guard, and add prefix shadowing**

Replace the whole `it("no alt key is live twice in the same buffer", …)` — renaming it — and add the helpers and a second `it` beside it. `reg` (line 880), `parley` (879) and `scopes_overlap` (922) are already locals of this `describe`, so all three are in scope:

```lua
    -- Canonical notation. `tests/integration/keybinding_agreement_spec.lua`
    -- carries this because "<C-g>" comes back as "<C-G>": without it a user
    -- override spelled <C-G>n slips past a guard whose entire job is catching
    -- the NEXT collision.
    local function canon(lhs)
        return vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
    end

    -- Two bindings only fight if they are live in the same buffer AND in the
    -- same mode. Widening from alt-only to EVERY key pulls in entries the old
    -- filter never saw: ae/ie/aE are {o,x} only, gf/gP are normal-only. Without
    -- this, the widened guard grows a false-positive surface.
    local function modes_overlap(a, b)
        for _, m in ipairs(a or {}) do
            for _, n in ipairs(b or {}) do
                if m == n then return true end
            end
        end
        return false
    end

    -- ONE detection, shared by both guards and by the plant that proves them.
    -- `overrides` maps an entry id to a replacement key list.
    local function owners_by_key(overrides)
        local owners = {}
        for _, e in ipairs(reg.entries) do
            local keys, modes = reg.resolve_keys(e, parley.config)
            keys = (overrides or {})[e.id] or keys or {}
            for _, k in ipairs(keys) do
                local c = canon(k)
                owners[c] = owners[c] or {}
                table.insert(owners[c], { entry = e, modes = modes })
            end
        end
        return owners
    end

    local function live_together(a, b)
        return scopes_overlap(a.entry.scope, b.entry.scope) and modes_overlap(a.modes, b.modes)
    end

    local function collisions(owners)
        local out = {}
        for key, owned in pairs(owners) do
            for i = 1, #owned do
                for j = i + 1, #owned do
                    if live_together(owned[i], owned[j]) then
                        out[#out + 1] = ("%s -> %s(%s) + %s(%s)"):format(key,
                            owned[i].entry.id, owned[i].entry.scope,
                            owned[j].entry.id, owned[j].entry.scope)
                    end
                end
            end
        end
        table.sort(out)
        return out
    end

    local function prefix_shadows(owners)
        local keys = {}
        for k in pairs(owners) do keys[#keys + 1] = k end
        local out = {}
        for _, short in ipairs(keys) do
            for _, long in ipairs(keys) do
                if short ~= long and #short < #long and long:sub(1, #short) == short then
                    for _, a in ipairs(owners[short]) do
                        for _, b in ipairs(owners[long]) do
                            if live_together(a, b) then
                                out[#out + 1] = ("%s(%s) delays %s(%s)"):format(
                                    short, a.entry.id, long, b.entry.id)
                            end
                        end
                    end
                end
            end
        end
        table.sort(out)
        return out
    end

    -- #263: this was filtered to `^<[Mm]-` and so inspected one family out of
    -- three. It could not have caught <C-g>n being bound twice, which is the
    -- collision #263 actually hit. The rule is about a buffer, not a family.
    it("no key is live twice in the same buffer", function()
        assert.same({}, collisions(owners_by_key()))
    end)

    -- A chord that is a PREFIX of another is not a silent overwrite -- it is a
    -- timeout. Binding <C-g>e would make <C-g>em and <C-g>eh wait for
    -- 'timeoutlen' on every press. That rule lives today as a comment above
    -- entity_delete in the registry; here it is a test.
    it("no key delays another by being its prefix", function()
        assert.same({}, prefix_shadows(owners_by_key()))
    end)
```

- [x] **Step 2: Prove the guard bites**

The existing `it("and the disjoint case is genuinely allowed, not accidentally passing", …)` proves `scopes_overlap`. Add one that proves the **widened** scan finds a real `<C-g>` double-bind — otherwise a guard that reports nothing is indistinguishable from a guard that looks at nothing:

```lua
    -- Both scopes are `parley_buffer`, so scopes_overlap hits its `a == b`
    -- branch, and both carry a normal mode, so modes_overlap holds too. The
    -- plant runs THE SAME collisions() the guard above runs -- not a copy that
    -- could drift away from it.
    it("and the widened scan really would catch a <C-g> double-bind", function()
        local found = collisions(owners_by_key({ outline = { "<C-g>k" } }))
        -- Assert the OFFENDER, not merely that something was found: a bare
        -- `#found > 0` borrows its meaning from the clean-registry test above,
        -- and would keep passing if an unrelated collision appeared.
        assert.equals(1, #found, "expected exactly the planted collision, got: "
            .. table.concat(found, "; "))
        assert.is_truthy(found[1]:find("outline", 1, true))
        assert.is_truthy(found[1]:find("entity_delete", 1, true))
    end)

    -- The prefix guard needs its own plant for the same reason.
    it("and the prefix scan really would catch a delaying chord", function()
        -- <C-g>e is UNBOUND precisely because <C-g>em / <C-g>eh exist; binding
        -- it is the exact mistake the registry comment warns about.
        local found = prefix_shadows(owners_by_key({ outline = { "<C-g>e" } }))
        assert.is_true(#found >= 1, "the prefix scan reported nothing on a planted shadow")
        assert.is_truthy(table.concat(found, "; "):find("outline", 1, true))
    end)
```

- [x] **Step 3: Run the keybinding specs**

Run:
```bash
make test-spec SPEC=ui/keybindings
```
Expected: PASS — including the two widened guards against the real registry and both planted cases. Measured during plan review: the widened rule finds **0** collisions and **0** prefix shadows on today's registry, and stays at 0/0 after this issue's entry, so a red run here is a real finding, not the generalization catching up with debt.

This is the first `make test-spec` in the plan, and it only works because Tasks 2 and 4 routed their specs in `atlas/traceability.yaml` — the spec key fans out to `tests/arch/single_source_sweeps_spec.lua`. If it reports an unrouted spec, that routing step was skipped.

- [x] **Step 4: Commit**

```bash
git add tests/unit/keybindings_spec.lua
git commit -m "#263: the shadowing guard covers every chord, not just alt"
```

---

### Task 6: Documentation

The repo has **no** which-key integration; the keybinding registry is the single source and `<C-g>?` help is generated from it, so Task 3's registry entry already published the chord to help. Verified during plan review that atlas really is the whole doc surface: there is no `doc/` directory, `README.md` names no chords, `packaging/tutorials/*.md` mention `<C-g>f` only in prose with no per-chord list, and `lua/parley/help.lua` serves atlas pages rather than an inline key table.

**Everything below leads with `<C-g>n`, not `<M-n>`.** `resolve_keys` returns the config list in order and the help float renders `keys[1]` as primary, so the shipped help says `<C-g>n (also <M-n>)`. Atlas prose that called `<M-n>` the primary would ship a claim the running help disproves.

**Files:**
- Modify: `atlas/ui/keybindings.md` (`## Common transcript actions`, ~line 15-34)
- Modify: `atlas/ui/keybindings.md` (`## Resolution`, ~line 96-112 — the alt-leads rule this entry departs from)
- Modify: `atlas/ui/keybindings.md` (`## Scope Forest`, ~line 43-60 — the new keyspace invariants)
- Modify: `atlas/chat/lifecycle.md` (a new `## New Question` section, after `## Creation`)

`atlas/traceability.yaml` is **not** listed: Tasks 2 and 4 already routed their specs there, in the commits that created them.

- [x] **Step 1: Add the chord to `atlas/ui/keybindings.md` § Common transcript actions**

After the structural-editing paragraph:

```markdown
`<C-g>n` (also `<M-n>`) opens a new, empty `💬:` question immediately after the
exchange the cursor is in, and leaves the cursor in insert mode on it. It reads
`chat_user_prefix`, so an operator override is what gets written. Pressing it on
an exchange that is already an empty question focuses that question rather than
adding a second one; pressing it on an answered exchange whose *successor* is
empty still inserts, because the rule is about the exchange the cursor is in and
not about content off-screen. This is the end-user path to a question line — the
emoji is not on the keyboard, and nothing here needs the clipboard.
```

- [x] **Step 2: Record the ordering exception in `atlas/ui/keybindings.md` § Resolution**

That section currently states the rule this entry breaks — "the **portable key leads** where portability is the issue, so `branch_ref` shows `<M-i>`" — and enumerates the alt family's members. `<M-n>` joins that family while `<C-g>n` leads, so both passages need the exception. After the alt-family sentence:

```markdown
`<M-n>` (new question, #263) joins that family, but its entry is the one place
the portable key does **not** lead: the operator asked for `<C-g>n` by name and
retired `chat_search` to free it, so `<C-g>n` is the gesture being taught and
help advertises it first. `outline` (`<C-g>t`, then `<M-t>`) has the same shape.
A rule page that does not record its own exceptions is the drift #214 removed.
```

- [x] **Step 3: Record the keyspace invariants in `atlas/ui/keybindings.md` § Scope Forest**

Task 5 promoted two rules from an alt-only test plus a registry comment into enforced invariants; the section that explains overlap semantics is where they belong. After the scope-forest diagram:

```markdown
Two invariants over this forest are enforced by `tests/unit/keybindings_spec.lua`
(#263), not by review:

1. **No key is live twice in the same buffer.** Two entries may share a key when
   their scopes are disjoint — `<M-CR>` is respond in a chat buffer and the
   review menu in a markdown one, and `<C-g>d` is chat-delete vs delete-file the
   same way — because a buffer is never both. What must not happen is two owners
   whose scopes overlap (one an ancestor of the other, or the same scope) *and*
   whose modes intersect: both bindings are then live at once and the later
   registration silently wins.
2. **No key delays another by being its prefix.** `<C-g>e` is unbound on purpose
   because `<C-g>em` and `<C-g>eh` exist; binding it would make both wait out
   `timeoutlen` on every press.

Both guards compare canonicalized notation (`keytrans` ∘ `replace_termcodes`),
so an override spelled `<C-G>n` cannot slip past them.
```

- [x] **Step 4: Add the action to `atlas/chat/lifecycle.md`**

After `## Creation`:

```markdown
## New Question (`:ParleyNewQuestion` / `<C-g>n` / `<M-n>`)

Opens an empty question after the exchange at the cursor. The insertion point
and its blank-line seam come from `exchange_clipboard` — the same definition
`<C-g>V` pastes against — so a pasted exchange and a new question are spaced
identically. `lua/parley/new_question.lua` decides the structure as a pure
plan; `M.cmd.NewQuestion` applies it through `buffer_edit`, which refuses while
a response is streaming into the region rather than corrupting the transcript.

Post-condition: the cursor sits at the end of a line that is the configured
user prefix followed by a space, in insert mode.
```

- [x] **Step 5: Verify the docs are wired**

`tests/integration/documentation_spec.lua` is what checks atlas link integrity, and it is routed under **`infra/starter`** (`atlas/traceability.yaml:55`) — *not* under `ui/keybindings` or `chat/lifecycle`. Running those two spec keys would report PASS while never executing the one check this step exists to perform. Run it directly:

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/documentation_spec.lua" -c "qa!"
```
Expected: PASS.

Then the two feature spec keys, for the code these docs describe:
```bash
make test-spec SPEC=ui/keybindings && make test-spec SPEC=chat/lifecycle
```
Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add atlas/
git commit -m "#263: atlas: the new-question chord and what it promises"
```

---

### Task 7: Full verification

- [x] **Step 1: Run the whole suite**

Run: `make test`
Expected: PASS. Watch specifically for `tests/unit/starter_config_spec.lua` and `tests/packaging/starter_probe.lua` — the app profile derives its key set from the registry, so `<C-g>n`/`<M-n>` reach the packaged app for free, but a spec that enumerated the old set would show up here.

- [x] **Step 2: Lint**

Run: `make lint`
Expected: clean.

- [x] **Step 3: Drive it by hand, once**

Open a real chat (`<C-g>c`), type a question, respond, put the cursor in the middle of the answer, press `<C-g>n`, type, and respond again. Then press `<C-g>n` from insert mode and press `u` once. A real press is the only oracle for a keymap (#231 M1 lesson). Record what happened in the issue's `## Log`.

- [x] **Step 4: Reconcile the issue before closing**

`sdlc close` enforces "the issue's `## Plan` has no unchecked items". Tick every box in `workshop/issues/000263-…md` `## Plan`, and confirm the restated Done-when in `## Revisions` is what the work actually satisfies — the original `## Spec` / `## Done when` bullets are superseded there, not deleted.

Then `sdlc issue sync --issue 263`.

- [x] **Step 5: Close**

```bash
sdlc close --issue 263 --verified 'unit 14/14 + integration 14/14 green; make lint 0/0 across 627 files; widened shadowing guard 0 collisions / 0 prefix shadows with both plants biting. NOT "full suite green": parley_harness_golden_spec fails and perf_document_spec is ~50% flaky, BOTH reproduced at the branch point and unrelated to this diff — see the issue Log.'
```

The `--actual` flag is deliberately absent: omitted, `close` measures and adopts the hours itself (active-time-v3). Never hand-type hours — a guessed value pollutes velocity calibration, which is the whole reason the `## Estimate` block above was derived rather than picked.

---

## Risks and open questions

1. **The insert-mode undo grouping (Task 4, case 4)** is the one behavior this plan asserts without having read it off existing code — no current Parley chord both edits the buffer and returns to insert mode. The plan commits to `stopinsert`-then-edit and names the fallback (`vim.schedule`) if the test says otherwise. It is a test, not an assumption, on purpose.
2. **The trailing space** (`💬: ` rather than the bare `💬:` the chat template and `chat_respond` write) is a deliberate third convention, and it is what the issue's Done-when asks for. It exists so `startinsert!` at end-of-line produces `💬: text`. The cost is a line with trailing whitespace if the user escapes immediately; the alternative costs a wrong-looking question line every time they do not.
3. **Retiring `chat_search` is user-visible.** Anyone with `<C-g>n` in muscle memory for "jump to the next question" loses it. It is a one-line `/` wrapper, the operator chose this explicitly over three alternatives, and the replacement is `/💬:`. Worth one line in the release notes if any are being written.

---

## Revisions

### 2026-09-16 — round 1 review disposition

Three fresh-context reviews ran against the first draft: one per chunk, plus
`sdlc change-code`'s plan-quality gate. Two of the three **executed** the plan's
literal module and literal unit spec in a real headless nvim rather than reading
them, which is what caught the blocking item below. Deltas:

**Blocking, from the plan-quality gate (PQ-1)** — the issue's `## Spec` and
`## Done when` still described the pre-revision cursor-position feature, so the
close gate would have judged this diff against criteria the design deliberately
does not satisfy. Fixed in the issue, not here: a restated, authoritative
Done-when now sits in `## Revisions` with the superseded clauses named.

**Blocking, from the chunk-1 review** — Task 2's first test asserted
`p.row < exchanges[2].question.line_start`, which **cannot pass**. Measured:
`p.after = 11`, `p.row = 12`, and exchange 2's pre-insertion `line_start` is
also 12, because `get_paste_line` returns the end of exchange 1 *including its
trailing blank*, so the new question takes exactly the row exchange 2 occupied.
Now `<=`, with the reasoning inline — and the troubleshooting note that pointed
at the parser (the wrong suspect entirely; `line_end` is never nil, per
`chat_parser.lua:998`) is replaced with a warning not to "fix" it by shrinking
`row`, which would destroy the seam the module exists to preserve.

**Task 4 was built on a misattribution** — `entity_textobj_spec.lua` does not
use `nvim_feedkeys`/`nvim_replace_termcodes` and does not drive the #262 chords
through real keymaps. The three techniques now cite three real sources:
`prepped()` there for the on-disk fixture (which is what gives case 5 real undo
history), `user_edit_callers_spec.lua:22-26` for firing a registry keymap, and
`open_reference_spec.lua:521-561` for the `vim.cmd` spy. `vim.fn.mode()` was
dropped outright: it appears in no test in this repo, and `startinsert!` from a
mapping callback is scheduled, so a synchronous read sees normal mode. The open
set grew from {4, 8} to {2, 3, 4, 5, 9} accordingly, and case 9's "reuse the
pending helper" became "follow `document_user_guards_spec`" — those helpers are
file-local, so it would have been a copy, not a reuse.

**Task 5 wrote its detection loop three times**, including inside the plant
meant to prove it — the exact defect the plan cites in Task 4 (an expectation
computed with the code under test agrees with itself), and ARCH-DRY. Now one
`owners_by_key` / `collisions` / `prefix_shadows` trio shared by both guards and
both plants. Also added, from review: `modes_overlap` (widening past the alt
family pulls in `{o,x}`-only text objects and normal-only `gf`/`gP`, which the
old filter never saw), `canon` via `keytrans` ∘ `replace_termcodes` (so an
override spelled `<C-G>n` cannot slip past a guard whose job is catching the
next collision), a second plant for the prefix rule, and assertions naming the
*offending entries* rather than `found == true`.

**Spec routing was scheduled too late.** `tests/arch/single_source_sweeps_spec.lua`
fails on a `NNNNNN-…` branch for any added-or-untracked spec no traceability
entry names — and it reads the working tree. Both new specs are now routed in
the commit that creates them (Tasks 2 and 4), not in Task 6; Task 3 Step 5's run
command changed to the spec file directly for the same reason.

**Task 6's stated oracle never ran.** `documentation_spec.lua` is routed under
`infra/starter`, so neither `SPEC=ui/keybindings` nor `SPEC=chat/lifecycle`
executes it — the step reported PASS while skipping its only check. Now invoked
directly. Two doc targets were also missing: `atlas/ui/keybindings.md`
§ Resolution states the "portable key leads" rule this entry departs from, and
§ Scope Forest is where the two new keyspace invariants belong.

**Both reviews caught the same prose contradiction** — atlas text called `<M-n>`
primary while the shipped config makes `<C-g>n` `keys[1]`, which is what help
renders first. All prose now leads with `<C-g>n`, and the departure from #214's
convention is recorded rather than silent.

**Task 7 would have hit a close-gate refusal** — nothing ticked the issue's
`## Plan`. Added as its own step, along with the literal `--verified` evidence
(the plan's only remaining placeholder) and a note that `--actual` stays absent
so `close` measures the hours instead of accepting a typed guess.

**ARCH-FUNERAL had no entry** (gate PQ-2). Added as a reasoned exemption rather
than a bare `N/A`.

Smaller fixes: Task 1's grep returns **four** lines, not three (the registry
entry matches on both `id` and `config_key`); Task 3 Step 5 named a `describe`
as though it were an `it`; the dead cursor-column computation in
`M.cmd.NewQuestion` is gone (`startinsert!` is `A` — only the row matters), with
an `assert(plan.row)` in its place; `is_empty_question`'s "already spaced" test
now requires a literal space, since a `💬:\t` line would otherwise yield
`💬:\thello`; and two unit cases were added — the tab normalization, and the
recorded decision that a *neighbouring* empty question is not adopted.

**Note on structure:** "Chunk 1" and "Chunk 2" are document organization for the
review loop, **not** SDLC milestones. There are no `Mx` tags and there is one
review boundary, at `sdlc close` (AGENTS.md §3).

### 2026-09-16 — boundary review disposition (close round 1, FIX-THEN-SHIP)

Eight findings, two blocking. The reviewer re-ran the whole suite and probed
header-cursor, EOF, closed-fold and two-press-with-typing shapes by hand.

**BR-1 / I1 (Important) — the "one undo step" clause was asserted for the
normal-mode press only.** The clause names *two* modes; the undo half was
tested in the mode where the insert path's `stopinsert` plays no part, so the
mechanism was untested exactly where it was at risk. The integration spec is
now **parameterized over `{ "n", "i" }`**, so a clause naming two modes is
asserted in both by construction — that is the class, not just the missing
case. The reviewer also ran the counterfactual and found an insert mapping
*without* `stopinsert` restores identically on one `u`: undo scope comes from
`document.apply_user`'s user transaction, not from the `stopinsert`. The
comment at `init.lua` no longer claims otherwise; `stopinsert` stays because it
mirrors `branch_ref`'s `i` handler, and the comment now says that instead.

**BR-2 / I2 (Important) — "the one place the portable key does not lead" was
false, and the same paragraph disproved it.** Measured over the registry: the
split is **even, 3–3**. `<C-g>`-leading: `outline`, `chat_drill_in`,
`new_question`. Alt-leading: `open_file`, `branch_ref`, `chat_prune`. The atlas
now states the measured split and explains the rule as scoped to cases where a
terminal cannot be relied on for the alt chord; `config.lua` and the registry
comment carry the same correction. The original claim was written from memory
of three entries — the fix was one probe away, which is the lesson.

**Minor — the preamble was on its fourth verbatim copy.** `chat_context(what)`
now owns `not_chat` → `find_header_end` → `parse_chat` → cursor, and
`ChatPrune`, `ExchangeCut`, `ExchangePaste` and `NewQuestion` all use it. Each
command keeps its own message wording through `what`. Verified green:
`topic_gen_spec` 9/9 (drives prune), `branch_child_spec`, `entity_textobj_spec`,
`chat_move_spec`, `new_question_spec` 14/14, lint 0/0.

**Minor — the streaming-refusal test stubbed a verdict.** Now labelled as the
double it is, with the evidence for why the realer options were rejected:
a second overlapping user capture is **measured to be allowed** (so it produces
no refusal), and a detached document silently re-attaches because
`buffer_edit.capture_user` does `document.get(buf) or document.attach(buf)`.
Driving a real generation needs `chat_pending_spec`'s file-local helpers.
Tracked as a follow-up rather than copied. The test now claims only what it
proves: that a refusal is caught and reported rather than raised or swallowed.

**Minor — the plan's literal `--verified` string was stale** ("unit 15/15 +
integration 10/10 green; make test full suite green"). Corrected to the
measured 14/14 + 14/14, and the "full suite green" claim replaced with the
named pre-existing failures.

**Minor — the atlas insertion swallowed a pre-existing sentence.** "`<C-g>` is
the prefix surface for everything else" is back with the paragraph it belongs
to.

**Minor — header-cursor placement was neither tested nor documented.** Now
both: an integration case pins that the question lands above the first
exchange, and `atlas/chat/lifecycle.md` names it as `get_paste_line`'s header
fallback and therefore `<C-g>V` parity.

**Not fixed, deliberately — the refusal-UX divergence.** `NewQuestion` pcalls
`replace_user_lines` and warns; the other twelve call sites let it raise a bare
Lua error. The reviewer notes the new behavior is the better one. Unifying
thirteen call sites changes error semantics across features this issue does not
otherwise touch, at close time — a separable extension, not the point of #263.
Filed as a follow-up issue instead of silently leaving it.

### 2026-09-16 — boundary review round 2: a repeat family, and the rule it forced

Round 2 confirmed BR-1/BR-2 fixed (it re-ran integration 14/14 including the
insert-mode undo) and raised three new items. One of them is the important one,
because it is the **second finding in the same family in consecutive rounds**.

**M2 — `duplicated-command-preamble`, 2nd occurrence.** Extracting
`chat_context` fixed the *site* the round-1 finding named and left the class
half-swept: three callers went on re-reading the cursor (`init.lua:4320`,
`:4482`, `:4592`) instead of consuming `ctx.cursor_line`, and `new_question`
had shipped its own copy of the exchange-scan that already lived inside
`get_paste_line`. The rule, written down because a family that repeats is the
ledger reporting the enumeration was never written:

> When a block is extracted into a shared helper, **every caller consumes every
> field the helper now owns**, and any new derivation of a concept the owning
> module already computes **calls that module** instead.

Swept in full this round: all three cursor re-readers now take `ctx.cursor_line`,
and `exchange_clipboard.exchange_index_at` is the single owner of "which
exchange is the cursor in", consumed by both `get_paste_line` and
`new_question.exchange_at`. Verified: `exchange_clipboard_spec` 31/31,
`entity_range_spec` 47/47, `topic_gen_spec` 9/9, `buffer_mutation_spec` 10/10,
`new_question` unit 14/14 + integration 15/15, lint 0/0.

**M3 — `assert(plan.row)` ran after the buffer write.** An unreachable nil row
would have left a half-applied edit behind a bare Lua error. Moved above the
write; it costs nothing there.

**Insert-mode fidelity.** Round 2 measured that `vim.cmd("startinsert")` inside
a busted `it()` does **not** change `mode()` — it still reports `n`. So the
`{"n","i"}` parameterization proves the `i` *mapping* is wired, not that the
command behaves mid-insert with typed text pending. A real case now drives
`nvim_feedkeys(replace_termcodes("A XYZ" .. key), "x", false)`: it asserts the
typed text survives, the chord fires, and the chord's write is its **own** undo
step (one `u` removes the new question, a second removes the typing). Also on
the record from round 2's counterfactual: one `u` restores identically with and
without `stopinsert`, even after typed text — `stopinsert` is house-idiom
consistency, not the undo mechanism.

**I1 — close-time artifacts were not reconciled.** All 40 plan steps are now
ticked. The rule: close-time artifacts are reconciled against the final run in
the closing commit — (a) `--verified` built from that run's output, (b) every
plan checkbox ticked or struck with a reason, (c) issue `## Plan` and durable
plan in agreement. Noted for the irony: Task 7 Step 4 ("Reconcile the issue
before closing") was itself the unticked step that would have caught the
other 39.

**Recorded, not fixed — `ExchangeCut` and `ExchangePaste` have no spec of their
own.** `grep -rln "ExchangeCut\|ExchangePaste\|ChatPrune" tests/` returns only
`topic_gen_spec` (prune). Pre-existing, not introduced here, but it is why a
preamble refactor at a close boundary had to be verified through neighbouring
specs rather than directly. Belongs with #265's test-fixture work.

### 2026-09-16 — boundary review round 3 (REWORK): three families, and the rules that end them

8 findings disposed, 4 new, 3 of them repeats. Round 3 is the round where the
*instances* stopped being the point.

**BR-9 (Critical) — a regression I introduced in round 2.** Hoisting
`exchange_index_at` in above `get_paste_line` put it *between* `get_paste_line`'s
`@param` block and its signature, so the doc block now documented the wrong
function. `tests/arch/superseded_comment_spec.lua` exists for exactly this and
went red. Fixed by giving the new function its own complete doc block and
placing it *before* `get_paste_line`'s, not inside it. The lesson is about
process, not about this file: round 2's verification ran the specs I expected to
be affected, not the arch suite that guards the kind of edit I had just made
(moving code). Moving code is a comment-adjacency hazard, and the repo already
knew it.

**BR-10 (Important) — `chat_context` was in the wrong table.** It was listed
under **Pure entities** while reading the current buffer, the current window and
the logger. Moved to Integration points, with the new module's three functions
listed and the reason each is a boundary and not a core entity.

**`duplicated-command-preamble`, 3rd occurrence — the rule, finally.** Rounds 1
and 2 each fixed what the finding named. Round 3 measured the real prevalence:
4 migrated in `init.lua`, **2 unmigrated in `chat_respond.lua`** (`respond`,
`respond_all`) that a *file-local* helper structurally could not reach, 1 partial
in `exporter.lua:965`, and 1 deliberate divergence in `delete_entity_range`
(which classifies through `entity_textobj.parsed_for` so the text objects and
the `:ParleyDelete*` commands cannot disagree — correctly excluded).

> **Rule:** the `not_chat → find_header_end → parse_chat` sequence has **one
> owner, reachable from any module** — `lua/parley/chat_context.lua`. It is
> written out nowhere else. The caller owns the *wording*, because the messages
> genuinely differ; the owner owns the *sequence*.

`init.lua`'s `chat_context(what)` is now only the command-entry wording over
that owner. `chat_respond.respond` and `respond_all` consume it too. The module
is deliberately **two-phase** (`chat_buffer` / `parse`) because `respond_all`
interleaves its batch precondition between the gates — a single `resolve` would
have made a header-less chat with an active batch report the wrong one. That
detail is the reason the first extraction was file-local and the family
survived: the second copy was not a copy, it was a copy *with an interleave*.

**`doc-claim-contradicts-code`, 2nd occurrence — the rule.** BR-2 corrected a
wrong count; the rule adopted then was manual ("run a probe before the sentence
ships"), and manual discipline is what produced the wrong count to begin with.
`tests/unit/keybindings_spec.lua` now **derives** the lead split from the
registry and pins both sides, plus a second case that flips one entry's key
order to prove the derivation reads `keys[1]` (what the help float renders)
rather than membership. A seventh dual-family pair now fails the suite instead
of silently making the page wrong.

**Verification.** unit 14/14, integration 15/15, keybindings **80/80**,
chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10, topic_gen 9/9,
exchange_clipboard 31/31, entity_range 47/47, superseded_comment 9/9,
buffer_mutation 10/10, single_source_sweeps 21/21, lint 0/0 across **628**
files. `make test-integration` clean apart from the known parallel-load flakes —
`branch_child_spec` failed once under 8-way parallelism and passes **62/62 three
times serially**; `perf_document_spec` is the already-recorded silent-death
class.
