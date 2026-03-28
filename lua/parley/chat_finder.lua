-- Chat finder module for Parley
-- Handles the ChatFinder UI command and related helpers

local M = {}
local _parley

M.setup = function(parley)
	_parley = parley
end

--------------------------------------------------------------------------------
-- Local helpers: sticky query extraction and initial query formatting
--------------------------------------------------------------------------------

local function extract_chat_finder_sticky_query(query)
	if type(query) ~= "string" or query == "" then
		return nil
	end

	local fragments = {}
	for token in query:gmatch("%S+") do
		if token:match("^%b[]$") then
			local value = vim.trim(token:sub(2, -2))
			if value ~= "" and not value:find("[%[%]]") then
				table.insert(fragments, "[" .. value .. "]")
			end
		elseif token:match("^%b{}$") then
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

--------------------------------------------------------------------------------
-- Shared recency helpers (also exported for use by note_finder)
--------------------------------------------------------------------------------

local function unique_positive_months(values)
	local dedup = {}
	local months = {}
	for _, value in ipairs(values) do
		if type(value) == "number" and value > 0 then
			local normalized = math.floor(value)
			if normalized > 0 and not dedup[normalized] then
				dedup[normalized] = true
				table.insert(months, normalized)
			end
		end
	end
	table.sort(months)
	return months
end

M.resolve_finder_recency = function(recency_config, recency_index)
	recency_config = recency_config or {}

	local configured_months = {}
	if type(recency_config.presets) == "table" then
		vim.list_extend(configured_months, recency_config.presets)
	end
	if type(recency_config.months) == "number" then
		table.insert(configured_months, recency_config.months)
	end

	local presets = unique_positive_months(configured_months)
	if #presets == 0 then
		presets = { 3 }
	end

	local states = {}
	for _, months in ipairs(presets) do
		table.insert(states, {
			label = string.format("Recent: %d months", months),
			months = months,
			is_all = false,
		})
	end
	table.insert(states, {
		label = "All",
		months = nil,
		is_all = true,
	})

	local resolved_index = recency_index
	if type(resolved_index) ~= "number" or resolved_index < 1 or resolved_index > #states then
		if recency_config.filter_by_default == false then
			resolved_index = #states
		else
			resolved_index = 1
			local default_months = type(recency_config.months) == "number" and math.floor(recency_config.months) or nil
			if default_months then
				for idx, state in ipairs(states) do
					if state.months == default_months then
						resolved_index = idx
						break
					end
				end
			end
		end
	end

	return {
		states = states,
		index = resolved_index,
		current = states[resolved_index],
	}
end

