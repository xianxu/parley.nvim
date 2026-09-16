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

-- THE RULE: a parity spec must vary every axis along which the two surfaces
-- could disagree, and each axis must be demonstrated red WITHOUT its fix.
-- Varying only the cursor row is what let two separate divergences ship green.
--
-- Axis enumeration for this spec -- add to it rather than rediscovering it:
--   (a) cursor row          -- done, every row 1..#FIXTURE
--   (b) classification      -- done, chat-classified vs markdown-classified
--                              filename (not_chat rejects on the name alone)
--   (c) document shape      -- done, the header mutilated two ways below
--   (d) fold state          -- done, every fixture carries a closed fold
--   (e) in-flight generation -- NOT an axis: the surfaces are DOCUMENTED to
--                              differ there (the command inherits
--                              buffer_edit's refusal, the operator does not),
--                              which is why this spec is scoped to a
--                              quiescent document.
local SHAPES = {
	{ name = "chat-classified", file = "2026-03-01-parity-%d.md" },
	-- not_chat rejects on the filename alone, so this is structurally the same
	-- transcript that parley classifies markdown -- the axis BR-2 lived on.
	{ name = "markdown-classified", file = "parity-notes-%d.md" },
	-- header mutilated ON DISK: classified before the surfaces ever see it.
	{ name = "no-separator", file = "2026-03-01-parity-%d.md", drop = 3 },
	{ name = "no-file-header", file = "2026-03-01-parity-%d.md", drop = 2 },
	-- header mutilated IN THE BUFFER, after classification. This is the axis
	-- BR-2 actually lived on and the one the on-disk shapes above could not
	-- see: the latch still says "chat" while not_chat now says "missing header
	-- separator", so a command that re-asks not_chat gets a different answer
	-- than an object that reads the latch. Verified red without its fix.
	{ name = "separator-edited-away", file = "2026-03-01-parity-%d.md", edit = 3 },
}

local shape = SHAPES[1]

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
	local path = dir .. "/" .. shape.file:format(seq)
	local content = vim.deepcopy(FIXTURE)
	if shape.drop then
		table.remove(content, shape.drop)
	end
	vim.fn.writefile(content, path)
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	Document.attach(buf, { schedule = false })
	if shape.edit then
		-- AFTER classification: the latch keeps saying "chat" while the
		-- document stops parsing, which is exactly the state BR-2 diverged in.
		vim.cmd(("silent! %ddelete _"):format(shape.edit))
	end
	-- a closed fold over the tool block, as tool_folds would produce
	vim.wo.foldmethod = "manual"
	vim.cmd("normal! zE")
	vim.cmd("14,17fold")
	return buf
end

--- The fixture as this shape writes it, and therefore how many rows exist.
local function content_for(s)
	local content = vim.deepcopy(FIXTURE)
	if s.drop then table.remove(content, s.drop) end
	if s.edit then table.remove(content, s.edit) end
	return content
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
	for _, s in ipairs(SHAPES) do
		it(("dae and :ParleyDeleteEntity agree on every row (%s)"):format(s.name), function()
			shape = s
			for row = 1, #content_for(s) do
				local native = run(row, function() vim.cmd("normal dae") end)
				local command = run(row, function() vim.cmd("ParleyDeleteEntity") end)
				assert.same(native, command,
					("%s: surfaces diverge at row %d (%q)"):format(s.name, row, FIXTURE[row]))
			end
		end)

		it(("daE and :ParleyDeleteToEnd agree on every row (%s)"):format(s.name), function()
			shape = s
			for row = 1, #content_for(s) do
				local native = run(row, function() vim.cmd("normal daE") end)
				local command = run(row, function() vim.cmd("ParleyDeleteToEnd") end)
				assert.same(native, command,
					("%s: surfaces diverge at row %d (%q)"):format(s.name, row, FIXTURE[row]))
			end
		end)
	end

	-- Scoped to shapes that HAVE a header. Strip the `---` and the document is
	-- no longer transcript-shaped, so there is nothing to floor and ordinary
	-- markdown rules are correct -- which is the contract, not an exception.
	it("never reaches into a header that exists, in any document shape", function()
		local chat_parser = require("parley.chat_parser")
		for _, s in ipairs(SHAPES) do
			shape = s
			local intact = content_for(s)
			local header_end = chat_parser.transcript_header_end(intact)
			if header_end then
				for row = 1, header_end do
					assert.same(intact, run(row, function() vim.cmd("normal dae") end),
						("%s: row %d is header metadata"):format(s.name, row))
				end
			else
				-- No `---` left, so the document is not transcript-shaped and
				-- there is nothing to floor. Ordinary markdown rules are the
				-- contract here, not an exception to it.
				assert.is_truthy(s.drop == 3 or s.edit == 3,
					s.name .. " lost its header without removing the separator")
			end
		end
	end)
end)
