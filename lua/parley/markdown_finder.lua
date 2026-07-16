-- Markdown file finder module for Parley
-- Finds markdown files from repo root, including parley-managed directories
-- (chats, notes, issues, history, vision). The contextual tag bar filters by
-- top-level directory in ordinary mode and repository in super-repo mode.

local M = {}
local _parley
local finder_facets = require("parley.finder_facets")
local finder_scan = require("parley.finder_scan")
local finder_loader = require("parley.finder_loader")
local finder_producer = require("parley.finder_producer")
local default_git_source = require("parley.git_markdown_source")
local default_file_source = require("parley.async_file_source")

M.setup = function(parley)
	_parley = parley
end

--- Extract the top-level directory tag from a relative path.
--- Files at root level get the tag ".".
local function top_level_dir(relative_path)
	local first_slash = relative_path:find("/")
	if first_slash then
		return relative_path:sub(1, first_slash - 1)
	end
	return "."
end

local function single_line(text)
	return text:gsub("[%z\1-\31\127]", " ")
end

M.path_candidate = function(root, relative, max_depth)
	if type(root) ~= "string" or root == "" or type(relative) ~= "string" or relative == "" then
		return nil
	end
	if relative:sub(1, 1) == "/" or relative:match("^%a:[/\\]") or not relative:match("%.md$") then
		return nil
	end

	local depth = 0
	for component in relative:gmatch("[^/]+") do
		if component == "." or component == ".." or component == "" then
			return nil
		end
		depth = depth + 1
	end
	if depth == 0 or depth > max_depth then
		return nil
	end

	return {
		relative = relative,
		unresolved_absolute = root:gsub("/+$", "") .. "/" .. relative,
	}
end

M.materialize_records = function(options)
	local records = finder_scan.deduplicate(options.records or {})
	records = finder_scan.sort(records, function(left, right)
		return (left.stat.mtime.sec or 0) > (right.stat.mtime.sec or 0)
	end)

	local entries = {}
	for _, record in ipairs(records) do
		local mtime = record.stat.mtime.sec or 0
		local native_path = record.resolved_absolute or record.unresolved_absolute
		assert(type(native_path) == "string", "Markdown record requires a native path")
		local tag = top_level_dir(record.relative)
		local prefix = ""
		if options.mode == "super_repo" then
			tag = record.root.name
			prefix = "{" .. tostring(tag or "") .. "} "
		end
		local picker_path = single_line(prefix .. record.relative)
		entries[#entries + 1] = {
			value = native_path,
			display = picker_path .. "  [" .. os.date("%Y-%m-%d", mtime) .. "]",
			search_text = picker_path:gsub("[/%-_]", " "),
			mtime = mtime,
			tag = tag,
			identity = record.identity,
		}
	end
	return entries
end

local function entry_facets(entry)
	return { entry.tag }
end

local function render_entry(entry)
	return {
		display = entry.display,
		search_text = entry.search_text,
		value = entry.value,
	}
end

local function repo_entries_match(entries, repo_facets)
	local known = {}
	for _, label in ipairs(repo_facets) do
		known[label] = true
	end
	for _, entry in ipairs(entries) do
		if type(entry.tag) ~= "string" or entry.tag == "" or not known[entry.tag] then
			return false
		end
	end
	return true
end

--- Build contextual picker data without reading runtime or module state.
--- @param opts table plain mode, entries, member roots, and facet states
--- @return table result with items, tags, facet domain, and copied states
M.build_picker_data = function(opts)
	opts = opts or {}
	local entries = opts.entries or {}
	local directory_state = finder_facets.merge_state(opts.directory_state, {})
	local repo_state = finder_facets.merge_state(opts.repo_state, {})
	local visible = entries
	local tags
	local facet_domain

	if opts.mode == "ordinary" then
		local directory_facets = finder_facets.discover(entries, entry_facets, "source")
		if #directory_facets >= 2 then
			facet_domain = "directory"
			directory_state = finder_facets.merge_state(directory_state, directory_facets)
			visible = finder_facets.filter(entries, directory_state, entry_facets)
			tags = finder_facets.project(directory_facets, directory_state)
		end
	elseif opts.mode == "super_repo" then
		local repo_facets = finder_facets.eligible_labels(opts.member_roots or {}, true, function(root)
			return root.name
		end)
		if repo_facets and repo_entries_match(entries, repo_facets) then
			facet_domain = "repo"
			repo_state = finder_facets.merge_state(repo_state, repo_facets)
			visible = finder_facets.filter(entries, repo_state, entry_facets)
			tags = finder_facets.project(repo_facets, repo_state)
		end
	end

	local items = {}
	for _, entry in ipairs(visible) do
		table.insert(items, render_entry(entry))
	end

	return {
		items = items,
		tags = tags,
		facet_domain = facet_domain,
		directory_state = directory_state,
		repo_state = repo_state,
	}
