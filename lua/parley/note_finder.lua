-- Note finder module for Parley
-- Handles the NoteFinder UI command and related helpers

local M = {}
local _parley
local _chat_finder_mod  -- set after both modules are loaded

M.setup = function(parley)
	_parley = parley
	-- Lazily resolve chat_finder module to avoid circular require issues
	_chat_finder_mod = require("parley.chat_finder")
end

--------------------------------------------------------------------------------
-- Local helpers
--------------------------------------------------------------------------------

local function extract_note_finder_sticky_query(query)
	if type(query) ~= "string" or query == "" then
		return nil
	end

	local fragments = {}
	for token in query:gmatch("%S+") do
		if token:match("^%b{}$") then
			local value = vim.trim(token:sub(2, -2))
			if value == "" then
				table.insert(fragments, "{}")
			elseif not value:find("[{}]") then
				table.insert(fragments, "{" .. value .. "}")
			end
		end
	end

	if #fragments == 0 then
		return nil
	end

	return table.concat(fragments, " ")
end

local function format_finder_initial_query(sticky_query)
	if type(sticky_query) ~= "string" or sticky_query == "" then
		return nil
	end

	return sticky_query .. " "
end

local function infer_note_directory_cutoff_time(file_path, notes_root)
	local expanded_root = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_root), ":p")):gsub("/+$", "")
	local absolute_path = vim.fn.resolve(vim.fn.fnamemodify(file_path, ":p")):gsub("/+$", "")
	local relative = absolute_path
	local prefix = expanded_root .. "/"
	if absolute_path:sub(1, #prefix) == prefix then
		relative = absolute_path:sub(#prefix + 1)
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local year = tonumber(parts[1] and parts[1]:match("^(%d%d%d%d)$"))
	local month = tonumber(parts[2] and parts[2]:match("^(%d%d)$"))
	local day = tonumber(vim.fn.fnamemodify(file_path, ":t"):match("^(%d%d)%-"))

	if year and month and day then
		return os.time({
			year = year,
			month = month,
			day = day,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	if year and month then
		return os.time({
			year = year,
			month = month + 1,
			day = 0,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	if year then
		return os.time({
			year = year,
			month = 12,
			day = 31,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	return nil
end

local function classify_note_finder_path(file_path, notes_root)
	local expanded_root = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_root), ":p")):gsub("/+$", "")
	local absolute_path = vim.fn.resolve(vim.fn.fnamemodify(file_path, ":p")):gsub("/+$", "")
	local relative = absolute_path
	local prefix = expanded_root .. "/"
	if absolute_path:sub(1, #prefix) == prefix then
		relative = absolute_path:sub(#prefix + 1)
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local first_part = parts[1]
	if not first_part or first_part == "templates" then
		return {
			is_template = first_part == "templates",
			relative_path = relative,
		}
	end

	local is_year = first_part:match("^%d%d%d%d$") ~= nil
	local base_folder = nil
	if not is_year then
		base_folder = first_part
	end
	return {
		is_template = false,
		relative_path = relative,
		base_folder = base_folder,
	}
end

--------------------------------------------------------------------------------
-- Reopen / delete helpers
--------------------------------------------------------------------------------

M.reopen = function(source_win, selection_index, selection_value)
	_parley.logger.debug(string.format(
		"NoteFinder trace: schedule reopen source_win=%s selection_index=%s selection_value=%s",
		tostring(source_win),
		tostring(selection_index),
		tostring(selection_value)
	))
	vim.defer_fn(function()
		_parley._note_finder.opened = false
		_parley._note_finder.source_win = source_win
		_parley._note_finder.initial_index = selection_index
		_parley._note_finder.initial_value = selection_value
		_parley.logger.debug(string.format(
			"NoteFinder trace: executing reopen source_win=%s initial_index=%s initial_value=%s",
			tostring(source_win),
			tostring(_parley._note_finder.initial_index),
			tostring(_parley._note_finder.initial_value)
		))
		_parley.cmd.NoteFinder()
	end, 100)
end

M.handle_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
	_parley.logger.debug(string.format(
		"NoteFinder trace: delete response input=%s item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(input),
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if input and input:lower() == "y" then
		_parley.helpers.delete_file(item_value)
		if close_fn then
			close_fn()
		end
		local next_index = math.min(selected_index, math.max(1, items_count - 1))
		local next_value = nil
		local items = context and context.note_finder_items or nil
		if type(items) == "table" then
			local next_item = items[selected_index + 1] or items[selected_index - 1]
			next_value = next_item and next_item.value or nil
		end
		_parley._reopen_note_finder(source_win, next_index, next_value)
		return
	end

	if context then
		context.resume_after_external_ui()
		vim.schedule(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end)
		vim.defer_fn(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end, 10)
		return
	end

	_parley._reopen_note_finder(source_win, selected_index, item_value)
end

M.prompt_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
	_parley.logger.debug(string.format(
		"NoteFinder trace: prompt delete item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		vim.api.nvim_set_current_win(source_win)
	end

	vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
		_parley._handle_note_finder_delete_response(
			input,
			item_value,
			selected_index,
			items_count,
			source_win,
			close_fn,
			context
		)
	end)
end

--------------------------------------------------------------------------------
-- Main NoteFinder open function (was M.cmd.NoteFinder body)
--------------------------------------------------------------------------------

M.open = function(_options)
	if _parley._note_finder.opened then
		_parley.logger.warning("Note finder is already open")
		return
	end
	_parley._note_finder.opened = true

	local note_finder_mappings = _parley.config.note_finder_mappings or {}
	local delete_shortcut = note_finder_mappings.delete or _parley.config.chat_shortcut_delete
	local next_recency_shortcut = note_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = note_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = _parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }
	local notes_root = vim.fn.expand(_parley.config.notes_dir)
	local files = _parley.helpers.find_files(notes_root, "*.md", true)
	local entries = {}
	local recency_config = _parley.config.note_finder_recency or {
		filter_by_default = true,
		months = 3,
	}
	local resolved_recency = _parley._resolve_note_finder_recency(recency_config, _parley._note_finder.recency_index)
	_parley._note_finder.recency_index = resolved_recency.index
	_parley._note_finder.show_all = resolved_recency.current.is_all

	local cutoff_time = nil
	if resolved_recency.current.months then
		cutoff_time = os.time() - (resolved_recency.current.months * 30 * 24 * 60 * 60)
	end

	for _, file in ipairs(files) do
		local classification = classify_note_finder_path(file, notes_root)
		if not classification.is_template then
			local stat = vim.loop.fs_stat(file)
			if stat then
				local inferred_time = infer_note_directory_cutoff_time(file, notes_root)
				local modified_time = stat.mtime.sec
				local sort_time = inferred_time or modified_time
				local range_time = inferred_time or modified_time
				local is_special_folder = classification.base_folder ~= nil
				if is_special_folder or not cutoff_time or range_time >= cutoff_time then
					local display
					local search_text
					if is_special_folder then
						local file_name = vim.fn.fnamemodify(file, ":t")
						display = string.format("{%s} %s [%s]", classification.base_folder, file_name, os.date("%Y-%m-%d", sort_time))
						search_text = string.format("{%s} %s %s", classification.base_folder, file_name, classification.relative_path:gsub("%-", " "))
					else
						display = classification.relative_path .. " [" .. os.date("%Y-%m-%d", sort_time) .. "]"
						search_text = "{} " .. classification.relative_path:gsub("%-", " ")
					end
					table.insert(entries, {
						value = file,
						display = display,
						ordinal = search_text,
						timestamp = sort_time,
						modified_time = modified_time,
						base_folder = classification.base_folder,
					})
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.timestamp == b.timestamp then
			if a.modified_time ~= b.modified_time then
				return a.modified_time > b.modified_time
			end
			return a.value < b.value
		end
		return a.timestamp > b.timestamp
	end)

	local items = {}
	for _, entry in ipairs(entries) do
		table.insert(items, {
			display = entry.display,
			search_text = entry.ordinal,
			value = entry.value,
		})
	end

	local source_win = _parley._note_finder.source_win
	if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
		source_win = vim.api.nvim_get_current_win()
		_parley._note_finder.source_win = source_win
	end

	local prompt_title = string.format(
		"Note Files (%s  %s/%s: cycle)",
		resolved_recency.current.label,
		next_recency_shortcut.shortcut,
		previous_recency_shortcut.shortcut
	)

	_parley.float_picker.open({
		title = prompt_title,
		items = items,
		initial_index = _chat_finder_mod.resolve_finder_initial_index(_parley._note_finder, items, "NoteFinder"),
		initial_query = format_finder_initial_query(_parley._note_finder.sticky_query),
		anchor = "bottom",
		on_query_change = function(query)
			_parley._note_finder.sticky_query = extract_note_finder_sticky_query(query)
		end,
		on_select = function(item)
			if source_win and vim.api.nvim_win_is_valid(source_win) then
				vim.api.nvim_set_current_win(source_win)
			end
			_parley.open_buf(item.value, true)
		end,
		on_cancel = function()
			_parley._note_finder.opened = false
			_parley._note_finder.initial_index = nil
			_parley._note_finder.initial_value = nil
		end,
		mappings = {
			{
				key = delete_shortcut.shortcut,
				fn = function(item, close_fn, context)
					if not item then
						return
					end
					local selected_index = 1
					for idx, picker_item in ipairs(items) do
						if picker_item.value == item.value then
							selected_index = idx
							break
						end
					end

					context.skip_focus_restore = true
					context.note_finder_items = items
					context.suspend_for_external_ui()
					vim.defer_fn(function()
						M.prompt_delete_confirmation(
							item.value,
							selected_index,
							#items,
							source_win,
							close_fn,
							context
						)
					end, 20)
				end,
			},
			{
				key = next_recency_shortcut.shortcut,
				fn = function(_, close_fn)
					local next_index, next_state = _parley._cycle_note_finder_recency(
						recency_config,
						_parley._note_finder.recency_index,
						"previous"
					)
					_parley._note_finder.recency_index = next_index
					_parley._note_finder.show_all = next_state.is_all
					close_fn()
					vim.defer_fn(function()
						_parley._note_finder.opened = false
						_parley._note_finder.source_win = source_win
						_parley.cmd.NoteFinder()
					end, 100)
				end,
			},
			{
				key = previous_recency_shortcut.shortcut,
				fn = function(_, close_fn)
					local next_index, next_state = _parley._cycle_note_finder_recency(
						recency_config,
						_parley._note_finder.recency_index,
						"next"
					)
					_parley._note_finder.recency_index = next_index
					_parley._note_finder.show_all = next_state.is_all
					close_fn()
					vim.defer_fn(function()
						_parley._note_finder.opened = false
						_parley._note_finder.source_win = source_win
						_parley.cmd.NoteFinder()
					end, 100)
				end,
			},
			{
				key = keybindings_shortcut.shortcut,
				fn = function(_, _)
					vim.schedule(function()
						_parley.cmd.KeyBindings()
					end)
				end,
			},
		},
	})

	_parley._note_finder.initial_index = nil
	_parley._note_finder.initial_value = nil
	_parley._note_finder.opened = false
end

return M