M.cycle_finder_recency = function(recency_config, recency_index, direction)
	local resolved = M.resolve_finder_recency(recency_config, recency_index)
	local step = direction == "previous" and -1 or 1
	local next_index = ((resolved.index - 1 + step) % #resolved.states) + 1
	return next_index, resolved.states[next_index]
end

M.resolve_finder_initial_index = function(state, items, label)
	local initial_value = state.initial_value
	if initial_value then
		for idx, item in ipairs(items) do
			if item.value == initial_value then
				_parley.logger.debug(string.format(
					"%s trace: resolve initial by value matched idx=%s value=%s fallback_index=%s item_count=%s",
					label,
					tostring(idx),
					initial_value,
					tostring(state.initial_index),
					tostring(#items)
				))
				return idx
			end
		end
		_parley.logger.debug(string.format(
			"%s trace: resolve initial by value missed value=%s fallback_index=%s item_count=%s",
			label,
			initial_value,
			tostring(state.initial_index),
			tostring(#items)
		))
	end

	_parley.logger.debug(string.format(
		"%s trace: resolve initial by fallback index=%s item_count=%s",
		label,
		tostring(state.initial_index),
		tostring(#items)
	))
	return state.initial_index
end

--------------------------------------------------------------------------------
-- Reopen / delete helpers
--------------------------------------------------------------------------------

M.reopen = function(source_win, selection_index, selection_value)
	_parley.logger.debug(string.format(
		"ChatFinder trace: schedule reopen source_win=%s selection_index=%s selection_value=%s",
		tostring(source_win),
		tostring(selection_index),
		tostring(selection_value)
	))
	vim.defer_fn(function()
		_parley._chat_finder.opened = false
		_parley._chat_finder.source_win = source_win
		_parley._chat_finder.initial_index = selection_index
		_parley._chat_finder.initial_value = selection_value
		_parley.logger.debug(string.format(
			"ChatFinder trace: executing reopen source_win=%s initial_index=%s initial_value=%s",
			tostring(source_win),
			tostring(_parley._chat_finder.initial_index),
			tostring(_parley._chat_finder.initial_value)
		))
		_parley.cmd.ChatFinder()
	end, 100)
end

M.handle_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
	_parley.logger.debug(string.format(
		"ChatFinder trace: delete response input=%s item=%s selected_index=%s items_count=%s source_win=%s",
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
		local items = context and context.chat_finder_items or nil
		if type(items) == "table" then
			-- ChatFinder items are stored newest-first but rendered bottom-up, so the
			-- item that stays in the same visual row after delete is the next logical
			-- item (older entry). Fall back to the previous item when deleting the
			-- oldest visible entry.
			local next_item = items[selected_index + 1] or items[selected_index - 1]
			next_value = next_item and next_item.value or nil
			_parley.logger.debug(string.format(
				"ChatFinder trace: confirmed delete selected_item=%s next_item=%s selected_index=%s next_index=%s item_count=%s",
				tostring(item_value),
				tostring(next_value),
				tostring(selected_index),
				tostring(next_index),
				tostring(#items)
			))
		end
		_parley._reopen_chat_finder(source_win, next_index, next_value)
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

	_parley._reopen_chat_finder(source_win, selected_index, item_value)
end

M.prompt_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
	_parley.logger.debug(string.format(
		"ChatFinder trace: prompt delete item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		vim.api.nvim_set_current_win(source_win)
	end

	vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
		_parley._handle_chat_finder_delete_response(
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
-- Main ChatFinder open function (was M.cmd.ChatFinder body)
--------------------------------------------------------------------------------

M.open = function(_options)
	if _parley._chat_finder.opened then
		_parley.logger.warning("Chat finder is already open")
		return
	end
	_parley._chat_finder.opened = true

	-- IMPORTANT: The window should have been captured from the keybinding
	_parley.logger.debug("ChatFinder using source_win: " .. (_parley._chat_finder.source_win or "nil"))

	local chat_roots = _parley.get_chat_roots()
	local delete_shortcut = _parley.config.chat_finder_mappings.delete or _parley.config.chat_shortcut_delete
	local move_shortcut = _parley.config.chat_finder_mappings.move or { shortcut = "<C-x>" }
	local next_recency_shortcut = _parley.config.chat_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = _parley.config.chat_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = _parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }

	-- Launch float picker for chat finder
	do
		-- Get all timestamp format files
		local files = {}
		local seen_files = {}
		for _, root in ipairs(chat_roots) do
			local dir = root.dir
			local pattern = vim.fn.fnameescape(dir) .. "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md"
			for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
				local resolved = vim.fn.resolve(file)
				if not seen_files[resolved] then
					seen_files[resolved] = true
					table.insert(files, {
						path = file,
						root = root,
					})
				end
			end
		end
		local entries = {}

		-- Get recency configuration
		local recency_config = _parley.config.chat_finder_recency
			or {
				filter_by_default = true,
				months = 3,
				use_mtime = true,
			}
		local resolved_recency = _parley._resolve_chat_finder_recency(recency_config, _parley._chat_finder.recency_index)
		_parley._chat_finder.recency_index = resolved_recency.index
		_parley._chat_finder.show_all = resolved_recency.current.is_all

		local cutoff_time = nil
		if resolved_recency.current.months then
			local current_time = os.time()
			local months_in_seconds = resolved_recency.current.months * 30 * 24 * 60 * 60
			cutoff_time = current_time - months_in_seconds
		end

		local is_filtering = not resolved_recency.current.is_all

		for _, item in ipairs(files) do
			local file = item.path
			local root = item.root
			local resolved_root_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"))
			local resolved_primary_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(_parley.config.chat_dir), ":p"))
			local is_primary_root = root.is_primary or resolved_root_dir == resolved_primary_dir
			-- Get file info
			local stat = vim.loop.fs_stat(file)
			if not stat then
				goto continue
			end

			-- Try to infer timestamp from chat filename first
			-- Chat files typically have format: YYYY-MM-DD-HH-MM-SS-topic.md
			local file_time
			local filename = vim.fn.fnamemodify(file, ":t:r")
			local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")

			if year and month and day and hour and min and sec then
				-- Create date table and convert to timestamp
				local date_table = {
					year = tonumber(year),
					month = tonumber(month),
					day = tonumber(day),
					hour = tonumber(hour),
					min = tonumber(min),
					sec = tonumber(sec),
				}
				file_time = os.time(date_table)
			else
				-- Fallback to file system times if we couldn't infer from filename
				file_time = stat.mtime.sec or (stat.birthtime and stat.birthtime.sec) or stat.mtime.sec
			end

			-- Skip files older than cutoff if filtering is active
			if is_filtering and file_time < cutoff_time then
				goto continue
			end

			-- Get topic and tags from the file
			local lines = vim.fn.readfile(file, "", 10) -- Read first 10 lines to get headers
			local topic = ""
			local tags = {}

			-- Parse the file headers to get topic and tags
			local header_end = _parley.chat_parser.find_header_end(lines)
			if header_end then
				local parsed_chat = _parley.parse_chat(lines, header_end)
				if parsed_chat.headers.topic then
					topic = parsed_chat.headers.topic
				end
				if parsed_chat.headers.tags and type(parsed_chat.headers.tags) == "table" then
					tags = parsed_chat.headers.tags
				end
			else
				-- Fallback: look for topic in old format
				for _, line in ipairs(lines) do
					local t = line:match("^# topic: (.+)")
					if t then
						topic = t
						break
					end
				end
			end

			-- Format date string
			local date_str = os.date("%Y-%m-%d", file_time)

			-- Format tags for display
			local tags_display = ""
			if #tags > 0 then
				local tag_parts = {}
				for _, tag in ipairs(tags) do
					table.insert(tag_parts, "[" .. tag .. "]")
				end
				tags_display = table.concat(tag_parts, " ") .. " "
			end

			-- Format tags for search ordinal
			local tags_searchable = #tags > 0 and (" [" .. table.concat(tags, "] [") .. "]") or ""

			local display_filename = vim.fn.fnamemodify(file, ":t")
			local root_prefix = is_primary_root and "" or string.format("{%s} ", root.label)
			local root_searchable = is_primary_root and " {}" or (" {" .. root.label .. "}")
			table.insert(entries, {
				value = file,
				display = display_filename .. " - " .. root_prefix .. tags_display .. topic .. " [" .. date_str .. "]",
				ordinal = display_filename .. root_searchable .. " " .. tags_searchable .. " " .. topic,
				timestamp = file_time,
			})

			::continue::
		end

		-- Sort entries by timestamp (newest first)
		table.sort(entries, function(a, b)
			return a.timestamp > b.timestamp
		end)

		-- Determine prompt title based on filtering state
		local prompt_title = string.format(
			"Chat Files (%s  %s/%s: cycle)",
			resolved_recency.current.label,
			next_recency_shortcut.shortcut,
			previous_recency_shortcut.shortcut
		)

		_parley.logger.debug("ChatFinder using active_window: " .. (_parley._chat_finder.active_window or "nil"))

		-- Build float-picker items from sorted entries
		local items = {}
		for _, entry in ipairs(entries) do
			table.insert(items, {
				display = entry.display,
				search_text = entry.ordinal,
				value = entry.value,
			})
		end

		local source_win = _parley._chat_finder.source_win
		if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
			source_win = vim.api.nvim_get_current_win()
			_parley._chat_finder.source_win = source_win
			_parley.logger.debug("ChatFinder captured fallback source_win: " .. source_win)
		end

		_parley.logger.debug(string.format(
			"ChatFinder trace: opening picker item_count=%s initial_index=%s initial_value=%s first_item=%s",
			tostring(#items),
			tostring(_parley._chat_finder.initial_index),
			tostring(_parley._chat_finder.initial_value),
			items[1] and items[1].value or "nil"
		))

		_parley.float_picker.open({
			title = prompt_title,
			items = items,
			initial_index = M.resolve_finder_initial_index(_parley._chat_finder, items, "ChatFinder"),
			initial_query = format_finder_initial_query(_parley._chat_finder.sticky_query),
			on_query_change = function(query)
				_parley._chat_finder.sticky_query = extract_chat_finder_sticky_query(query)
			end,
			on_select = function(item)
				local file_path = item.value
				local display = item.display

				-- Check if we're in insert mode (for inserting chat references)
				if _parley._chat_finder.insert_mode then
					-- Switch to the original source window first
					if source_win and vim.api.nvim_win_is_valid(source_win) then
						vim.api.nvim_set_current_win(source_win)
						_parley.logger.debug("Switched to source window for insert: " .. source_win)
					end

					if _parley._chat_finder.insert_buf and vim.api.nvim_buf_is_valid(_parley._chat_finder.insert_buf) then
						-- Extract topic from the display
						local topic = display:match(" %- (.+) %[") or "Chat"

						-- Use bare filename — chat files are in the same directory
						local rel_path = vim.fn.fnamemodify(file_path, ":t")

						-- Handle normal mode insertion
						if _parley._chat_finder.insert_normal_mode then
							vim.api.nvim_buf_set_lines(
								_parley._chat_finder.insert_buf,
								_parley._chat_finder.insert_line - 1,
								_parley._chat_finder.insert_line - 1,
								false,
								{ "@@" .. rel_path .. ": " .. topic }
							)
						else
							-- Handle insert mode insertion by modifying the current line
							local current_line = vim.api.nvim_buf_get_lines(
								_parley._chat_finder.insert_buf,
								_parley._chat_finder.insert_line - 1,
								_parley._chat_finder.insert_line,
								false
							)[1]

							local col = _parley._chat_finder.insert_col
							local new_line = current_line:sub(1, col) .. "@@" .. rel_path .. ": " .. topic .. current_line:sub(col + 1)

							vim.api.nvim_buf_set_lines(
								_parley._chat_finder.insert_buf,
								_parley._chat_finder.insert_line - 1,
								_parley._chat_finder.insert_line,
								false,
								{ new_line }
							)

							-- Move cursor to the end of the inserted reference
							vim.api.nvim_win_set_cursor(0, {
								_parley._chat_finder.insert_line,
								col + #("@@" .. rel_path .. ": " .. topic),
							})

							-- Return to insert mode
							vim.schedule(function()
								vim.cmd("startinsert")
							end)
						end

						_parley.logger.info("Inserted chat reference: " .. rel_path)
					end

					-- Reset insert mode flags
					_parley._chat_finder.insert_mode = false
					_parley._chat_finder.insert_buf = nil
					_parley._chat_finder.insert_line = nil
					_parley._chat_finder.insert_col = nil
					_parley._chat_finder.insert_normal_mode = nil
				else
					-- Normal behavior - open the selected chat
					if source_win and vim.api.nvim_win_is_valid(source_win) then
						vim.api.nvim_set_current_win(source_win)
						_parley.logger.debug("Switched to source window for file open: " .. source_win)
					end
					_parley.open_buf(file_path, true)
				end
			end,
			on_cancel = function()
				_parley._chat_finder.opened = false
				_parley._chat_finder.initial_index = nil
				_parley._chat_finder.initial_value = nil
			end,
			mappings = {
				-- Delete selected chat file
				{
					key = delete_shortcut.shortcut,
					fn = function(item, close_fn, context)
						if not item then
							_parley.logger.debug("ChatFinder trace: delete mapping invoked with nil item")
							return
						end
						local selected_index = 1
						for idx, picker_item in ipairs(items) do
							if picker_item.value == item.value then
								selected_index = idx
								break
							end
						end

						_parley.logger.debug(string.format(
							"ChatFinder trace: delete mapping item=%s selected_index=%s item_count=%s first_item=%s",
							tostring(item.value),
							tostring(selected_index),
							tostring(#items),
							items[1] and items[1].value or "nil"
						))

						context.skip_focus_restore = true
						context.chat_finder_items = items
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
				-- Move selected chat file to another registered chat root
				{
					key = move_shortcut.shortcut,
					fn = function(item, close_fn)
						if not item then
							return
						end

						close_fn()
						vim.schedule(function()
							_parley.prompt_chat_move(item.value, function(new_file)
								_parley._chat_finder.opened = false
								_parley._chat_finder.source_win = source_win
								M.reopen(source_win, nil, new_file)
							end, function()
								_parley._chat_finder.opened = false
								_parley._chat_finder.source_win = source_win
								M.reopen(source_win, nil, item.value)
							end)
						end)
					end,
				},
				-- Move left through recency presets
				{
					key = next_recency_shortcut.shortcut,
					fn = function(_, close_fn)
						local next_index, next_state = _parley._cycle_chat_finder_recency(
							recency_config,
							_parley._chat_finder.recency_index,
							"previous"
						)
						_parley._chat_finder.recency_index = next_index
						_parley._chat_finder.show_all = next_state.is_all
						close_fn()
						vim.defer_fn(function()
							_parley._chat_finder.opened = false
							_parley._chat_finder.source_win = source_win
							_parley.cmd.ChatFinder()
						end, 100)
					end,
				},
				-- Move right through recency presets and "All"
				{
					key = previous_recency_shortcut.shortcut,
					fn = function(_, close_fn)
						local next_index, next_state = _parley._cycle_chat_finder_recency(
							recency_config,
							_parley._chat_finder.recency_index,
							"next"
						)
						_parley._chat_finder.recency_index = next_index
						_parley._chat_finder.show_all = next_state.is_all
						close_fn()
						vim.defer_fn(function()
							_parley._chat_finder.opened = false
							_parley._chat_finder.source_win = source_win
							_parley.cmd.ChatFinder()
						end, 100)
					end,
				},
				-- Show key bindings help
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
	end

	_parley._chat_finder.initial_index = nil
	_parley._chat_finder.initial_value = nil
	_parley._chat_finder.opened = false
end

return M
