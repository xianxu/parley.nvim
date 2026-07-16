-- Note finder module for Parley
-- Handles the NoteFinder UI command and related helpers

local M = {}
local _parley
local _chat_finder_mod  -- set after both modules are loaded
local finder_sticky = require("parley.finder_sticky")
local finder_scan = require("parley.finder_scan")
local finder_loader = require("parley.finder_loader")
local finder_producer = require("parley.finder_producer")
local async_file_source = require("parley.async_file_source")
local note_records = require("parley.note_finder_records")

-- Mtime-based cache: avoids re-classifying and re-stating unchanged files.
-- Key: resolved file path, Value: { mtime, classification, inferred_time }
local _file_cache = {}

local _prewarm_session

M.setup = function(parley)
	_parley = parley
	_chat_finder_mod = require("parley.chat_finder")
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
		M.invalidate_path(item_value)
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
	for ordinal, root in ipairs(_parley.get_note_roots() or {}) do
		roots[#roots + 1] = {
			path = vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"):gsub("/+$", ""),
			label = root.label,
			is_primary = root.is_primary == true or ordinal == 1,
			optional = true,
		}
	end
	return finder_scan.snapshot({
		kind = "note",
		roots = roots,
		recursion = true,
		max_depth = math.huge,
		pattern = "*.md",
		backend = { source = "libuv", body = "none" },
	})
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
						recurse = true,
						max_depth = data.max_depth,
						match = function(relative)
							return relative:match("%.md$") ~= nil
						end,
						read_policy = function(candidate)
							return note_records.read_decision(_file_cache, {
								identity = identity_for(candidate),
								stat = candidate.stat,
							})
						end,
						concurrency = 16,
					}, on_root, on_complete)
				end,
				adapter = function(candidate)
					candidate.identity = candidate.identity or identity_for(candidate)
					return note_records.adapt(candidate)
				end,
				finalize = function(records)
					return finder_scan.sort(finder_scan.deduplicate(records), function(left, right)
						if left.timestamp ~= right.timestamp then
							return left.timestamp > right.timestamp
						end
						return left.modified_time > right.modified_time
					end)
				end,
				batch = {
					item_budget = 25,
					time_budget_ms = 5,
					now = dependencies.now,
					schedule = dependencies.schedule,
				},
				on_record = function(record)
					local cached = note_records.cache_entry(record)
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
					"NoteFinder prewarm: %s (%d roots, %d files failed)",
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

M._materialize_records = note_records.materialize
M._discovery_snapshot = discovery_snapshot
-- Open the picker immediately, then materialize the recursive disk scan into it.
M.open = function(_)
	if _parley._note_finder.opened then
		_parley.logger.warning("Note finder is already open")
		return
	end
	_parley._note_finder.opened = true

	local snapshot = discovery_snapshot()
	local session
	if _prewarm_session and not _prewarm_session:is_retired()
		and _prewarm_session:fingerprint() == snapshot:fingerprint() then
		session = _prewarm_session
	else
		session = new_session(snapshot, "picker", false)
	end

	local mappings = _parley.config.note_finder_mappings or {}
	local delete_shortcut = mappings.delete or _parley.config.chat_shortcut_delete
	local next_recency_shortcut = mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = _parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }
	local recency_config = _parley.config.note_finder_recency or {
		filter_by_default = true,
		months = 3,
	}
	local resolved_recency = _parley._resolve_note_finder_recency(
		recency_config,
		_parley._note_finder.recency_index
	)
	_parley._note_finder.recency_index = resolved_recency.index
	_parley._note_finder.show_all = resolved_recency.current.is_all
	local cutoff_time
	if resolved_recency.current.months then
		cutoff_time = os.time() - (resolved_recency.current.months * 30 * 24 * 60 * 60)
	end

	local items = {}
	local source_win = _parley._note_finder.source_win
	if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
		source_win = vim.api.nvim_get_current_win()
		_parley._note_finder.source_win = source_win
	end

	local function cycle_recency(direction)
		return function(_, close_fn)
			local next_index, next_state = _parley._cycle_note_finder_recency(
				recency_config,
				_parley._note_finder.recency_index,
				direction
			)
			_parley._note_finder.recency_index = next_index
			_parley._note_finder.show_all = next_state.is_all
			close_fn()
			vim.defer_fn(function()
				_parley._note_finder.opened = false
				_parley._note_finder.source_win = source_win
				_parley.cmd.NoteFinder()
			end, 100)
		end
	end

	finder_loader.open_picker({
		session = session,
		picker_open = _parley.float_picker.open,
		warning = function(failed_roots, failed_records)
			_parley.logger.warning(string.format(
				"Note finder: partial scan (%d roots, %d files failed)",
				failed_roots,
				failed_records
			))
		end,
		materialize = function(outcome)
			local entries = note_records.materialize(outcome.records, {
				cutoff_time = resolved_recency.current.is_all and nil or cutoff_time,
			})
			local next_items = {}
			for _, entry in ipairs(entries) do
				next_items[#next_items + 1] = {
					display = entry.display,
					search_text = entry.ordinal,
					value = entry.value,
				}
			end
			items = next_items
			return {
				items = next_items,
				initial_index = _chat_finder_mod.resolve_finder_initial_index(
					_parley._note_finder,
					next_items,
					"NoteFinder"
				),
			}
		end,
		picker_options = {
			title = string.format(
				"Note Files (%s  %s/%s: cycle)",
				resolved_recency.current.label,
				next_recency_shortcut.shortcut,
				previous_recency_shortcut.shortcut
			),
			recall_key = "parley.note_finder",
			initial_index = _chat_finder_mod.resolve_finder_initial_index(
				_parley._note_finder,
				items,
				"NoteFinder"
			),
			initial_query = finder_sticky.format_initial_query(_parley._note_finder.sticky_query),
			anchor = "bottom",
			on_query_change = function(query)
				_parley._note_finder.sticky_query = finder_sticky.extract(query, { "root" })
			end,
			on_select = function(item)
				_parley._note_finder.opened = false
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
						for index, picker_item in ipairs(items) do
							if picker_item.value == item.value then
								selected_index = index
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
				{ key = next_recency_shortcut.shortcut, fn = cycle_recency("previous") },
				{ key = previous_recency_shortcut.shortcut, fn = cycle_recency("next") },
				{
					key = keybindings_shortcut.shortcut,
					fn = function()
						vim.schedule(function()
							_parley.cmd.KeyBindings("note_finder")
						end)
					end,
				},
			},
		},
	})
	session:start()

	_parley._note_finder.initial_index = nil
	_parley._note_finder.initial_value = nil
end

return M
