-- Chat finder module for Parley
-- Handles the ChatFinder UI command and related helpers

local M = {}
local _parley

-- Mtime-based metadata cache: avoids re-reading unchanged files on repeated opens.
-- Key: resolved file path, Value: { mtime = number, topic = string, tags = {} }
local _file_cache = {}

-- Prewarm state: when a prewarm is in flight, ChatFinder waits for it
-- instead of triggering a second filesystem traversal.
local _prewarm_pending = false
local _prewarm_callbacks = {}

M.setup = function(parley)
	_parley = parley
end

M.clear_cache = function()
	_file_cache = {}
end

M.get_cache = function()
	return _file_cache
end

M.is_prewarming = function()
	return _prewarm_pending
end

M.invalidate_path = function(path)
	_file_cache[vim.fn.resolve(path)] = nil
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
		M.invalidate_path(item_value)
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

M.handle_delete_tree_response = function(input, item_value, tree_files, selected_index, items_count, source_win, close_fn, context)
	if input and input:lower() == "y" then
		for _, f in ipairs(tree_files) do
			_parley.helpers.delete_file(f)
			M.invalidate_path(f)
		end
		if close_fn then
			close_fn()
		end
		local next_index = math.min(selected_index, math.max(1, items_count - 1))
		local next_value = nil
		local items = context and context.chat_finder_items or nil
		if type(items) == "table" then
			local next_item = items[selected_index + 1] or items[selected_index - 1]
			next_value = next_item and next_item.value or nil
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

M.prompt_delete_tree_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		vim.api.nvim_set_current_win(source_win)
	end

	local tree_files = _parley.get_chat_tree_files(item_value)
	if #tree_files == 0 then
		if context then
			context.resume_after_external_ui()
		end
		return
	end

	local rel_files = {}
	for _, f in ipairs(tree_files) do
		table.insert(rel_files, vim.fn.fnamemodify(f, ":~:."))
	end
	local prompt = "Delete " .. #tree_files .. " file(s) in tree? [" .. table.concat(rel_files, ", ") .. "] [y/N] "

	vim.ui.input({ prompt = prompt }, function(input)
		_parley._handle_chat_finder_delete_tree_response(
			input,
			item_value,
			tree_files,
			selected_index,
			items_count,
			source_win,
			close_fn,
			context
		)
	end)
end

--------------------------------------------------------------------------------
-- File scanning with mtime cache
--------------------------------------------------------------------------------

--- Read and parse a single file's header, returning topic and tags.
--- Uses _file_cache to skip re-reading unchanged files.
--- @param resolved string already-resolved path (cache key)
local function read_file_metadata(file, resolved, stat_mtime)
	local cached = _file_cache[resolved]
	if cached and cached.mtime == stat_mtime then
		return cached.topic, cached.tags
	end

	local topic = ""
	local tags = {}
	local lines = vim.fn.readfile(file, "", 10)

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
		for _, line in ipairs(lines) do
			local t = line:match("^# topic: (.+)")
			if t then
				topic = t
				break
			end
		end
	end

	_file_cache[resolved] = { mtime = stat_mtime, topic = topic, tags = tags }
	return topic, tags
end

