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

	-- REGRESSION (M1 boundary review, Critical): `# topic:` is a valid level-1
	-- heading that nothing outranks, so before the header floor a `dae` on
	-- line 1 emptied the whole transcript. Parity alone would NOT catch this --
	-- both surfaces agreed on deleting everything.
	it("leaves the transcript untouched from the header", function()
		for row = 1, 3 do
			local buf = prepped(FIXTURE)
			vim.api.nvim_win_set_cursor(0, { row, 0 })
			vim.cmd("normal dae")
			assert.same(FIXTURE, body(buf),
				("row %d is header metadata: dae must be a no-op"):format(row))
			vim.cmd("normal daE")
			assert.same(FIXTURE, body(buf))
		end
	end)

	-- The realistic degradation path: the buffer was a VALID chat when parley
	-- classified it at BufEnter, and the user then edits the `---` away. The
	-- latch still says "chat", the parse now fails, and the range would lose
	-- both its header floor and its exchange clamp. A file that never had a
	-- header is a different case -- parley classifies it markdown from the
	-- start, and markdown semantics are then correct.
	it("refuses rather than degrading when the header is edited away", function()
		local buf = prepped(FIXTURE)
		vim.cmd("silent! 3delete _")   -- the user removes the --- separator
		local broken = body(buf)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		vim.cmd("normal dae")
		assert.same(broken, body(buf),
			"an unparsable chat must refuse, not fall back to unclamped markdown rules")
	end)

	-- REGRESSION (M1 round 2, Critical): the first fix took the floor from
	-- `parsed`, which is nil whenever not_chat rejects the buffer -- and it
	-- rejects for five reasons that have nothing to do with document shape. A
	-- transcript saved under a non-timestamped name is classified markdown,
	-- still gets the text object installed, and had no floor.
	it("floors a transcript that parley classifies as markdown", function()
		setup()
		local dir = parley.config.chat_dir
		vim.fn.mkdir(dir, "p")
		local path = dir .. "/notes-about-entities.md"   -- no timestamp => markdown
		vim.fn.writefile(FIXTURE, path)
		vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
		local buf = vim.api.nvim_get_current_buf()
		parley.setup_markdown_keymaps(buf)
		Document.attach(buf, { schedule = false })

		assert.is_truthy(parley.not_chat(buf, path), "fixture must be markdown-classified")
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal dae")
		assert.same(FIXTURE, body(buf),
			"a transcript keeps its header even when classified markdown")
	end)

	-- ARCH-ORDER: the ONE documented asymmetry between the surfaces. The
	-- command goes through buffer_edit and inherits its refusal; the native
	-- operator does not. Driven by withholding the document rather than by
	-- stubbing the call, so it exercises the real refusal path.
	it("raises instead of mutating when the document withholds the grant", function()
		local buf = prepped(FIXTURE)
		-- SCOPE: this asserts the COMMAND propagates a refusal and leaves the
		-- buffer intact -- not that the document refuses correctly, which is
		-- document_user_guards_spec's job and is already covered there.
		--
		-- The refusal is injected at the buffer_edit seam because the real
		-- trigger is an in-flight generation writing the same region, and
		-- holding an overlapping user capture does not reproduce it (the
		-- document permits concurrent user regions). A narrower substitution
		-- than staging a live stream, and it tests the one thing this diff
		-- owns: that delete_entity_range does not swallow the error.
		local edit = require("parley.buffer_edit")
		local real = edit.replace_user_lines
		edit.replace_user_lines = function() error("User edit refused: generation") end

		vim.api.nvim_win_set_cursor(0, { 8, 0 })   -- "para one"; row 9 is blank
		local ok = pcall(vim.cmd, "ParleyDeleteEntity")
		edit.replace_user_lines = real

		assert.is_false(ok, "the command must refuse, not silently corrupt the transcript")
		assert.same(FIXTURE, body(buf))
	end)

	it("die and cae work, as Done-when claims for every operator", function()
		local buf = prepped(FIXTURE)
		vim.api.nvim_win_set_cursor(0, { 10, 0 })
		vim.cmd("normal die")
		local after = body(buf)
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "## a heading" end, after)[1],
			"inner section keeps the heading")
		assert.is_nil(vim.tbl_filter(function(l) return l == "under heading" end, after)[1])
	end)

	it("keeps a summary at the answer edge through daE", function()
		local with_summary = vim.deepcopy(FIXTURE)
		table.insert(with_summary, 13, "📝: the summary")
		table.insert(with_summary, 14, "")
		local buf = prepped(with_summary)
		vim.api.nvim_win_set_cursor(0, { 8, 0 })
		vim.cmd("normal daE")
		local after = body(buf)
		assert.is_nil(vim.tbl_filter(function(l) return l == "para one" end, after)[1])
		assert.is_not_nil(vim.tbl_filter(function(l) return l == "📝: the summary" end, after)[1],
			"an edge summary survives when the question does")
	end)

	-- BR-37: an INDEPENDENT oracle. The unit invariant checks the range with the
	-- same code_block_memo/is_fence_delim the guard itself uses, so a wrong
	-- predicate agrees with itself and passes. This counts fence lines in the
	-- RESULTING BUFFER with a plain pattern that shares nothing with the
	-- implementation, and asserts the transcript still has balanced fences
	-- after a real dae/daE through the real keymaps.
	it("never strands a fence, counted independently of the implementation", function()
		local FENCED = {
			"# topic: entity",   -- 1
			"- file: entity.md", -- 2
			"---",               -- 3
			"",                  -- 4
			"💬: q",             -- 5
			"",                  -- 6
			"🤖: [A]",           -- 7
			"prose",             -- 8
			"",                  -- 9
			"```lua",            -- 10
			"local a = 1",       -- 11
			"",                  -- 12
			"local b = 2",       -- 13
			"```",               -- 14
			"",                  -- 15
			"~~~",               -- 16
			"tilde body",        -- 17
			"~~~",               -- 18
			"tail",              -- 19
		}
		-- deliberately NOT lexical.is_fence_delim: an oracle that shares the
		-- implementation's predicate cannot detect a wrong predicate.
		local function fence_lines(buf_lines)
			local n = 0
			for _, l in ipairs(buf_lines) do
				if l:match("^%s*```") or l:match("^%s*~~~") then n = n + 1 end
			end
			return n
		end
		assert.equals(4, fence_lines(FENCED))

		for _, keys in ipairs({ "dae", "daE" }) do
			for row = 4, #FENCED do
				local buf = prepped(FENCED)
				vim.api.nvim_win_set_cursor(0, { row, 0 })
				vim.cmd("normal " .. keys)
				local after = body(buf)
				assert.equals(0, fence_lines(after) % 2,
					("%s at row %d left %d fence lines (odd) -- a block is stranded")
						:format(keys, row, fence_lines(after)))
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
	end)

	-- #262: the packaged app runs default_keymaps=false and re-enables only the
	-- <C-g>/<M-> families, so "it works in the plugin" does not imply "it works
	-- in the app". This drives the APP's own option builder, not the shipped
	-- defaults, and asserts the objects are really mapped on a prepped buffer.
	it("installs the text objects under the packaged app profile", function()
		local roots = { data = base_tmp_dir .. "/app/data", state = base_tmp_dir .. "/app/state" }
		parley.setup(require("parley.starter_config").options(roots))
		seq = seq + 1
		local dir = parley.config.chat_dir
		vim.fn.mkdir(dir, "p")
		local path = dir .. "/2026-03-01-app-" .. seq .. ".md"
		vim.fn.writefile(FIXTURE, path)
		vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
		local buf = vim.api.nvim_get_current_buf()
		parley.prep_chat(buf, path)

		local function mapped(mode, lhs)
			for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
				if m.lhs == lhs then return true end
			end
			return false
		end

		assert.is_true(mapped("o", "ae"), "dae must work in the app, not just the plugin")
		assert.is_true(mapped("o", "ie"))
		assert.is_true(mapped("o", "aE"))
		assert.is_true(mapped("x", "ae"))
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
