-- Chat finder module for Parley
-- Handles the ChatFinder UI command and related helpers

local M = {}
local _parley
local finder_sticky = require("parley.finder_sticky")
local finder_facets = require("parley.finder_facets")
local finder_scan = require("parley.finder_scan")
local finder_loader = require("parley.finder_loader")
local finder_producer = require("parley.finder_producer")
local async_file_source = require("parley.async_file_source")
local chat_records = require("parley.chat_finder_records")

-- Mtime-based metadata cache: avoids re-reading unchanged files on repeated opens.
-- Key: resolved file path, Value: { mtime = number, topic = string, tags = {} }
local _file_cache = {}

local _prewarm_session

M.setup = function(parley)
	_parley = parley
end

M.clear_cache = function()
	_file_cache = {}
	if _prewarm_session then
		_prewarm_session:cancel_owner()
		_prewarm_session = nil
	end
end

M.get_cache = function()
	return _file_cache
end

M.is_prewarming = function()
	return _prewarm_session ~= nil and not _prewarm_session:is_retired()
end

M.invalidate_path = function(path)
	_file_cache[vim.fn.resolve(path)] = nil
end

-- In plain repo mode, default the chat finder's sticky filter to `{}` so chats
-- from the global chat root (and other roots) are filtered out. ChatFinder
-- indexes the primary chat root with `{}`; repo mode makes the repo chat root
-- primary, so this narrows to repo chats without changing root-label semantics.
-- Skipped in super-repo mode: that mode's whole point is aggregating siblings,
-- and narrowing to the local repo would defeat it. Returns the value to set,
-- or nil to leave sticky_query alone.
function M.default_sticky_query_for_repo_mode(config)
	local repo_root = config and config.repo_root
	if type(repo_root) ~= "string" or repo_root == "" then
		return nil
	end
	local super_repo_root = config.super_repo_root
	if type(super_repo_root) == "string" and super_repo_root ~= "" then
		return nil
	end
	return "{}"
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
-- Asynchronous discovery and retained prewarm
--------------------------------------------------------------------------------

local function discovery_dependencies()
	local injected = _parley._finder_dependencies or {}
	return {
		async_file_source = injected.async_file_source or async_file_source,
		schedule = injected.schedule or vim.schedule,
		now = injected.now or function()
			return (vim.uv or vim.loop).hrtime() / 1000000
		end,
	}
end

local function discovery_snapshot()
	local roots = {}
	for ordinal, root in ipairs(_parley.get_chat_roots() or {}) do
		local path = vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"):gsub("/+$", "")
		roots[#roots + 1] = {
			path = path,
			label = root.label,
			is_primary = root.is_primary == true or ordinal == 1,
			optional = true,
		}
	end
	return finder_scan.snapshot({
		kind = "chat",
		roots = roots,
		recursion = false,
		max_depth = 1,
		pattern = "YYYY-MM-DD*.md",
		backend = { source = "libuv", header_lines = 10 },
	})
end