--- Scan chat roots and return sorted entries using the cache.
--- Shared by M.open() and M.prewarm().
local function scan_chat_files(chat_roots, cutoff_time, is_filtering)
	local files = {}
	local seen_files = {}
	local resolved_primary_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(_parley.config.chat_dir), ":p"))
	for _, root in ipairs(chat_roots) do
		local dir = root.dir
		local resolved_root_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(dir), ":p"))
		local is_primary_root = root.is_primary or resolved_root_dir == resolved_primary_dir
		local pattern = vim.fn.fnameescape(dir) .. "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md"
		for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
			local resolved = vim.fn.resolve(file)
			if not seen_files[resolved] then
				seen_files[resolved] = true
				table.insert(files, { path = file, resolved = resolved, root = root, is_primary_root = is_primary_root })
			end
		end
	end

	-- Prune stale cache entries
	for cached_path in pairs(_file_cache) do
		if not seen_files[cached_path] then
			_file_cache[cached_path] = nil
		end
	end

	local entries = {}

	for _, item in ipairs(files) do
		local file = item.path
		local resolved = item.resolved
		local root = item.root
		local is_primary_root = item.is_primary_root

		-- Extract timestamp from filename first (no I/O needed)
		local file_time
		local filename = vim.fn.fnamemodify(file, ":t:r")
		local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")

		if year and month and day and hour and min and sec then
			file_time = os.time({
				year = tonumber(year), month = tonumber(month), day = tonumber(day),
				hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec),
			})
			-- Skip old files before stat — no I/O for filtered-out files with parseable filenames
			if is_filtering and cutoff_time and file_time < cutoff_time then
				goto continue
			end
		end

		local stat = vim.loop.fs_stat(file)
		if not stat then
			goto continue
		end

		if not file_time then
			file_time = stat.mtime.sec or (stat.birthtime and stat.birthtime.sec) or stat.mtime.sec
			if is_filtering and cutoff_time and file_time < cutoff_time then
				goto continue
			end
		end

		local topic, tags = read_file_metadata(file, resolved, stat.mtime.sec)

		local date_str = os.date("%Y-%m-%d", file_time)
		local tags_display = ""
		if #tags > 0 then
			local tag_parts = {}
			for _, tag in ipairs(tags) do
				table.insert(tag_parts, "[" .. tag .. "]")
			end
			tags_display = table.concat(tag_parts, " ") .. " "
		end
		local tags_searchable = #tags > 0 and (" [" .. table.concat(tags, "] [") .. "]") or " []"
		local display_filename = vim.fn.fnamemodify(file, ":t")
		local root_prefix = is_primary_root and "" or string.format("{%s} ", root.label)
		local root_searchable = is_primary_root and " {}" or (" {" .. root.label .. "}")

		table.insert(entries, {
			value = file,
			display = display_filename .. " - " .. root_prefix .. tags_display .. topic .. " [" .. date_str .. "]",
			ordinal = display_filename .. root_searchable .. " " .. tags_searchable .. " " .. topic,
			timestamp = file_time,
			tags = tags,
		})

		::continue::
	end

	table.sort(entries, function(a, b)
		return a.timestamp > b.timestamp
	end)

	return entries
end

--- Prewarm the file metadata cache in the background.
M.prewarm = function()
	if _prewarm_pending or not _parley then
		return
	end
	_prewarm_pending = true
	vim.defer_fn(function()
		local ok, err = pcall(function()
			local chat_roots = _parley.get_chat_roots()
			if chat_roots and #chat_roots > 0 then
				scan_chat_files(chat_roots, nil, false)
			end
		end)
		if not ok and _parley then
			_parley.logger.debug("ChatFinder prewarm error: " .. tostring(err))
		end
		_prewarm_pending = false
		local callbacks = _prewarm_callbacks
		_prewarm_callbacks = {}
		for _, cb in ipairs(callbacks) do
			cb()
		end
	end, 0)
end

