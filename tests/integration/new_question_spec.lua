-- #263 end-to-end: <C-g>n / <M-n> opens a new empty question after the
-- exchange at the cursor, driven through a REAL prepped chat buffer.
--
-- Three things here cannot be tested at the unit level, and each one needed a
-- different existing spec as its model:
--   * firing the chord -- through the registry's resolved key and the real
--     mapping callback (the idiom in tests/integration/user_edit_callers_spec.lua),
--     not vim.cmd("normal ...");
--   * "did it enter insert" -- `startinsert!` from a mapping callback is
--     SCHEDULED, so vim.fn.mode() read synchronously still says normal. The
--     repo's way of asserting this is a vim.cmd spy that outlives the callback
--     (tests/integration/open_reference_spec.lua:521-561);
--   * single-undo -- which only means anything on a buffer loaded from disk,
--     because a set_lines fixture puts the fixture write and the edit under
--     test in one undo block and `u` empties the buffer.
--
-- The question-count oracle deliberately scans buffer text with a plain
-- vim.startswith rather than re-parsing: a guard whose expectation is computed
-- by the code under test agrees with itself (#262).
local parley = require("parley")
local Document = require("parley.document")
local Registry = require("parley.keybinding_registry")

local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-newq-" .. os.time()

local function setup(extra)
	parley.setup(vim.tbl_extend("force", {
		chat_dir = base_tmp_dir .. "/chat",
		state_dir = base_tmp_dir .. "/state",
		providers = {},
		api_keys = {},
	}, extra or {}))
end

local FIXTURE = {
	"# topic: newq",   -- 1
	"- file: newq.md", -- 2
	"---",             -- 3
	"",                -- 4
	"💬: first q",     -- 5
	"",                -- 6
	"🤖: [A]",         -- 7
	"first answer",    -- 8
	"",                -- 9
	"💬: second q",    -- 10
	"",                -- 11
	"🤖: [A]",         -- 12
	"second answer",   -- 13
}

local seq = 0

local function prepped(lines, extra)
	setup(extra)
	seq = seq + 1
	local dir = parley.config.chat_dir
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/2026-03-01-newq-" .. seq .. ".md"
	vim.fn.writefile(lines, path)
	-- From disk, not set_lines: otherwise the fixture write shares an undo
	-- block with the edit under test and a single `u` empties the buffer.
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	Document.attach(buf, { schedule = false })
	return buf
end

local function body(buf)
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

--- Fire the chord through its real mapping, capturing the commands it issues.
--- Returns the concatenated vim.cmd calls so `startinsert` can be asserted.
local function press(mode)
	local key = Registry.key_for("new_question", parley.config)
	assert.is_truthy(key, "new_question resolved to no key")
	local mapping = vim.fn.maparg(key, mode or "n", false, true)
	assert.equals("function", type(mapping.callback),
		"no buffer-local callback for " .. tostring(key) .. " in mode " .. (mode or "n"))

	local cmds = {}
	local real_cmd = vim.cmd
	vim.cmd = function(c)
		table.insert(cmds, tostring(c))
		return real_cmd(c)
	end
	local ok, err = pcall(mapping.callback)
	-- `startinsert` is scheduled, so the spy has to outlive the callback.
	-- Restoring first is why the first version of this saw nothing.
	vim.wait(50, function() return false end)
	vim.cmd = real_cmd
	assert(ok, err)
	return table.concat(cmds, "\n")
end

--- Independent oracle: count question lines by plain text scan.
local function question_count(buf, prefix)
	local n = 0
	for _, l in ipairs(body(buf)) do
		if vim.startswith(l, prefix or "💬:") then n = n + 1 end
	end
	return n
end

local function question_rows(buf, prefix)
	local rows = {}
	for i, l in ipairs(body(buf)) do
		if vim.startswith(l, prefix or "💬:") then rows[#rows + 1] = i end
	end
	return rows
end

describe("new question chord", function()
	it("opens a question after the cursor's exchange, not at the end", function()
		local buf = prepped(FIXTURE)
		assert.equals(2, question_count(buf))
		-- cursor inside exchange 1's ANSWER
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		press()
		assert.equals(3, question_count(buf))
		local rows = question_rows(buf)
		-- the new one sits between the old first and the old second
		assert.equals(5, rows[1])
		assert.is_true(rows[2] > 5 and rows[2] < rows[3])
		vim.cmd("stopinsert")
	end)

	it("writes the prefix with a trailing space and asks for insert", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		local cmds = press()
		assert.is_truthy(cmds:match("startinsert"), "no startinsert was issued")
		local row = vim.api.nvim_win_get_cursor(0)[1]
		assert.equals("💬: ", body(buf)[row])
		vim.cmd("stopinsert")
	end)

	it("typing into the new question produces a spaced question line", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		press()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local text = body(buf)[row]
		vim.api.nvim_buf_set_text(buf, row - 1, #text, row - 1, #text, { "hello" })
		assert.equals("💬: hello", body(buf)[row])
		vim.cmd("stopinsert")
	end)

	-- The restated Done-when says "works from normal AND insert mode, and is one
	-- undo step" -- ONE clause over two modes. The first version asserted the
	-- undo half for normal only, which is exactly the mode where the insert
	-- path's `stopinsert` plays no part, so the clause was untested where it was
	-- actually at risk (#263 close review I1). Parameterising is the fix: a
	-- clause naming two modes gets asserted in both, by construction.
	for _, mode in ipairs({ "n", "i" }) do
		local label = mode == "n" and "normal" or "insert"

		it("opens and enters insert from " .. label .. " mode", function()
			local buf = prepped(FIXTURE)
			vim.api.nvim_win_set_cursor(0, { 8, 0 })
			if mode == "i" then vim.cmd("startinsert") end
			local cmds = press(mode)
			assert.is_truthy(cmds:match("startinsert"),
				"no startinsert from the " .. label .. "-mode map")
			assert.equals(3, question_count(buf))
			local row = vim.api.nvim_win_get_cursor(0)[1]
			assert.equals("💬: ", body(buf)[row])
			vim.cmd("stopinsert")
		end)

		it("is a single undo step from " .. label .. " mode", function()
			local buf = prepped(FIXTURE)
			local before = body(buf)
			vim.api.nvim_win_set_cursor(0, { 8, 0 })
			if mode == "i" then vim.cmd("startinsert") end
			press(mode)
			vim.cmd("stopinsert")
			assert.equals(3, question_count(buf))
			vim.cmd("silent normal! u")
			assert.same(before, body(buf))
		end)
	end

	it("does not duplicate on a second press", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		press()
		vim.cmd("stopinsert")
		press()
		vim.cmd("stopinsert")
		assert.equals(3, question_count(buf))
	end)

	it("opens the first question in a chat that has none", function()
		-- Six lines, not four: not_chat rejects a buffer under 5 lines
		-- (init.lua:1816), so a minimal header-only fixture never gets prepped
		-- and the chord is simply not bound in it.
		local buf = prepped({
			"# topic: empty", "- file: empty.md", "- tags:", "---", "", "",
		})
		assert.equals(0, question_count(buf))
		vim.api.nvim_win_set_cursor(0, { 5, 0 })
		press()
		assert.equals(1, question_count(buf))
		assert.equals("💬: ", body(buf)[question_rows(buf)[1]])
		vim.cmd("stopinsert")
	end)

	it("honors an overridden chat_user_prefix", function()
		local buf = prepped({
			"# topic: pfx", "- file: pfx.md", "---", "",
			">> first q", "", "🤖: [A]", "an answer",
		}, { chat_user_prefix = ">>" })
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		press()
		assert.equals(2, question_count(buf, ">>"))
		local row = vim.api.nvim_win_get_cursor(0)[1]
		assert.equals(">> ", body(buf)[row])
		vim.cmd("stopinsert")
	end)

	it("does not adopt the next exchange's empty question", function()
		local buf = prepped({
			"# topic: next", "- file: next.md", "---", "",
			"💬: first q", "", "🤖: [A]", "first answer", "",
			"💬:",
		})
		assert.equals(2, question_count(buf))
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		press()
		-- inserts rather than jumping forward to the empty one below
		assert.equals(3, question_count(buf))
		vim.cmd("stopinsert")
	end)

	it("focuses an existing empty question rather than adding one", function()
		local buf = prepped({
			"# topic: focus", "- file: focus.md", "---", "",
			"💬: first q", "", "🤖: [A]", "first answer", "",
			"💬:",
		})
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		press()
		assert.equals(2, question_count(buf))
		assert.equals("💬: ", body(buf)[10])
		assert.equals(10, vim.api.nvim_win_get_cursor(0)[1])
		vim.cmd("stopinsert")
	end)

	-- A DOUBLE at the buffer_edit seam, and labelled as one. It proves that
	-- NewQuestion catches a refusal and reports it visibly instead of raising a
	-- bare Lua error at the user or silently doing nothing. It does NOT prove
	-- that a live generation produces that refusal (#263 close review, minor).
	--
	-- Two realer options were tried and rejected on evidence:
	--   * a second overlapping user capture -- MEASURED to be allowed, so it
	--     produces no refusal at all;
	--   * a detached document -- buffer_edit.capture_user does
	--     `document.get(buf) or document.attach(buf)`, so it silently re-attaches
	--     and the edit goes through.
	-- Driving a real generation needs chat_pending_spec's file-local helpers,
	-- which are not exported; that is tracked as a follow-up rather than copied
	-- here. See the plan's ## Revisions.
	it("catches a refusal and reports it instead of raising or no-op'ing", function()
		local buf = prepped(FIXTURE)
		local before = body(buf)
		local warned = {}
		local real_warning = parley.logger.warning
		parley.logger.warning = function(m) table.insert(warned, tostring(m)) end

		local edits = require("parley.buffer_edit")
		local real_capture = edits.capture_user
		edits.capture_user = function() return nil, "response is streaming" end

		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		local ok = pcall(parley.cmd.NewQuestion)

		edits.capture_user = real_capture
		parley.logger.warning = real_warning

		assert.is_true(ok, "NewQuestion propagated the refusal instead of reporting it")
		assert.same(before, body(buf))
		assert.is_true(#warned > 0, "refusal was silent")
		assert.is_truthy(table.concat(warned, "\n"):match("NewQuestion stopped"))
	end)

	-- Verified by hand during the close review: with the cursor in the front
	-- matter the question lands ABOVE the first exchange. That is correct
	-- <C-g>V parity (get_paste_line falls back to header_end), and it was
	-- neither tested nor documented until the review asked.
	it("opens above the first exchange when the cursor is in the header", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
		press()
		assert.equals(3, question_count(buf))
		local rows = question_rows(buf)
		-- the new one is FIRST, above what used to be the opening question
		assert.is_true(rows[1] < rows[2])
		assert.equals("💬: ", body(buf)[rows[1]])
		vim.cmd("stopinsert")
	end)
end)
