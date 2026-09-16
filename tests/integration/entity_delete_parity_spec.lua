-- #262: the text object and the :Parley command must produce IDENTICAL
-- buffers, for every cursor row, or the "two surfaces, one range function"
-- design is a claim rather than a fact.
--
-- Scoped deliberately to a QUIESCENT document: the command path inherits
-- buffer_edit.replace_user_lines' refusal while a response streams into the
-- exchange and the native operator does not. That asymmetry is intended and
-- documented (ARCH-ORDER); everything else must match.
--
-- The fixture carries a CLOSED FOLD, because `G` cannot enter one and snaps to
-- its first line. A flat-buffer version of this test passes while the feature
-- is broken in the editor.
local parley = require("parley")
local Document = require("parley.document")

local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-parity-" .. os.time()

local FIXTURE = {
	"# topic: parity",   -- 1
	"- file: parity.md", -- 2
	"---",               -- 3
	"",                  -- 4
	"@@tagged@@",        -- 5
	"💬: first q",       -- 6
	"",                  -- 7
	"🤖: [A]",           -- 8
	"para one",          -- 9
	"",                  -- 10
	"## a heading",      -- 11
	"under heading",     -- 12
	"",                  -- 13
	"🔧: tool call",     -- 14
	"```json",           -- 15
	"{}",                -- 16
	"```",               -- 17
	"",                  -- 18
	"📝: a summary",     -- 19
	"",                  -- 20
	"💬: second q",      -- 21
	"",                  -- 22
	"🤖: [A]",           -- 23
	"second answer",     -- 24
}

local seq = 0

local function fresh()
	seq = seq + 1
	parley.setup({
		chat_dir = base_tmp_dir .. "/chat",
		state_dir = base_tmp_dir .. "/state",
		providers = {},
		api_keys = {},
	})
	local dir = parley.config.chat_dir
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/2026-03-01-parity-" .. seq .. ".md"
	vim.fn.writefile(FIXTURE, path)
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	Document.attach(buf, { schedule = false })
	-- a closed fold over the tool block, as tool_folds would produce
	vim.wo.foldmethod = "manual"
	vim.cmd("normal! zE")
	vim.cmd("14,17fold")
	return buf
end

local function run(row, action)
	local buf = fresh()
	vim.api.nvim_win_set_cursor(0, { row, 0 })
	action()
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- Rows 1-3 are the transcript header. They are covered deliberately: the
-- earlier `for row = 4` is exactly why a whole-transcript delete shipped
-- green, and Done-when claims parity over EVERY cursor row.
describe("entity delete parity", function()
	it("dae and :ParleyDeleteEntity agree on every cursor row", function()
		for row = 1, #FIXTURE do
			local native = run(row, function() vim.cmd("normal dae") end)
			local command = run(row, function() vim.cmd("ParleyDeleteEntity") end)
			assert.same(native, command, ("surfaces diverge at row %d (%q)"):format(row, FIXTURE[row]))
		end
	end)

	it("daE and :ParleyDeleteToEnd agree on every cursor row", function()
		for row = 1, #FIXTURE do
			local native = run(row, function() vim.cmd("normal daE") end)
			local command = run(row, function() vim.cmd("ParleyDeleteToEnd") end)
			assert.same(native, command, ("surfaces diverge at row %d (%q)"):format(row, FIXTURE[row]))
		end
	end)
end)
