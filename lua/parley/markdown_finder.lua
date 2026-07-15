-- Markdown file finder module for Parley
-- Finds markdown files from repo root, including parley-managed directories
-- (chats, notes, issues, history, vision). The tag bar lets users filter by
-- top-level directory if they want to hide categories.

local M = {}
local _parley
local finder_facets = require("parley.finder_facets")

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

--- Scan markdown files from repo_root up to max_depth levels.
--- @param repo_root string absolute path to git root
--- @param max_depth number maximum directory depth to search
--- @return table list of {value, display, search_text, mtime, tag}
local function scan_markdown_files(repo_root, max_depth)
	local files = {}
	local seen = {}

	for depth = 1, max_depth do
		local pattern = repo_root
		for _ = 1, depth - 1 do
			pattern = pattern .. "/*"
		end
		pattern = pattern .. "/*.md"

		local matches = vim.fn.glob(pattern, false, true)
		for _, file in ipairs(matches) do
			local resolved = vim.fn.resolve(file)
			if not seen[resolved] and vim.fn.isdirectory(file) == 0 then
				seen[resolved] = true
				table.insert(files, resolved)
			end
		end
	end

	local root_prefix = vim.fn.resolve(repo_root):gsub("/+$", "") .. "/"
	local entries = {}
	for _, file in ipairs(files) do
		local stat = vim.loop.fs_stat(file)
		if stat then
			local relative = file:sub(1, #root_prefix) == root_prefix
				and file:sub(#root_prefix + 1)
				or vim.fn.fnamemodify(file, ":t")
			local tag = top_level_dir(relative)

			table.insert(entries, {
				value = file,
				display = relative .. "  [" .. os.date("%Y-%m-%d", stat.mtime.sec) .. "]",
				search_text = relative:gsub("[/%-_]", " "),
				mtime = stat.mtime.sec,
				tag = tag,
			})
		end
	end

	table.sort(entries, function(a, b)
		return a.mtime > b.mtime
	end)

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

--- Aggregate markdown entries across super-repo members.
--- Each entry is tagged by repo name and its display becomes "<repo>/<relative>".
M._scan_members = function(members, max_depth)
	local entries = {}
	for _, m in ipairs(members or {}) do
		if type(m.path) == "string" and m.path ~= "" then
			local root_prefix = vim.fn.resolve(m.path):gsub("/+$", "") .. "/"
			local sub_entries = scan_markdown_files(m.path, max_depth)
			for _, e in ipairs(sub_entries) do
				local relative = e.value:sub(1, #root_prefix) == root_prefix
					and e.value:sub(#root_prefix + 1)
					or vim.fn.fnamemodify(e.value, ":t")
				if type(m.name) == "string" and m.name ~= "" then
					e.display = "{" .. m.name .. "} " .. relative .. "  [" .. os.date("%Y-%m-%d", e.mtime) .. "]"
					e.search_text = "{" .. m.name .. "} " .. (relative:gsub("[/%-_]", " "))
					e.tag = m.name
				else
					e.tag = nil
				end
				table.insert(entries, e)
			end
		end
	end
	table.sort(entries, function(a, b) return a.mtime > b.mtime end)
	return entries
end

M.open = function()
	local config = _parley.config
	local max_depth = config.markdown_finder_max_depth or 4

	local super_state = _parley.super_repo and _parley.super_repo.get_state()
		or { active = false, members = {} }
	local mode = super_state.active and "super_repo" or "ordinary"
	local member_roots = super_state.members or {}

	local entries
	if mode == "super_repo" then
		entries = M._scan_members(member_roots, max_depth)
	else
		local repo_root = config.repo_root
		if not repo_root or repo_root == "" then
			repo_root = _parley.helpers.find_git_root(vim.fn.getcwd())
			if repo_root == "" then
				_parley.logger.warning("Markdown finder: not in a git repository")
				return
			end
		end
		entries = scan_markdown_files(repo_root, max_depth)
	end

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

	local picker_data = compute_picker_data()

	local source_win = vim.api.nvim_get_current_win()
	local picker_ref = {}

	local tag_bar = nil
	if picker_data.tags then
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
		tag_bar = {
			tags = picker_data.tags,
			on_toggle = function(tag_label)
				update_active_state(function(state)
					return finder_facets.toggle(state, tag_label)
				end)
			end,
			on_all = function()
				update_active_state(function(state)
					return finder_facets.set_all(state, true)
				end)
			end,
			on_none = function()
				update_active_state(function(state)
					return finder_facets.set_all(state, false)
				end)
			end,
		}
	end

	local picker = _parley.float_picker.open({
		title = "Markdown Files",
		items = picker_data.items,
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
	})
	picker_ref.update = picker and picker.update or nil
end

return M