-- Exposed for benchmarking (perf_chat_finder.lua)
M._scan_chat_files = scan_chat_files

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
	local delete_tree_shortcut = _parley.config.chat_finder_mappings.delete_tree or { shortcut = "<C-D>" }
	local move_shortcut = _parley.config.chat_finder_mappings.move or { shortcut = "<C-x>" }
	local next_recency_shortcut = _parley.config.chat_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = _parley.config.chat_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = _parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }

	-- If a prewarm is in flight, wait for it instead of scanning again
	if _prewarm_pending then
		_parley.logger.debug("ChatFinder: waiting for prewarm to finish")
		_parley._chat_finder.opened = false
		table.insert(_prewarm_callbacks, function()
			M.open(_options)
		end)
		return
	end

	-- Launch float picker for chat finder
	do
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

		local entries = scan_chat_files(chat_roots, cutoff_time, is_filtering)

		-- Collect all unique tags from current entries (for tag bar)
		local all_tags_set = {}
		local has_untagged = false
		for _, entry in ipairs(entries) do
			if #entry.tags == 0 then
				has_untagged = true
			else
				for _, tag in ipairs(entry.tags) do
					all_tags_set[tag] = true
				end
			end
		end
		local all_tags = {}
		for tag in pairs(all_tags_set) do
			table.insert(all_tags, tag)
		end
		table.sort(all_tags)
		if has_untagged then
			table.insert(all_tags, "")  -- "" represents "no tag" files
		end

		-- Initialize or merge tag state
		if _parley._chat_finder.tag_state == nil then
			local state = {}
			for _, tag in ipairs(all_tags) do
				state[tag] = true
			end
			_parley._chat_finder.tag_state = state
		else
			-- New tags (not seen before) default to enabled
			for _, tag in ipairs(all_tags) do
				if _parley._chat_finder.tag_state[tag] == nil then
					_parley._chat_finder.tag_state[tag] = true
				end
			end
		end

		-- Build picker items and tag bar tags from entries + current tag_state.
		-- Returns items list and tag_bar_tags list (or nil if no tags).
		local function build_picker_data()
			local any_tag_disabled = false
			for _, enabled in pairs(_parley._chat_finder.tag_state) do
				if not enabled then any_tag_disabled = true; break end
			end

			-- OR logic: include file if any of its tags is enabled.
			-- Untagged files are included if the "" (no-tag) entry is enabled.
			local tag_filtered_entries = entries
			if any_tag_disabled then
				local tag_state = _parley._chat_finder.tag_state
				tag_filtered_entries = {}
				for _, entry in ipairs(entries) do
					local matches = false
					if #entry.tags == 0 then
						if tag_state[""] then matches = true end
					else
						for _, tag in ipairs(entry.tags) do
							if tag_state[tag] then matches = true; break end
						end
					end
					if matches then
						table.insert(tag_filtered_entries, entry)
					end
				end
			end

			local new_items = {}
			for _, entry in ipairs(tag_filtered_entries) do
				table.insert(new_items, {
					display = entry.display,
					search_text = entry.ordinal,
					value = entry.value,
				})
			end

			local new_tag_bar_tags = nil
			if #all_tags > 0 then
				new_tag_bar_tags = {}
				for _, tag in ipairs(all_tags) do
					table.insert(new_tag_bar_tags, {
						label = tag,
						enabled = _parley._chat_finder.tag_state[tag] ~= false,
					})
				end
			end

			return new_items, new_tag_bar_tags
		end

		local items, tag_bar_tags = build_picker_data()

		-- Determine prompt title based on filtering state
		local prompt_title = string.format(
			"Chat Files (%s  %s/%s: cycle)",
			resolved_recency.current.label,
			next_recency_shortcut.shortcut,
			previous_recency_shortcut.shortcut
		)

		_parley.logger.debug("ChatFinder using active_window: " .. (_parley._chat_finder.active_window or "nil"))

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

		-- picker_ref lets on_toggle call picker.update() before the picker is created
		local picker_ref = {}

		-- Build tag bar options (only shown when there are tags to display)
		local tag_bar = nil
		if tag_bar_tags then
			local function refresh_picker()
				local new_items, new_tb_tags = build_picker_data()
				if picker_ref.update then picker_ref.update(new_items, new_tb_tags) end
			end
			local function set_all_tags(value)
				for tag in pairs(_parley._chat_finder.tag_state) do
					_parley._chat_finder.tag_state[tag] = value
				end
				refresh_picker()
			end
			tag_bar = {
				tags = tag_bar_tags,
				on_toggle = function(tag_label)
					_parley._chat_finder.tag_state[tag_label] = not _parley._chat_finder.tag_state[tag_label]
					refresh_picker()
				end,
				on_all  = function() set_all_tags(true)  end,
				on_none = function() set_all_tags(false) end,
			}
		end

		local picker = _parley.float_picker.open({
			title = prompt_title,
			items = items,
			initial_index = M.resolve_finder_initial_index(_parley._chat_finder, items, "ChatFinder"),
			initial_query = format_finder_initial_query(_parley._chat_finder.sticky_query),
			tag_bar = tag_bar,
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

						local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"

						-- Handle normal mode insertion (full-line branch ref)
						if _parley._chat_finder.insert_normal_mode then
							vim.api.nvim_buf_set_lines(
								_parley._chat_finder.insert_buf,
								_parley._chat_finder.insert_line - 1,
								_parley._chat_finder.insert_line - 1,
								false,
								{ branch_prefix .. " " .. rel_path .. ": " .. topic }
							)
						else
							-- Handle insert mode insertion (inline branch link)
							local current_line = vim.api.nvim_buf_get_lines(
								_parley._chat_finder.insert_buf,
								_parley._chat_finder.insert_line - 1,
								_parley._chat_finder.insert_line,
								false
							)[1]

							local col = _parley._chat_finder.insert_col
							local inline_link = "[" .. branch_prefix .. topic .. "](" .. rel_path .. ")"
							local new_line = current_line:sub(1, col) .. inline_link .. current_line:sub(col + 1)

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
								col + #inline_link,
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
				-- Delete entire chat tree for the selected file
				{
					key = delete_tree_shortcut.shortcut,
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
						context.chat_finder_items = items
						context.suspend_for_external_ui()
						vim.defer_fn(function()
							M.prompt_delete_tree_confirmation(
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
							_parley.cmd.KeyBindings("chat_finder")
						end)
					end,
				},
			},
		})
		if picker then picker_ref.update = picker.update end
	end

	_parley._chat_finder.initial_index = nil
	_parley._chat_finder.initial_value = nil
	_parley._chat_finder.opened = false
end

return M
