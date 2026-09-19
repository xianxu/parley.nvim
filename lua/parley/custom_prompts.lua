-- Custom system prompts persistence for Parley.nvim
-- Loads/saves user-edited system prompts from {state_dir}/custom_system_prompts.json

local M = {}

local _helpers = nil
local _state_dir = nil

--- Store shared references from init.lua.
---@param helpers table  parley.helper module
---@param state_dir string  path to state directory
M.setup = function(helpers, state_dir)
	_helpers = helpers
	_state_dir = state_dir
end

--- Return the path to the custom prompts JSON file.
---@return string
M.file_path = function()
	return _state_dir .. "/custom_system_prompts.json"
end

--- The file's table: `{}` when there is no file, nil when a file exists but
--- cannot be read (file_to_table has already said so, once).
local function read_file()
	local path = M.file_path()
	if vim.fn.filereadable(path) == 0 then return {} end
	return _helpers.file_to_table(path)
end

--- Load custom prompts from disk.
---@return table<string, table>  map of name → { system_prompt = "...", ... }
M.load = function()
	-- #261: callers see only prompts they can use — a table carrying a string
	-- system_prompt. This is a VIEW: the file is authored by the user, so the
	-- writes below work on the file as written and never persist the filter
	-- (#261 M1 review BR-5).
	local raw = read_file()
	if not raw then return {} end
	local view = _helpers.conform(vim.deepcopy(raw), { ["*"] = { system_prompt = "string" } }, M.file_path())
	for name, prompt in pairs(view) do
		if prompt.system_prompt == nil then view[name] = nil end
	end
	return view
end

--- The file as the user wrote it — every entry, usable or not — for the
--- writes. `{}` when there is no file; nil when a file exists but cannot be
--- read, so a write refuses rather than replacing it (file_to_table has warned).
---@return table|nil
M.read_authored = function()
	local authored = read_file()
	if not authored then
		require("parley.logger").warning("Custom prompt not saved: " .. M.file_path()
			.. " exists but cannot be read; fix or remove it first")
	end
	return authored
end

--- Save custom prompts to disk.
---@param prompts table<string, table>  map of name → { system_prompt = "...", ... }
---@return boolean|nil ok
---@return string|nil err
M.save = function(prompts)
	return _helpers.table_to_file(prompts, M.file_path())
end

--- Get a single custom prompt by name, or nil.
---@param name string
---@return table|nil
M.get = function(name)
	local all = M.load()
	return all[name]
end

--- Set (create or update) a custom prompt and save.
---@param name string
---@param prompt table  { system_prompt = "...", ... }
--- Returns whether the prompt reached the file — false when the file could not
--- be read (it is never replaced) or written.
---@return boolean
M.set = function(name, prompt)
	local all = M.read_authored()
	if not all then return false end
	all[name] = prompt
	return M.save(all) == true
end

--- Remove a custom prompt by name and save. Returns true if it existed.
---@param name string
---@return boolean
M.remove = function(name)
	local all = M.read_authored()
	if all and all[name] then
		all[name] = nil
		return M.save(all) == true
	end
	return false
end

--- Rename a custom prompt. Returns true on success.
---@param old_name string
---@param new_name string
---@return boolean
M.rename = function(old_name, new_name)
	local all = M.read_authored()
	if not all or not all[old_name] or all[new_name] then
		return false
	end
	all[new_name] = all[old_name]
	all[old_name] = nil
	return M.save(all) == true
end

--- Determine the source of a prompt: "builtin", "custom", or "modified".
---@param name string
---@param builtin_prompts table  M._builtin_system_prompts snapshot
---@return string  "builtin" | "custom" | "modified"
--- `loaded`, when given, is a `load()` result to consult instead of reading the
--- file again: a caller classifying every prompt reads once, not once per prompt
--- (#261 M1 review BR-15).
M.source = function(name, builtin_prompts, loaded)
	local custom
	if loaded then custom = loaded[name] else custom = M.get(name) end
	local is_builtin = builtin_prompts[name] ~= nil
	if custom then
		return is_builtin and "modified" or "custom"
	end
	return "builtin"
end

return M
