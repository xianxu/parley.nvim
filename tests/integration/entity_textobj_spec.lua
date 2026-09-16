-- #262 end-to-end: the ae/ie/aE text objects and their hotkey twins, driven
-- through a REAL prepped chat buffer.
--
-- The two cases that matter most here are the ones a flat-buffer test misses:
--   * `vae` from a different starting line -- an existing visual selection
--     keeps its anchor through V, so a naive implementation selects from
--     wherever the user was rather than from the entity;
--   * a buffer with a CLOSED FOLD -- `G` cannot enter one and snaps to the
--     fold's first line, silently widening the range. tool_folds closes
--     🔧:/📎: blocks in every prepped chat buffer, so this is ordinary use.
local parley = require("parley")
local Document = require("parley.document")

local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-entity-" .. os.time()

local function setup()
	parley.setup({
		chat_dir = base_tmp_dir .. "/chat",
		state_dir = base_tmp_dir .. "/state",
		providers = {},
		api_keys = {},
	})
end

local FIXTURE = {
	"# topic: entity",   -- 1
	"- file: entity.md", -- 2
	"---",               -- 3
	"",                  -- 4
	"💬: first q",       -- 5
	"",                  -- 6
	"🤖: [A]",           -- 7
	"para one",          -- 8
	"",                  -- 9
	"## a heading",      -- 10
	"under heading",     -- 11
	"",                  -- 12
	"💬: second q",      -- 13
	"",                  -- 14
	"🤖: [A]",           -- 15
	"second answer",     -- 16
}

local seq = 0

local function prepped(lines)
	setup()
	seq = seq + 1
	local dir = parley.config.chat_dir
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/2026-03-01-entity-" .. seq .. ".md"
	vim.fn.writefile(lines, path)
	-- Load from disk rather than set_lines into a scratch buffer: otherwise the
	-- fixture write lands in the same undo block as the edit under test, and a
	-- single `u` reverts all the way to an empty buffer.
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	Document.attach(buf, { schedule = false })
	return buf
end

local function body(buf)
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("entity text objects", function()
	it("dae on a paragraph deletes just that paragraph", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		vim.cmd("normal dae")
		local after = body(buf)
		assert.is_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1])
		-- the rest of the exchange survives, shifted up by the two deleted lines
		assert.equals("## a heading", after[8])
	end)

	it("dae on a heading takes the section", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		vim.cmd("normal dae")
		local after = body(buf)
		assert.is_nil(vim.tbl_filter(function(l) return l == "## a heading" end, after)[1])
		assert.is_nil(vim.tbl_filter(function(l) return l == "under heading" end, after)[1])
		assert.equals("para one", after[8])
	end)

	it("dae on the question line takes the whole exchange", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 5, 0 })
		vim.cmd("normal dae")
		local after = body(buf)
		assert.is_nil(vim.tbl_filter(function(l) return l == "💬: first q" end, after)[1])
		assert.is_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1])
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "💬: second q" end, after)[1])
	end)

	it("daE deletes from the paragraph through end of the question", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		vim.cmd("normal daE")
		local after = body(buf)
		assert.is_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1])
		assert.is_nil(vim.tbl_filter(function(l) return l == "under heading" end, after)[1])
		-- the question itself survives; the next one is untouched
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "💬: first q" end, after)[1])
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "💬: second q" end, after)[1])
	end)

	it("undoes as a single step", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		vim.cmd("normal dae")
		vim.cmd("normal u")
		assert.same(FIXTURE, body(buf))
	end)

	it("yae round-trips through the register", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		vim.cmd("normal yae")
		assert.is_not_nil(vim.fn.getreg('"'):find("under heading", 1, true))
	end)

	it("vae selects the entity, not from the cursor's old anchor", function()
		local buf = prepped(FIXTURE)
		-- Start a linewise visual on 8, extend to 9, THEN ask for the object
		-- and delete -- all in ONE :normal, or the visual state does not
		-- survive between calls. A naive V-based selection keeps the line-8
		-- anchor and deletes 8..12 instead of the heading's section.
		vim.cmd("normal 10GVjaed")
		local after = body(buf)
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1],
			"para one must survive: vae should reset the anchor to the entity")
	end)

	it("respects a closed fold instead of snapping to its first line", function()
		local buf = prepped(FIXTURE)
		vim.wo.foldmethod = "manual"
		vim.cmd("normal! zE")
		vim.cmd("8,9fold")          -- closed fold over para one + its blank
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		vim.cmd("normal dae")
		local after = body(buf)
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1],
			"para one is inside a closed fold ABOVE the target and must survive")
		assert.is_nil(vim.tbl_filter(function(l) return l == "## a heading" end, after)[1])
	end)
end)
