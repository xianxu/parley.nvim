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

--- Load custom prompts from disk.
---@return table<string, table>  map of name → { system_prompt = "...", ... }
M.load = function()
	local path = M.file_path()
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return _helpers.file_to_table(path) or {}
end

--- Save custom prompts to disk.
---@param prompts table<string, table>  map of name → { system_prompt = "...", ... }
M.save = function(prompts)
	_helpers.table_to_file(prompts, M.file_path())
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
M.set = function(name, prompt)
	local all = M.load()
	all[name] = prompt
	M.save(all)
end

--- Remove a custom prompt by name and save. Returns true if it existed.
---@param name string
---@return boolean
M.remove = function(name)
	local all = M.load()
	if all[name] then
		all[name] = nil
		M.save(all)
		return true
	end
	return false
end

--- Rename a custom prompt. Returns true on success.
---@param old_name string
---@param new_name string
---@return boolean
M.rename = function(old_name, new_name)
	local all = M.load()
	if not all[old_name] or all[new_name] then
		return false
	end
	all[new_name] = all[old_name]
	all[old_name] = nil
	M.save(all)
	return true
end

--- Determine the source of a prompt: "builtin", "custom", or "modified".
---@param name string
---@param builtin_prompts table  M._builtin_system_prompts snapshot
---@return string  "builtin" | "custom" | "modified"
M.source = function(name, builtin_prompts)
	local custom = M.get(name)
	local is_builtin = builtin_prompts[name] ~= nil
	if custom then
		return is_builtin and "modified" or "custom"
	end
	return "builtin"
end

return M