local function split_lines(payload)
	local lines = {}
	payload = payload or ""
	for line in (payload .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local function identity_for(candidate)
	return finder_scan.path_identity({
		unresolved_absolute = candidate.unresolved_absolute,
		resolved_absolute = candidate.resolved_absolute,
		root_ordinal = candidate.root_ordinal,
	})
end

local function prune_root_cache(root_path, seen_keys)
	local seen = {}
	for _, key in ipairs(seen_keys) do
		seen[key] = true
	end
	for key, cached in pairs(_file_cache) do
		if cached.root_path == root_path and not seen[key] then
			_file_cache[key] = nil
		end
	end
end

local function new_session(snapshot, ownership, register_prewarm)
	local dependencies = discovery_dependencies()
	local session
	session = finder_loader.new_session({
		snapshot = snapshot,
		ownership = ownership,
		schedule = dependencies.schedule,
		producer_factory = function(settle)
			local data = snapshot:copy()
			return finder_producer.run({
				roots = data.roots,
				acquire = function(on_root, on_complete)
					return dependencies.async_file_source.scan({
						roots = data.roots,
						recurse = false,
						max_depth = data.max_depth,
						match = function(relative)
							return relative:match("^%d%d%d%d%-%d%d%-%d%d.*%.md$") ~= nil
						end,
						read_policy = function(candidate)
							return chat_records.read_decision(_file_cache, {
								identity = identity_for(candidate),
								stat = candidate.stat,
							})
						end,
						concurrency = 16,
					}, on_root, on_complete)
				end,
				adapter = function(candidate)
					local input = {
						kind = candidate.precomputed ~= nil and "cached" or "lines",
						path = candidate.unresolved_absolute,
						identity = candidate.identity or identity_for(candidate),
						stat = candidate.stat,
						root = candidate.root,
						metadata = candidate.precomputed,
						first_lines = split_lines(candidate.payload),
					}
					return chat_records.adapt(input)
				end,
				finalize = function(records)
					local unique = finder_scan.deduplicate(records)
					return finder_scan.sort(unique, function(left, right)
						return left.timestamp > right.timestamp
					end)
				end,
				batch = {
					item_budget = 25,
					time_budget_ms = 5,
					now = dependencies.now,
					schedule = dependencies.schedule,
				},
				on_record = function(record)
					local cached = chat_records.cache_entry(record)
					cached.root_path = record.root.path
					_file_cache[record.identity.key] = cached
				end,
				on_root_success = function(root_ordinal, seen_keys)
					prune_root_cache(data.roots[root_ordinal].path, seen_keys)
				end,
			}, settle)
		end,
		on_terminal = function(outcome, had_subscribers)
			if not had_subscribers and outcome.kind ~= "success" then
				_parley.logger.debug(string.format(
					"ChatFinder prewarm: %s (%d roots, %d files failed)",
					outcome.kind,
					outcome.failed_root_count or 0,
					outcome.failed_record_count or 0
				))
			end
		end,
		on_retire = function()
			if register_prewarm and _prewarm_session == session then
				_prewarm_session = nil
			end
		end,
	})
	return session
end

M.prewarm = function()
	if not _parley then
		return
	end
	local snapshot = discovery_snapshot()
	if _prewarm_session and not _prewarm_session:is_retired()
		and _prewarm_session:fingerprint() == snapshot:fingerprint() then
		return
	end
	if _prewarm_session then
		_prewarm_session:cancel_owner()
	end
	local session = new_session(snapshot, "retained", true)
	_prewarm_session = session
	session:start()
end

M._materialize_records = chat_records.materialize
M._discovery_snapshot = discovery_snapshot

--------------------------------------------------------------------------------
-- Main ChatFinder open function (was M.cmd.ChatFinder body)
--------------------------------------------------------------------------------

M.open = function(_)
	if _parley._chat_finder.opened then
		_parley.logger.warning("Chat finder is already open")
		return
	end
	_parley._chat_finder.opened = true

	-- One-shot: on the first open of a parley session, in plain repo mode,
	-- pre-seed sticky_query to "{}" so the finder defaults to repo chats.
	-- After the user clears or modifies the filter, sticky_query takes over and
	-- the default is never re-applied.
	if not _parley._chat_finder.sticky_query_initialized then
		_parley._chat_finder.sticky_query_initialized = true
		if _parley._chat_finder.sticky_query == nil then
			_parley._chat_finder.sticky_query = M.default_sticky_query_for_repo_mode(_parley.config)
		end
	end

	-- IMPORTANT: The window should have been captured from the keybinding
	_parley.logger.debug("ChatFinder using source_win: " .. (_parley._chat_finder.source_win or "nil"))

	local snapshot = discovery_snapshot()
	local session
	if _prewarm_session and not _prewarm_session:is_retired()
		and _prewarm_session:fingerprint() == snapshot:fingerprint() then
		session = _prewarm_session
	else
		session = new_session(snapshot, "picker", false)
	end
	local delete_shortcut = _parley.config.chat_finder_mappings.delete or _parley.config.chat_shortcut_delete
	local delete_tree_shortcut = _parley.config.chat_finder_mappings.delete_tree or { shortcut = "<C-D>" }
	local move_shortcut = _parley.config.chat_finder_mappings.move or { shortcut = "<C-x>" }
	local next_recency_shortcut = _parley.config.chat_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = _parley.config.chat_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local cycle_filter_shortcut = _parley.config.chat_finder_mappings.cycle_filter or { shortcut = "<Tab>" }
	local cycle_filter_prev_shortcut = _parley.config.chat_finder_mappings.cycle_filter_prev or { shortcut = "<S-Tab>" }
	local keybindings_shortcut = _parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }

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

			local entries = {}

		local function chat_facets(entry)
			return #entry.tags == 0 and { "" } or entry.tags
		end
			local all_tags = finder_facets.discover(entries, chat_facets)
		_parley._chat_finder.tag_state = finder_facets.merge_state(
			_parley._chat_finder.tag_state,
			all_tags
		)

		-- Build picker items and tag bar tags from entries + current tag_state.
		-- Returns items list and tag_bar_tags list (or nil if no tags).
		local function build_picker_data()
			local tag_filtered_entries = finder_facets.filter(
				entries,
				_parley._chat_finder.tag_state,
				chat_facets
			)

			local new_items = {}
			for _, entry in ipairs(tag_filtered_entries) do
				table.insert(new_items, {
					display = entry.display,
					search_text = entry.ordinal,
					value = entry.value,
				})
			end

			local new_tag_bar_tags = finder_facets.project(all_tags, _parley._chat_finder.tag_state)

			return new_items, new_tag_bar_tags
		end

		local items, tag_bar_tags = build_picker_data()

		-- Determine prompt title based on filtering state
		local prompt_title = string.format(
			"Chat Files (%s  %s/%s: cycle)",
			resolved_recency.current.label,
			cycle_filter_shortcut.shortcut,
			cycle_filter_prev_shortcut.shortcut
		)

		_parley.logger.debug("ChatFinder using active_window: " .. (_parley._chat_finder.active_window or "nil"))

		local source_win = _parley._chat_finder.source_win
		if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
			source_win = vim.api.nvim_get_current_win()
			_parley._chat_finder.source_win = source_win
			_parley.logger.debug("ChatFinder captured fallback source_win: " .. source_win)
		end

		-- The two recency-cycle handlers differ only by direction; one factory,
		-- four keys: <C-a>/<Tab> (left) and <C-s>/<S-Tab> (right). #159 (ARCH-DRY).
		local function make_recency_cycle(direction)
			return function(_, close_fn)
				local next_index, next_state = _parley._cycle_chat_finder_recency(
					recency_config,
					_parley._chat_finder.recency_index,
					direction
				)
				_parley._chat_finder.recency_index = next_index
				_parley._chat_finder.show_all = next_state.is_all
				close_fn()
				vim.defer_fn(function()
					_parley._chat_finder.opened = false
					_parley._chat_finder.source_win = source_win
					_parley.cmd.ChatFinder()
				end, 100)
			end
		end
		local recency_left_fn = make_recency_cycle("previous")  -- <C-a> / <Tab>
		local recency_right_fn = make_recency_cycle("next")     -- <C-s> / <S-Tab>

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
			local function refresh_picker()
				local new_items, new_tb_tags = build_picker_data()
				items = new_items
				if picker_ref.update then picker_ref.update(new_items, new_tb_tags) end
			end
			local function set_all_tags(value)
				_parley._chat_finder.tag_state = finder_facets.set_all(_parley._chat_finder.tag_state, value)
				refresh_picker()
			end
			local tag_bar = {
				tags = tag_bar_tags or {},
				on_toggle = function(tag_label)
					_parley._chat_finder.tag_state = finder_facets.toggle(
						_parley._chat_finder.tag_state,
						tag_label
					)
					refresh_picker()
				end,
				on_all  = function() set_all_tags(true)  end,
				on_none = function() set_all_tags(false) end,
			}

			local binding = finder_loader.open_picker({
				session = session,
				picker_open = _parley.float_picker.open,
				warning = function(failed_roots, failed_records)
					_parley.logger.warning(string.format(
						"Chat finder: partial scan (%d roots, %d files failed)",
						failed_roots,
						failed_records
					))
				end,
				materialize = function(outcome)
					entries = chat_records.materialize(outcome.records, {
						cutoff_time = is_filtering and cutoff_time or nil,
					})
					all_tags = finder_facets.discover(entries, chat_facets)
					_parley._chat_finder.tag_state = finder_facets.merge_state(
						_parley._chat_finder.tag_state,
						all_tags
					)
					local next_items, next_tags = build_picker_data()
					items = next_items
					return {
						items = next_items,
						tags = next_tags,
						initial_index = M.resolve_finder_initial_index(
							_parley._chat_finder,
							next_items,
							"ChatFinder"
						),
					}
				end,
				picker_options = {
				title = prompt_title,
				recall_key = "parley.chat_finder",
			initial_index = M.resolve_finder_initial_index(_parley._chat_finder, items, "ChatFinder"),
			initial_query = finder_sticky.format_initial_query(_parley._chat_finder.sticky_query),
			tag_bar = tag_bar,
			on_query_change = function(query)
				_parley._chat_finder.sticky_query = finder_sticky.extract(query, { "root", "tag" })
			end,
				on_select = function(item)
					_parley._chat_finder.opened = false
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
				-- Move left through recency presets (<C-a> and <Tab>)
				{
					key = next_recency_shortcut.shortcut,
					fn = recency_left_fn,
				},
				{
					key = cycle_filter_shortcut.shortcut,
					fn = recency_left_fn,
				},
				-- Move right through recency presets and "All" (<C-s> and <S-Tab>)
				{
					key = previous_recency_shortcut.shortcut,
					fn = recency_right_fn,
				},
				{
					key = cycle_filter_prev_shortcut.shortcut,
					fn = recency_right_fn,
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
				},
			})
			picker_ref.update = binding.picker.update
			session:start()
		end

	_parley._chat_finder.initial_index = nil
	_parley._chat_finder.initial_value = nil
end

return M
