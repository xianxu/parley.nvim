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
| `new_question.plan` | `lua/parley/new_question.lua` | new |
| `new_question.is_empty_question` | `lua/parley/new_question.lua` | new |
| `exchange_clipboard.get_paste_line` | `lua/parley/exchange_clipboard.lua` | unchanged (reused) |
| `exchange_clipboard.build_paste_lines` | `lua/parley/exchange_clipboard.lua` | unchanged (reused) |
| `chat_search` registry entry | `lua/parley/keybinding_registry.lua` | deleted |
| `chat_shortcut_search` option | `lua/parley/config.lua` | deleted |
| `new_question` registry entry | `lua/parley/keybinding_registry.lua` | new |
| `chat_shortcut_new_question` option | `lua/parley/config.lua` | new |

**Test surface implied by the table.** `lua/parley/new_question.lua` is pure — it takes a parsed chat and a line array, never a buffer, exactly like `entity_range.lua` (#262). Its unit spec (`tests/unit/new_question_spec.lua`) runs with no buffer, no mocks and no IO. The deleted `chat_search` entry has no test of its own to remove; the registry specs that enumerate entries are generic and stay.

- **`new_question.plan(parsed_chat, lines, cursor_line, header_end, user_prefix)`** — decides what the keystroke does, as a value.
  - Returns `{ kind = "insert", after = N, lines = {…}, row = R }` or `{ kind = "focus", after = nil, lines = {…} | nil, row = R }`. In both cases `row` is the 1-based line that will hold the question, and the **post-condition is the same**: after the shell applies the plan, `lines[row]` equals `user_prefix .. " "` — or the prefix followed by at least one space, if the line already had trailing whitespace.
  - **Relationships:** 1:1 with a keystroke; N:1 with `parsed_chat`. Holds no state (ARCH-ORDER: it is a pure function of its arguments, so there is no state to carry between events).
  - **DRY rationale:** It does not re-derive the exchange span or the blank-line seam — both come from `exchange_clipboard`, the module whose header already declares itself the owner of "an exchange includes its preface, question, and answer … including trailing blank lines". Without this, `<C-g>n` and `<C-g>V` would drift into two different ideas of where an exchange ends.
  - **Future extensions:** the natural axis is *what* gets opened — a `🔒:` local note or a `@@tag@@`-prefaced question. That widens as a `kind` argument feeding the `lines` it builds, not as a second function.

- **`new_question.is_empty_question(lines, exchange, user_prefix)`** — is this exchange an unanswered question with no body?
  - **DRY rationale:** first occurrence of the predicate as a *shared* helper. `outline.lua:259` has the same idea inline for display purposes; that one classifies an outline item, this one classifies a parsed exchange, and merging them would couple the outline's item shape to the parser's. Named and exported so the next caller reuses it rather than re-inlining a third copy.
  - **ARCH-SECURE:** `user_prefix` is operator configuration and is compared with `string.sub`, never interpolated into a Lua pattern. A prefix containing a magic character (`>`, `%`, `.`, `-`) must behave like any other string; `init.lua:3940` records what happened the last time runtime text reached a pattern position (#214 BR-34).

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.cmd.NewQuestion` | `lua/parley/init.lua` | new | buffer read/write, cursor, mode |
| `new_question` keymap callback | `lua/parley/init.lua` (chat `register_buffer` table) | new | Neovim keymap dispatch |

- **`M.cmd.NewQuestion`** — the IO shell. Guards with `M.not_chat`, reads lines, finds the header, parses, reads the cursor, calls `new_question.plan`, applies through `buffer_edit.replace_user_lines`, sets the cursor and calls `startinsert!`. Auto-registers as `:ParleyNewQuestion` via the `for cmd, _ in pairs(M.cmd)` loop at `init.lua:1317`.
  - **Injected into:** nothing — it is the outermost layer. It injects `M.config.chat_user_prefix` *into* the pure planner, which is what keeps an operator override honored without the planner knowing what config is.
  - **ARCH-MOCK:** N/A. This touches no external binary or service — only the current Neovim buffer. The integration spec drives the real editor, not a double.
  - **Future extensions:** a `{ before = true }` option if "new question *before* this exchange" is ever wanted; the planner already returns an `after` index, so only the index changes.

- **`new_question` keymap callback** — normal- and insert-mode entry points.
  - Normal mode calls the command directly. Insert mode leaves insert first (`stopinsert`) so the buffer write is not folded into the surrounding insert session's undo block, then the command's own `startinsert!` puts the cursor back in insert at the new line. This is the one behavior the plan cannot settle by reading code — Task 4 tests it (single-undo, correct mode) before it is called done.

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

- [ ] **Step 1: Confirm the blast radius is exactly those three sites**

Run:
```bash
grep -rn "chat_search\|chat_shortcut_search" --include="*.lua" --include="*.md" --include="*.txt" . | grep -v workshop/
```
Expected: exactly the three source lines above and nothing under `tests/`, `doc/`, `README.md` or `atlas/`. If anything else appears, it is a consumer this plan did not account for — stop and add it.

- [ ] **Step 2: Delete the config option**

Remove `lua/parley/config.lua:372`:
```lua
	chat_shortcut_search = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },
```

- [ ] **Step 3: Delete the registry entry**

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

- [ ] **Step 4: Delete the callback**

Remove `lua/parley/init.lua:2803-2808`:
```lua
			chat_search = function()
				local user_prefix = M.config.chat_user_prefix
				local branch_prefix = M.config.chat_branch_prefix
				vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(branch_prefix))
			end,
