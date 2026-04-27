-- parley.super_repo — super-repo mode (read-aggregation overlay)
--
-- Toggle activates a runtime overlay on top of plain repo mode:
--   * Discovers sibling .parley repos under the current repo's parent dir.
--   * Pushes their workshop/parley and workshop/notes paths into chat_roots
--     and note_roots as extras (label = "repo" so they are filtered out of
--     persisted state.json — see init.lua persistence gate).
--   * Writes are unchanged: still go to the current repo, exactly as plain
--     repo mode does today.
--
-- Toggle is transient — never persisted.

local M = {}
local _parley

-- Active state. Cleared on toggle-off.
local _state = {
	active = false,
	workspace_root = nil,
	members = {},          -- list of { path, name }
	pushed_chat_dirs = {}, -- resolved paths we appended (for cleanup)
	pushed_note_dirs = {}, -- resolved paths we appended (for cleanup)
}

local function resolve_dir_key(dir)
	local out = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
	return out
end

M.setup = function(parley)
	_parley = parley
end

M.is_active = function()
	return _state.active
end

M.get_state = function()
	return {
		active = _state.active,
		workspace_root = _state.workspace_root,
		members = vim.deepcopy(_state.members),
	}
end

--- Resolved paths of sibling chat dirs currently pushed into chat_roots.
--- Used by the persistence gate in init.lua to exclude these from state.json.
M.get_pushed_chat_dirs = function()
	return vim.deepcopy(_state.pushed_chat_dirs)
end

--- Resolved paths of sibling note dirs currently pushed into note_roots.
M.get_pushed_note_dirs = function()
	return vim.deepcopy(_state.pushed_note_dirs)
end

--- Compute per-finder roots for a given repo-relative subdir (e.g. "workshop/issues").
--- When super-repo is active and has members, returns a list of
--- `{ dir = <abs>, repo_name = <name> }` per member. Otherwise returns nil so
--- the caller falls back to its single-repo path.
--- @param subdir string repo-relative path (or absolute; absolute is left as-is)
--- @return table|nil list of {dir, repo_name} or nil for single-repo
M.expand_roots = function(subdir)
	if not _state.active or #_state.members == 0 then
		return nil
	end
	if type(subdir) ~= "string" or subdir == "" then
		return nil
	end
	local roots = {}
	for _, m in ipairs(_state.members) do
		local dir = subdir
		if dir:sub(1, 1) ~= "/" then
			dir = m.path .. "/" .. dir
		end
		table.insert(roots, { dir = dir, repo_name = m.name })
	end
	return roots
end

--- Compute sibling .parley repos under repo_root's parent directory.
--- Returns { workspace_root, members } where members is a list of
--- { path, name } sorted by name. Returns nil, err on failure.
M.compute_members = function(repo_root)
	if type(repo_root) ~= "string" or repo_root == "" then
		return nil, "repo_root is empty"
	end
	local resolved = resolve_dir_key(repo_root)
	local workspace_root = vim.fn.fnamemodify(resolved, ":h")
	if not workspace_root or workspace_root == "" or workspace_root == "/" or workspace_root == resolved then
		return nil, "repo_root has no parent"
	end
	local matches = vim.fn.glob(workspace_root .. "/*/.parley", false, true) or {}
	local members = {}
	for _, marker in ipairs(matches) do
		local path = vim.fn.fnamemodify(marker, ":h")
		local name = vim.fn.fnamemodify(path, ":t")
		table.insert(members, { path = path, name = name })
	end
	table.sort(members, function(a, b) return a.name < b.name end)
	return { workspace_root = workspace_root, members = members }
end

local function fire_changed()
	pcall(function()
		vim.api.nvim_exec_autocmds("User", { pattern = "ParleySuperRepoChanged", modeline = false })
	end)
end

