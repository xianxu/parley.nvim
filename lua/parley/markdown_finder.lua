-- Markdown file finder module for Parley
-- Finds markdown files from repo root, excluding parley-managed directories

local M = {}
local _parley

-- Tag state persists across opens within a session
local _tag_state = {} -- { [dir_name] = true/false }

M.setup = function(parley)
	_parley = parley
end

--- Build the set of absolute directory prefixes that parley manages.
--- Files under these prefixes are excluded from results.
local function managed_prefixes(repo_root, config)
	local prefixes = {}
	local managed_dirs = {
		config.repo_chat_dir,
		config.issues_dir,
		config.history_dir,
		config.vision_dir,
	}
	for _, dir in ipairs(managed_dirs) do
		if dir and dir ~= "" and not dir:match("^/") then
			local abs = repo_root .. "/" .. dir
			table.insert(prefixes, vim.fn.resolve(abs) .. "/")
		end
	end
	-- Also exclude notes_dir if it falls within the repo
	local notes = vim.fn.expand(config.notes_dir or "")
	if notes ~= "" then
		local resolved_notes = vim.fn.resolve(notes) .. "/"
		if resolved_notes:sub(1, #repo_root) == repo_root then
			table.insert(prefixes, resolved_notes)
		end
	end
	return prefixes
end

--- Check if a resolved path is under any managed prefix.
local function is_managed(resolved_path, prefixes)
	for _, prefix in ipairs(prefixes) do
		if resolved_path:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
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
--- @param prefixes table list of managed directory prefixes to exclude
--- @return table list of {value, display, search_text, mtime, tag}
local function scan_markdown_files(repo_root, max_depth, prefixes)
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
				if not is_managed(resolved, prefixes) then
					table.insert(files, resolved)
				end
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

--- Build picker items and tag bar from entries, respecting tag_state.
--- @return table items, table|nil tag_bar_tags, table all_tags_ordered
local function build_picker_data(entries)
	-- Collect unique tags in order of first appearance (mtime-sorted)
	local tag_order = {}
	local tag_seen = {}
	for _, entry in ipairs(entries) do
		if not tag_seen[entry.tag] then
			tag_seen[entry.tag] = true
			table.insert(tag_order, entry.tag)
		end
	end

	-- Check if any tag is disabled
	local any_disabled = false
	for _, tag in ipairs(tag_order) do
		if _tag_state[tag] == false then
			any_disabled = true
			break
		end
	end

	-- Build filtered items
	local items = {}
	for _, entry in ipairs(entries) do
		local enabled = _tag_state[entry.tag] ~= false
		if not any_disabled or enabled then
			table.insert(items, {
				display = entry.display,
				search_text = entry.search_text,
				value = entry.value,
			})
		end
	end

	-- Build tag bar tags
	local tag_bar_tags = nil
	if #tag_order > 1 then
		tag_bar_tags = {}
		for _, tag in ipairs(tag_order) do
			table.insert(tag_bar_tags, {
				label = tag,
				enabled = _tag_state[tag] ~= false,
			})
		end
	end

	return items, tag_bar_tags
end

M.open = function()
	local config = _parley.config
	local repo_root = config.repo_root
	if not repo_root or repo_root == "" then
		repo_root = _parley.helpers.find_git_root(vim.fn.getcwd())
		if repo_root == "" then
			_parley.logger.warning("Markdown finder: not in a git repository")
			return
		end
	end

	local max_depth = config.markdown_finder_max_depth or 4
	local prefixes = managed_prefixes(repo_root, config)
	local entries = scan_markdown_files(repo_root, max_depth, prefixes)
	local items, tag_bar_tags = build_picker_data(entries)

	local source_win = vim.api.nvim_get_current_win()
	local picker_ref = {}

	local tag_bar = nil
	if tag_bar_tags then
		local function refresh_picker()
			local new_items, new_tb_tags = build_picker_data(entries)
			if picker_ref.update then
				picker_ref.update(new_items, new_tb_tags)
			end
		end
		local function set_all_tags(value)
			for _, entry in ipairs(entries) do
				_tag_state[entry.tag] = value
			end
			refresh_picker()
		end
		tag_bar = {
			tags = tag_bar_tags,
			on_toggle = function(tag_label)
				_tag_state[tag_label] = _tag_state[tag_label] == false
				refresh_picker()
			end,
			on_all = function()
				set_all_tags(true)
			end,
			on_none = function()
				set_all_tags(false)
			end,
		}
	end

	local picker = _parley.float_picker.open({
		title = "Markdown Files",
		items = items,
		anchor = "bottom",
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