```

- [ ] **Step 5: Run the keybinding specs — they must still pass**

Run: `make test-spec SPEC=ui/keybindings`
Expected: PASS. Several specs assert "every registry entry can be disabled / rebound" and "help shows no key that is not bound"; removing an entry cleanly must not disturb them. A failure here means something outside the three sites referenced `chat_search`.

- [ ] **Step 6: Commit**

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

- [ ] **Step 1: Write the failing unit spec**

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
        -- It lands inside the transcript, before exchange 2 -- not appended at EOF.
        assert.is_true(p.row < parsed.exchanges[2].question.line_start)
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

- [ ] **Step 2: Run it to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/new_question_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.new_question' not found`.

- [ ] **Step 3: Write the minimal implementation**

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
		if lines[row] ~= user_prefix then
			return { kind = "focus", row = row }
		end
		-- Bare `💬:` -- give it the space the post-condition promises.
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

- [ ] **Step 4: Run the spec to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/new_question_spec.lua" -c "qa!"`
Expected: PASS, all cases.

If the "focus" cases fail because the parser does not produce a second exchange for a trailing bare `💬:`, that is a real finding about the parser, not a test bug — read `chat_parser.lua:700-735` before changing either side.

- [ ] **Step 5: Lint**

Run: `make lint`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/new_question.lua tests/unit/new_question_spec.lua
git commit -m "#263: where a new question goes, as a value"
```

---

### Task 3: Wire the command and the chord

**Files:**
- Modify: `lua/parley/init.lua` (add `M.cmd.NewQuestion` near `M.cmd.ExchangePaste`, ~line 4595; add `new_question` to the chat callback table at ~line 2800)
- Modify: `lua/parley/keybinding_registry.lua` (add the `new_question` entry where `chat_search` was)
- Modify: `lua/parley/config.lua` (add `chat_shortcut_new_question` where `chat_shortcut_search` was)

- [ ] **Step 1: Add the config option**

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

- [ ] **Step 2: Add the registry entry**

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

- [ ] **Step 3: Add the command**

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

	local row = math.min(plan.row, vim.api.nvim_buf_line_count(buf))
	local text = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	vim.api.nvim_win_set_cursor(0, { row, #text })
	vim.cmd("startinsert!")
end
```

- [ ] **Step 4: Wire the keymap callback**

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

- [ ] **Step 5: Verify the command and chord exist**