local function activate()
	if _state.active then return true end

	local repo_root = _parley.config.repo_root
	if type(repo_root) ~= "string" or repo_root == "" then
		_parley.logger.warning("super-repo: cwd is not inside a .parley repo")
		return false, "not in repo"
	end

	local discovered, err = M.compute_members(repo_root)
	if not discovered then
		_parley.logger.warning("super-repo: " .. (err or "discovery failed"))
		return false, err
	end

	local current_resolved = resolve_dir_key(repo_root)
	local repo_chat_subdir = _parley.config.repo_chat_dir or "workshop/parley"
	local repo_note_subdir = _parley.config.repo_note_dir or "workshop/notes"

	-- Build sibling dir lists (excluding current repo, which is already primary).
	-- Label = repo name so the finder UI shows "{ariadne}" / "{brain}" etc.
	-- Persistence filtering is handled separately (init.lua persist gate consults
	-- super_repo.get_pushed_*_dirs() to drop these from state.json), so we don't
	-- need to overload the label as a sentinel.
	local sibling_chat_roots = {}
	local sibling_note_roots = {}
	for _, m in ipairs(discovered.members) do
		if resolve_dir_key(m.path) ~= current_resolved then
			table.insert(sibling_chat_roots, {
				dir = m.path .. "/" .. repo_chat_subdir,
				label = m.name,
			})
			table.insert(sibling_note_roots, {
				dir = m.path .. "/" .. repo_note_subdir,
				label = m.name,
			})
		end
	end

	-- Append to existing chat_roots / note_roots (persist=false: transient)
	local new_chat_roots = vim.deepcopy(_parley.get_chat_roots())
	for _, r in ipairs(sibling_chat_roots) do
		table.insert(new_chat_roots, r)
	end
	_parley.set_chat_roots(new_chat_roots, false)

	local new_note_roots = vim.deepcopy(_parley.get_note_roots())
	for _, r in ipairs(sibling_note_roots) do
		table.insert(new_note_roots, r)
	end
	_parley.set_note_roots(new_note_roots, false)

	_state.active = true
	_state.workspace_root = discovered.workspace_root
	_state.members = vim.deepcopy(discovered.members)
	_state.pushed_chat_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_chat_roots)
	_state.pushed_note_dirs = vim.tbl_map(function(r) return resolve_dir_key(r.dir) end, sibling_note_roots)
	_parley.config.super_repo_root = discovered.workspace_root
	_parley.config.super_repo_members = vim.deepcopy(discovered.members)

	fire_changed()
	return true
end

local function strip_pushed(roots, pushed_set)
	local kept = {}
	for _, r in ipairs(roots) do
		if not pushed_set[resolve_dir_key(r.dir)] then
			table.insert(kept, r)
		end
	end
	return kept
end

local function deactivate()
	if not _state.active then return true end

	local pushed_chat_set = {}
	for _, d in ipairs(_state.pushed_chat_dirs) do pushed_chat_set[d] = true end
	local pushed_note_set = {}
	for _, d in ipairs(_state.pushed_note_dirs) do pushed_note_set[d] = true end

	-- Always re-apply, even when the user has mutated roots in the meantime.
	-- The set_*_roots API requires at least one root, so fall back to the
	-- existing primary if stripping pushed siblings would leave nothing.
	local kept_chat = strip_pushed(vim.deepcopy(_parley.get_chat_roots()), pushed_chat_set)
	if #kept_chat > 0 then
		_parley.set_chat_roots(kept_chat, false)
	end
	local kept_note = strip_pushed(vim.deepcopy(_parley.get_note_roots()), pushed_note_set)
	if #kept_note > 0 then
		_parley.set_note_roots(kept_note, false)
	end

	_state.active = false
	_state.workspace_root = nil
	_state.members = {}
	_state.pushed_chat_dirs = {}
	_state.pushed_note_dirs = {}
	_parley.config.super_repo_root = nil
	_parley.config.super_repo_members = nil

	fire_changed()
	return true
end

M.toggle = function()
	if _state.active then
		return deactivate()
	end
	return activate()
end

return M