end

local function valid_roots(mode, member_roots, repo_root)
	if mode == "ordinary" then
		return { { path = repo_root } }
	end

	local roots = {}
	for _, member in ipairs(member_roots) do
		if type(member.path) == "string" and member.path ~= "" then
			roots[#roots + 1] = { path = member.path, name = member.name }
		end
	end
	return roots
end

local function acquisition(dependencies, roots, max_depth)
	return function(on_root, on_complete)
		local cancelled = false
		local pending = #roots
		local settled_roots = {}
		local handles = {}
		local handle = {}

		local function add_handle(child)
			if type(child) ~= "table" or type(child.cancel) ~= "function" then
				return
			end
			if cancelled then
				pcall(child.cancel, child)
			else
				handles[#handles + 1] = child
			end
		end

		local function finish_root(ordinal, event)
			if cancelled or settled_roots[ordinal] then
				return
			end
			settled_roots[ordinal] = true
			pending = pending - 1
			on_root(event)
			if pending == 0 then
				on_complete()
			end
		end

		local function fail_root(ordinal, kind, diagnostic)
			finish_root(ordinal, {
				root_ordinal = ordinal,
				status = "failed",
				failure = { kind = kind, diagnostic = diagnostic },
			})
		end

		for ordinal, root in ipairs(roots) do
			local ok, git_handle = pcall(dependencies.git_markdown_source.list, {
				root = root.path,
				root_ordinal = ordinal,
				executable = dependencies.git_executable,
				env = dependencies.git_env,
			}, function(result)
				if cancelled or settled_roots[ordinal] then
					return
				end
				if type(result) ~= "table" or result.status ~= "success" then
					local failure = type(result) == "table" and result.failure or nil
					fail_root(
						ordinal,
						failure and failure.kind or finder_scan.FAILURE_KIND.root_enumeration,
						failure and failure.diagnostic or nil
					)
					return
				end

				local paths = {}
				for _, relative in ipairs(result.paths or {}) do
					local candidate = M.path_candidate(root.path, relative, max_depth)
					if candidate then
						paths[#paths + 1] = candidate.relative
					end
				end
				local read_ok, read_handle = pcall(dependencies.async_file_source.read_paths, {
					root = root,
					root_ordinal = ordinal,
					paths = paths,
					read = "none",
					concurrency = 16,
				}, function(result_set)
					if cancelled or settled_roots[ordinal] then
						return
					end
					local candidates = result_set.candidates or {}
					local failures = result_set.failures or {}
					table.sort(candidates, function(left, right) return left.relative < right.relative end)
					table.sort(failures, function(left, right)
						return (left.relative or "") < (right.relative or "")
					end)
					for _, candidate in ipairs(candidates) do
						candidate.identity = finder_scan.path_identity({
							unresolved_absolute = candidate.unresolved_absolute,
							resolved_absolute = candidate.resolved_absolute,
							root_ordinal = candidate.root_ordinal,
						})
					end
					finish_root(ordinal, {
						root_ordinal = ordinal,
						status = "success",
						candidates = candidates,
						failures = failures,
					})
				end)
				if read_ok then
					add_handle(read_handle)
				else
					fail_root(ordinal, finder_scan.FAILURE_KIND.root_enumeration)
				end
			end)
			if ok then
				add_handle(git_handle)
			else
				fail_root(ordinal, finder_scan.FAILURE_KIND.root_enumeration)
			end
		end

		if pending == 0 and #roots == 0 then
			on_complete()
		end

		handle.cancel = function()
			if cancelled then
				return
			end
			cancelled = true
			for _, child in ipairs(handles) do
				pcall(child.cancel, child)
			end
		end
		handle.is_cancelled = function() return cancelled end
		return handle
	end
end

M.open = function()
	local config = _parley.config
	local max_depth = config.markdown_finder_max_depth or 4

	local super_state = _parley.super_repo and _parley.super_repo.get_state()
		or { active = false, members = {} }
	local mode = super_state.active and "super_repo" or "ordinary"
	local member_roots = super_state.members or {}
	local repo_root = config.repo_root
	if mode == "ordinary" and (not repo_root or repo_root == "") then
		repo_root = _parley.helpers.find_git_root(vim.fn.getcwd())
		if repo_root == "" then
			_parley.logger.warning("Markdown finder: not in a git repository")
			return
		end
	end
	local roots = valid_roots(mode, member_roots, repo_root)
	local snapshot = finder_scan.snapshot({
		kind = "markdown",
		roots = roots,
		max_depth = max_depth,
		pattern = "*.md",
		backend = "git",
	})
	local dependencies = _parley._finder_dependencies or {}
	dependencies = {
		git_markdown_source = dependencies.git_markdown_source or default_git_source,
		async_file_source = dependencies.async_file_source or default_file_source,
		git_executable = dependencies.git_executable,
		git_env = dependencies.git_env,
		now = dependencies.now or function()
			return (vim.uv or vim.loop).hrtime() / 1000000
		end,
		schedule = dependencies.schedule or vim.schedule,
	}
	local entries = {}
	local picker_data = { facet_domain = nil, items = {}, tags = nil }

	local function compute_picker_data()
		local result = M.build_picker_data({
			mode = mode,
			entries = entries,
			member_roots = member_roots,
			directory_state = _parley._markdown_finder.directory_facet_state,
			repo_state = _parley._markdown_finder.repo_facet_state,
		})
		_parley._markdown_finder.directory_facet_state = result.directory_state
		_parley._markdown_finder.repo_facet_state = result.repo_state
		return result
	end

	local source_win = vim.api.nvim_get_current_win()
	local picker_ref = {}
	local function refresh_picker()
		picker_data = compute_picker_data()
		if picker_ref.update then
			picker_ref.update(picker_data.items, picker_data.tags)
		end
	end
	local function update_active_state(update)
		if picker_data.facet_domain == "directory" then
			_parley._markdown_finder.directory_facet_state = update(
				_parley._markdown_finder.directory_facet_state
			)
		elseif picker_data.facet_domain == "repo" then
			_parley._markdown_finder.repo_facet_state = update(
				_parley._markdown_finder.repo_facet_state
			)
		end
		refresh_picker()
	end
	local tag_bar = {
		tags = {},
		on_toggle = function(tag_label)
			update_active_state(function(state) return finder_facets.toggle(state, tag_label) end)
		end,
		on_all = function()
			update_active_state(function(state) return finder_facets.set_all(state, true) end)
		end,
		on_none = function()
			update_active_state(function(state) return finder_facets.set_all(state, false) end)
		end,
	}

	local session = finder_loader.new_session({
		snapshot = snapshot,
		ownership = "picker",
		schedule = dependencies.schedule,
		producer_factory = function(settle)
			local data = snapshot:copy()
			return finder_producer.run({
				roots = data.roots,
				acquire = acquisition(dependencies, data.roots, data.max_depth),
				adapter = function(candidate) return { kind = "record", value = candidate } end,
				finalize = function(records) return records end,
				batch = {
					item_budget = 25,
					time_budget_ms = 5,
					now = dependencies.now,
					schedule = dependencies.schedule,
				},
			}, settle)
		end,
	})
	local binding = finder_loader.open_picker({
		session = session,
		picker_open = _parley.float_picker.open,
		warning = function(failed_roots, failed_records)
			_parley.logger.warning(string.format(
				"Markdown finder: partial scan (%d roots, %d files failed)",
				failed_roots,
				failed_records
			))
		end,
		materialize = function(outcome)
			entries = M.materialize_records({ mode = mode, records = outcome.records })
			picker_data = compute_picker_data()
			return picker_data
		end,
		picker_options = {
		title = "Markdown Files",
		recall_key = "parley.markdown_finder",
		anchor = "bottom",
		initial_query = _parley._markdown_finder.query,
		on_query_change = function(query)
			_parley._markdown_finder.query = query
		end,
		tag_bar = tag_bar,
		on_select = function(item)
			if source_win and vim.api.nvim_win_is_valid(source_win) then
				vim.api.nvim_set_current_win(source_win)
			end
			_parley.open_buf(item.value, true)
		end,
		on_cancel = function() end,
		},
	})
	picker_ref.update = binding.picker.update
	session:start()
end

return M