Run:
```bash
make test-spec SPEC=ui/keybindings
```
Expected: PASS. Three existing guards bear on this entry specifically:
- `<C-g>? can show every bound key` (line 695) — the new entry must appear in the chat help, and the reverse check must find no key bound that help does not show.
- `no alt key is live twice in the same buffer` (line 935) — `<M-n>` must be unowned elsewhere.
- `each shipped default preserves the entry's registry keys AND modes` (line 415) — `config.lua`'s `shortcut` list must be a superset of the registry's `default_key` list, and its `modes` a subset of `default_modes`. The plan ships both as `{ "<C-g>n", "<M-n>" }` / `{ "n", "i" }` precisely so this passes; if you change one, change both.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/init.lua lua/parley/keybinding_registry.lua lua/parley/config.lua
git commit -m "#263: <C-g>n / <M-n> opens a new question"
```

---

### Task 4: Prove it in a real editor

**Files:**
- Create: `tests/integration/new_question_spec.lua`

**Test strategy.** The unit spec proves the planner's arithmetic; this spec exists to test what the planner cannot see — the real keymap, the real modes, undo, and the streaming refusal. Its assertions are deliberately **not** derived from the code under test: question lines are counted with a plain `vim.startswith` scan of the buffer, not by re-parsing (the #262 lesson — a guard whose expectation is computed with its own predicates agrees with itself). The riskiest function here is the insert-mode callback, because the undo grouping is the one thing this plan asserts without having been able to read it off existing code.

- [ ] **Step 1: Write the failing integration spec**

Create `tests/integration/new_question_spec.lua`. Model the harness setup (temp chat dir, `parley.setup`, opening a real chat buffer, feeding keys with `vim.api.nvim_feedkeys` + `nvim_replace_termcodes`) on `tests/integration/entity_textobj_spec.lua`, which drives the #262 chords through the real keymaps. Cases:

1. **Normal mode, mid-transcript** — cursor on exchange 1 of a two-exchange chat, press `<C-g>n`. Independent oracle: the count of lines starting with `💬:` goes from 2 to 3, **and** the new one sits between the old first and second (compare line indices, not parser output).
2. **The new line is typed into correctly** — after the press, `vim.fn.mode()` is `i`, the cursor column is at end-of-line, and the line is exactly `💬: `. Then feed `hello<Esc>` and assert the line is `💬: hello` — the real proof that the trailing space is there.
3. **Insert mode** — start insert on an answer line, press `<C-g>n`, assert the same post-condition as (2).
4. **Single undo** — from case (1), press `u` once and assert the buffer is byte-identical to the pre-press snapshot. This is the assertion that judges the `stopinsert`-first decision in Task 3 Step 4; if it fails, the callback is wrong, not the test.
5. **No duplicate on a second press** — press `<C-g>n` twice with no typing in between; the `💬:` count goes 2 → 3, not 2 → 4.
6. **Empty chat** — a transcript with a header and nothing else; one press produces exactly one `💬: ` line below the `---`.
7. **Non-default prefix** — `parley.setup{ chat_user_prefix = ">>" }`, and the inserted line is `>> `.
8. **Refusal while streaming** — with a pending generation owning the region (reuse the pending-state helper from `tests/integration/chat_pending_spec.lua`), a press must leave the buffer unchanged and log a warning. Assert both: unchanged buffer *and* the warning, so a silent no-op cannot pass.

- [ ] **Step 2: Run it to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/new_question_spec.lua" -c "qa!"`
Expected: the cases that exercise behavior not yet correct fail. Cases 1-3 and 5-7 should already pass from Task 3; **cases 4 and 8 are the ones this task exists to settle.**

- [ ] **Step 3: Fix whatever cases 4 and 8 expose**

If case 4 fails, the insert-mode callback is folding the edit into the surrounding undo block — adjust the `i` handler (the likely fix is `vim.cmd("stopinsert")` followed by running the command from `vim.schedule`, at the cost of making the integration spec schedule-aware). If case 8 fails, `replace_user_lines` is not raising where expected — read `buffer_edit.capture_user`'s refusal path rather than adding a guard of your own.

- [ ] **Step 4: Run the full spec to verify it passes**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/new_question_spec.lua" -c "qa!"`
Expected: PASS, all eight cases.

- [ ] **Step 5: Commit**

```bash
git add tests/integration/new_question_spec.lua lua/parley/init.lua
git commit -m "#263: drive the chord through a real editor"
```

---

## Chunk 2: The guard and the docs

### Task 5: Generalize the shadowing guard (ARCH-PURPOSE)

The issue's Done-when says the chord must shadow no existing Parley chord, "verified against the keybinding registry". Today's guard (`tests/unit/keybindings_spec.lua:935`, `"no alt key is live twice in the same buffer"`) filters to `k:match("^<[Mm]%-")` — it inspects only alt keys and therefore **could not have caught this `<C-g>n` collision**, which is the exact class the issue names. Fixing only the one chord is the instance; the class is "no chord is live twice in the same buffer, and no chord delays another".

