-- Native edit/suggestion boundary; the controller fake owns live one-shot tickets.
local function fixture(line, word, mode)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.bo[buf].spelllang = "en"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
	local first, last = line:find(word, 1, true)
	vim.api.nvim_win_set_cursor(0, { 1, first - 1 })
	local ticket = {
		buf = buf, win = vim.api.nvim_get_current_win(), row = 0,
		start_col = first - 1, end_col = last, col = first - 1,
		word = word, mode = mode or "n", tick = vim.api.nvim_buf_get_changedtick(buf),
		generation = 1, max_suggest = 3,
	}
	local controller = { live = ticket, consumed = false }
	function controller.source_target(request_buf)
		if request_buf == buf and not controller.consumed then return controller.live end
	end
	function controller.consume(evidence)
		local live = controller.live
		if not live or controller.consumed or not vim.deep_equal(live, evidence)
			or not vim.api.nvim_buf_is_valid(buf)
			or vim.api.nvim_buf_get_changedtick(buf) ~= evidence.tick
			or vim.api.nvim_get_current_buf() ~= buf
			or vim.api.nvim_win_get_cursor(0)[2] ~= evidence.col then return false end
		controller.consumed = true
		return true
	end
	local source = require("parley.spell_source").new({ controller = controller })
	local ctx = { bufnr = buf }
	local response, calls
	calls = 0
	source:get_completions(ctx, function(result) response = result; calls = calls + 1 end)
	assert.equals(1, calls)
	return source, controller, ctx, response, ticket
end

describe("Blink spell source", function()
	local buffers
	before_each(function() buffers = vim.api.nvim_list_bufs() end)
	after_each(function()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if not vim.tbl_contains(buffers, buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
		end
	end)

	it("bounds native suggestions and retains byte ranges and independent evidence", function()
		local _, controller, _, result, ticket = fixture("é teh!", "teh")
		assert.is_true(#result.items > 0)
		assert.is_true(#result.items <= 3)
		assert.is_true(result.is_incomplete_forward)
		assert.is_true(result.is_incomplete_backward)
		local item = result.items[1]
		assert.equals("teh", item.filterText)
		assert.equals("utf-8", item.offset_encoding)
		assert.same({ start = { line = 0, character = 3 }, ["end"] = { line = 0, character = 6 } }, item.textEdit.range)
		assert.same(ticket, item.data.parley_spell)
		controller.live.generation = 2
		assert.equals(1, item.data.parley_spell.generation)
	end)

	it("shares the buffer dictionary check with automatic request admission", function()
		local _, _, _, _, bad = fixture("teh", "teh")
		local _, _, _, _, good = fixture("hello", "hello")
		local source = require("parley.spell_source")
		assert.is_true(source.is_misspelled(bad))
		assert.is_false(source.is_misspelled(good))
	end)

	it("offers no corrections for a correctly spelled word", function()
		local _, _, _, result = fixture("hello", "hello")
		assert.same({}, result.items)
	end)

	it("completes denied requests without suggestions", function()
		local source, controller, ctx = fixture("teh", "teh")
		controller.live = nil
		local calls = 0
		source:get_completions(ctx, function(result)
			calls = calls + 1
			assert.same({}, result.items)
			assert.is_false(result.is_incomplete_forward)
			assert.is_false(result.is_incomplete_backward)
		end)
		assert.equals(1, calls)
	end)

	it("replaces the whole Normal word despite Blink adjusting its range and undoes once", function()
		local source, _, ctx, result = fixture("é teh!", "teh")
		local item = result.items[1]
		item.textEdit.newText = "café"
		item.textEdit.range["end"].character = 4
		local calls, defaults = 0, 0
		source:execute(ctx, item, function() calls = calls + 1 end, function() defaults = defaults + 1 end)
		assert.equals("é café!", vim.api.nvim_get_current_line())
		assert.same({ 1, 6 }, vim.api.nvim_win_get_cursor(0))
		assert.equals(1, calls)
		assert.equals(0, defaults)
		vim.cmd.undo()
		assert.equals("é teh!", vim.api.nvim_get_current_line())
	end)

	it("restores Insert's original whole-word edit before invoking Blink", function()
		local source, _, ctx, result = fixture("é teh!", "teh", "i")
		local item = result.items[1]
		item.textEdit.range["end"].character = 4
		local calls, defaults = 0, 0
		source:execute(ctx, item, function() calls = calls + 1 end, function()
			defaults = defaults + 1
			assert.equals(6, item.textEdit.range["end"].character)
		end)
		assert.equals(1, calls)
		assert.equals(1, defaults)
	end)

	it("rejects delayed resolution after generation changes even with identical text", function()
		local source, controller, ctx, result = fixture("teh", "teh")
		controller.live = vim.deepcopy(controller.live)
		controller.live.generation = 2
		local calls = 0
		source:execute(ctx, result.items[1], function() calls = calls + 1 end, function() error("stale default") end)
		assert.equals("teh", vim.api.nvim_get_current_line())
		assert.equals(1, calls)
	end)

	it("rejects stale edits and duplicate acceptance while completing every callback", function()
		local source, _, ctx, result = fixture("teh", "teh")
		local calls = 0
		local item = result.items[1]
		source:execute(ctx, item, function() calls = calls + 1 end, function() error("normal default") end)
		local after = vim.api.nvim_get_current_line()
		source:execute(ctx, item, function() calls = calls + 1 end, function() error("duplicate default") end)
		assert.equals(after, vim.api.nvim_get_current_line())
		assert.equals(2, calls)
	end)

	it("rejects text changed while a result is waiting to execute", function()
		local source, _, ctx, result = fixture("teh", "teh")
		vim.api.nvim_buf_set_lines(ctx.bufnr, 0, -1, false, { "typed" })
		local calls = 0
		source:execute(ctx, result.items[1], function() calls = calls + 1 end, function() error("stale default") end)
		assert.equals("typed", vim.api.nvim_get_current_line())
		assert.equals(1, calls)
	end)

	it("finishes the callback if Insert's default edit raises an error", function()
		local source, _, ctx, result = fixture("teh", "teh", "i")
		local calls = 0
		local ok, err = pcall(source.execute, source, ctx, result.items[1], function() calls = calls + 1 end,
			function() error("native insertion failed") end)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("native insertion failed", 1, true))
		assert.equals(1, calls)
	end)

	it("finishes the callback even when the native edit refuses a locked buffer", function()
		local source, _, ctx, result = fixture("teh", "teh")
		vim.bo[ctx.bufnr].modifiable = false
		local calls = 0
		local ok = pcall(source.execute, source, ctx, result.items[1], function() calls = calls + 1 end, function() end)
		assert.is_false(ok)
		assert.equals(1, calls)
	end)
end)
