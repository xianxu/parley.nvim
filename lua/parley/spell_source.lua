-- Blink boundary: only controller-issued evidence can authorize a correction.
local Source = {}
Source.__index = Source

function Source.new(opts)
	return setmetatable({ controller = (opts or {}).controller or require("parley.spell_blink") }, Source)
end

-- Shared with automatic request admission: a correct word must not cause
-- cmp.show to reopen another provider's menu and borrow the next Return.
function Source.is_misspelled(evidence)
	return vim.api.nvim_buf_call(evidence.buf, function()
		return vim.fn.spellbadword(evidence.word)[1] ~= ""
	end)
end

local function text_edit(evidence, replacement)
	return {
		newText = replacement,
		range = {
			start = { line = evidence.row, character = evidence.start_col },
			["end"] = { line = evidence.row, character = evidence.end_col },
		},
	}
end

function Source:get_completions(ctx, callback)
	local items = {}
	local ok, err = xpcall(function()
		local evidence = self.controller.source_target(ctx.bufnr)
		if not evidence or not Source.is_misspelled(evidence) then return end
		-- Calling in the target buffer honors its spelllang without copying options
		-- into a global scope or interpolating language names into Ex commands.
		local suggestions = vim.api.nvim_buf_call(evidence.buf, function()
			return vim.fn.spellsuggest(evidence.word, evidence.max_suggest)
		end)
		for _, suggestion in ipairs(suggestions) do
			items[#items + 1] = {
				label = suggestion,
				kind = vim.lsp.protocol.CompletionItemKind.Text,
				filterText = evidence.word,
				textEdit = text_edit(evidence, suggestion),
				offset_encoding = "utf-8",
				data = { parley_spell = vim.deepcopy(evidence) },
			}
		end
	end, debug.traceback)
	-- Cursor movement and typing can change the whole word, so Blink must ask
	-- again in either direction instead of filtering a previous target's list.
	callback({ items = items, is_incomplete_forward = #items > 0, is_incomplete_backward = #items > 0 })
	if not ok then error(err, 0) end
	-- Native spellsuggest is synchronous; there is no deferred work to cancel.
	return function() end
end

local function normal_edit(evidence, replacement)
	-- A user correction is a document write: the editor owns the buffer callback
	-- and the undo boundary (#254's buffer_mutation boundary).
	local edits = require("parley.buffer_edit")
	local capture, reason = edits.capture_user(evidence.buf, "spell-correction", {
		{ first = { row = evidence.row, col = evidence.start_col }, last = { row = evidence.row, col = evidence.end_col } },
	})
	if not capture then error("spell correction unavailable: " .. tostring(reason), 0) end
	local result = edits.apply_user(capture, { { region = 1, text = replacement } })
	if result.status ~= "applied" then
		error("spell correction not applied: " .. tostring(result.reason or result.error or result.status), 0)
	end
	local last = math.max(0, vim.fn.match(replacement, ".$"))
	vim.api.nvim_win_set_cursor(evidence.win, { evidence.row + 1, evidence.start_col + last })
end

function Source:execute(_, item, callback, default_implementation)
	local ok, err = xpcall(function()
		local evidence = item.data and item.data.parley_spell
		if not evidence or not self.controller.consume(evidence) then return end
		-- Blink adjusts end columns for its query; retain the original whole-word
		-- range separately so a middle-of-word correction never strands a suffix.
		item.textEdit = text_edit(evidence, item.textEdit.newText)
		if evidence.mode == "n" then
			normal_edit(evidence, item.textEdit.newText)
		else
			default_implementation()
		end
	end, debug.traceback)
	callback()
	if not ok then error(err, 0) end
end

return Source