Measured before planning: under the wider rule the registry has **0** collisions today, so this generalization lands green rather than opening a cleanup.

**Files:**
- Modify: `tests/unit/keybindings_spec.lua:878-967` (the `describe` block holding the guard)

- [ ] **Step 1: Widen the guard and add prefix shadowing**

Replace the `it("no alt key is live twice in the same buffer", …)` body so it walks **every** resolved key, not just alt keys, and add a second `it` for prefix shadowing:

```lua
    -- #263: this was filtered to `^<[Mm]-` and so inspected one family out of
    -- three. It could not have caught <C-g>n being bound twice, which is the
    -- collision #263 actually hit. The rule is about a buffer, not a family.
    it("no key is live twice in the same buffer", function()
        local owners = {}
        for _, e in ipairs(reg.entries) do
            for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do
                owners[k] = owners[k] or {}
                table.insert(owners[k], e)
            end
        end
        local collisions = {}
        for key, entries in pairs(owners) do
            for i = 1, #entries do
                for j = i + 1, #entries do
                    if scopes_overlap(entries[i].scope, entries[j].scope) then
                        collisions[#collisions + 1] = ("%s -> %s(%s) + %s(%s)"):format(
                            key, entries[i].id, entries[i].scope,
                            entries[j].id, entries[j].scope)
                    end
                end
            end
        end
        table.sort(collisions)
        assert.same({}, collisions)
    end)

    -- A chord that is a PREFIX of another is not a silent overwrite -- it is a
    -- timeout. Binding <C-g>e would make <C-g>em and <C-g>eh wait for
    -- 'timeoutlen' on every press. That rule lives today as a comment above
    -- entity_delete in the registry; here it is a test.
    it("no key delays another by being its prefix", function()
        local owners = {}
        for _, e in ipairs(reg.entries) do
            for _, k in ipairs(reg.resolve_keys(e, parley.config) or {}) do
                owners[k] = owners[k] or {}
                table.insert(owners[k], e)
            end
        end
        local keys = {}
        for k in pairs(owners) do keys[#keys + 1] = k end
        local shadows = {}
        for _, short in ipairs(keys) do
            for _, long in ipairs(keys) do
                if short ~= long and #short < #long and long:sub(1, #short) == short then
                    for _, a in ipairs(owners[short]) do
                        for _, b in ipairs(owners[long]) do
                            if scopes_overlap(a.scope, b.scope) then
                                shadows[#shadows + 1] = ("%s(%s) delays %s(%s)"):format(
                                    short, a.id, long, b.id)
                            end
                        end
                    end
                end
            end
        end
        table.sort(shadows)
        assert.same({}, shadows)
    end)
```

- [ ] **Step 2: Prove the guard bites**

The existing `it("and the disjoint case is genuinely allowed, not accidentally passing", …)` proves `scopes_overlap`. Add one that proves the **widened** scan finds a real `<C-g>` double-bind — otherwise a guard that reports nothing is indistinguishable from a guard that looks at nothing:

```lua
    it("and the widened scan really would catch a <C-g> double-bind", function()
        -- Give an existing entry a chord another entry already owns in an
        -- overlapping scope, then run the same detection over the result.
        local keys = { outline = { "<C-g>k" } } -- <C-g>k is entity_delete (parley_buffer)
        local owners = {}
        for _, e in ipairs(reg.entries) do
            for _, k in ipairs(keys[e.id] or reg.resolve_keys(e, parley.config) or {}) do
                owners[k] = owners[k] or {}
                table.insert(owners[k], e)
            end
        end
        local found = false
        for _, entries in pairs(owners) do
            for i = 1, #entries do
                for j = i + 1, #entries do
                    if scopes_overlap(entries[i].scope, entries[j].scope) then found = true end
                end
            end
        end
        assert.is_true(found, "the widened scan reported nothing on a planted collision")
    end)
```

- [ ] **Step 3: Run the keybinding specs**

Run: `make test-spec SPEC=ui/keybindings`
Expected: PASS — including the two widened guards on the real registry, and the planted-collision case.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/keybindings_spec.lua
git commit -m "#263: the shadowing guard covers every chord, not just alt"
```

---

### Task 6: Documentation

The repo has **no** which-key integration; the keybinding registry is the single source and `<C-g>?` help is generated from it, so Task 3's registry entry already published the chord to help. What remains is the atlas.

**Files:**
- Modify: `atlas/ui/keybindings.md` (`## Common transcript actions`, ~line 15-34)
- Modify: `atlas/chat/lifecycle.md` (a new `## New Question` section, after `## Creation`)
- Modify: `atlas/traceability.yaml` (`ui/keybindings` and `chat/lifecycle` code+test lists)

- [ ] **Step 1: Add the chord to `atlas/ui/keybindings.md`**

In `## Common transcript actions`, after the structural-editing paragraph:

```markdown
`<M-n>` (alias `<C-g>n`) opens a new, empty `💬:` question immediately after the
exchange the cursor is in, and leaves the cursor in insert mode on it. It reads
`chat_user_prefix`, so an operator override is what gets written. Pressing it on
an exchange that is already an empty question focuses that question rather than
adding a second one. This is the end-user path to a question line — the emoji is
not on the keyboard, and nothing here needs the clipboard.
```

- [ ] **Step 2: Add the action to `atlas/chat/lifecycle.md`**

After `## Creation`:

```markdown
## New Question (`:ParleyNewQuestion` / `<M-n>` / `<C-g>n`)

Opens an empty question after the exchange at the cursor. The insertion point
and its blank-line seam come from `exchange_clipboard` — the same definition
`<C-g>V` pastes against — so a pasted exchange and a new question are spaced
identically. `lua/parley/new_question.lua` decides the structure as a pure
plan; `M.cmd.NewQuestion` applies it through `buffer_edit`, which refuses while
a response is streaming into the region rather than corrupting the transcript.

Post-condition: the cursor sits at the end of a line that is the configured
user prefix followed by a space, in insert mode.
```

- [ ] **Step 3: Update `atlas/traceability.yaml`**

Add `lua/parley/new_question.lua` to the `ui/keybindings` and `chat/lifecycle` `code:` lists, and `tests/unit/new_question_spec.lua` + `tests/integration/new_question_spec.lua` to both `tests:` lists.

- [ ] **Step 4: Verify the docs are wired**

Run: `make test-spec SPEC=ui/keybindings && make test-spec SPEC=chat/lifecycle`
Expected: PASS. `tests/integration/documentation_spec.lua` checks atlas link integrity; a broken reference fails here.

- [ ] **Step 5: Commit**

```bash
git add atlas/
git commit -m "#263: atlas: the new-question chord and what it promises"
```

---

### Task 7: Full verification

- [ ] **Step 1: Run the whole suite**

Run: `make test`
Expected: PASS. Watch specifically for `tests/unit/starter_config_spec.lua` and `tests/packaging/starter_probe.lua` — the app profile derives its key set from the registry, so `<C-g>n`/`<M-n>` reach the packaged app for free, but a spec that enumerated the old set would show up here.

- [ ] **Step 2: Lint**

Run: `make lint`
Expected: clean.

- [ ] **Step 3: Drive it by hand, once**

Open a real chat (`<C-g>c`), type a question, respond, put the cursor in the middle of the answer, press `<C-g>n`, type, and respond again. A real press is the only oracle for a keymap (#231 M1 lesson). Record the result in the issue's `## Log`.

- [ ] **Step 4: Close**

```bash
sdlc close --issue 263 --verified '<evidence>'
```

---

## Risks and open questions

1. **The insert-mode undo grouping (Task 4, case 4)** is the one behavior this plan asserts without having read it off existing code — no current Parley chord both edits the buffer and returns to insert mode. The plan commits to `stopinsert`-then-edit and names the fallback (`vim.schedule`) if the test says otherwise. It is a test, not an assumption, on purpose.
2. **The trailing space** (`💬: ` rather than the bare `💬:` the chat template and `chat_respond` write) is a deliberate third convention, and it is what the issue's Done-when asks for. It exists so `startinsert!` at end-of-line produces `💬: text`. The cost is a line with trailing whitespace if the user escapes immediately; the alternative costs a wrong-looking question line every time they do not.
3. **Retiring `chat_search` is user-visible.** Anyone with `<C-g>n` in muscle memory for "jump to the next question" loses it. It is a one-line `/` wrapper, the operator chose this explicitly over three alternatives, and the replacement is `/💬:`. Worth one line in the release notes if any are being written.
